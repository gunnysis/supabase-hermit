# 검색 기능 동기화 설계 — 앱 → 웹/중앙

> 작성일: 2026-03-06
> 상태: 설계 (Draft)

---

## 1. 현재 상태 비교

### 앱 (search.tsx) — 이미 개선 완료
| 기능 | 상태 |
|---|---|
| 초기 화면: 최근 검색어 (개별/전체 삭제) | O |
| 초기 화면: 감정으로 찾기 그리드 | O |
| 검색 입력: 아이콘 + 클리어 버튼 + 뒤로가기 | O |
| 감정 칩 가로 스크롤 (EMOTION_COLOR_MAP 색상) | O |
| 텍스트 + 감정 동시 필터 | O (클라이언트 사이드) |
| 필터 상태 바 (검색어 + 감정 + 결과 건수) | O |
| 빈 상태: 감정/검색 조합별 맞춤 메시지 | O |
| 디바운스 | 300ms |
| API | `search_posts` v1 (ILIKE) |
| 페이지네이션 | 50건 일괄 로드 |

### 웹 (SearchView.tsx) — 개선 필요
| 기능 | 상태 |
|---|---|
| 검색 입력: 아이콘만 | O (클리어 버튼 없음) |
| 감정 필터: URL 파라미터 연동 Badge | O (단일 Badge만) |
| 감정 칩 가로 스크롤 | X |
| 초기 화면: 최근 검색어 | X |
| 초기 화면: 감정으로 찾기 그리드 | X |
| 필터 상태 바 | X (결과 건수만) |
| 빈 상태 | 기본적 |
| 디바운스 | 500ms |
| API | `search_posts` v1 (ILIKE) |
| 페이지네이션 | 20건 일괄 로드 |

---

## 2. 동기화 범위

### 2.1 Phase A: 앱 v2 전환 (앱 레포)

앱의 검색 API를 `search_posts` → `search_posts_v2`로 전환.

#### 파일: `src/shared/lib/api/posts.ts`

```typescript
// 기존 searchPosts → v2로 교체
import type { SearchResult, SearchSort } from '@/types';

export async function searchPosts(params: {
  query: string;
  emotion?: string | null;
  sort?: SearchSort;
  limit?: number;
  offset?: number;
}): Promise<SearchResult[]> {
  const { query, emotion, sort = 'relevance', limit = 20, offset = 0 } = params;
  const q = query.trim();
  if (q.length < 2) return [];

  const { data, error } = await supabase.rpc('search_posts_v2', {
    p_query: q,
    p_emotion: emotion ?? null,
    p_sort: sort,
    p_limit: limit,
    p_offset: offset,
  });

  if (error) {
    logger.error('[API] searchPosts 에러:', error.message);
    throw new APIError(500, error.message);
  }

  return (data ?? []) as SearchResult[];
}
```

#### 파일: `src/app/search.tsx` 변경사항

1. **API 호출 변경**: `api.searchPosts(trimmed, 50, 0)` → `api.searchPosts({ query: trimmed, emotion: selectedEmotion || null, sort, limit: 20, offset })`
2. **서버 사이드 감정 필터**: 클라이언트 `posts.filter(...)` 제거 → `p_emotion` 파라미터로 서버 위임
3. **정렬 토글 UI 추가**: `관련도순` | `최신순` | `인기순`
4. **하이라이트 렌더링**: `title_highlight` / `content_highlight`에서 `<<>>` 파싱 → `<Text style={highlight}>`
5. **무한 스크롤**: `useInfiniteQuery` + FlashList `onEndReached`
6. **감정 전용 검색도 v2 사용**: `getPostsByEmotion` 대신 `searchPosts({ query: '', emotion })` — 단, v2는 query 2자 필수이므로 감정 전용은 기존 `getPostsByEmotion` RPC 유지

#### 하이라이트 컴포넌트: `src/shared/components/HighlightText.tsx`

```tsx
import { Text, type TextStyle } from 'react-native';

interface HighlightTextProps {
  text: string;
  highlightStyle?: TextStyle;
  style?: TextStyle;
  numberOfLines?: number;
}

/** <<...>> 구분자로 감싼 텍스트를 하이라이트 렌더링 */
export function HighlightText({ text, highlightStyle, style, numberOfLines }: HighlightTextProps) {
  const parts = parseHighlight(text);

  return (
    <Text style={style} numberOfLines={numberOfLines}>
      {parts.map((part, i) =>
        part.highlighted ? (
          <Text key={i} style={[{ fontWeight: '700', backgroundColor: '#FFF3CC' }, highlightStyle]}>
            {part.text}
          </Text>
        ) : (
          <Text key={i}>{part.text}</Text>
        ),
      )}
    </Text>
  );
}

function parseHighlight(text: string): { text: string; highlighted: boolean }[] {
  const parts: { text: string; highlighted: boolean }[] = [];
  const regex = /<<(.*?)>>/g;
  let lastIndex = 0;
  let match;

  while ((match = regex.exec(text)) !== null) {
    if (match.index > lastIndex) {
      parts.push({ text: text.slice(lastIndex, match.index), highlighted: false });
    }
    parts.push({ text: match[1], highlighted: true });
    lastIndex = regex.lastIndex;
  }

  if (lastIndex < text.length) {
    parts.push({ text: text.slice(lastIndex), highlighted: false });
  }

  return parts.length > 0 ? parts : [{ text, highlighted: false }];
}
```

---

### 2.2 Phase B: 웹 v2 전환 + UX 동기화 (웹 레포)

앱의 검색 UX를 웹에 이식하면서 동시에 v2 API로 전환.

#### 파일: `src/features/posts/api/postsApi.ts`

```typescript
// searchPosts → v2 교체
import type { SearchResult, SearchSort } from '@/types/database';

export async function searchPosts(params: {
  query: string;
  emotion?: string | null;
  sort?: SearchSort;
  limit?: number;
  offset?: number;
}): Promise<SearchResult[]> {
  const { query, emotion, sort = 'relevance', limit = 20, offset = 0 } = params;
  const supabase = createClient();
  const q = query.trim();
  if (q.length < 2) return [];

  const { data, error } = await supabase.rpc('search_posts_v2', {
    p_query: q,
    p_emotion: emotion ?? null,
    p_sort: sort,
    p_limit: limit,
    p_offset: offset,
  });
  if (error) throw error;
  return (data ?? []) as SearchResult[];
}
```

#### 파일: `src/features/posts/components/SearchView.tsx` — 전면 재작성

앱의 `search.tsx` 구조를 웹으로 이식:

```
[현재 웹]                              [개선 후 웹]
─────────────────────                ─────────────────────
🔍 [_______________]                 🔍 [_______________] ✕

(Badge 1개)                          감정 칩 가로 스크롤 (13개)
                                     EMOTION_COLOR_MAP 색상

                                     정렬: [관련도] [최신] [인기]

                                     필터 상태 바 + N건

PostCard × N                         SearchResultCard × N
                                      (하이라이트 + 감정 태그)
─────────────────────                ─────────────────────

[초기 상태]
─────────────────────
🔍 [_______________]

최근 검색어          전체 삭제
  🕐 우울한 하루     ✕
  🕐 직장 스트레스   ✕

감정으로 찾기
  [😰불안] [😢슬픔] [😔외로움] ...
─────────────────────
```

**주요 변경:**

| # | 항목 | 구현 |
|---|---|---|
| 1 | 초기 화면: 최근 검색어 | `localStorage` 기반 (앱의 `draftStorage` 대응) |
| 2 | 초기 화면: 감정으로 찾기 그리드 | `ALLOWED_EMOTIONS` + `EMOTION_EMOJI` |
| 3 | 감정 칩 가로 스크롤 | `overflow-x-auto flex gap-1.5` (앱의 ScrollView horizontal 대응) |
| 4 | 정렬 토글 | `관련도순` `최신순` `인기순` 버튼 그룹 |
| 5 | 필터 상태 바 | 검색어 + 감정 조합 표시 + N건 + 필터 해제 |
| 6 | 하이라이트 렌더링 | `<<>>` → `<mark>` 태그 변환 |
| 7 | 빈 상태 맞춤 메시지 | 감정/검색 조합별 (앱과 동일) |
| 8 | 클리어 버튼 | 입력 필드 우측 X 버튼 |
| 9 | API v2 전환 | `search_posts_v2` + 서버 사이드 감정 필터 |
| 10 | URL 파라미터 | `?q=&emotion=&sort=` (기존 q, emotion에 sort 추가) |
| 11 | 디바운스 | 500ms → 400ms (앱 300ms와의 중간값) |

#### 하이라이트 유틸: `src/lib/highlight.tsx`

```tsx
import { Fragment } from 'react';

/** <<...>> 구분자 텍스트를 <mark>로 렌더링 */
export function HighlightText({ text, className }: { text: string; className?: string }) {
  const parts = text.split(/<<(.*?)>>/g);

  return (
    <span className={className}>
      {parts.map((part, i) =>
        i % 2 === 1 ? (
          <mark key={i} className="bg-happy-100 text-inherit rounded-sm px-0.5">
            {part}
          </mark>
        ) : (
          <Fragment key={i}>{part}</Fragment>
        ),
      )}
    </span>
  );
}
```

#### 최근 검색어 유틸: `src/lib/recent-searches.ts`

```typescript
const STORAGE_KEY = 'search_recent';
const MAX_ITEMS = 8;

export function getRecentSearches(): string[] {
  if (typeof window === 'undefined') return [];
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.slice(0, MAX_ITEMS) : [];
  } catch {
    return [];
  }
}

export function addRecentSearch(query: string): void {
  if (!query.trim()) return;
  const recent = getRecentSearches().filter((q) => q !== query);
  recent.unshift(query.trim());
  localStorage.setItem(STORAGE_KEY, JSON.stringify(recent.slice(0, MAX_ITEMS)));
}

export function removeRecentSearch(query: string): string[] {
  const recent = getRecentSearches().filter((q) => q !== query);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(recent));
  return recent;
}

export function clearAllRecentSearches(): void {
  localStorage.removeItem(STORAGE_KEY);
}
```

---

### 2.3 Phase C: 중앙 문서 업데이트 (중앙 레포)

| 파일 | 변경 |
|---|---|
| `CLAUDE.md` | RPC 16개 반영 (이미 완료) |
| `docs/SCHEMA.md` | search_posts_v2 문서 (이미 완료) |
| `docs/DESIGN-search-improvements.md` | Phase 2~4 구현 상태 업데이트 |

---

## 3. 구현 순서

```
Phase A: 앱 v2 전환
  A1. src/shared/lib/api/posts.ts — searchPosts → v2 API
  A2. src/shared/components/HighlightText.tsx — 하이라이트 컴포넌트
  A3. src/app/search.tsx — v2 연동 + 정렬 토글 + 하이라이트 + 서버 사이드 감정 필터
  A4. 테스트 + EAS Update 배포

Phase B: 웹 v2 전환 + UX 동기화
  B1. src/lib/recent-searches.ts — 최근 검색어 유틸
  B2. src/lib/highlight.tsx — 하이라이트 컴포넌트
  B3. src/features/posts/api/postsApi.ts — searchPosts → v2 API
  B4. src/features/posts/components/SearchView.tsx — 전면 재작성
  B5. 테스트 + Vercel 배포

Phase C: 중앙 문서 최신화
  C1. docs/DESIGN-search-improvements.md — 구현 상태 업데이트
  C2. 커밋 + 푸시
```

---

## 4. 주의사항

### 감정 전용 검색 (텍스트 없음)
- `search_posts_v2`는 `p_query` 2자 미만이면 빈 결과 반환
- 감정만 선택한 경우 기존 `get_posts_by_emotion` RPC 유지 (앱/웹 동일)
- 향후 v2에 감정 전용 모드 추가 고려

### 타입 호환성
- `SearchResult` 인터페이스가 `Post`와 다름 (highlight, score 추가)
- `PostCard`가 `Post | PostWithCounts` 타입 기대 → `SearchResult`도 수용하도록 확인 필요
- 앱: `PostList`에 `SearchResult[]` 전달 시 타입 캐스팅 또는 컴포넌트 prop 확장

### 기존 search_posts v1 제거
- 앱/웹 모두 v2 전환 확인 후 별도 마이그레이션으로 DROP
- 전환 기간 동안 v1/v2 병행 유지

### URL 파라미터 (웹)
- 기존: `?q=&emotion=`
- 추가: `?q=&emotion=&sort=relevance`
- 하위 호환: `sort` 없으면 `'relevance'` 기본값

### 최근 검색어 저장
- 앱: `MMKV` (`draftStorage`) — 동기식, 빠름
- 웹: `localStorage` — SSR 시 `typeof window` 체크 필수
