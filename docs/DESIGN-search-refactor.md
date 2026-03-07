# 검색 기능 통합 리팩토링 설계

> 작성일: 2026-03-07
> 대상: 중앙(supabase-hermit) + 앱(React Native/Expo) + 웹(Next.js)
> 상태: 설계 완료 — 구현 대기
> 기반: 검색 v2 구현 완료 상태에서의 코드 품질/동기화/성능 개선

---

## 1. 현재 상태

### 1.1 아키텍처

```
[DB] search_posts_v2 RPC (SECURITY DEFINER)
  ├── to_tsvector('simple') + plainto_tsquery('simple')
  ├── ts_rank 관련도 + 제목 ILIKE 가중치
  ├── ts_headline << >> 하이라이트
  ├── 서버 사이드 감정 필터 (p_emotion)
  ├── 3종 정렬 (relevance / recent / popular)
  └── GIN 인덱스 (partial: deleted_at IS NULL AND group_id IS NULL)

[DB] search_posts v1 (deprecated, 미사용)
  └── ILIKE 패턴 매칭, 14컬럼, 정렬 고정

[앱] src/app/search.tsx (595줄)
  ├── useInfiniteQuery + FlashList onEndReached
  ├── 디바운스 300ms
  ├── 최근 검색어: draftStorage (MMKV) — 인라인 함수
  ├── 하이라이트: HighlightText (React.memo)
  └── URL 파라미터 미사용

[웹] src/features/posts/components/SearchView.tsx (399줄)
  ├── useInfiniteQuery + "더 보기" 버튼
  ├── 디바운스 400ms
  ├── 최근 검색어: localStorage — 별도 유틸 파일
  ├── 하이라이트: HighlightText (mark 태그)
  └── URL 파라미터 동기화 (q, emotion, sort)
```

### 1.2 식별된 문제 (우선순위순)

| 등급 | 문제 | 영향 |
|------|------|------|
| **높음** | search_posts v1 미사용인데 DB에 잔존 | 스키마 혼란, 유지보수 비용 |
| **높음** | 앱 최근 검색어 함수가 search.tsx 인라인 (595줄) | 단일 파일 비대화, 재사용 불가 |
| **중간** | 디바운스 불일치 (앱 300ms / 웹 400ms) | 플랫폼 간 검색 경험 차이 |
| **중간** | 하이라이트 색상 불일치 (앱 #FFF3CC / 웹 bg-amber-100) | 시각적 비일관성 |
| **중간** | 무한 스크롤 UX 불일치 (앱 자동 / 웹 수동 버튼) | 플랫폼 간 UX 패턴 차이 |
| **중간** | 웹 SearchResultCard/HighlightText 미메모이제이션 | 불필요한 리렌더링 |
| **낮음** | 하이라이트 색상 하드코딩 (중앙 상수 없음) | 단일 정본 부재 |
| **낮음** | 앱 검색 탭이 re-export 래퍼 (불필요한 indirection) | 파일 구조 복잡성 |

### 1.3 크로스 플랫폼 일관성 점수

| 항목 | 점수 | 비고 |
|------|------|------|
| 타입 동기화 | 100% | SearchResult, SearchSort 완전 동기화 |
| RPC 사용 | 100% | 양쪽 모두 search_posts_v2 |
| 정렬/필터 로직 | 100% | 서버 사이드 통일 |
| API 함수 구조 | 100% | 동일 시그니처 |
| 하이라이트 파싱 | 100% | 동일 정규식 `<<(.*?)>>` |
| UI/UX 패리티 | 75% | 디바운스, 무한스크롤, URL 차이 |
| 코드 조직 | 80% | 최근 검색어 중복 |
| 스타일 일관성 | 85% | 하이라이트 색상 미세 차이 |
| **종합** | **85%** | |

---

## 2. 설계 결정

| 항목 | 결정 | 이유 |
|------|------|------|
| search_posts v1 | **DROP** | 앱/웹 모두 v2 사용 확인, 잔존 이유 없음 |
| 디바운스 | **400ms 통일** | 설계 문서 권장값, API 부하 감소 |
| 최근 검색어 | **앱에서 유틸 파일로 추출** | 웹 패턴 이식, search.tsx 경량화 |
| 하이라이트 색상 | **중앙 상수로 추출** | 단일 정본, sync로 자동 배포 |
| 무한 스크롤 | **플랫폼별 유지** (의도적 차이) | 앱: 자동 (모바일 UX), 웹: 수동 (접근성) |
| 웹 메모이제이션 | **React.memo 추가** | 스크롤 시 불필요 리렌더링 방지 |
| 앱 탭 래퍼 | **유지** | Expo Router 규약상 필요 |

---

## 3. 중앙 DB 변경

### 3.1 마이그레이션: search_posts v1 제거

```sql
-- 파일: supabase/migrations/YYYYMMDDHHMMSS_drop_search_posts_v1.sql

-- ============================================================
-- search_posts v1 제거 (deprecated, 앱/웹 모두 v2 전환 완료)
-- ============================================================
DROP FUNCTION IF EXISTS public.search_posts(TEXT, INTEGER, INTEGER);
```

### 3.2 shared/constants.ts: 하이라이트 색상 상수 추가

```typescript
/** 검색 하이라이트 색상 (앱/웹 공유) */
export const SEARCH_HIGHLIGHT = {
  light: '#FFF3CC',
  dark: '#664E00',
} as const

/** 검색 설정 */
export const SEARCH_CONFIG = {
  DEBOUNCE_MS: 400,
  PAGE_SIZE: 20,
  MIN_QUERY_LENGTH: 2,
  RECENT_MAX: 8,
  STALE_TIME_MS: 30_000,
} as const
```

---

## 4. 앱 변경

### 4.1 최근 검색어 유틸 추출

현재 `search.tsx`에 인라인된 4개 함수를 별도 파일로 추출:

```typescript
// src/shared/lib/recent-searches.ts (신규)
import { draftStorage } from './storage'
import { SEARCH_CONFIG } from './constants'

const RECENT_SEARCHES_KEY = 'search_recent'

export function getRecentSearches(): string[] {
  try {
    const raw = draftStorage.getString(RECENT_SEARCHES_KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw) as unknown
    return Array.isArray(parsed) ? parsed.slice(0, SEARCH_CONFIG.RECENT_MAX) : []
  } catch {
    return []
  }
}

export function addRecentSearch(query: string): void {
  if (!query.trim()) return
  const recent = getRecentSearches().filter((q) => q !== query)
  recent.unshift(query.trim())
  draftStorage.set(RECENT_SEARCHES_KEY, JSON.stringify(recent.slice(0, SEARCH_CONFIG.RECENT_MAX)))
}

export function removeRecentSearch(query: string): string[] {
  const recent = getRecentSearches().filter((q) => q !== query)
  draftStorage.set(RECENT_SEARCHES_KEY, JSON.stringify(recent))
  return recent
}

export function clearAllRecentSearches(): void {
  draftStorage.remove(RECENT_SEARCHES_KEY)
}
```

`search.tsx`에서 이 함수들의 인라인 정의를 삭제하고 import로 교체.

### 4.2 디바운스 통일

```typescript
// src/app/search.tsx
-const DEBOUNCE_MS = 300
+import { SEARCH_CONFIG } from '@/shared/lib/constants'
// 사용: setTimeout(..., SEARCH_CONFIG.DEBOUNCE_MS)
```

### 4.3 하이라이트 색상 상수 적용

색상은 2곳에서 수정 필요:

1. **HighlightText.tsx** — 기본 fallback 색상:
```typescript
// src/shared/components/HighlightText.tsx
-backgroundColor: '#FFF3CC'  // 기본 fallback (line 26)
+import { SEARCH_HIGHLIGHT } from '@/shared/lib/constants'
+backgroundColor: SEARCH_HIGHLIGHT.light
```

2. **search.tsx** — SearchResultCard에서 dark mode 분기:
```typescript
// src/app/search.tsx (SearchResultCard 내부)
-highlightStyle={{ backgroundColor: isDark ? '#664E00' : '#FFF3CC' }}
+highlightStyle={{ backgroundColor: isDark ? SEARCH_HIGHLIGHT.dark : SEARCH_HIGHLIGHT.light }}
```

### 4.4 SearchResultCard 메모이제이션

```tsx
// src/app/search.tsx 내부
-function SearchResultCard({ result, onPress }: Props) {
+const SearchResultCard = React.memo(function SearchResultCard({ result, onPress }: Props) {
  // 기존 렌더링 로직
-}
+})
```

### 4.5 constants.ts barrel re-export 추가

```typescript
// src/shared/lib/constants.ts (기존 barrel 파일에 추가)
export { SEARCH_HIGHLIGHT, SEARCH_CONFIG } from './constants.generated'
```

> sync 후 `constants.generated.ts`에 `SEARCH_HIGHLIGHT`/`SEARCH_CONFIG`가 자동 추가되지만,
> 앱 코드는 `@/shared/lib/constants`에서 import하므로 barrel re-export가 필수.

### 4.6 앱 파일 변경 목록

| 작업 | 파일 | 변경 |
|------|------|------|
| 신규 | `src/shared/lib/recent-searches.ts` | 최근 검색어 유틸 (search.tsx에서 추출) |
| 수정 | `src/app/search.tsx` | 인라인 함수 → import, DEBOUNCE_MS → SEARCH_CONFIG, 색상 → SEARCH_HIGHLIGHT, SearchResultCard React.memo |
| 수정 | `src/shared/components/HighlightText.tsx` | 기본 색상 → SEARCH_HIGHLIGHT.light |
| 수정 | `src/shared/lib/constants.ts` | SEARCH_HIGHLIGHT, SEARCH_CONFIG re-export 추가 |

---

## 5. 웹 변경

### 5.1 디바운스 상수 적용

```typescript
// src/features/posts/components/SearchView.tsx
-const DEBOUNCE_MS = 400
+import { SEARCH_CONFIG } from '@/lib/constants'
// 사용: setTimeout(..., SEARCH_CONFIG.DEBOUNCE_MS)
```

### 5.2 하이라이트 색상 통일

다크 모드 감지 후 인라인 스타일로 적용 (Tailwind className과 inline style 충돌 방지):

```tsx
// src/lib/highlight.tsx
'use client'

import { Fragment, memo } from 'react'
import { useTheme } from 'next-themes'
import { SEARCH_HIGHLIGHT } from '@/lib/constants'

export const HighlightText = memo(function HighlightText({ text, className }: { text: string; className?: string }) {
  const { resolvedTheme } = useTheme()
  const isDark = resolvedTheme === 'dark'
  const parts = text.split(/<<(.*?)>>/g)

  return (
    <span className={className}>
      {parts.map((part, i) =>
        i % 2 === 1 ? (
          <mark
            key={i}
            style={{ backgroundColor: isDark ? SEARCH_HIGHLIGHT.dark : SEARCH_HIGHLIGHT.light }}
            className="text-inherit rounded-sm px-0.5"
          >
            {part}
          </mark>
        ) : (
          <Fragment key={i}>{part}</Fragment>
        ),
      )}
    </span>
  )
})
```

> `useTheme()` (next-themes)로 다크 모드를 JS 레벨에서 감지하여 인라인 스타일만 사용.
> Tailwind `dark:` className과 inline style의 specificity 충돌 문제를 근본적으로 회피.

### 5.3 SearchResultCard 메모이제이션

```tsx
// src/features/posts/components/SearchView.tsx 내부
const SearchResultCard = React.memo(function SearchResultCard({ result, onClick }: Props) {
  // 기존 렌더링 로직
})
```

### 5.4 HighlightText 메모이제이션

```tsx
// src/lib/highlight.tsx
export const HighlightText = React.memo(function HighlightText({ text, className }: Props) {
  // 기존 로직
})
```

### 5.5 constants.ts barrel re-export 추가

```typescript
// src/lib/constants.ts (기존 barrel 파일에 추가)
export { SEARCH_HIGHLIGHT, SEARCH_CONFIG } from './constants.generated'
```

### 5.6 웹 파일 변경 목록

| 작업 | 파일 | 변경 |
|------|------|------|
| 수정 | `src/features/posts/components/SearchView.tsx` | DEBOUNCE_MS → SEARCH_CONFIG, SearchResultCard 메모이제이션 |
| 수정 | `src/lib/highlight.tsx` | 전면 리라이트: 색상 → SEARCH_HIGHLIGHT, useTheme 다크모드, React.memo |
| 수정 | `src/lib/recent-searches.ts` | RECENT_MAX → SEARCH_CONFIG.RECENT_MAX |
| 수정 | `src/lib/constants.ts` | SEARCH_HIGHLIGHT, SEARCH_CONFIG re-export 추가 |

---

## 6. 성능 개선

### 6.1 현재 성능 프로파일

| 계층 | 현재 상태 | 개선 |
|------|-----------|------|
| **DB RPC** | CTE 내부 ts_headline (LIMIT 전 전체 실행) | 향후 최적화 여지 있음 (아래 참조) |
| **GIN 인덱스** | partial (deleted_at IS NULL, group_id IS NULL) | 이미 최적화됨 |
| **앱 렌더링** | HighlightText memo, FlashList 가상화 | 이미 최적화됨 |
| **웹 렌더링** | 메모이제이션 없음 | **React.memo 추가** |
| **캐싱** | staleTime 30초 | 적절함 |
| **디바운스** | 앱 300ms (과도한 쿼리 가능) | **400ms로 통일** |

### 6.2 RPC 레벨 (변경 없음)

`search_posts_v2` 현재 구조:
- CTE `matched` 내부에서 ts_headline 실행 (LIMIT 전 전체 행에 적용)
- SECURITY DEFINER로 RLS 오버헤드 회피
- partial GIN 인덱스로 공개 게시글만 인덱싱

> **향후 최적화 가능**: ts_headline은 비용이 높은 연산. 현재는 CTE 내부에서 모든 매칭 행에 실행 후 LIMIT 적용.
> 데이터 증가 시 CTE를 2단계로 분리 (1단계: 매칭+정렬+LIMIT, 2단계: ts_headline)하면 성능 개선 가능.
> 현재 데이터 규모에서는 문제 없으므로 이번 리팩토링 범위 밖.

### 6.3 클라이언트 레벨

| 개선 | 앱 | 웹 | 효과 |
|------|-----|-----|------|
| SearchResultCard memo | **추가** | **추가** | 스크롤 시 리렌더링 감소 |
| HighlightText memo | 이미 적용 | **추가** | 하이라이트 재파싱 방지 |
| SEARCH_CONFIG 상수화 | **적용** | **적용** | 매직 넘버 제거, 일관성 |
| 최근 검색어 추출 | **적용** | 이미 적용 | search.tsx 경량화 |

---

## 7. 플랫폼별 의도적 차이 (유지)

| 항목 | 앱 | 웹 | 유지 이유 |
|------|-----|-----|-----------|
| 무한 스크롤 | FlashList `onEndReached` (자동) | "더 보기" 버튼 (수동) | 모바일: 스크롤 자연스러움, 웹: 접근성 + SEO |
| URL 동기화 | 없음 (앱 내 네비게이션) | 쿼리 파라미터 동기화 | 웹: 딥링크/공유/북마크 필요, 앱: 불필요 |
| 최근 검색어 저장소 | MMKV (draftStorage) | localStorage | 플랫폼 네이티브 스토리지 사용 |
| 하이라이트 렌더링 | `<Text>` + style 객체 | `<mark>` + Tailwind | 플랫폼 네이티브 컴포넌트 |
| 검색 입력 | `TextInput` (RN) | `<input>` (HTML) | 플랫폼 네이티브 |

---

## 8. 구현 순서

```
Phase 0: DB 정리 (독립)
  0. 사전 검증: 앱/웹에서 `search_posts` (v1) 호출 코드 없음 확인 (grep)
  1. search_posts v1 DROP 마이그레이션
  2. db.sh push → gen-types (database.gen.ts에서 v1 타입 자동 제거) → sync

Phase 1: 중앙 상수 추가 (Phase 0 이후)
  3. shared/constants.ts — SEARCH_HIGHLIGHT + SEARCH_CONFIG 추가
  4. sync → 앱/웹 constants.generated.ts에 자동 배포

Phase 2: 앱 리팩토링 (Phase 1 이후)
  5. src/shared/lib/constants.ts — SEARCH_HIGHLIGHT, SEARCH_CONFIG re-export 추가
  6. recent-searches.ts 신규 (search.tsx에서 추출)
  7. search.tsx — import 교체 + DEBOUNCE_MS → SEARCH_CONFIG + 색상 → SEARCH_HIGHLIGHT + SearchResultCard React.memo
  8. HighlightText.tsx — 기본 색상 → SEARCH_HIGHLIGHT.light

Phase 3: 웹 리팩토링 (Phase 1 이후, Phase 2와 병렬 가능)
  9. src/lib/constants.ts — SEARCH_HIGHLIGHT, SEARCH_CONFIG re-export 추가
  10. SearchView.tsx — DEBOUNCE_MS → SEARCH_CONFIG + SearchResultCard memo
  11. highlight.tsx — 전면 리라이트 (useTheme + SEARCH_HIGHLIGHT + React.memo)
  12. recent-searches.ts — RECENT_MAX → SEARCH_CONFIG.RECENT_MAX
```

**Phase 의존성:**
```
Phase 0 (DB) → Phase 1 (상수) ──┬── Phase 2 (앱)
                                └── Phase 3 (웹) ← 병렬 가능
```

---

## 9. 변경 요약

| 영역 | 변경 전 | 변경 후 |
|------|---------|---------|
| **DB** | v1 + v2 공존 | v1 DROP, v2만 유지 |
| **상수** | 검색 설정 각 파일 하드코딩 | SEARCH_HIGHLIGHT + SEARCH_CONFIG 중앙화 |
| **앱 디바운스** | 300ms 로컬 상수 | 400ms 공유 상수 (SEARCH_CONFIG) |
| **웹 디바운스** | 400ms 로컬 상수 | 400ms 공유 상수 (SEARCH_CONFIG) |
| **앱 최근 검색** | search.tsx 인라인 (4함수) | recent-searches.ts 별도 파일 |
| **하이라이트 색상** | 앱 #FFF3CC / 웹 amber-100 | 통일 (SEARCH_HIGHLIGHT 상수) |
| **웹 메모이제이션** | 없음 | SearchResultCard + HighlightText에 React.memo |
| **앱 SearchResultCard** | 미메모이제이션 | React.memo 적용 |
| **앱 search.tsx** | ~594줄 | ~565줄 (유틸 추출 후) |
| **barrel re-export** | 없음 (상수 미존재) | 앱/웹 constants.ts에 SEARCH_* re-export 추가 |
| **무한 스크롤** | 앱 자동 / 웹 수동 | 유지 (의도적 플랫폼 차이) |

---

## 10. 검증 체크리스트

- [ ] search_posts v1 호출 코드 부재 확인 (앱/웹 grep `search_posts` — v2 아닌 것)
- [ ] search_posts v1 DROP 후 앱/웹 정상 작동 확인
- [ ] 앱/웹 constants.ts barrel re-export에 SEARCH_HIGHLIGHT, SEARCH_CONFIG 포함 확인
- [ ] SEARCH_CONFIG.DEBOUNCE_MS 적용 후 검색 반응성 확인
- [ ] 하이라이트 색상 앱/웹 동일한지 시각 확인
- [ ] 앱 recent-searches.ts 추출 후 최근 검색어 저장/삭제/전체삭제 동작 확인
- [ ] 웹 React.memo 적용 후 리렌더링 감소 확인 (React DevTools Profiler)
- [ ] 감정 필터 + 텍스트 검색 복합 쿼리 정상 작동
- [ ] 정렬 3종 (관련도/최신/인기) 결과 정확성 확인
- [ ] 2자 미만 입력 시 빈 결과 반환 확인

---

## 11. 주의사항 및 향후 고려사항 해결 방안

### 11.1 ts_headline 성능 최적화 (2단계 CTE 분리)

**문제**: 현재 `search_posts_v2`는 CTE `matched` 내부에서 모든 매칭 행에 `ts_headline`을 실행한 뒤 외부에서 `ORDER BY` + `LIMIT`을 적용한다. 매칭 결과가 1,000건이면 1,000건 전부에 ts_headline이 실행되지만 실제 반환은 20건뿐이다. 데이터 증가 시 불필요한 연산이 선형 증가한다.

**트리거 기준**: 공개 게시글 수가 **5,000건 이상**이거나, `search_posts_v2` 평균 응답 시간이 **200ms 초과** 시 적용.

**모니터링 쿼리**:
```sql
-- 공개 게시글 수 확인
SELECT COUNT(*) FROM posts WHERE deleted_at IS NULL AND group_id IS NULL;

-- RPC 응답 시간 측정 (pg_stat_statements 활성화 시)
SELECT mean_exec_time, calls
FROM pg_stat_statements
WHERE query LIKE '%search_posts_v2%';
```

**해결: 2단계 CTE**

1단계 `filtered`: 매칭 + 정렬 + LIMIT (ts_headline 없이)
2단계 `highlighted`: LIMIT된 결과에만 ts_headline 적용

```sql
-- 파일: supabase/migrations/YYYYMMDDHHMMSS_search_v2_ts_headline_optimize.sql

CREATE OR REPLACE FUNCTION public.search_posts_v2(
  p_query TEXT,
  p_emotion TEXT DEFAULT NULL,
  p_sort TEXT DEFAULT 'relevance',
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
  title_highlight TEXT,
  content_highlight TEXT,
  relevance_score REAL
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_tsquery TSQUERY;
  v_pattern TEXT;
  v_trimmed TEXT;
BEGIN
  v_trimmed := trim(p_query);

  IF v_trimmed IS NULL OR length(v_trimmed) < 2 THEN
    RETURN;
  END IF;

  v_tsquery := plainto_tsquery('simple', v_trimmed);
  v_pattern := '%' || v_trimmed || '%';

  RETURN QUERY
  -- 1단계: 매칭 + 점수 + 정렬 + LIMIT (ts_headline 없이)
  WITH filtered AS (
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
      (
        COALESCE(ts_rank(
          setweight(to_tsvector('simple', p.title), 'A') ||
          setweight(to_tsvector('simple', p.content), 'B'),
          v_tsquery
        ), 0) * 10
        + CASE WHEN p.title ILIKE v_pattern THEN 5.0 ELSE 0.0 END
        + CASE WHEN p.title ILIKE v_trimmed || '%' THEN 3.0 ELSE 0.0 END
      )::REAL AS relevance_score
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
        (to_tsvector('simple', p.title) || to_tsvector('simple', p.content)) @@ v_tsquery
        OR p.title ILIKE v_pattern
        OR p.content ILIKE v_pattern
      )
      AND (p_emotion IS NULL OR p_emotion = ANY(pa.emotions))
    ORDER BY
      CASE
        WHEN p_sort = 'relevance' THEN -relevance_score
        WHEN p_sort = 'popular' THEN -(COALESCE(r_agg.total_reactions, 0) + COALESCE(c_agg.total_comments, 0) * 2)::REAL
        ELSE NULL
      END,
      p.created_at DESC
    LIMIT p_limit
    OFFSET p_offset
  )
  -- 2단계: LIMIT된 결과에만 ts_headline 적용 (최대 p_limit건)
  SELECT
    f.id,
    f.title,
    f.content,
    f.board_id,
    f.like_count,
    f.comment_count,
    f.emotions,
    f.created_at,
    f.display_name,
    f.author_id,
    f.is_anonymous,
    f.image_url,
    f.initial_emotions,
    f.group_id,
    ts_headline('simple', f.title, v_tsquery,
      'StartSel=<<, StopSel=>>, MaxWords=50, MinWords=10, MaxFragments=1'
    ) AS title_highlight,
    ts_headline('simple', f.content, v_tsquery,
      'StartSel=<<, StopSel=>>, MaxWords=30, MinWords=10, MaxFragments=1'
    ) AS content_highlight,
    f.relevance_score
  FROM filtered f
  ORDER BY
    CASE
      WHEN p_sort = 'relevance' THEN -f.relevance_score
      WHEN p_sort = 'popular' THEN -(f.like_count + f.comment_count * 2)::REAL
      ELSE NULL
    END,
    f.created_at DESC;
END;
$$;
```

**성능 비교**:

| 시나리오 | 현재 (1단계 CTE) | 최적화 (2단계 CTE) | 개선 |
|----------|-------------------|---------------------|------|
| 매칭 100건, LIMIT 20 | ts_headline × 100 | ts_headline × 20 | **5× 감소** |
| 매칭 1,000건, LIMIT 20 | ts_headline × 1,000 | ts_headline × 20 | **50× 감소** |
| 매칭 10건, LIMIT 20 | ts_headline × 10 | ts_headline × 10 | 동일 |

**주의**: ORDER BY를 1단계(filtered)에서 적용하고, 2단계에서도 동일 ORDER BY를 유지해야 정렬 순서가 보장된다. CTE는 정렬을 보장하지 않으므로 외부 SELECT에서 재정렬 필수.

### 11.2 ILIKE 폴백 성능 (GIN 인덱스 미적용 경로)

**문제**: `search_posts_v2`의 WHERE 절에서 FTS 매칭(`@@`)과 ILIKE 매칭이 `OR`로 결합된다. GIN 인덱스는 `@@` 경로에만 적용되고, ILIKE 경로는 순차 스캔(Seq Scan)을 유발할 수 있다. PostgreSQL 옵티마이저가 Bitmap OR로 최적화하지만, 데이터가 커지면 ILIKE 경로가 병목이 된다.

**트리거 기준**: 공개 게시글 수 **10,000건 이상** 시 적용 검토.

**해결 방안: pg_trgm GIN 인덱스 추가**

```sql
-- pg_trgm 확장이 이미 활성화되어 있다면 (Supabase 기본 포함)
CREATE INDEX IF NOT EXISTS idx_posts_trgm_title
  ON posts USING GIN (title gin_trgm_ops)
  WHERE deleted_at IS NULL AND group_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_posts_trgm_content
  ON posts USING GIN (content gin_trgm_ops)
  WHERE deleted_at IS NULL AND group_id IS NULL;
```

> pg_trgm 인덱스는 ILIKE 쿼리에 자동으로 적용된다. 인덱스 2개 추가로 쓰기 성능이 미세하게 저하되므로 데이터 규모가 충분할 때만 적용한다. 현재 규모에서는 불필요.

**대안: ILIKE 제거 (FTS only)**

데이터가 충분히 커지면 ILIKE 폴백을 제거하고 FTS만 사용하는 것도 고려 가능. 단, `to_tsvector('simple')`은 한국어 형태소 분석을 하지 않으므로 부분 일치가 누락될 수 있어 ILIKE 폴백이 현재는 필수적이다.

### 11.3 한국어 검색 품질 개선

**현재 상태**: `to_tsvector('simple')`은 공백 기준 토크나이징만 수행. 한국어 형태소 분석 없음. "슬픔"으로 검색하면 "슬픔이"는 FTS로 매칭되지 않고 ILIKE 폴백에 의존.

**향후 선택지**:

| 방법 | 장점 | 단점 | 적용 시기 |
|------|------|------|-----------|
| **현재 유지** (simple + ILIKE) | 안정적, 추가 비용 없음 | 부분 일치 ILIKE 의존 | 현재 |
| **pgroonga 확장** | 한국어 형태소 분석 지원 | Supabase hosted에서 미지원 | Self-hosted 전환 시 |
| **pg_bigm** | 2-gram 인덱싱, LIKE 가속 | Supabase hosted 미지원 | Self-hosted 전환 시 |
| **외부 검색 엔진** (Meilisearch/Typesense) | 최상 검색 품질, 자동완성 | 인프라 추가, 동기화 복잡성 | MAU 1,000+ |

**결론**: 현재 `simple` + ILIKE 하이브리드 방식은 한국어 커뮤니티 서비스에 적합한 실용적 선택이다. 사용자 피드백에서 검색 누락 불만이 반복되면 외부 검색 엔진 도입을 검토한다.

### 11.4 search_posts v1 제거 안전성

**문제**: v1 DROP 시 혹시 모를 외부 호출자(DB 트리거, 다른 RPC, 크론 등)가 있으면 장애 발생.

**사전 검증 절차**:

```sql
-- 1. DB 내부에서 search_posts를 참조하는 함수/트리거 확인
SELECT routine_name, routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_definition LIKE '%search_posts(%'
  AND routine_name != 'search_posts';

-- 2. pg_depend로 의존성 확인
SELECT deptype, classid::regclass, objid, refobjid::regprocedure
FROM pg_depend
WHERE refobjid = 'public.search_posts(text,integer,integer)'::regprocedure;
```

```bash
# 3. 앱/웹 코드에서 v1 호출 확인 (Phase 0 사전 검증)
grep -rn "search_posts[^_v]" /mnt/c/Users/Administrator/programming/apps/gns-hermit-comm/src/
grep -rn "search_posts[^_v]" /home/gunny/apps/web/src/
grep -rn "\.rpc.*search_posts['\"]" /mnt/c/Users/Administrator/programming/apps/gns-hermit-comm/src/
grep -rn "\.rpc.*search_posts['\"]" /home/gunny/apps/web/src/
```

위 4개 쿼리 모두 결과가 0건이면 안전하게 DROP 가능.

### 11.5 플랫폼별 의도적 차이 재검토 기준

**섹션 7의 의도적 차이에 대한 구체적 재검토 트리거**:

| 차이점 | 재검토 트리거 | 방향 |
|--------|---------------|------|
| 무한 스크롤 (앱 자동 / 웹 수동) | 웹에 Intersection Observer 도입 검토 시 | 웹도 자동 전환 가능. 단, "더 보기" 버튼은 접근성(a11y) 측면에서 우위이므로 WCAG 기준 우선 |
| URL 동기화 (웹만) | 앱에 딥링크 요구사항 발생 시 | 앱도 expo-linking으로 `hermit://search?q=...` 구현 가능. 현재는 ROI 부족 |
| 최근 검색어 저장소 (MMKV / localStorage) | 변경 필요 없음 | 플랫폼 네이티브 스토리지 사용이 정답. 통합 불필요 |
| 하이라이트 렌더링 (Text / mark) | 변경 필요 없음 | 플랫폼 네이티브 컴포넌트 사용이 정답. 통합 불필요 |

### 11.6 shared/constants.ts 함수 포함 문제

**문제**: admin redesign에서 `generateInviteCode()`, `validateGroupInput()` 등 **함수**를 `shared/constants.ts`에 추가했다. 이 파일은 sync로 앱/웹에 `constants.generated.ts`로 복사되는데, 함수가 포함되면:
1. "constants" 파일에 로직이 섞여 의미가 모호해짐
2. 함수가 외부 의존성을 가지면 sync 후 빌드 실패 가능

**해결 방안**:

```
shared/
├── constants.ts    # 값만 (문자열, 숫자, 객체 리터럴, as const)
├── types.ts        # 타입/인터페이스만
└── utils.ts        # 순수 함수 (신규)
```

`shared/utils.ts`를 신규 생성하고, 순수 함수들을 이동:

```typescript
// shared/utils.ts (신규)
export function generateInviteCode(length = 6): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  return Array.from({ length }, () => chars[Math.floor(Math.random() * chars.length)]).join('')
}

export function validateGroupInput(name: string): { valid: boolean; error?: string } {
  const trimmed = name.trim()
  if (!trimmed) return { valid: false, error: '그룹명을 입력해주세요' }
  if (trimmed.length > 50) return { valid: false, error: '그룹명은 50자 이내로 입력해주세요' }
  return { valid: true }
}
```

**sync 대상 추가**: `sync-to-projects.sh`에 `shared/utils.ts` → 앱/웹 동기화 경로 추가.

| 소스 (중앙) | 앱 대상 | 웹 대상 |
|---|---|---|
| `shared/utils.ts` | `src/shared/lib/utils.generated.ts` | `src/lib/utils.generated.ts` |

> 현재 `generateInviteCode`와 `validateGroupInput`은 외부 의존성이 없는 순수 함수이므로 sync 안전. 향후 함수 추가 시에도 **외부 import 없는 순수 함수만** `shared/utils.ts`에 추가하는 규칙 적용.

---

## 12. 개선된 구현 순서 (전체)

```
Phase 0: DB 정리 (독립)
  0. 사전 검증: search_posts v1 의존성 확인 (11.4절 쿼리 실행)
  1. search_posts v1 DROP 마이그레이션
  2. db.sh push → gen-types → sync

Phase 1: 중앙 상수 추가 (Phase 0 이후)
  3. shared/constants.ts — SEARCH_HIGHLIGHT + SEARCH_CONFIG 추가
  4. shared/utils.ts 신규 — 함수 분리 (11.6절, admin 함수 이동)
  5. sync-to-projects.sh — utils.ts 동기화 경로 추가
  6. sync → 앱/웹 자동 배포

Phase 2: 앱 리팩토링 (Phase 1 이후)
  7. constants.ts barrel — SEARCH_HIGHLIGHT, SEARCH_CONFIG re-export
  8. recent-searches.ts 신규 (search.tsx에서 추출)
  9. search.tsx — import 교체 + 상수 적용 + SearchResultCard memo
  10. HighlightText.tsx — SEARCH_HIGHLIGHT.light 적용

Phase 3: 웹 리팩토링 (Phase 1 이후, Phase 2와 병렬 가능)
  11. constants.ts barrel — SEARCH_HIGHLIGHT, SEARCH_CONFIG re-export
  12. SearchView.tsx — SEARCH_CONFIG + SearchResultCard memo
  13. highlight.tsx — useTheme + SEARCH_HIGHLIGHT + React.memo
  14. recent-searches.ts — SEARCH_CONFIG.RECENT_MAX

Phase 4: DB 성능 최적화 (Phase 0 이후, 트리거 기준 충족 시)
  15. search_posts_v2 2단계 CTE 분리 (11.1절)
  16. pg_trgm 인덱스 추가 (11.2절, 선택적)
```

**Phase 의존성:**
```
Phase 0 (DB 정리) → Phase 1 (상수+유틸) ──┬── Phase 2 (앱)
                                           └── Phase 3 (웹) ← 병렬 가능
                 → Phase 4 (DB 성능) ← 트리거 기준 충족 시 독립 실행
```
