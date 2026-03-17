# 서비스 개선 설계 v2 — Sentry 분석 + 감정 분석 리팩토링 + 닉네임 제거 + 검색 UX 개선

> 작성일: 2026-03-08
> 기반: Sentry 에러 로그 분석, 코드베이스 전수 조사

---

## 목차

1. [Sentry 에러 로그 분석](#1-sentry-에러-로그-분석)
2. [감정 분석 기능 리팩토링](#2-감정-분석-기능-리팩토링)
3. [닉네임 입력 항목 삭제](#3-닉네임-입력-항목-삭제)
4. [검색 페이지 프론트엔드 설계 개선](#4-검색-페이지-프론트엔드-설계-개선)

---

## 1. Sentry 에러 로그 분석

### 1-1. WEB-HERMIT-COMM-3 (웹, Priority: HIGH)

| 항목 | 값 |
|---|---|
| 이슈 ID | 7313066681 |
| 프로젝트 | web-hermit-comm (Next.js) |
| 에러 | `Error: Failed to load external module jsdom` |
| 발생 횟수 | 11회 (3일간) |
| 영향 경로 | `GET /post/[id]` (게시글 상세 페이지) |
| 환경 | production (Vercel, Node v24.13.0, Turbopack) |
| 상태 | unresolved, unhandled |

**근본 원인:**
- `isomorphic-dompurify@3.0.0`이 서버 사이드에서 `jsdom`을 `require()`로 로드
- `jsdom`의 의존성 `@exodus/bytes/encoding-lite.js`가 ESM-only 패키지
- Node.js의 CommonJS 컨텍스트에서 ESM 모듈을 `require()`할 수 없어 런타임 에러 발생
- 스택트레이스: `isomorphic-dompurify/dist/index.mjs:3` → `import { JSDOM } from "jsdom"` → `html-encoding-sniffer` → `@exodus/bytes` (ESM)

**영향 범위:**
- 게시글 상세 페이지(`/post/[id]`)에서 `sanitizeHtml()` 호출 시 서버 렌더링 실패
- `PostDetailView.tsx:279`에서 `dangerouslySetInnerHTML={{ __html: sanitizeHtml(post.content) }}` 사용

**해결 방안:**

```
[방안 A] isomorphic-dompurify 제거 → 서버/클라이언트 분리 (권장)
```

서버 사이드에서는 `jsdom` 의존 없이 HTML sanitize를 수행하고, 클라이언트에서만 `dompurify`를 사용:

```typescript
// src/lib/sanitize.ts (수정)
// 서버: 정규식 기반 경량 sanitizer
// 클라이언트: DOMPurify (브라우저 네이티브 DOM 사용)

const ALLOWED_TAGS_SET = new Set(['p', 'br', 'strong', 'em', 'u', 's', 'a', 'ul', 'ol', 'li', 'h1', 'h2', 'h3', 'blockquote', 'img', 'pre', 'code'])
const ALLOWED_ATTR_SET = new Set(['href', 'src', 'alt', 'class', 'target', 'rel'])

function serverSanitize(dirty: string): string {
  // 허용 태그 외 모두 제거 (정규식 기반)
  return dirty.replace(/<\/?([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>/gi, (match, tag) => {
    if (!ALLOWED_TAGS_SET.has(tag.toLowerCase())) return ''
    // 허용 태그의 속성 필터링
    return match.replace(/\s+([a-zA-Z-]+)(?:=(?:"[^"]*"|'[^']*'|[^\s>]*))?/g, (attrMatch, attr) => {
      return ALLOWED_ATTR_SET.has(attr.toLowerCase()) ? attrMatch : ''
    })
  })
}

let clientSanitize: ((dirty: string) => string) | null = null

export function sanitizeHtml(dirty: string): string {
  if (typeof window !== 'undefined') {
    if (!clientSanitize) {
      const DOMPurify = require('dompurify')  // 브라우저 전용 (jsdom 불필요)
      clientSanitize = (html: string) =>
        DOMPurify.sanitize(html, {
          ALLOWED_TAGS: [...ALLOWED_TAGS_SET],
          ALLOWED_ATTR: [...ALLOWED_ATTR_SET],
        })
    }
    return clientSanitize(dirty)
  }
  return serverSanitize(dirty)
}
```

패키지 변경:
```diff
- "isomorphic-dompurify": "^3.0.0",
+ "dompurify": "^3.2.0",
+ "@types/dompurify": "^3.2.0",
```
`jsdom`은 devDependencies(vitest용)에만 남김.

```
[방안 B] Next.js dynamic import로 클라이언트 전용 렌더링
```

`PostDetailView.tsx`에서 콘텐츠 영역만 클라이언트 렌더링:

```typescript
// PostDetailContent.tsx (새 컴포넌트)
'use client'
import DOMPurify from 'dompurify'  // 브라우저 전용

export function PostContent({ html }: { html: string }) {
  const clean = DOMPurify.sanitize(html, { ALLOWED_TAGS, ALLOWED_ATTR })
  return <div dangerouslySetInnerHTML={{ __html: clean }} />
}
```

**권장: 방안 A** — SEO를 위한 서버 렌더링을 유지하면서 에러를 근본적으로 해결.

---

### 1-2. GNS-HERMIT-COMM-7 (앱, Priority: MEDIUM, Escalating)

| 항목 | 값 |
|---|---|
| 이슈 ID | 7304843201 |
| 프로젝트 | gns-hermit-comm (React Native) |
| 에러 | `reportToSentry` → 다수 API 에러 집합 |
| 발생 횟수 | 106회 (5일간), 9명 영향 |
| 버전 | v1.6.0 ~ v1.7.0 |
| 상태 | unresolved, escalating |

**에러 분포 (100건 샘플):**

| 에러 메시지 | 횟수 | 비율 |
|---|---|---|
| `[API] searchPosts 에러:` | 61 | 61% |
| `[API] invokeSmartService 에러:` | 28 | 28% |
| `[API] createPost 에러:` | 7 | 7% |
| `[API] my groups 조회 에러:` | 2 | 2% |
| `[Auth] 이메일 로그인 실패:` | 1 | 1% |
| `[API] board posts 조회 에러:` | 1 | 1% |

**핵심 문제 1: searchPosts 에러 (61%)**

`search_posts_v2` RPC 호출 실패. 가능한 원인:
- Supabase RPC 함수의 풀텍스트 검색이 한국어 특수문자/짧은 쿼리에서 PostgreSQL 에러
- `p_emotion`에 `undefined` 전달 시 RPC 파라미터 타입 불일치
- 네트워크 타임아웃 (복잡한 쿼리 + ts_headline)

**핵심 문제 2: invokeSmartService 에러 (28%)**

Edge Function(`analyze-post-on-demand`) 호출 실패. 원인 분석은 [섹션 2](#2-감정-분석-기능-리팩토링)에서 상세.

**핵심 문제 3: logger.error의 Sentry 전송 품질**

현재 `logger.ts`의 `reportToSentry` 함수 문제:
```typescript
// 현재: 에러 메시지만 전송, 원인 정보 누락
logger.error('[API] invokeSmartService 에러:', error.message);
// → Sentry에 "[API] invokeSmartService 에러:" 만 기록, 실제 에러 내용 누락
```

`error.message`가 `undefined`일 때 빈 문자열로 전송되어 디버깅 정보 손실.

**해결 방안:**

```typescript
// logger.ts 개선
function reportToSentry(args: unknown[]): void {
  if (IS_DEV) return;
  try {
    const Sentry = require('@sentry/react-native');

    // 모든 args를 하나의 메시지로 결합 + Error 객체 분리
    const errors: Error[] = [];
    const parts: string[] = [];

    for (const arg of args) {
      if (arg instanceof Error) {
        errors.push(arg);
        parts.push(arg.message);
      } else if (arg !== undefined && arg !== null) {
        parts.push(String(arg));
      }
    }

    const message = parts.join(' ') || 'Unknown error';

    if (errors.length > 0) {
      Sentry.captureException(errors[0], {
        extra: { fullMessage: message, args: args.slice(1) },
      });
    } else {
      Sentry.captureMessage(message, {
        level: 'error',
        extra: { args },
      });
    }
  } catch {
    // Sentry 미설정 시 무시
  }
}
```

**API 에러 로깅 개선:**
```typescript
// 현재
logger.error('[API] searchPosts 에러:', error.message);
// 개선 → error 객체 전체 전송
logger.error('[API] searchPosts 에러:', error.message, { code: error.code, details: error.details, hint: error.hint });
```

---

## 2. 감정 분석 기능 리팩토링

### 2-1. 현재 아키텍처 분석

```
게시글 작성/수정
  │
  ├─[자동] DB Trigger → Webhook → analyze-post Edge Function
  │   └─ Gemini API 호출 → post_analysis UPSERT
  │
  └─[폴백] 15초 후 앱에서 analyze-post-on-demand 수동 호출
      └─ usePostDetailAnalysis.ts (3초 폴링 + Realtime + 15초 fallback)
```

### 2-2. 식별된 문제점

#### P1: Edge Function 호출 실패 (Sentry 28건)

**원인 분석:**
1. **Gemini API 키 미설정/만료**: `GEMINI_API_KEY` 환경변수 누락 시 500 응답
2. **Gemini API 제한**: 무료 티어의 RPM(요청/분) 제한 초과 → 429 에러
3. **Edge Function cold start**: Supabase Edge Function 초기화 시간(~2초) + Gemini 응답 시간
4. **콘텐츠 빈값 전송**: `invokeSmartService(postId, '')` 호출 시, on-demand 함수가 DB에서 content를 재조회하지만 post가 삭제되었거나 접근 불가하면 빈 콘텐츠로 분석 시도

**에러 메시지 누락 문제:**
```typescript
// analysis.ts:49 — error.message가 undefined일 수 있음
logger.error('[API] invokeSmartService 에러:', error.message);
```
`supabase.functions.invoke`의 error 객체는 `FunctionsHttpError | FunctionsRelayError | FunctionsFetchError` 중 하나이며, `.message` 대신 `.context`에 실제 에러 정보가 있을 수 있음.

#### P2: 불필요한 폴백 호출

현재 `usePostDetailAnalysis.ts`는 게시글 상세 진입 시 무조건 15초 타이머를 설정. 이미 분석 완료된(status='done') 게시글도 불필요하게 15초를 기다린 후 `needsFallback` 체크를 수행.

#### P3: 폴링 + Realtime 중복

3초 폴링과 Realtime 구독이 동시에 동작. Realtime이 정상이면 폴링은 불필요한 DB 부하.

#### P4: 재시도 로직의 비결정성

- 서버(Edge Function): `callGeminiWithRetry` 최대 3회 (1s, 2s 백오프)
- 클라이언트(앱): 15초 후 1회 fallback → 실패 시 추가 재시도 없음
- DB에 `retry_count`를 기록하지만, 이를 기반으로 한 재시도 판단 로직 없음

#### P5: Gemini 모델 하드코딩

`_shared/analyze.ts:191`: `Deno.env.get('GEMINI_MODEL') ?? 'gemini-2.5-flash'`
- 환경변수로 모델 변경 가능하나, 모델 변경 시 프롬프트 호환성 검증 없음
- `thinkingBudget: 0`은 Flash 모델 전용 설정 — 다른 모델에서 무시될 수 있음

### 2-3. 리팩토링 설계

#### A. Edge Function 에러 핸들링 강화

```typescript
// _shared/analyze.ts 개선

// 1. 에러 타입 세분화
export type AnalyzeErrorCode =
  | 'missing_api_key'
  | 'content_too_short'
  | 'cooldown_60s'
  | 'gemini_rate_limit'    // 429
  | 'gemini_api_error'     // 4xx (429 제외)
  | 'gemini_server_error'  // 5xx
  | 'json_parse_error'
  | 'no_valid_emotions'
  | 'db_upsert_error'
  | 'unknown';

// 2. 결과에 에러 코드 포함
export type AnalyzeResult =
  | { ok: true; emotions: string[] }
  | { ok: true; skipped: string }
  | { ok: false; reason: AnalyzeErrorCode; message: string; retryable: boolean };

// 3. retryable 판단을 서버에서 결정
// 429, 5xx, json_parse_error, no_valid_emotions → retryable: true
// 400, 403, missing_api_key → retryable: false
```

#### B. 클라이언트 에러 핸들링 개선

```typescript
// analysis.ts 개선
export async function invokeSmartService(
  postId: number,
  content: string,
  title?: string,
): Promise<{ emotions: string[]; error?: string; retryable?: boolean }> {
  const { data, error } = await supabase.functions.invoke(SMART_SERVICE_FUNCTION, {
    body: { postId, content, title },
  });

  if (error) {
    // FunctionsHttpError/FunctionsRelayError/FunctionsFetchError 구분
    const errorMessage = error instanceof Error ? error.message : String(error);
    const context = (error as { context?: unknown }).context;
    logger.error('[API] invokeSmartService 에러:', errorMessage, { context, postId });
    return { emotions: [], error: errorMessage };
  }

  const result = data as AnalyzeResult | null;
  if (!result?.ok) {
    const failResult = result as { reason?: string; retryable?: boolean } | null;
    return {
      emotions: [],
      error: failResult?.reason ?? 'unknown',
      retryable: failResult?.retryable ?? false,
    };
  }

  if ('emotions' in result) return { emotions: result.emotions };
  return { emotions: [] };
}
```

#### C. usePostDetailAnalysis 리팩토링

```typescript
// usePostDetailAnalysis.ts 개선

export function usePostDetailAnalysis(postId: number) {
  const queryClient = useQueryClient();
  const fallbackCalledRef = useRef(false);

  useEffect(() => {
    fallbackCalledRef.current = false;
  }, [postId]);

  const { data: postAnalysis, isLoading: analysisLoading } = useQuery({
    queryKey: ['postAnalysis', postId],
    queryFn: () => api.getPostAnalysis(postId),
    enabled: postId > 0,
    staleTime: 5 * 60 * 1000,
    // 개선: 폴링은 Realtime 실패 시에만 (Realtime이 주축)
    refetchInterval: (query) => {
      const status = (query.state.data as PostAnalysis | null | undefined)?.status;
      if (status === 'done' || status === 'failed') return false;
      // pending/analyzing 상태에서만 5초 간격 (3초 → 5초로 완화)
      return status === 'pending' || status === 'analyzing' ? 5000 : false;
    },
  });

  // Realtime 구독 (변경 없음)
  useEffect(() => {
    const channel = supabase
      .channel(`post-analysis-${postId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'post_analysis',
        filter: `post_id=eq.${postId}`,
      }, () => {
        queryClient.invalidateQueries({ queryKey: ['postAnalysis', postId] });
      })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [postId, queryClient]);

  // 개선된 On-demand 폴백
  useEffect(() => {
    if (postId <= 0) return;

    // 1차: 10초 후 체크 (15초 → 10초로 단축)
    const timer = setTimeout(async () => {
      if (fallbackCalledRef.current) return;
      const cached = queryClient.getQueryData<PostAnalysis | null>(['postAnalysis', postId]);

      // 이미 완료/실패면 스킵
      if (cached?.status === 'done') return;

      // failed + retry_count >= 3이면 더 이상 재시도 안 함
      if (cached?.status === 'failed' && (cached.retry_count ?? 0) >= 3) return;

      const needsFallback =
        cached === null || cached === undefined ||
        cached.status === 'pending' || cached.status === 'analyzing';

      if (needsFallback) {
        fallbackCalledRef.current = true;
        const currentPost = queryClient.getQueryData<{ content?: string; title?: string }>(['post', postId]);
        const result = await api.invokeSmartService(
          postId,
          currentPost?.content ?? '',
          currentPost?.title,
        );

        // 실패 시 3초 후 refetch (성공은 Realtime이 처리)
        if (result.emotions.length === 0) {
          setTimeout(() => {
            queryClient.invalidateQueries({ queryKey: ['postAnalysis', postId] });
          }, 3000);
        }
      }
    }, 10000);

    return () => clearTimeout(timer);
  }, [postId, queryClient]);

  return { postAnalysis, analysisLoading };
}
```

#### D. 감정 분석 상태 UI 개선

현재 분석 중/실패 시 사용자에게 명확한 피드백이 없음. 상태별 UI 추가:

| status | UI 표시 |
|---|---|
| `pending` | "마음을 읽고 있어요..." + 물결 애니메이션 |
| `analyzing` | "감정을 분석하고 있어요..." + 진행 애니메이션 |
| `done` | 감정 태그 표시 (현행) |
| `failed` (retry < 3) | "분석에 실패했어요" + "다시 시도" 버튼 |
| `failed` (retry >= 3) | "분석할 수 없었어요" (재시도 버튼 없음) |

#### E. 모니터링 개선

Edge Function 로그에 구조화된 JSON 출력:
```typescript
console.log(JSON.stringify({
  event: 'analyze_complete',
  postId,
  status: 'done',
  emotions,
  model: MODEL,
  durationMs: Date.now() - startTime,
  attempt: attemptCount,
}));
```

---

## 3. 닉네임 입력 항목 삭제

### 3-1. 현황 분석

**익명성 위배 시나리오:**
- 현재 `always_anon` 모드에서도 닉네임 입력 필드가 노출됨
- `resolveDisplayName()`은 `always_anon`이면 입력값을 무시하고 자동 별칭을 생성
- 즉, **입력받지만 사용하지 않는** 불필요한 UX 요소
- 사용자가 실명/식별 가능한 닉네임을 입력하면 `storage`에 저장되어 `useAuthor` 훅으로 계속 추적됨
- `allow_choice` 모드 전환 시 저장된 닉네임이 노출될 위험

**관련 코드 위치:**

| 파일 | 역할 |
|---|---|
| 앱 `src/app/(tabs)/create.tsx:175-188` | 닉네임 Input 필드 렌더링 |
| 앱 `src/features/posts/hooks/useAuthor.ts` | 닉네임 로컬 저장/복원 |
| 앱 `src/features/posts/hooks/useDraft.ts` | 임시저장에 author 포함 |
| 앱 `src/features/posts/hooks/useCreatePost.ts` | 폼에 author 필드 포함 |
| 앱 `src/shared/lib/schemas.ts` | 폼 검증 스키마 (author 필드) |
| 앱 `src/shared/lib/anonymous.ts` | resolveDisplayName (author 처리) |
| 웹 `src/features/posts/components/CreatePostForm.tsx` | 이미 닉네임 입력 없음 |

### 3-2. 변경 설계

**원칙**: 웹은 이미 닉네임 입력 없이 자동 별칭(`resolveDisplayName`)만 사용. 앱도 동일하게 통일.

#### A. 앱 게시글 작성 화면 수정

```diff
// src/app/(tabs)/create.tsx

- import { useAuthor } from '@/features/posts/hooks/useAuthor';

  export default function CreateScreen() {
-   const { author: savedAuthor, setAuthor: saveAuthor } = useAuthor();

    const {
      control, handleSubmit, setValue, watch,
      handleContentChange, errors, isSubmitting,
-     showName, setShowName,
      onSubmit: handleFormSubmit,
    } = useCreatePost({
      boardId: DEFAULT_PUBLIC_BOARD_ID,
      user,
      anonMode,
-     defaultValues: { author: savedAuthor ?? '' },
-     getExtraPostData: () => ({ ... }),
+     getExtraPostData: () => ({
+       image_url: imageUrl ?? undefined,
+       ...(initialEmotions.length > 0 ? { initial_emotions: initialEmotions } : {}),
+     }),
      onSuccess: async (data) => {
-       const rawAuthor = data.author?.trim() ?? '';
-       if (rawAuthor && rawAuthor !== (savedAuthor ?? '')) {
-         await saveAuthor(rawAuthor);
-       }
        clearDraft();
        Toast.show({ type: 'success', text1: '게시글이 작성되었습니다.' });
        pushTabs(router);
      },
      ...
    });

    // 렌더링에서 제거:
-   <Controller
-     control={control}
-     name="author"
-     render={({ field: { value, onChange } }) => (
-       <Input label="닉네임 (선택)" ... />
-     )}
-   />
-
-   <AnonModeInfo
-     anonMode={anonMode}
-     showName={showName}
-     onToggle={() => setShowName((prev) => !prev)}
-   />
  }
```

#### B. useCreatePost 훅 정리

```diff
// src/features/posts/hooks/useCreatePost.ts

  const onSubmit = useCallback(async (data: PostFormValues) => {
-   const rawAuthor = data.author?.trim() ?? '';
-   const { isAnonymous, displayName } = resolveDisplayName({
-     anonMode,
-     rawAuthorName: rawAuthor,
-     userId: user?.id ?? null,
-     boardId,
-     groupId: groupId ?? null,
-     wantNameOverride: showName,
-   });
+   const { isAnonymous, displayName } = resolveDisplayName({
+     anonMode,
+     userId: user?.id ?? null,
+     boardId,
+     groupId: groupId ?? null,
+   });
```

#### C. 스키마 수정

```diff
// src/shared/lib/schemas.ts
  export const postSchema = z.object({
    title: z.string().min(1, '제목을 입력하세요').max(100),
    content: z.string().min(1, '내용을 입력하세요').max(5000),
-   author: z.string().max(50).optional().default(''),
  });
```

#### D. useAuthor 훅 제거

- `src/features/posts/hooks/useAuthor.ts` 삭제
- `storage.getAuthor()`, `storage.saveAuthor()` 관련 코드 정리
- 기존 저장된 author 값은 자연 소멸 (localStorage/AsyncStorage에 남아있어도 참조 안 함)

#### E. AnonModeInfo 컴포넌트 간소화

`always_anon` 모드에서는 단순 안내 텍스트만 표시:
```
"모든 게시글은 익명으로 작성됩니다. 게시판별 고유 별칭이 자동 부여돼요."
```
`showName` 토글 제거 (always_anon에서는 의미 없음).

#### F. 임시저장(Draft) 스키마 수정

```diff
// useDraft.ts
  interface Draft {
    title: string;
    content: string;
-   author: string;
  }
```

#### G. 마이그레이션 불필요

DB `posts` 테이블의 `display_name` 컬럼은 유지 — `resolveDisplayName()`이 자동 생성한 별칭을 저장하는 데 계속 사용.

---

## 4. 검색 페이지 프론트엔드 설계 개선

### 4-1. 현황 분석

**앱 (search.tsx, 575줄)**
- 단일 파일에 모든 로직 집중 (SearchScreen + SearchResultCard + SearchResultList + EmotionPostList)
- 3가지 모드: 초기(최근검색어+감정추천) / 텍스트검색 / 감정전용
- FlashList 무한스크롤, SEARCH_CONFIG 중앙 상수 사용
- HighlightText + SEARCH_HIGHLIGHT 색상 적용

**웹 (SearchView.tsx, 397줄)**
- SearchView에 모든 로직 집중
- URL 파라미터 동기화 (`/search?q=...&emotion=...&sort=...`)
- 무한스크롤 "더 보기" 버튼 방식
- HighlightText + 테마 대응

**공통 문제:**

| 문제 | 영향 |
|---|---|
| Sentry: searchPosts 에러 61% | RPC 호출 실패 시 사용자에게 빈 화면 |
| 에러 상태 UI 없음 | 네트워크/서버 에러 시 빈 상태와 구분 불가 |
| 감정 전용 모드 + 텍스트 모드 전환 시 깜빡임 | 쿼리 키 변경으로 데이터 리셋 |
| 검색 결과 0건일 때 검색어 제안 없음 | 사용자 이탈 |
| 단일 파일 575줄 (앱) | 유지보수 어려움 |

### 4-2. 설계 개선

#### A. 에러 상태 UI 추가 (앱/웹 공통)

현재 `searchPosts`가 `throw new APIError()`를 하면 TanStack Query의 `error` 상태가 됨. 하지만 UI에서 `error`를 처리하지 않음.

```typescript
// 앱/웹 공통 패턴
const { data, isLoading, error, refetch } = useInfiniteQuery({ ... });

// 에러 상태 UI
{error && !isLoading && (
  <ErrorState
    title="검색 중 문제가 발생했어요"
    description="잠시 후 다시 시도해주세요"
    onRetry={refetch}
  />
)}
```

앱 전용 ErrorState:
```typescript
function SearchErrorState({ onRetry }: { onRetry: () => void }) {
  return (
    <View className="items-center justify-center py-16">
      <Text className="text-2xl mb-2">😥</Text>
      <Text className="text-base font-semibold text-gray-700 dark:text-stone-200 mb-1">
        검색 중 문제가 발생했어요
      </Text>
      <Text className="text-sm text-gray-500 dark:text-stone-400 mb-4 text-center">
        네트워크를 확인하고 다시 시도해주세요
      </Text>
      <Pressable onPress={onRetry} className="px-4 py-2 rounded-xl bg-happy-400 active:bg-happy-500">
        <Text className="text-sm font-semibold text-white">다시 시도</Text>
      </Pressable>
    </View>
  );
}
```

#### B. searchPosts RPC 방어 강화

```typescript
// posts.ts — searchPosts 개선
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

  // 방어: 특수문자만으로 구성된 쿼리 필터링
  const sanitized = q.replace(/[&|!():*<>'"\\]/g, ' ').trim();
  if (sanitized.length < 2) return [];

  const { data, error } = await supabase.rpc('search_posts_v2', {
    p_query: sanitized,
    p_emotion: emotion || null,  // undefined → null 명시적 변환
    p_sort: sort,
    p_limit: limit,
    p_offset: offset,
  });

  if (error) {
    logger.error('[API] searchPosts 에러:', error.message, {
      code: error.code,
      details: error.details,
      query: sanitized,
    });
    throw new APIError(500, error.message);
  }

  return (data ?? []) as SearchResult[];
}
```

DB 측 방어 (마이그레이션):
```sql
-- search_posts_v2 함수 내부 방어 추가
-- 쿼리 sanitize: tsquery 파싱 실패 방지
v_safe_query := regexp_replace(p_query, '[&|!():*<>''"\\]', ' ', 'g');
v_safe_query := trim(regexp_replace(v_safe_query, '\s+', ' ', 'g'));

IF length(v_safe_query) < 2 THEN
  RETURN;
END IF;
```

#### C. 앱 컴포넌트 분리

```
src/app/search.tsx (메인 — 상태 관리 + 레이아웃만)
  ├── src/features/search/components/SearchHeader.tsx       (검색 입력 + 뒤로가기)
  ├── src/features/search/components/EmotionFilter.tsx      (감정 칩 필터)
  ├── src/features/search/components/SortBar.tsx            (정렬 + 필터 상태)
  ├── src/features/search/components/RecentSearches.tsx     (최근 검색어)
  ├── src/features/search/components/SearchResultCard.tsx   (기존 SearchResultCard 분리)
  ├── src/features/search/components/SearchResultList.tsx   (FlashList 래퍼)
  ├── src/features/search/components/EmotionPostList.tsx    (감정 전용 리스트)
  ├── src/features/search/components/SearchErrorState.tsx   (에러 UI)
  └── src/features/search/hooks/useSearch.ts               (검색 로직 훅)
```

`useSearch` 훅으로 상태 관리를 분리:
```typescript
// useSearch.ts
export function useSearch(initialParams?: { q?: string; emotion?: string }) {
  const [query, setQuery] = useState(initialParams?.q ?? '');
  const [debouncedQuery, setDebouncedQuery] = useState(initialParams?.q ?? '');
  const [selectedEmotion, setSelectedEmotion] = useState(initialParams?.emotion ?? '');
  const [sort, setSort] = useState<SearchSort>('relevance');

  // 디바운스
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedQuery(query), SEARCH_CONFIG.DEBOUNCE_MS);
    return () => clearTimeout(timer);
  }, [query]);

  const trimmedQuery = debouncedQuery.trim();
  const hasTextQuery = trimmedQuery.length >= SEARCH_CONFIG.MIN_QUERY_LENGTH;
  const isSearchMode = hasTextQuery;
  const isEmotionOnlyMode = selectedEmotion.length > 0 && !hasTextQuery;

  // TanStack Query — 텍스트 검색
  const searchQuery = useInfiniteQuery({
    queryKey: ['search', trimmedQuery, selectedEmotion, sort],
    queryFn: ({ pageParam = 0 }) => api.searchPosts({
      query: trimmedQuery,
      emotion: selectedEmotion || null,
      sort,
      limit: SEARCH_CONFIG.PAGE_SIZE,
      offset: pageParam,
    }),
    getNextPageParam: (lastPage, allPages) =>
      lastPage.length === SEARCH_CONFIG.PAGE_SIZE ? allPages.flat().length : undefined,
    initialPageParam: 0,
    enabled: hasTextQuery,
    staleTime: SEARCH_CONFIG.STALE_TIME_MS,
    retry: 1,  // 1회 자동 재시도
  });

  // TanStack Query — 감정 전용
  const emotionQuery = useQuery({
    queryKey: ['postsByEmotion', selectedEmotion],
    queryFn: () => api.getPostsByEmotion(selectedEmotion, 50, 0),
    enabled: isEmotionOnlyMode,
  });

  return {
    // 입력
    query, setQuery,
    selectedEmotion, setSelectedEmotion,
    sort, setSort,
    // 파생 상태
    trimmedQuery, hasTextQuery, isSearchMode, isEmotionOnlyMode,
    hasActiveFilter: hasTextQuery || selectedEmotion.length > 0,
    // 쿼리 결과
    searchResults: searchQuery.data?.pages.flat() ?? [],
    emotionPosts: emotionQuery.data ?? [],
    isLoading: isSearchMode ? searchQuery.isLoading : isEmotionOnlyMode ? emotionQuery.isLoading : false,
    error: isSearchMode ? searchQuery.error : isEmotionOnlyMode ? emotionQuery.error : null,
    hasNextPage: searchQuery.hasNextPage,
    isFetchingNextPage: searchQuery.isFetchingNextPage,
    fetchNextPage: searchQuery.fetchNextPage,
    refetch: isSearchMode ? searchQuery.refetch : emotionQuery.refetch,
  };
}
```

#### D. 검색 결과 0건 시 개선

빈 결과일 때 사용자 이탈을 줄이기 위한 UX:

```
검색 결과가 없어요
────────────────────
이런 검색어는 어때요?
  · "외로움" → 감정 필터 바로가기
  · "무기력할 때" → 제안 검색어
────────────────────
감정으로 탐색하기
  [고립감] [무기력] [불안] ...
```

#### E. 웹 Intersection Observer 무한스크롤

현재 "더 보기" 버튼을 Intersection Observer로 교체:

```typescript
// SearchView.tsx 내부
const loadMoreRef = useRef<HTMLDivElement>(null);

useEffect(() => {
  if (!loadMoreRef.current || !hasNextPage) return;
  const observer = new IntersectionObserver(([entry]) => {
    if (entry.isIntersecting && !isFetchingNextPage) {
      fetchNextPage();
    }
  }, { threshold: 0.1 });
  observer.observe(loadMoreRef.current);
  return () => observer.disconnect();
}, [hasNextPage, isFetchingNextPage, fetchNextPage]);

// 렌더링
{hasNextPage && <div ref={loadMoreRef} className="h-10" />}
{isFetchingNextPage && <PostCardSkeleton />}
```

#### F. 검색어 하이라이트 개선

현재 ts_headline이 `<b>...</b>` 태그를 반환하며, 프론트에서 파싱. 추가 개선:

- 검색 키워드가 제목에 없고 본문에만 있을 때, 제목 하이라이트가 비어있는 문제 → 원본 title 폴백
- 하이라이트 텍스트가 잘리는 경우(`...` prefix) 처리 개선

---

## 구현 우선순위

| 순위 | 작업 | 영향도 | 난이도 | 예상 변경 범위 |
|---|---|---|---|---|
| 1 | isomorphic-dompurify 에러 수정 | HIGH (웹 상세페이지 깨짐) | LOW | 웹 sanitize.ts + package.json |
| 2 | logger/Sentry 에러 품질 개선 | HIGH (디버깅 불가) | LOW | 앱 logger.ts + API 파일들 |
| 3 | searchPosts RPC 방어 (특수문자) | HIGH (61% 에러) | LOW | 앱/웹 posts.ts + DB 마이그레이션 |
| 4 | 닉네임 입력 항목 삭제 | MEDIUM (익명성) | LOW | 앱 create.tsx + 훅/스키마 |
| 5 | 감정 분석 에러 핸들링 강화 | MEDIUM (28% 에러) | MEDIUM | Edge Function + analysis.ts |
| 6 | 검색 에러 상태 UI | MEDIUM (UX) | LOW | 앱/웹 검색 컴포넌트 |
| 7 | usePostDetailAnalysis 리팩토링 | LOW (성능) | MEDIUM | 앱 훅 |
| 8 | 앱 검색 컴포넌트 분리 | LOW (유지보수) | MEDIUM | 앱 search 폴더 구조화 |
| 9 | 웹 무한스크롤 개선 | LOW (UX) | LOW | 웹 SearchView |

---

## 파일 변경 맵

```
[웹] /home/gunny/apps/web-hermit-comm
  src/lib/sanitize.ts              — isomorphic-dompurify → dompurify + 서버 폴백
  package.json                     — 의존성 교체

[앱] /mnt/c/Users/Administrator/programming/apps/gns-hermit-comm
  src/shared/utils/logger.ts       — reportToSentry 에러 품질 개선
  src/shared/lib/api/posts.ts      — searchPosts 특수문자 방어
  src/shared/lib/api/analysis.ts   — invokeSmartService 에러 상세화
  src/app/(tabs)/create.tsx        — 닉네임 입력 제거
  src/features/posts/hooks/useCreatePost.ts — author 필드 제거
  src/features/posts/hooks/useAuthor.ts     — 삭제
  src/features/posts/hooks/useDraft.ts      — author 필드 제거
  src/shared/lib/schemas.ts        — author 필드 제거
  src/features/posts/hooks/usePostDetailAnalysis.ts — 폴백 로직 개선
  src/features/posts/components/AnonModeInfo.tsx    — 간소화
  supabase/functions/_shared/analyze.ts — 에러 타입 세분화

[중앙] /home/gunny/apps/supabase-hermit
  supabase/migrations/XXXXXXXX_search_v2_defense.sql — tsquery 방어 추가
```
