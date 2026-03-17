# 검색 기능 개선 설계

> 작성일: 2026-03-06
> 상태: 구현 완료 (Phase 1~4)

---

## 1. 현재 상태 분석

### 현재 구현
- **RPC**: `search_posts(p_query, p_limit, p_offset)` — ILIKE 기반 제목+본문 검색
- **인덱스**: pg_trgm GIN 트라이그램 인덱스 (title, content)
- **범위**: 공개 게시글만 (`group_id IS NULL`), 최소 2자
- **정렬**: `created_at DESC` (최신순 고정)
- **앱**: 300ms 디바운스, 최근 검색어 로컬 저장(8개), 감정 필터 칩
- **웹**: 500ms 디바운스, URL 파라미터 동기화, React Query 캐싱

### 한계점

| 영역 | 문제 |
|---|---|
| **검색 품질** | ILIKE 패턴 매칭만 — 형태소 분석 없음, 유사어/오타 미지원 |
| **정렬** | 최신순 고정 — 관련도 정렬 없음 |
| **하이라이팅** | 검색어 매칭 부분 강조 없음 |
| **범위** | 게시글만 — 댓글 검색 불가 |
| **필터** | 감정 필터 + 텍스트 조합 시 클라이언트 필터링 (비효율) |
| **페이지네이션** | 앱은 50건 일괄 로드, 무한 스크롤 미구현 |
| **UX** | 검색 진입점 제한적, 빈 상태/로딩 피드백 부족 |

---

## 2. 개선 설계

### 2.1 백엔드 — 풀텍스트 검색 + 관련도 정렬

#### 새 RPC: `search_posts_v2`

```sql
CREATE OR REPLACE FUNCTION public.search_posts_v2(
  p_query TEXT,
  p_emotion TEXT DEFAULT NULL,        -- 감정 필터 (서버 사이드)
  p_sort TEXT DEFAULT 'relevance',    -- 'relevance' | 'recent' | 'popular'
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
) RETURNS TABLE(
  id BIGINT,
  title TEXT,
  content TEXT,
  board_id BIGINT,
  like_count INTEGER,
  comment_count INTEGER,
  emotions TEXT[],
  created_at TIMESTAMPTZ,
  display_name TEXT,
  author_id UUID,
  is_anonymous BOOLEAN,
  image_url TEXT,
  initial_emotions TEXT[],
  group_id BIGINT,
  -- 새 컬럼
  title_highlight TEXT,               -- 검색어 하이라이트된 제목
  content_highlight TEXT,             -- 검색어 하이라이트된 본문 미리보기
  relevance_score REAL                -- 관련도 점수
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tsquery TSQUERY;
  v_pattern TEXT;
BEGIN
  IF length(trim(p_query)) < 2 THEN
    RETURN;
  END IF;

  -- 한국어: 공백 분리 → OR 조합 tsquery
  -- (PostgreSQL 기본 parser는 한국어 형태소 미지원이므로 공백 토큰화)
  v_tsquery := plainto_tsquery('simple', trim(p_query));
  v_pattern := '%' || trim(p_query) || '%';

  RETURN QUERY
  WITH matched AS (
    SELECT
      p.id,
      p.title,
      p.content,
      p.board_id,
      p.author_id,
      p.is_anonymous,
      p.display_name,
      p.image_url,
      p.initial_emotions,
      p.group_id,
      p.created_at,
      COALESCE(r_agg.total_reactions, 0)::integer AS like_count,
      COALESCE(c_agg.total_comments, 0)::integer AS comment_count,
      pa.emotions,
      -- 관련도 점수: ts_rank + 제목 매칭 가중치
      (
        COALESCE(ts_rank(
          setweight(to_tsvector('simple', p.title), 'A') ||
          setweight(to_tsvector('simple', p.content), 'B'),
          v_tsquery
        ), 0) * 10
        + CASE WHEN p.title ILIKE v_pattern THEN 5.0 ELSE 0.0 END
        + CASE WHEN p.title ILIKE trim(p_query) || '%' THEN 3.0 ELSE 0.0 END
      )::REAL AS relevance_score,
      -- 하이라이트
      ts_headline('simple', p.title, v_tsquery,
        'StartSel=<<, StopSel=>>, MaxWords=50, MinWords=10, MaxFragments=1'
      ) AS title_highlight,
      ts_headline('simple', p.content, v_tsquery,
        'StartSel=<<, StopSel=>>, MaxWords=30, MinWords=10, MaxFragments=1'
      ) AS content_highlight
    FROM posts p
    LEFT JOIN post_analysis pa ON pa.post_id = p.id
    LEFT JOIN (
      SELECT r.post_id, SUM(r.count)::integer AS total_reactions
      FROM reactions r GROUP BY r.post_id
    ) r_agg ON r_agg.post_id = p.id
    LEFT JOIN (
      SELECT c.post_id, COUNT(*)::integer AS total_comments
      FROM comments c WHERE c.deleted_at IS NULL GROUP BY c.post_id
    ) c_agg ON c_agg.post_id = p.id
    WHERE p.deleted_at IS NULL
      AND p.group_id IS NULL
      AND (
        to_tsvector('simple', p.title) || to_tsvector('simple', p.content)
      ) @@ v_tsquery
      -- 감정 필터 (서버 사이드)
      AND (p_emotion IS NULL OR p_emotion = ANY(pa.emotions))
  )
  SELECT m.*
  FROM matched m
  ORDER BY
    CASE p_sort
      WHEN 'relevance' THEN -m.relevance_score
      WHEN 'popular'   THEN -(m.like_count + m.comment_count * 2)::REAL
      ELSE NULL
    END,
    m.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;
```

**핵심 변경점:**
- `ILIKE` → `to_tsvector('simple') @@ plainto_tsquery('simple')` (풀텍스트)
- 관련도 점수: `ts_rank` + 제목 매칭 보너스
- `ts_headline`으로 하이라이트 마크업 (`<<` `>>` 구분자)
- 감정 필터 서버 사이드 처리 (기존 클라이언트 필터링 제거)
- 정렬 옵션: 관련도순 / 최신순 / 인기순

#### 인덱스 추가

```sql
-- tsvector GIN 인덱스 (풀텍스트 검색용)
CREATE INDEX IF NOT EXISTS idx_posts_fts
  ON posts
  USING GIN ((to_tsvector('simple', title) || to_tsvector('simple', content)))
  WHERE deleted_at IS NULL AND group_id IS NULL;
```

> 기존 pg_trgm 인덱스는 `ILIKE` 폴백용으로 유지.

#### 한국어 검색 전략

PostgreSQL 기본 `simple` 설정은 공백 토큰화만 지원하여 한국어 형태소 분석이 없음.

**Phase 1 (현재 설계)**: `simple` config — 공백 토큰화 + ILIKE 폴백
- 장점: 추가 확장 설치 불필요, Supabase 호환
- 단점: "행복했다" 검색 시 "행복" 매칭 안 됨

**Phase 2 (향후)**: 아래 중 택 1
| 옵션 | 설명 | 비고 |
|---|---|---|
| `pgroonga` | 한/중/일 형태소 지원 확장 | Supabase 미지원 |
| n-gram 인덱스 | 2-gram/3-gram 분리 | 커스텀 함수 필요 |
| 외부 검색 엔진 | Typesense / Meilisearch | 별도 인프라 |

Phase 1에서는 `simple` + ILIKE 하이브리드로 실용적 수준 달성.

---

### 2.2 프론트엔드 UX/UI 개선

#### 2.2.1 검색 진입점

**현재**: 탭 바에 검색 아이콘 (앱), 사이드바 링크 (웹)

**개선**:
- 홈 상단에 검색 바 영역 추가 (탭 이동 없이 바로 검색)
- 검색 바 탭 시 검색 화면으로 전환 (앱: 모달/push, 웹: 인라인 확장)

```
[앱 홈 상단]
┌────────────────────────────────┐
│  🔍 어떤 이야기를 찾고 있나요?   │  ← 탭하면 검색 화면 진입
└────────────────────────────────┘
```

#### 2.2.2 검색 화면 레이아웃

```
┌──────────────────────────────────────┐
│ ← 🔍 [검색어 입력________________] ✕ │  헤더: 입력 + 뒤로가기 + 클리어
├──────────────────────────────────────┤
│                                      │
│ ┌ 정렬 ──────────────────────────┐   │
│ │ [관련도순] [최신순] [인기순]      │   │  정렬 토글 (기본: 관련도순)
│ └────────────────────────────────┘   │
│                                      │
│ ┌ 감정 필터 ─────────────────────┐   │
│ │ [전체] [행복] [슬픔] [불안] ... │   │  가로 스크롤 칩
│ └────────────────────────────────┘   │
│                                      │
│  12건의 결과                          │  결과 카운트
│                                      │
│ ┌────────────────────────────────┐   │
│ │ 제목에서 <<매칭>> 하이라이트     │   │  검색 결과 카드
│ │ 본문에서 ...<<매칭>>된 부분...   │   │  하이라이트 미리보기
│ │ 😊 행복 😢 슬픔 · 2시간 전      │   │  감정 태그 + 시간
│ │ ❤️ 5  💬 3                      │   │  리액션/댓글 수
│ └────────────────────────────────┘   │
│                                      │
│ ┌────────────────────────────────┐   │
│ │ ...                            │   │  무한 스크롤
│ └────────────────────────────────┘   │
│                                      │
└──────────────────────────────────────┘
```

#### 2.2.3 검색 상태별 화면

**1) 초기 상태 (검색어 없음)**

```
┌──────────────────────────────────────┐
│ ← 🔍 [_____________________________] │
├──────────────────────────────────────┤
│                                      │
│  최근 검색                    전체삭제 │
│  ┌──────────────────────────────┐    │
│  │ 🕐 우울한 하루  ✕             │    │
│  │ 🕐 직장 스트레스  ✕           │    │
│  │ 🕐 수면 장애  ✕               │    │
│  └──────────────────────────────┘    │
│                                      │
│  지금 많이 느끼는 감정                 │
│  ┌──────────────────────────────┐    │
│  │ [😊 행복 42%] [😢 슬픔 28%]   │    │  get_emotion_trend 활용
│  │ [😰 불안 15%] [😠 분노 10%]   │    │
│  └──────────────────────────────┘    │
│                                      │
└──────────────────────────────────────┘
```

**2) 입력 중 (2자 미만)**

```
│  2자 이상 입력해주세요                 │
```

**3) 로딩 중**

```
│  ┌────────────────────────────────┐  │
│  │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓ (스켈레톤)      │  │  스켈레톤 카드 3개
│  │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓            │  │
│  └────────────────────────────────┘  │
```

**4) 결과 없음**

```
│                                      │
│         🔍                           │
│  '수면 장애'에 대한 결과가 없어요      │
│                                      │
│  다른 키워드로 검색하거나              │
│  감정으로 탐색해보세요                 │
│                                      │
│  [😊 행복] [😢 슬픔] [😰 불안] ...   │  감정 칩 (탭 시 감정 필터 검색)
│                                      │
```

#### 2.2.4 검색 결과 카드 컴포넌트

```
┌────────────────────────────────────┐
│ 익명 · 2시간 전                      │  작성자 + 시간
│                                      │
│ 오늘 정말 <<힘든>> 하루였다            │  제목 (하이라이트)
│ ...회사에서 <<힘든>> 일이 있었는데     │  본문 미리보기 (하이라이트, 2줄)
│ 집에 오니까 좀 나아졌다...             │
│                                      │
│ 😢 슬픔  😰 불안                     │  감정 태그 (pill)
│ ❤️ 5  💬 3                           │  참여 지표
└────────────────────────────────────┘
```

**하이라이트 렌더링:**
- RPC가 `<<` `>>` 구분자로 반환
- 클라이언트에서 파싱 → `<Text style={highlight}>` (앱) / `<mark>` (웹)

```typescript
// 하이라이트 파싱 유틸리티 (shared/로 관리 가능)
function parseHighlight(text: string): { text: string; highlighted: boolean }[] {
  const parts: { text: string; highlighted: boolean }[] = []
  const regex = /<<(.*?)>>/g
  let lastIndex = 0
  let match

  while ((match = regex.exec(text)) !== null) {
    if (match.index > lastIndex) {
      parts.push({ text: text.slice(lastIndex, match.index), highlighted: false })
    }
    parts.push({ text: match[1], highlighted: true })
    lastIndex = regex.lastIndex
  }

  if (lastIndex < text.length) {
    parts.push({ text: text.slice(lastIndex), highlighted: false })
  }

  return parts
}
```

#### 2.2.5 무한 스크롤 (앱)

```typescript
// useInfiniteQuery 패턴
const {
  data, fetchNextPage, hasNextPage, isFetchingNextPage
} = useInfiniteQuery({
  queryKey: ['search', query, emotion, sort],
  queryFn: ({ pageParam = 0 }) =>
    api.searchPostsV2({ query, emotion, sort, limit: 20, offset: pageParam }),
  getNextPageParam: (lastPage, allPages) =>
    lastPage.length === 20 ? allPages.flat().length : undefined,
  enabled: query.length >= 2,
  staleTime: 30_000,
})
```

**FlashList `onEndReached`로 다음 페이지 자동 로드.**

#### 2.2.6 디바운스 통일

현재 앱 300ms / 웹 500ms → **400ms 통일** (반응성과 API 부하 균형)

---

### 2.3 공유 타입 업데이트

```typescript
// shared/types.ts 추가

export interface SearchResult {
  id: number
  title: string
  content: string
  board_id: number | null
  like_count: number
  comment_count: number
  emotions: string[] | null
  created_at: string
  display_name: string
  author_id: string
  is_anonymous: boolean
  image_url: string | null
  initial_emotions: string[] | null
  group_id: number | null
  // v2 추가
  title_highlight: string
  content_highlight: string
  relevance_score: number
}

export type SearchSort = 'relevance' | 'recent' | 'popular'
```

> 기존 `SearchResult = Post` alias → 전용 인터페이스로 변경 (하이라이트/점수 포함)

---

### 2.4 API 함수

```typescript
// posts API
export async function searchPostsV2(params: {
  query: string
  emotion?: string | null
  sort?: SearchSort
  limit?: number
  offset?: number
}): Promise<SearchResult[]> {
  const { query, emotion, sort = 'relevance', limit = 20, offset = 0 } = params
  const q = query.trim()
  if (q.length < 2) return []

  const { data, error } = await supabase.rpc('search_posts_v2', {
    p_query: q,
    p_emotion: emotion ?? null,
    p_sort: sort,
    p_limit: limit,
    p_offset: offset,
  })

  if (error) throw error
  return (data ?? []) as SearchResult[]
}
```

---

## 3. 마이그레이션 계획

### 파일: `20260312000001_search_v2.sql`

```
1. tsvector GIN 인덱스 생성 (idx_posts_fts)
2. search_posts_v2 RPC 생성
3. 기존 search_posts는 유지 (하위 호환)
```

**기존 `search_posts` 제거 시점**: 앱/웹 모두 v2 전환 완료 후 별도 마이그레이션으로 DROP.

---

## 4. 구현 순서

### Phase 1: 백엔드 (마이그레이션)
1. `search_posts_v2` RPC + 인덱스 마이그레이션 작성
2. `db.sh push` → 타입 생성 → 동기화
3. Supabase Dashboard에서 RPC 테스트

### Phase 2: 공유 코드
4. `shared/types.ts` — `SearchResult` 인터페이스 확장, `SearchSort` 타입 추가
5. 하이라이트 파서 유틸리티 (앱/웹 각각 구현 또는 shared/)
6. 동기화 실행

### Phase 3: 앱 (React Native)
7. `api/posts.ts` — `searchPostsV2` 함수 추가
8. `search.tsx` — useInfiniteQuery, 정렬 토글, 서버 사이드 감정 필터, 하이라이트 렌더링
9. 홈 상단 검색 바 진입점 추가 (선택)
10. 검색 결과 카드 하이라이트 컴포넌트

### Phase 4: 웹 (Next.js)
11. `postsApi.ts` — `searchPostsV2` 함수 추가
12. `SearchView.tsx` — 정렬/필터 UI, 하이라이트 렌더링, 무한 스크롤
13. 검색 결과 카드 `<mark>` 하이라이트

### Phase 5: 정리
14. 기존 `search_posts` RPC 제거 마이그레이션 (앱/웹 전환 확인 후)

---

## 5. 성능 고려사항

| 항목 | 대응 |
|---|---|
| tsvector 인덱스 빌드 | partial index (deleted_at IS NULL, group_id IS NULL) — 대상 행 축소 |
| ts_headline 비용 | LIMIT 적용 후 하이라이트 계산 (CTE matched에서 처리) |
| 동시 검색 부하 | SECURITY DEFINER + `SET search_path` (RLS 우회로 쿼리 단순화) |
| 캐싱 | 클라이언트 staleTime 30초, 동일 쿼리 재실행 방지 |

---

## 6. 향후 확장

- **댓글 검색**: `search_comments` RPC 추가 (별도 탭)
- **자동 완성**: 인기 검색어 / 감정 기반 추천 검색어
- **검색 분석**: 검색어 로깅 → 인기 검색어 / 트렌드 분석
- **한국어 형태소**: pgroonga 또는 외부 검색 엔진 도입
- **그룹 내 검색**: 그룹 멤버용 검색 (group_id 파라미터 추가)
