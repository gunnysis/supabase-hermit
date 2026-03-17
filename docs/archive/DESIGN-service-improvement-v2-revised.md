# 서비스 개선 설계 v2 — 수정 설계안 (코드 대조 검증 완료)

> 작성일: 2026-03-08
> 기반: DESIGN-service-improvement-v2.md + 앱/웹/중앙 코드베이스 전수 대조
> 목적: 원안의 설계를 실제 코드와 대조하여 **정확한 변경 지점, 누락된 문제, 보안 주의사항, 호환성 전략**을 확정

---

## 목차

1. [isomorphic-dompurify 에러 수정 (웹)](#1-isomorphic-dompurify-에러-수정-웹)
2. [logger/Sentry 에러 품질 개선 (앱)](#2-loggersentry-에러-품질-개선-앱)
3. [searchPosts RPC 방어 강화 (앱/웹/DB)](#3-searchposts-rpc-방어-강화-앱웹db)
4. [닉네임 입력 항목 삭제 (앱)](#4-닉네임-입력-항목-삭제-앱)
5. [감정 분석 에러 핸들링 강화 (Edge Function/앱)](#5-감정-분석-에러-핸들링-강화-edge-function앱)
6. [검색 에러 상태 UI (앱/웹)](#6-검색-에러-상태-ui-앱웹)
7. [usePostDetailAnalysis 리팩토링 (앱)](#7-usepostdetailanalysis-리팩토링-앱)
8. [앱 검색 컴포넌트 분리 (앱)](#8-앱-검색-컴포넌트-분리-앱)
9. [웹 무한스크롤 개선 (웹)](#9-웹-무한스크롤-개선-웹)

---

## 1. isomorphic-dompurify 에러 수정 (웹)

### 코드 대조 결과

| 항목 | 원안 | 실제 코드 | 일치 |
|---|---|---|---|
| sanitize.ts 위치 | `src/lib/sanitize.ts` | `src/lib/sanitize.ts` (8줄) | O |
| isomorphic-dompurify 사용 | O | `import DOMPurify from 'isomorphic-dompurify'` (L1) | O |
| package.json 의존성 | `"isomorphic-dompurify": "^3.0.0"` | 동일 (L31) | O |
| jsdom devDeps | O | `"jsdom": "^28.1.0"` (L54, vitest용) | O |
| PostDetailView 사용 | L279 | `PostDetailView.tsx:279` — `sanitizeHtml(post.content)` | O |
| 사용처 | PostDetailView만 | Grep 확인: PostDetailView만 사용 (1곳) | O |

### 원안 평가: 방안 A 보안 우려

원안의 **서버 사이드 정규식 sanitizer**는 보안 취약점이 있다:

```typescript
// 원안: 정규식 기반 — XSS 우회 가능
dirty.replace(/<\/?([a-zA-Z][a-zA-Z0-9]*)\b[^>]*>/gi, ...)
```

**문제점:**
1. 정규식으로 HTML을 안전하게 파싱하는 것은 근본적으로 불가능 (nested quotes, comments, CDATA 등)
2. `<img src=x onerror=alert(1)>` — 속성 필터링 정규식이 edge case에서 우회될 수 있음
3. HTML entities (`&#x3C;script&#x3E;`), SVG/MathML namespace 공격 미방어

### 수정 설계안: 방안 B (클라이언트 전용 렌더링)

**전략**: 콘텐츠 영역만 `'use client'` 컴포넌트로 분리하여 브라우저 네이티브 DOMPurify만 사용.

**방안 A-R(서버 stripHtml + 클라이언트 DOMPurify)을 채택하지 않는 이유:**
- 서버/클라이언트 출력 불일치로 React hydration warning 발생 (`suppressHydrationWarning`으로 억제 가능하나 근본 해결 아님)
- SEO 영향이 미미함 (검색엔진은 plain text도 동일 인덱싱, `<meta>`와 `<title>`은 별도 설정)
- 코드 복잡도 증가 대비 이점 없음

```typescript
// PostContent.tsx (새 파일)
'use client'
import DOMPurify from 'dompurify'

const ALLOWED_TAGS = ['p', 'br', 'strong', 'em', 'u', 's', 'a', 'ul', 'ol', 'li', 'h1', 'h2', 'h3', 'blockquote', 'img', 'pre', 'code']
const ALLOWED_ATTR = ['href', 'src', 'alt', 'class', 'target', 'rel']

export function PostContent({ html }: { html: string }) {
  const clean = DOMPurify.sanitize(html, { ALLOWED_TAGS, ALLOWED_ATTR })
  return <div className="prose dark:prose-invert" dangerouslySetInnerHTML={{ __html: clean }} />
}
```

`PostDetailView.tsx:279`에서 `sanitizeHtml()` 호출을 `<PostContent>` 컴포넌트로 교체:

```diff
// PostDetailView.tsx
- import { sanitizeHtml } from '@/lib/sanitize'
+ import { PostContent } from './PostContent'

  // L279:
- <div
-   className="post-content"
-   dangerouslySetInnerHTML={{ __html: sanitizeHtml(post.content) }}
- />
+ <PostContent html={post.content} />
```

`sanitize.ts`는 다른 사용처가 없으므로 삭제.

### 패키지 변경

```diff
- "isomorphic-dompurify": "^3.0.0",
+ "dompurify": "^3.2.0",
+ "@types/dompurify": "^3.2.0",
```

`jsdom`은 devDependencies(vitest용)에 유지.

---

## 2. logger/Sentry 에러 품질 개선 (앱)

### 코드 대조 결과

| 항목 | 원안 | 실제 코드 | 차이점 |
|---|---|---|---|
| reportToSentry 위치 | `logger.ts` | `src/shared/utils/logger.ts` (40줄) | 경로 정확 |
| args[0] instanceof Error 체크 | O | O (L13) | 일치 |
| 나머지 args 처리 | `String(args[0])` | `String(args[0] ?? 'Error')` (L16) | 실제가 더 방어적 |
| 문제: 에러 메시지 손실 | O | O — `logger.error('[API] ...:', error.message)` 패턴 전체 확인 | 일치 |

### 실제 호출 패턴 분석

현재 코드에서 `logger.error` 호출 패턴:

```typescript
// 패턴 1: 문자열 prefix + error.message (가장 많음)
logger.error('[API] searchPosts 에러:', error.message);  // posts.ts:89
logger.error('[API] invokeSmartService 에러:', error.message);  // analysis.ts:49
logger.error('[API] createPost 에러:', error.message);  // posts.ts:138,145
logger.error('[API] deletePost 에러:', error.message);  // posts.ts:165
// ... 총 8곳

// 패턴 2: 문자열 + Error 객체
logger.error('임시저장 실패:', error);  // useDraft.ts:52
```

**Sentry에 전달되는 정보:**
- 패턴 1: `captureMessage("[API] searchPosts 에러:")` + `extra: { args: [error.message] }`
  - `error.message`가 `undefined`이면 → `extra: { args: [undefined] }` → 디버깅 불가
- 패턴 2: `captureMessage("임시저장 실패:")` + `extra: { args: [Error] }`
  - Error 객체가 args[1]에 있지만 `captureException`이 아닌 `captureMessage`로 전송 → 스택트레이스 손실

### 수정 설계안

```typescript
// src/shared/utils/logger.ts (수정)

const IS_DEV = __DEV__;

function reportToSentry(args: unknown[]): void {
  if (IS_DEV) return;
  try {
    const Sentry = require('@sentry/react-native');

    const errors: Error[] = [];
    const parts: string[] = [];
    const extras: Record<string, unknown> = {};

    for (const arg of args) {
      if (arg instanceof Error) {
        errors.push(arg);
        parts.push(arg.message || arg.name);
      } else if (typeof arg === 'object' && arg !== null) {
        // Supabase error 등 plain object → extra에 병합 + 메시지에 JSON 추가
        Object.assign(extras, arg);
        try {
          parts.push(JSON.stringify(arg));
        } catch {
          parts.push(String(arg));
        }
      } else if (arg !== undefined && arg !== null) {
        parts.push(String(arg));
      }
    }

    const message = parts.join(' ') || 'Unknown error';

    if (errors.length > 0) {
      // Error 객체가 있으면 captureException (스택트레이스 보존)
      Sentry.captureException(errors[0], {
        extra: { fullMessage: message, ...extras },
      });
    } else {
      // 문자열만 있으면 captureMessage
      Sentry.captureMessage(message, {
        level: 'error',
        extra: { args, ...extras },
      });
    }
  } catch {
    // Sentry 미설정 시 무시
  }
}

export const logger = {
  log: (...args: unknown[]) => {
    if (IS_DEV) console.log(...args);
  },
  error: (...args: unknown[]) => {
    if (IS_DEV) {
      console.error(...args);
    } else {
      reportToSentry(args);
    }
  },
  warn: (...args: unknown[]) => {
    if (IS_DEV) console.warn(...args);
  },
  info: (...args: unknown[]) => {
    if (IS_DEV) console.info(...args);
  },
};
```

### API 호출부 개선

Supabase 에러는 `.message`, `.code`, `.details`, `.hint` 필드를 가짐. 현재 `.message`만 전달하여 나머지 정보 손실.
구조화된 context 객체를 3번째 인자로 전달하면 위 `reportToSentry`가 `extras`에 병합:

```typescript
// 기존
logger.error('[API] searchPosts 에러:', error.message);

// 개선: 구조화된 context 전달
logger.error('[API] searchPosts 에러:', error.message, {
  code: error.code,
  details: error.details,
  hint: error.hint,
});
```

이 패턴을 `logger.error` 호출 8곳 전체에 통일 적용.

### 변경 파일

| 파일 | 변경 내용 |
|---|---|
| `src/shared/utils/logger.ts` | `reportToSentry` 전면 개선 |
| `src/shared/lib/api/posts.ts` | `error.message` → `error` 전체 또는 구조화 정보 |
| `src/shared/lib/api/analysis.ts` | 동일 |
| (기타 logger.error 사용처) | 패턴 통일 |

---

## 3. searchPosts RPC 방어 강화 (앱/웹/DB)

### 코드 대조 결과

| 항목 | 앱 (posts.ts) | 웹 (postsApi.ts) | 차이점 |
|---|---|---|---|
| 특수문자 방어 | 없음 | 없음 | 양쪽 모두 취약 |
| emotion 전달 | `emotion ?? undefined` (L82) | `emotion ?? undefined` (L167) | **둘 다 문제** |
| 에러 로깅 | `logger.error` + `throw APIError` | `throw error` (raw) | 웹이 더 단순 |
| 최소 길이 체크 | `q.length < 2` | `q.length < 2` | 일치 |

### 발견된 추가 문제

#### 문제 1: `emotion ?? undefined`가 아닌 `emotion ?? null` 필요

Supabase JS client에서 RPC 파라미터로 `undefined`를 전달하면 해당 파라미터가 **아예 누락**됨.
PostgreSQL 함수는 `DEFAULT NULL`로 선언되어 있어 누락 시 `NULL`로 처리되긴 하지만,
명시적으로 `null`을 전달하는 것이 안전:

```typescript
// 현재 (앱): emotion ?? undefined → 파라미터 누락
// 현재 (웹): emotion ?? undefined → 동일
// 수정: emotion ?? null 또는 emotion || null
```

#### 문제 2: DB ILIKE 패턴 인젝션

`search_posts_v2` SQL에서:
```sql
v_pattern := '%' || v_trimmed || '%';
-- ...
OR p.title ILIKE v_pattern
OR p.content ILIKE v_pattern
```

사용자가 `%` 또는 `_`를 입력하면 의도하지 않은 ILIKE 와일드카드 매칭 발생:
- 입력 `%` → 패턴 `%%%` → 모든 게시글 매칭
- 입력 `_` → 패턴 `%_%` → 1자 이상 모든 게시글 매칭

#### 문제 3: tsquery 파싱은 안전

`plainto_tsquery('simple', v_trimmed)`는 특수문자를 자동으로 무시하므로 tsquery injection은 발생하지 않음.
따라서 원안의 `[&|!():*<>'"\\]` 정규식 제거는 **tsquery 방어용으로는 불필요**.
다만 ILIKE 와일드카드 이스케이프는 필요.

### 수정 설계안

#### A. 클라이언트 (앱/웹 공통)

```typescript
// 앱: src/shared/lib/api/posts.ts — searchPosts 수정
// 웹: src/features/posts/api/postsApi.ts — searchPosts 수정

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
    p_emotion: emotion || null,  // undefined → null 명시적 변환
    p_sort: sort,
    p_limit: limit,
    p_offset: offset,
  });

  if (error) {
    logger.error('[API] searchPosts 에러:', error.message, {
      code: error.code,
      details: error.details,
      query: q,
    });
    throw new APIError(500, error.message);
  }

  return (data ?? []) as SearchResult[];
}
```

**주의**: 특수문자 클라이언트 제거는 하지 않음. DB에서 ILIKE 이스케이프로 처리.
클라이언트에서 `[&|!()]`를 제거하면 사용자가 실제로 해당 문자를 검색하려는 경우를 차단함.

#### B. DB 마이그레이션 (ILIKE 이스케이프 추가)

```sql
-- 20260309XXXXXX_search_v2_ilike_escape.sql

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
  v_escaped TEXT;
  v_pattern TEXT;
  v_trimmed TEXT;
BEGIN
  v_trimmed := trim(p_query);

  IF v_trimmed IS NULL OR length(v_trimmed) < 2 THEN
    RETURN;
  END IF;

  v_tsquery := plainto_tsquery('simple', v_trimmed);

  -- ILIKE 와일드카드 이스케이프: % _ を 리터럴로 처리
  -- $$...$$ 블록 안에서는 백슬래시가 리터럴이므로 E'' 불필요
  v_escaped := replace(replace(v_trimmed, '%', '\%'), '_', '\_');
  v_pattern := '%' || v_escaped || '%';

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
      (
        COALESCE(ts_rank(
          setweight(to_tsvector('simple', p.title), 'A') ||
          setweight(to_tsvector('simple', p.content), 'B'),
          v_tsquery
        ), 0) * 10
        + CASE WHEN p.title ILIKE v_pattern THEN 5.0 ELSE 0.0 END
        + CASE WHEN p.title ILIKE v_escaped || '%' THEN 3.0 ELSE 0.0 END
      )::REAL AS relevance_score,
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
        (to_tsvector('simple', p.title) || to_tsvector('simple', p.content)) @@ v_tsquery
        OR p.title ILIKE v_pattern
        OR p.content ILIKE v_pattern
      )
      AND (p_emotion IS NULL OR p_emotion = ANY(pa.emotions))
  )
  SELECT m.*
  FROM matched m
  ORDER BY
    CASE
      WHEN p_sort = 'relevance' THEN -m.relevance_score
      WHEN p_sort = 'popular' THEN -(m.like_count + m.comment_count * 2)::REAL
      ELSE NULL
    END,
    m.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;
```

### 변경 파일

| 파일 | 변경 내용 |
|---|---|
| 앱 `src/shared/lib/api/posts.ts` | `emotion ?? undefined` → `emotion \|\| null` |
| 웹 `src/features/posts/api/postsApi.ts` | 동일 |
| 중앙 `supabase/migrations/` | ILIKE 이스케이프 마이그레이션 추가 |

---

## 4. 닉네임 입력 항목 삭제 (앱)

### 코드 대조 결과

| 항목 | 원안 | 실제 코드 | 일치 |
|---|---|---|---|
| create.tsx 닉네임 Input | L175-188 | L175-188 (`Controller name="author"`) | O |
| useAuthor 사용 | L26 | L26 (`useAuthor()` 호출) | O |
| useDraft author 필드 | O | `DraftData.author` (L11) | O |
| schemas.ts author | O | `postSchema` 내 `author` 필드 (L20-21) | O |
| useCreatePost rawAuthor | L70-78 | L70-78 (`resolveDisplayName` 호출) | O |
| AnonModeInfo showName | O | L190-196 (always_anon 시 텍스트만 표시) | O |
| 웹 닉네임 입력 | 이미 없음 | 웹 CreatePostForm에 author 필드 없음 확인 | O |

### 수정 설계안: 즉시 전면 삭제

author 데이터는 중요하지 않으므로 하위호환 없이 한 번에 정리한다.

#### A. create.tsx — 닉네임 UI + useAuthor 제거

```diff
// src/app/(tabs)/create.tsx

- import { useAuthor } from '@/features/posts/hooks/useAuthor';
- import { AnonModeInfo } from '@/features/posts/components/AnonModeInfo';

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
      getExtraPostData: () => ({
        image_url: imageUrl ?? undefined,
        ...(initialEmotions.length > 0 ? { initial_emotions: initialEmotions } : {}),
      }),
-     onSuccess: async (data) => {
-       const rawAuthor = data.author?.trim() ?? '';
-       if (rawAuthor && rawAuthor !== (savedAuthor ?? '')) {
-         await saveAuthor(rawAuthor);
-       }
+     onSuccess: async () => {
        clearDraft();
        Toast.show({ type: 'success', text1: '게시글이 작성되었습니다.' });
        pushTabs(router);
      },
      ...
    });

    const watched = watch();
-   const { loadDraft, clearDraft } = useDraft(DEFAULT_PUBLIC_BOARD_ID, {
-     title: watched.title ?? '',
-     content: watched.content ?? '',
-     author: watched.author ?? '',
-   });
+   const { loadDraft, clearDraft } = useDraft(DEFAULT_PUBLIC_BOARD_ID, {
+     title: watched.title ?? '',
+     content: watched.content ?? '',
+   });

-   useEffect(() => {
-     if (savedAuthor) setValue('author', savedAuthor);
-   }, [savedAuthor, setValue]);

    // draft 복원에서 author 제거
    ...
    onPress: () => {
      setValue('title', draft.title);
      setValue('content', draft.content);
-     setValue('author', draft.author);
    },

    // 렌더링에서 닉네임 Input + AnonModeInfo 제거:
-   <Controller control={control} name="author" ... />
-   <AnonModeInfo anonMode={anonMode} showName={showName} onToggle={...} />
+   <View className="mt-2 mb-2">
+     <Text className="text-xs text-gray-500 dark:text-stone-400">
+       모든 게시글은 익명으로 작성됩니다. 게시판별 고유 별칭이 자동 부여돼요.
+     </Text>
+   </View>
  }
```

#### B. useCreatePost — author/showName 제거

```diff
// src/features/posts/hooks/useCreatePost.ts

- const [showName, setShowName] = useState(false);

  const { ... } = useForm<PostFormValues>({
    resolver: zodResolver(postSchema),
-   defaultValues: { title: '', content: '', author: '', ...defaultValues },
+   defaultValues: { title: '', content: '', ...defaultValues },
  });

  const onSubmit = useCallback(async (data: PostFormValues) => {
-   const rawAuthor = data.author?.trim() ?? '';
    const { isAnonymous, displayName } = resolveDisplayName({
      anonMode,
-     rawAuthorName: rawAuthor,
      userId: user?.id ?? null,
      boardId,
      groupId: groupId ?? null,
-     wantNameOverride: showName,
    });
    // ...
- }, [boardId, groupId, user?.id, anonMode, showName, ...]);
+ }, [boardId, groupId, user?.id, anonMode, ...]);

  return {
    control, handleSubmit, setValue, watch,
    handleContentChange, errors, isSubmitting,
-   showName, setShowName,
    onSubmit,
  };
```

#### C. schemas.ts — author 필드 삭제

```diff
// src/shared/lib/schemas.ts

  export const postSchema = z.object({
    title: z.string().min(1, '제목을 입력해주세요.').max(VALIDATION.POST_TITLE_MAX, ...),
    content: z.string().min(1, '내용을 입력해주세요.').max(VALIDATION.POST_CONTENT_MAX, ...),
-   author: z.string().max(VALIDATION.AUTHOR_MAX, ...).optional(),
  });
```

#### D. useDraft — author 필드 완전 제거

```diff
// src/features/posts/hooks/useDraft.ts

  export interface DraftData {
    title: string;
    content: string;
-   author: string;
    updatedAt: number;
  }

  function getDraftSync(boardId: number): DraftData | null {
    // ...
    if (typeof parsed === 'object' && parsed !== null &&
-       'title' in parsed && 'content' in parsed && 'author' in parsed) {
+       'title' in parsed && 'content' in parsed) {
      return {
        title: String((parsed as DraftData).title),
        content: String((parsed as DraftData).content),
-       author: String((parsed as DraftData).author),
        updatedAt: Number((parsed as DraftData).updatedAt) || Date.now(),
      };
    }

- function setDraftSync(boardId: number, data: Omit<DraftData, 'updatedAt'>): void {
+ function setDraftSync(boardId: number, data: { title: string; content: string }): void {

  export function useDraft(
    boardId: number,
-   values: { title: string; content: string; author: string },
+   values: { title: string; content: string },
  ) {
    // ...
-   }, [values.title, values.content, values.author, saveDraft]);
+   }, [values.title, values.content, saveDraft]);
  }
```

#### E. 파일 삭제

| 파일 | 처리 |
|---|---|
| `src/features/posts/hooks/useAuthor.ts` | 삭제 |
| `src/features/posts/components/AnonModeInfo.tsx` | 삭제 |

`storage.getAuthor()`, `storage.saveAuthor()` 관련 코드도 storage 모듈에서 제거.

### 변경 파일

| 파일 | 변경 내용 |
|---|---|
| `src/app/(tabs)/create.tsx` | 닉네임 UI + useAuthor + AnonModeInfo 제거 |
| `src/features/posts/hooks/useCreatePost.ts` | author/showName 참조 완전 제거 |
| `src/features/posts/hooks/useDraft.ts` | DraftData에서 author 제거 |
| `src/shared/lib/schemas.ts` | postSchema에서 author 필드 삭제 |
| `src/features/posts/hooks/useAuthor.ts` | **삭제** |
| `src/features/posts/components/AnonModeInfo.tsx` | **삭제** |
| `src/shared/lib/storage.ts` | getAuthor/saveAuthor 제거 |

---

## 5. 감정 분석 에러 핸들링 강화 (Edge Function/앱)

### 코드 대조 결과

| 항목 | 원안 | 실제 코드 | 차이점 |
|---|---|---|---|
| AnalyzeResult 타입 | 3종 (ok+emotions, ok+skipped, **fail+reason+retryable**) | 3종 (ok+emotions, ok+skipped, fail+reason) | **retryable 없음** |
| callGeminiWithRetry | 최대 3회 | `MAX_RETRIES = 2` (초기+2재시도 = 3회) | 일치 |
| 쿨다운 | 60초 | `COOLDOWN_MS = 60_000` | 일치 |
| force 파라미터 | O | `force = false` (L156) | 일치 |
| 에러 코드 세분화 | 8종 코드 | 단순 `reason: string` (에러 메시지 그대로) | **차이** |

### 발견된 추가 문제

#### 문제 1: invokeSmartService 반환 타입 불일치

현재 `analysis.ts:43`: `Promise<string[]>` — emotions 배열만 반환.
원안은 `Promise<{ emotions: string[]; error?: string; retryable?: boolean }>` 제안.
이 변경은 호출부 (`usePostDetailAnalysis.ts:85`)에도 영향.

#### 문제 2: Edge Function 에러 객체 구조

`supabase.functions.invoke`의 error는 `FunctionsHttpError | FunctionsRelayError | FunctionsFetchError`:
- `FunctionsHttpError`: `.message`는 있지만 실제 에러 내용은 `error.context` (Response 객체)
- `FunctionsRelayError`: `.message` 있음
- `FunctionsFetchError`: `.message` 있음 (네트워크 에러)

현재 `analysis.ts:49`: `error.message`만 접근 — `FunctionsHttpError`의 경우 실제 에러 본문 누락.

#### 문제 3: retry_count 기반 재시도 판단 없음

`analyze.ts:254`에서 `retry_count`를 증가시키지만, 클라이언트(`usePostDetailAnalysis.ts`)에서 이 값을 체크하지 않음.
현재는 `status === 'pending' || status === 'analyzing'`만 체크하여 `failed` 상태도 무한 재시도 가능.
다만 `fallbackCalledRef`가 마운트당 1회로 제한하므로 실제로는 1회만 호출됨.

### 수정 설계안

#### A. Edge Function AnalyzeResult 확장

```typescript
// _shared/analyze.ts — AnalyzeResult 타입 수정

export type AnalyzeResult =
  | { ok: true; emotions: string[] }
  | { ok: true; skipped: string }
  | { ok: false; reason: string; retryable: boolean };

// analyzeAndSave 내부 catch 블록 수정:
} catch (err) {
  const reason = err instanceof Error ? err.message : 'unknown';

  // retryable 판단
  const retryable = [
    'gemini_api_error_429',
    'json_parse_error',
    'no_valid_emotions',
  ].some(r => reason.startsWith(r)) || reason.startsWith('gemini_api_error_5');

  // ... (retry_count 증가 로직 동일)

  return { ok: false, reason, retryable };
}
```

#### B. 클라이언트 invokeSmartService 개선

```typescript
// src/shared/lib/api/analysis.ts — invokeSmartService 수정

export async function invokeSmartService(
  postId: number,
  content: string,
  title?: string,
): Promise<{ emotions: string[]; error?: string; retryable?: boolean }> {
  const { data, error } = await supabase.functions.invoke(SMART_SERVICE_FUNCTION, {
    body: { postId, content, title },
  });

  if (error) {
    // FunctionsHttpError의 경우 context에서 실제 에러 추출
    let errorMessage: string;
    try {
      if ('context' in error && error.context instanceof Response) {
        const body = await error.context.json();
        errorMessage = body?.reason || body?.message || error.message;
      } else {
        errorMessage = error.message ?? String(error);
      }
    } catch {
      errorMessage = error.message ?? 'Unknown edge function error';
    }

    logger.error('[API] invokeSmartService 에러:', errorMessage, { postId });
    return { emotions: [], error: errorMessage };
  }

  const result = data as AnalyzeResult | null;

  if (!result) {
    return { emotions: [], error: 'empty_response' };
  }

  if (!result.ok) {
    return {
      emotions: [],
      error: result.reason,
      retryable: result.retryable,
    };
  }

  if ('emotions' in result) return { emotions: result.emotions };
  return { emotions: [] };  // skipped
}
```

**주의**: `invokeSmartService` 반환 타입이 변경되므로 호출부도 수정 필요 (섹션 7 참조).

#### C. 감정 분석 상태 UI (앱)

현재 앱에서 분석 상태별 UI가 없음. 상태별 표시 추가:

| status | UI |
|---|---|
| `null` / `undefined` | 표시 없음 (아직 분석 전) |
| `pending` | "마음을 읽고 있어요..." + 작은 애니메이션 |
| `analyzing` | "감정을 분석하고 있어요..." |
| `done` | 감정 태그 표시 (현행) |
| `failed` (retry < 3) | "분석에 실패했어요" + "다시 시도" 버튼 |
| `failed` (retry >= 3) | "분석할 수 없었어요" (버튼 없음) |

이 UI는 게시글 상세 화면의 감정 태그 영역에 통합.

### 변경 파일

| 파일 | 변경 내용 |
|---|---|
| 앱 `supabase/functions/_shared/analyze.ts` | AnalyzeResult에 retryable 추가 |
| 앱 `src/shared/lib/api/analysis.ts` | 반환 타입 확장 + 에러 상세화 |
| 앱 게시글 상세 컴포넌트 | 분석 상태 UI 추가 |

---

## 6. 검색 에러 상태 UI (앱/웹)

### 코드 대조 결과

| 항목 | 앱 (search.tsx) | 웹 (SearchView.tsx) |
|---|---|---|
| error 변수 | **사용 안 함** | **사용 안 함** |
| useInfiniteQuery error | destructure 안 함 | destructure 안 함 |
| useQuery error | destructure 안 함 | destructure 안 함 |
| 빈 상태 UI | EmptyState 컴포넌트 | EmptyState 컴포넌트 |
| 에러 상태 UI | **없음** | **없음** |

### 수정 설계안

#### A. 앱 — error 추출 + ErrorState UI

query 객체를 먼저 받고 destructure하여 `refetch`에 접근:

```diff
// src/app/search.tsx

- const {
-   data: searchPages,
-   isLoading: searchLoading,
-   fetchNextPage,
-   hasNextPage,
-   isFetchingNextPage,
- } = useInfiniteQuery({ ... });
+ const searchQuery = useInfiniteQuery({ ... });
+ const { data: searchPages, isLoading: searchLoading, error: searchError,
+         fetchNextPage, hasNextPage, isFetchingNextPage } = searchQuery;

- const { data: emotionPosts, isLoading: emotionLoading } = useQuery({ ... });
+ const emotionQuery = useQuery({ ... });
+ const { data: emotionPosts, isLoading: emotionLoading, error: emotionError } = emotionQuery;

+ const error = isSearchMode ? searchError : isEmotionOnlyMode ? emotionError : null;
+ const refetch = isSearchMode ? searchQuery.refetch : emotionQuery.refetch;

  // 렌더링에서 에러 처리 추가 (빈 상태 바로 위):
+ {!showInitial && error && !isLoading && (
+   <View className="items-center justify-center py-16 px-4">
+     <Text className="text-base font-semibold text-gray-700 dark:text-stone-200 mb-1">
+       검색 중 문제가 발생했어요
+     </Text>
+     <Text className="text-sm text-gray-500 dark:text-stone-400 mb-4 text-center">
+       네트워크를 확인하고 다시 시도해주세요
+     </Text>
+     <Pressable
+       onPress={() => refetch()}
+       className="px-4 py-2 rounded-xl bg-happy-400 active:bg-happy-500">
+       <Text className="text-sm font-semibold text-white">다시 시도</Text>
+     </Pressable>
+   </View>
+ )}
```

#### B. 웹 — error + retry

```diff
// src/features/posts/components/SearchView.tsx

  const {
    data: searchPages,
    isLoading: searchLoading,
+   error: searchError,
+   refetch: refetchSearch,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
  } = useInfiniteQuery({ ... })

- const { data: emotionPosts, isLoading: emotionLoading } = useQuery({ ... })
+ const { data: emotionPosts, isLoading: emotionLoading, error: emotionError, refetch: refetchEmotion } = useQuery({ ... })

+ const error = isSearchMode ? searchError : isEmotionOnlyMode ? emotionError : null
+ const refetch = isSearchMode ? refetchSearch : refetchEmotion

  // 빈 상태 바로 위에 에러 UI 추가:
+ {error && !isLoading && (
+   <div className="flex flex-col items-center justify-center py-16">
+     <p className="text-base font-semibold mb-1">검색 중 문제가 발생했어요</p>
+     <p className="text-sm text-muted-foreground mb-4">잠시 후 다시 시도해주세요</p>
+     <button
+       onClick={() => refetch()}
+       className="px-4 py-2 rounded-xl bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90"
+     >
+       다시 시도
+     </button>
+   </div>
+ )}
```

#### C. TanStack Query retry 설정

양쪽 모두 `retry` 옵션이 미설정 → 기본 3회 재시도. searchPosts가 계속 실패하면 사용자가 최대 ~9초 대기.

```typescript
// 앱/웹 공통: 검색 쿼리에 retry 제한 추가
useInfiniteQuery({
  // ...
  retry: 1,  // 1회만 자동 재시도 (기본 3 → 1)
});
```

### 변경 파일

| 파일 | 변경 내용 |
|---|---|
| 앱 `src/app/search.tsx` | error destructure + ErrorState 렌더링 + retry:1 |
| 웹 `src/features/posts/components/SearchView.tsx` | 동일 |

---

## 7. usePostDetailAnalysis 리팩토링 (앱)

### 코드 대조 결과

| 항목 | 원안 | 실제 코드 (105줄) | 차이점 |
|---|---|---|---|
| 폴링 간격 | 3초 → 5초 | 3초 (L34) | 원안이 완화 |
| 폴백 타이머 | 15초 → 10초 | 15초 (L96) | 원안이 단축 |
| failed + retry >= 3 체크 | O | **없음** | **원안 추가** |
| done 상태 스킵 | O | **없음** — pending/analyzing만 체크 | done은 폴링이 중단되지만 폴백은 무조건 실행 |
| Realtime + 폴링 중복 | 지적 | 둘 다 활성 | 맞음 |
| content 빈값 전달 | 지적 | L88: `invokeSmartService(postId, '')` | 맞음 |

### 발견된 추가 문제

#### 문제 1: done 상태에서도 15초 타이머 실행

`useEffect` (L62-102)는 `postId > 0`이면 무조건 15초 타이머 시작.
이미 `done` 상태인 게시글도 타이머가 설정됨 (cleanup으로 해제되긴 하지만 불필요한 리소스).

#### 문제 2: invokeSmartService 반환 타입 변경 대응

섹션 5에서 `invokeSmartService`의 반환 타입이 `string[]` → `{ emotions, error?, retryable? }`로 변경됨.
`usePostDetailAnalysis.ts:85`의 호출부도 수정 필요.

### 수정 설계안

```typescript
// src/features/posts/hooks/usePostDetailAnalysis.ts (수정)

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
    // pending/analyzing 상태에서만 5초 간격 폴링 (3초 → 5초 완화)
    refetchInterval: (query) => {
      const status = (query.state.data as PostAnalysis | null | undefined)?.status;
      if (status === 'done' || status === 'failed') return false;
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

  // On-demand 폴백 (개선)
  useEffect(() => {
    if (postId <= 0) return;

    let innerTimer: ReturnType<typeof setTimeout> | undefined;

    const timer = setTimeout(async () => {
      if (fallbackCalledRef.current) return;

      const cached = queryClient.getQueryData<PostAnalysis | null>(['postAnalysis', postId]);

      // 이미 완료면 스킵
      if (cached?.status === 'done') return;

      // failed + retry_count >= 3이면 더 이상 재시도 안 함
      if (cached?.status === 'failed' && (cached.retry_count ?? 0) >= 3) return;

      const needsFallback =
        cached === null ||
        cached === undefined ||
        cached.status === 'pending' ||
        cached.status === 'analyzing' ||
        cached.status === 'failed';  // failed도 재시도 (retry < 3)

      if (needsFallback) {
        fallbackCalledRef.current = true;
        const currentPost = queryClient.getQueryData<{ content?: string; title?: string }>([
          'post', postId,
        ]);

        const result = await api.invokeSmartService(
          postId,
          currentPost?.content ?? '',
          currentPost?.title,
        );

        // 실패 시 3초 후 refetch
        if (result.emotions.length === 0) {
          innerTimer = setTimeout(() => {
            queryClient.invalidateQueries({ queryKey: ['postAnalysis', postId] });
          }, 3000);
        }
      }
    }, 10000);  // 15초 → 10초 단축

    return () => {
      clearTimeout(timer);
      clearTimeout(innerTimer);
    };
  }, [postId, queryClient]);

  return { postAnalysis, analysisLoading };
}
```

### 핵심 변경 요약

| 변경 | 이전 | 이후 | 이유 |
|---|---|---|---|
| 폴링 간격 | 3초 | 5초 | DB 부하 완화 |
| 폴백 타이머 | 15초 | 10초 | 사용자 대기 시간 단축 |
| done 상태 스킵 | 없음 | 추가 | 불필요한 API 호출 방지 |
| failed 재시도 | 무조건 스킵 | retry < 3이면 재시도 | 일시적 실패 복구 |
| innerTimer | 5초 | 3초 | Realtime 보완 속도 개선 |

---

## 8. 앱 검색 컴포넌트 분리 (앱)

### 코드 대조 결과

- `src/app/search.tsx`: **575줄**, 단일 파일
- 내부 컴포넌트: `SearchScreen` (421줄) + `SearchResultCard` (memo, 100줄) + `SearchResultList` (30줄) + `EmotionPostList` (12줄)

### 수정 설계안: 최소 분리

575줄은 크지만, 로직이 명확하게 분리되어 있어 **과도한 분리는 오버엔지니어링**.
에러 상태 UI 추가(섹션 6)와 함께 최소한의 분리만 수행:

```
src/app/search.tsx (메인 — 300줄 이하 목표)
  |- SearchResultCard → src/features/search/components/SearchResultCard.tsx (100줄)
  |- SearchResultList → src/features/search/components/SearchResultList.tsx (30줄)
  |- EmotionPostList  → src/features/search/components/EmotionPostList.tsx (12줄)
```

`useSearch` 훅 추출은 현 시점에서 불필요 — 상태 관리가 JSX와 밀접하게 결합되어 분리 시 prop drilling 증가.

---

## 9. 웹 무한스크롤 개선 (웹)

### 코드 대조 결과

- `SearchView.tsx:323-331`: "더 보기" 버튼 방식 확인
- IntersectionObserver 미사용

### 수정 설계안

원안과 동일. "더 보기" 버튼을 IntersectionObserver로 교체:

```typescript
// SearchView.tsx 내부
const loadMoreRef = useRef<HTMLDivElement>(null)

useEffect(() => {
  if (!loadMoreRef.current || !hasNextPage) return
  const observer = new IntersectionObserver(([entry]) => {
    if (entry.isIntersecting && !isFetchingNextPage) {
      fetchNextPage()
    }
  }, { threshold: 0.1 })
  observer.observe(loadMoreRef.current)
  return () => observer.disconnect()
}, [hasNextPage, isFetchingNextPage, fetchNextPage])

// 렌더링: "더 보기" 버튼 → sentinel div
- <button onClick={() => fetchNextPage()} ...>더 보기</button>
+ {hasNextPage && <div ref={loadMoreRef} className="h-10" />}
+ {isFetchingNextPage && <PostCardSkeleton />}
```

---

## 구현 우선순위 (수정)

| 순위 | 작업 | 영향도 | 난이도 | 변경 범위 | 비고 |
|---|---|---|---|---|---|
| 1 | isomorphic-dompurify 수정 (방안 B) | HIGH | LOW | 웹 sanitize.ts + PostDetailView + package.json | 신규 컴포넌트 1개 |
| 2 | logger/Sentry 에러 품질 개선 | HIGH | LOW | 앱 logger.ts + API 파일 8곳 | object 직렬화 주의 |
| 3 | searchPosts ILIKE 이스케이프 | HIGH | LOW | DB 마이그레이션 + 앱/웹 emotion null 변환 | 원안의 클라이언트 특수문자 제거는 불필요 |
| 4 | 닉네임 입력 즉시 전면 삭제 | MEDIUM | LOW | 앱 create.tsx + 훅/스키마 + 파일 2개 삭제 | author 하위호환 불필요 |
| 5 | 감정 분석 에러 핸들링 | MEDIUM | MEDIUM | Edge Function + analysis.ts | 반환 타입 변경 → 호출부 영향 |
| 6 | 검색 에러 상태 UI | MEDIUM | LOW | 앱/웹 검색 컴포넌트 | error destructure + retry:1 |
| 7 | usePostDetailAnalysis 개선 | LOW | LOW | 앱 훅 1파일 | invokeSmartService 타입 변경 후 |
| 8 | 앱 검색 컴포넌트 분리 | LOW | LOW | 앱 3파일 분리 | 에러 UI와 동시 작업 |
| 9 | 웹 무한스크롤 개선 | LOW | LOW | 웹 SearchView | IntersectionObserver |

---

## 파일 변경 맵 (확정)

```
[웹] /home/gunny/apps/web-hermit-comm
  src/lib/sanitize.ts                      — [삭제] isomorphic-dompurify 제거, PostContent로 대체
  src/features/posts/components/PostContent.tsx  — [신규] 클라이언트 전용 sanitize 컴포넌트
  src/features/posts/components/PostDetailView.tsx  — PostContent 사용으로 교체 (L279)
  src/features/posts/components/SearchView.tsx   — error UI + IntersectionObserver
  src/features/posts/api/postsApi.ts       — emotion null 변환
  package.json                             — isomorphic-dompurify → dompurify

[앱] /mnt/c/Users/Administrator/programming/apps/gns-hermit-comm
  src/shared/utils/logger.ts               — reportToSentry 전면 개선
  src/shared/lib/api/posts.ts              — emotion null + 에러 로깅 상세화
  src/shared/lib/api/analysis.ts           — invokeSmartService 반환 타입 확장
  src/app/(tabs)/create.tsx                — 닉네임 UI 제거
  src/features/posts/hooks/useCreatePost.ts — author/showName 참조 제거
  src/features/posts/hooks/useDraft.ts     — author 필드 완전 제거
  src/features/posts/hooks/useAuthor.ts     — [삭제]
  src/features/posts/components/AnonModeInfo.tsx — [삭제]
  src/shared/lib/storage.ts                — getAuthor/saveAuthor 제거
  src/features/posts/hooks/usePostDetailAnalysis.ts — 폴백 로직 개선
  src/app/search.tsx                       — error UI + retry:1 + 컴포넌트 분리
  src/features/search/components/SearchResultCard.tsx  — [신규] 분리
  src/features/search/components/SearchResultList.tsx  — [신규] 분리
  src/features/search/components/EmotionPostList.tsx   — [신규] 분리
  supabase/functions/_shared/analyze.ts    — AnalyzeResult retryable 추가

[중앙] /home/gunny/apps/supabase-hermit
  supabase/migrations/XXXXXXXX_search_v2_ilike_escape.sql — ILIKE 와일드카드 이스케이프
```

---

## 원안 대비 주요 수정 사항 요약

| # | 원안 | 수정 | 이유 |
|---|---|---|---|
| 1 | 방안 A: 정규식 서버 sanitizer | **방안 B: 클라이언트 전용** | 정규식 HTML sanitize는 XSS 우회 위험. hydration 문제도 회피 |
| 2 | 클라이언트 특수문자 정규식 제거 | **DB ILIKE 이스케이프만** | tsquery는 안전. 사용자가 특수문자 검색 불가해지는 부작용 방지 |
| 3 | author 즉시 삭제 | **즉시 전면 삭제 (원안 동의)** | author 데이터는 중요하지 않으므로 하위호환 불필요 |
| 4 | reportToSentry 개선만 | **+ plain object JSON 직렬화** | Supabase error가 plain object — `String()` 시 `[object Object]` |
| 5 | AnalyzeResult에 message+retryable | **reason+retryable만** | message와 reason이 중복. 기존 reason 필드에 에러 메시지 역할 통합 |
| 6 | useSearch 훅 추출 | **불필요 — 최소 분리만** | 상태와 JSX 결합이 밀접. prop drilling 증가 대비 이점 부족 |
| 7 | FunctionsHttpError 처리 안 함 | **context Response body 추출** | `.message`만으로는 실제 에러 내용 파악 불가 |
