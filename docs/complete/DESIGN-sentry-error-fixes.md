# Sentry 에러 해결 + 감정분석 파이프라인 보완 설계

> 작성일: 2026-03-08
> 대상: Sentry 이슈 2건 + 감정분석 파이프라인 구조적 결함 7건

---

## 목차

1. [전체 요약](#1-전체-요약)
2. [감정분석 파이프라인 현황](#2-감정분석-파이프라인-현황)
3. [구조적 결함 분석 (7건)](#3-구조적-결함-분석-7건)
4. [Sentry 이슈 분석 (2건)](#4-sentry-이슈-분석-2건)
5. [해결 설계](#5-해결-설계)
6. [구현 우선순위](#6-구현-우선순위)
7. [변경 파일 목록](#7-변경-파일-목록)
8. [검증 계획](#8-검증-계획)

---

## 1. 전체 요약

감정분석 기능이 여러 차례 설계/구현에도 불구하고 안정적으로 작동하지 않는 원인은
**단일 실패 지점이 아니라 파이프라인 전체에 걸친 7개의 구조적 결함**이 복합적으로 작용하기 때문.

```
실패 체인 예시 (최악 시나리오):

POST INSERT → DB Webhook 발화 → Edge Function cold start 5초 초과 ❌ (결함 #1)
           → post_analysis status='pending' 유지
           → 클라이언트 10초 후 fallback 시도
           → JWT 만료 상태 → 401 Invalid JWT ❌ (결함 #2)
           → post_analysis status='pending' 영구 유지 (결함 #3)
           → 클라이언트 5초 polling 무한 반복 (결함 #4)
           → 사용자에게 감정 분석 결과 영원히 미표시
```

| 구분 | 건수 | 심각도 |
|---|---|---|
| 감정분석 구조적 결함 | 7건 | Critical 2 / High 3 / Medium 2 |
| Sentry 이슈 (앱) | 107이벤트/9명 | Medium (escalating) |
| Sentry 이슈 (웹) | 15이벤트 | High (unhandled) |

---

## 2. 감정분석 파이프라인 현황

### 2.1 아키텍처

```
┌─ 클라이언트 (앱/웹) ──────────────────────────────────────────────┐
│                                                                    │
│  createPost()  ──POST INSERT──→  [DB]                             │
│                                   │                                │
│                                   ├─ AFTER INSERT ①               │
│                                   │  trg_create_pending_analysis   │
│                                   │  → post_analysis(pending, {}) │
│                                   │                                │
│                                   ├─ AFTER INSERT ②               │
│                                   │  analyze_post_on_insert        │
│                                   │  → HTTP webhook (5s timeout)   │
│                                   │     ↓                          │
│                               ┌───┴───────────────────┐           │
│                               │ Edge: analyze-post     │           │
│                               │ (verify_jwt=false)     │           │
│                               │ → Gemini API (3회시도) │           │
│                               │ → UPSERT done/failed   │           │
│                               └───┬───────────────────┘           │
│                                   │                                │
│  usePostDetailAnalysis            │ Realtime notification          │
│  ├─ 쿼리: getPostAnalysis         │                                │
│  ├─ Realtime 구독 (post_analysis) ←┘                               │
│  ├─ 폴링: 5초 (pending/analyzing)                                  │
│  └─ 10초 후 fallback ─────────────────→ ┌────────────────────────┐│
│                                         │ Edge: on-demand         ││
│                                         │ (verify_jwt=true) ← ❌ ││
│                                         │ → Gemini API            ││
│                                         │ → UPSERT done/failed    ││
│                                         └────────────────────────┘│
└────────────────────────────────────────────────────────────────────┘
```

### 2.2 상태 흐름

```
POST INSERT
  │
  ▼
pending ──[webhook]──→ analyzing ──[Gemini]──→ done ✅
  │                       │                     │
  │                       └──[Gemini 실패]──→ failed
  │                                             │
  └──[webhook 실패, fallback 실패]──→ pending (영구) ❌
```

### 2.3 타이밍 (현재)

| 단계 | 시간 | 비고 |
|---|---|---|
| DB webhook 전송 | 0s | INSERT 직후 (async) |
| Edge Function cold start | 0~8s | Deno 런타임, 비결정적 |
| Gemini API 호출 | 1~6s | 재시도 포함 (1s, 2s 백오프) |
| webhook timeout | 5s | `supabase_functions.http_request` 4번째 인자 |
| 클라이언트 폴링 | 5s 간격 | pending/analyzing 상태에서 |
| 클라이언트 fallback | 10s 후 | `invokeSmartService` 호출 |
| fallback 내부 refetch | 13s (10+3) | Realtime 미수신 대비 |
| 쿨다운 | 60s | 비-force 호출 시 재분석 차단 |

---

## 3. 구조적 결함 분석 (7건)

### 결함 #1: Webhook 타임아웃 < Edge Function 실행 시간 [Critical]

**문제**: DB webhook 타임아웃이 **5초**이지만, Edge Function의 실제 실행 시간은 **cold start(~3-8s) + Gemini API(1-6s) = 4~14초**.

```sql
-- 현재 트리거
EXECUTE FUNCTION supabase_functions.http_request(
  '.../analyze-post', 'POST', '...', '{}', '5000'  -- ← 5초 타임아웃
);
```

- Cold start 시 높은 확률로 5초 초과 → **webhook 자체는 타임아웃되지만 Edge Function은 계속 실행됨**
- `supabase_functions.http_request`는 fire-and-forget이라 타임아웃이 실질적 의미 없음
- 하지만 webhook이 실패로 기록되어 Supabase 대시보드에서 혼란 유발

**실질적 영향**: 낮음 (fire-and-forget이라 Edge Function은 실행됨). 단, cold start가 길면 Edge Function 자체가 처리되지 않을 가능성 존재.

### 결함 #2: Fallback의 JWT 의존성 [Critical]

**문제**: 유일한 복구 경로인 `analyze-post-on-demand`가 **`verify_jwt = true`**로 설정되어, JWT가 만료된 상태에서는 복구 자체가 불가능.

```
Sentry 데이터 (107건 중):
- "Invalid JWT" 메시지: 명시적으로 확인된 건만 ~5건
- 빈 에러 메시지 (JWT 실패 추정): ~25건
- 전체 invokeSmartService 에러: ~30건
```

**발생 시나리오**:
1. 앱 백그라운드 → JWT 만료 → foreground 복귀 → 10초 후 fallback → Invalid JWT
2. `autoRefreshToken`은 활성화돼 있으나 **갱신 완료 전에 fallback 타이머가 발화**

Breadcrumb 증거:
```
05:18:02  앱 foreground 전환
05:18:02  GET posts_with_like_count → 200 ✅ (anon key, JWT 불필요)
05:18:02  GET app_admin → 200 ✅ (anon key, JWT 불필요)
05:18:12  invokeSmartService → Invalid JWT ❌ (JWT 필요, 아직 미갱신)
```

### 결함 #3: `content_too_short` / `cooldown_60s` 스킵 시 상태 미갱신 [High]

**문제**: `analyzeAndSave()`가 분석을 건너뛸 때 `post_analysis.status`를 갱신하지 않음.

```typescript
// _shared/analyze.ts
const text = stripHtml(content);
if (text.length < 10) {
  return { ok: true, skipped: 'content_too_short' };  // ← status 갱신 없이 리턴
}

if (!force) {
  // ...cooldown 체크
  if (diffMs < COOLDOWN_MS) {
    return { ok: true, skipped: 'cooldown_60s' };  // ← status 갱신 없이 리턴
  }
}
```

**결과**:
- `content_too_short`: `post_analysis.status = 'pending'` **영구 유지** → 클라이언트 5초 폴링 무한 반복
- `cooldown_60s`: 이전 상태(pending/analyzing) 유지 → 같은 문제

### 결함 #4: 폴링 무한 루프 가능성 [High]

**문제**: `usePostDetailAnalysis`의 `refetchInterval`이 `pending` 또는 `analyzing` 상태에서 5초 폴링을 지속. 결함 #3과 결합하면 **영원히 폴링**.

```typescript
// usePostDetailAnalysis.ts
refetchInterval: (query) => {
  const status = query.state.data?.status;
  if (status === 'done') return false;
  if (status === 'failed' && retryCount >= 3) return false;
  return status === 'pending' || status === 'analyzing' ? 5000 : false;
  //     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  //     content_too_short로 영원히 pending이면 → 무한 폴링
},
```

**영향**: 불필요한 DB 쿼리 누적 + 배터리/데이터 소모.

### 결함 #5: `analyzing` 상태 무한 체류 [High]

**문제**: Edge Function이 `status='analyzing'`으로 설정한 후 크래시하면 **복구 불가**.

```typescript
// _shared/analyze.ts — analyzing 설정 후 크래시하면 이 코드에 도달 안 함
await supabase.from('post_analysis').upsert({
  post_id: postId,
  status: 'analyzing',  // ← 여기서 설정
  last_attempted_at: new Date().toISOString(),
}, { onConflict: 'post_id' });

// Gemini 호출 중 크래시 → done/failed로 전환 안 됨
const { emotions } = await callGeminiWithRetry(geminiUrl, geminiBody);
```

- 클라이언트는 `analyzing` → 5초 폴링 지속
- 10초 fallback은 1회만 실행 (`fallbackCalledRef`)
- fallback도 JWT 문제로 실패하면 → `analyzing` 영구 유지

### 결함 #6: Fallback 1회 제한 [Medium]

**문제**: `fallbackCalledRef`로 fallback을 **postId당 1회만** 실행. 첫 fallback이 JWT 문제로 실패하면 재시도 없음.

```typescript
const fallbackCalledRef = useRef(false);

// 10초 후 fallback
if (fallbackCalledRef.current) return;  // ← 1회 실패 후 재시도 안 함
fallbackCalledRef.current = true;
const result = await api.invokeSmartService(...);
```

### 결함 #7: Sentry 에러 그룹핑 붕괴 [Medium]

**문제**: 모든 API 에러가 `reportToSentry()` 스택 프레임으로 그룹핑되어 **107건이 하나의 이슈로 묶임**.

```
실제 에러 종류 5+개:
- invokeSmartService (Invalid JWT, empty)
- searchPosts (연속 실패)
- createPost (빈 메시지)
- 이메일 로그인 실패
- groups/board posts 조회 실패
→ 전부 GNS-HERMIT-COMM-7 하나로 그룹핑
```

---

## 4. Sentry 이슈 분석 (2건)

### 4.1 GNS-HERMIT-COMM-7: 앱 — reportToSentry 통합 에러

| 항목 | 값 |
|---|---|
| Sentry ID | 7304843201 |
| 우선순위 | Medium → escalating |
| 발생 | 107회 / 9명 |
| 기간 | 2026-03-03 ~ 2026-03-08 |
| 릴리스 | v1.6.0 ~ v1.7.0 |

**세부 에러 분류** (이벤트 목록 분석):

| 에러 유형 | 건수 | 패턴 |
|---|---|---|
| `invokeSmartService 에러` | ~30 | Invalid JWT 또는 빈 메시지. 결함 #2 |
| `searchPosts 에러` | ~60 | 한 유저가 1-2초 간격 26건+ 연속. 빈 메시지 |
| `createPost 에러` | ~8 | 빈 메시지. 42501(권한) 에러 재시도 실패 |
| `이메일 로그인 실패` | ~1 | 빈 메시지 |
| `조회 에러 (groups/board)` | ~2 | 빈 메시지 |

**근본 원인**: 결함 #7 (Sentry 그룹핑) + 결함 #2 (JWT) + 빈 에러 메시지

### 4.2 WEB-HERMIT-COMM-3: 웹 — jsdom ESM 충돌

| 항목 | 값 |
|---|---|
| Sentry ID | 7313066681 |
| 우선순위 | High (unhandled) |
| 발생 | 15회 / 0명 (서버) |
| 기간 | 2026-03-05 ~ 2026-03-08 |
| Culprit | GET /post/[id] |

**에러**:
```
Error: Failed to load external module jsdom:
  ERR_REQUIRE_ESM: require() of ES Module @exodus/bytes/encoding-lite.js
  from html-encoding-sniffer not supported.
```

**스택**: `isomorphic-dompurify` → `jsdom` → `html-encoding-sniffer` → `@exodus/bytes` (ESM-only) → `require()` 실패

**근본 원인**: `isomorphic-dompurify` → `dompurify` 마이그레이션은 코드에선 완료(커밋 `ef6cd0b`, 2026-03-08)되었으나, Vercel 배포가 이전 커밋(`c5a774e`, 2026-03-05)에 머물러 있음. **배포하면 즉시 해결**.

---

## 5. 해결 설계

### 5.1 Edge Function: skip 시 상태 갱신 [결함 #3 해결]

`analyzeAndSave()`에서 `content_too_short`와 `cooldown_60s`로 스킵할 때 `post_analysis.status`를 명확히 갱신.

**파일**: `supabase/functions/_shared/analyze.ts` (앱 레포)

```typescript
export async function analyzeAndSave(params: { ... }): Promise<AnalyzeResult> {
  const { supabaseUrl, supabaseServiceKey, geminiApiKey, postId, content, title, force = false } = params;
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  const text = stripHtml(content);
  if (text.length < 10) {
    // ── 개선: status를 'done'으로 갱신 (빈 emotions)
    await supabase.from('post_analysis').upsert(
      {
        post_id: postId,
        status: 'done',
        emotions: [],
        analyzed_at: new Date().toISOString(),
        error_reason: 'content_too_short',
      },
      { onConflict: 'post_id' },
    );
    return { ok: true, skipped: 'content_too_short' };
  }

  if (!force) {
    const { data: existing } = await supabase
      .from('post_analysis')
      .select('analyzed_at, status, emotions')
      .eq('post_id', postId)
      .maybeSingle();

    if (existing?.analyzed_at) {
      const diffMs = Date.now() - new Date(existing.analyzed_at).getTime();
      if (diffMs < COOLDOWN_MS) {
        // ── 개선: 이전 분석이 성공(done)이었으면 유지, 아니면 done으로 갱신
        if (existing.status !== 'done') {
          await supabase.from('post_analysis').upsert(
            {
              post_id: postId,
              status: 'done',
              emotions: existing.emotions ?? [],
              analyzed_at: existing.analyzed_at,
            },
            { onConflict: 'post_id' },
          );
        }
        return { ok: true, skipped: 'cooldown_60s' };
      }
    }
  }

  // ... 기존 로직 유지
}
```

### 5.2 클라이언트: Fallback 세션 확인 + 재시도 [결함 #2, #6 해결]

`invokeSmartService`에서 호출 전 세션을 확인/갱신하고, fallback 재시도 로직 추가.

**파일**: `src/shared/lib/api/analysis.ts` (앱 레포)

```typescript
/**
 * 세션을 확인하고 필요 시 갱신.
 * @returns 유효한 세션이 있으면 true, 없으면 false
 */
async function ensureValidSession(): Promise<boolean> {
  const { data: { session } } = await supabase.auth.getSession();
  if (session) return true;

  const { error } = await supabase.auth.refreshSession();
  return !error;
}

export async function invokeSmartService(
  postId: number,
  content: string,
  title?: string,
): Promise<{ emotions: string[]; error?: string; retryable?: boolean }> {
  // ── 세션 확인
  const hasSession = await ensureValidSession();
  if (!hasSession) {
    return { emotions: [], error: 'session_expired', retryable: false };
  }

  const { data, error } = await supabase.functions.invoke(SMART_SERVICE_FUNCTION, {
    body: { postId, content, title },
  });

  if (error) {
    let errorMessage: string;
    try {
      if ('context' in error && error.context instanceof Response) {
        const body = await error.context.json();
        errorMessage = body?.reason || body?.message || error.message;

        // ── JWT 만료 시 1회 재시도 (세션 갱신 후)
        if (error.context.status === 401) {
          const refreshed = await ensureValidSession();
          if (refreshed) {
            const retry = await supabase.functions.invoke(SMART_SERVICE_FUNCTION, {
              body: { postId, content, title },
            });
            if (!retry.error) {
              const result = retry.data as { ok: boolean; emotions?: string[] } | null;
              return { emotions: result?.emotions ?? [] };
            }
          }
          return { emotions: [], error: 'jwt_refresh_failed', retryable: false };
        }
      } else {
        errorMessage = error.message ?? String(error);
      }
    } catch {
      errorMessage = error.message ?? 'Unknown edge function error';
    }

    logger.error('[API] invokeSmartService 에러:', errorMessage, { postId });
    return { emotions: [], error: errorMessage };
  }

  // ... 기존 결과 처리 유지
}
```

### 5.3 클라이언트: 폴링 타임아웃 + Fallback 재시도 [결함 #4, #5, #6 해결]

`usePostDetailAnalysis`에 폴링 최대 시간 제한과 fallback 재시도 로직 추가.

**파일**: `src/features/posts/hooks/usePostDetailAnalysis.ts` (앱 레포)

```typescript
/** 폴링 최대 시간 (2분). 이후 강제 중단. */
const MAX_POLLING_MS = 2 * 60 * 1000;

/** Fallback 최대 재시도 횟수 */
const MAX_FALLBACK_RETRIES = 2;

/** Fallback 간격 (초) — 10초, 20초 */
const FALLBACK_DELAYS = [10_000, 20_000];

export function usePostDetailAnalysis(postId: number) {
  const queryClient = useQueryClient();
  const fallbackCountRef = useRef(0);
  const pollingStartRef = useRef<number>(0);

  useEffect(() => {
    fallbackCountRef.current = 0;
    pollingStartRef.current = Date.now();
  }, [postId]);

  const { data: postAnalysis, isLoading: analysisLoading } = useQuery({
    queryKey: ['postAnalysis', postId],
    queryFn: () => api.getPostAnalysis(postId),
    enabled: postId > 0,
    staleTime: 5 * 60 * 1000,
    refetchInterval: (query) => {
      const status = (query.state.data as PostAnalysis | null | undefined)?.status;
      if (status === 'done') return false;
      if (status === 'failed') {
        const retryCount = (query.state.data as PostAnalysis | null | undefined)?.retry_count ?? 0;
        if (retryCount >= 3) return false;
      }

      // ── 개선: 폴링 최대 시간 초과 시 중단
      if (Date.now() - pollingStartRef.current > MAX_POLLING_MS) {
        return false;
      }

      return status === 'pending' || status === 'analyzing' ? 5000 : false;
    },
  });

  // Realtime 구독 (기존 유지)
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

  // ── 개선: 단계적 fallback (10초, 20초)
  useEffect(() => {
    if (postId <= 0) return;

    const timers: ReturnType<typeof setTimeout>[] = [];

    const tryFallback = async (attempt: number) => {
      const cached = queryClient.getQueryData<PostAnalysis | null>(['postAnalysis', postId]);

      // 이미 완료됐으면 스킵
      if (cached?.status === 'done') return;
      if (cached?.status === 'failed' && (cached.retry_count ?? 0) >= 3) return;

      // 이미 충분히 재시도했으면 스킵
      if (attempt >= MAX_FALLBACK_RETRIES) return;

      const needsFallback =
        cached === null ||
        cached === undefined ||
        cached.status === 'pending' ||
        cached.status === 'analyzing' ||
        cached.status === 'failed';

      if (!needsFallback) return;

      fallbackCountRef.current = attempt + 1;

      const currentPost = queryClient.getQueryData<{ content?: string; title?: string }>([
        'post', postId,
      ]);

      if (currentPost?.content) {
        await api.invokeSmartService(postId, currentPost.content, currentPost.title);
      } else {
        await api.invokeSmartService(postId, '');
      }

      // 3초 후 결과 확인
      const innerTimer = setTimeout(() => {
        queryClient.invalidateQueries({ queryKey: ['postAnalysis', postId] });
      }, 3000);
      timers.push(innerTimer);
    };

    // 단계적 fallback 스케줄
    FALLBACK_DELAYS.forEach((delay, i) => {
      const timer = setTimeout(() => tryFallback(i), delay);
      timers.push(timer);
    });

    return () => timers.forEach(clearTimeout);
  }, [postId, queryClient]);

  return { postAnalysis, analysisLoading };
}
```

### 5.4 DB: stuck 상태 자동 복구 함수 [결함 #5 해결]

5분 이상 `analyzing` 또는 `pending` 상태인 레코드를 `failed`로 전환하는 DB 함수.

**파일**: `supabase/migrations/YYYYMMDD_fix_stuck_analysis.sql` (중앙 레포)

```sql
-- 5분 이상 pending/analyzing 상태인 분석을 failed로 전환
CREATE OR REPLACE FUNCTION public.cleanup_stuck_analyses()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  affected INTEGER;
BEGIN
  UPDATE post_analysis
  SET
    status = 'failed',
    error_reason = CASE
      WHEN status = 'pending' THEN 'webhook_never_processed'
      ELSE 'analyzing_timeout'
    END,
    last_attempted_at = now()
  WHERE status IN ('pending', 'analyzing')
    AND (
      -- pending: 생성 후 5분 이상 경과
      (status = 'pending' AND last_attempted_at IS NULL
       AND analyzed_at < now() - INTERVAL '5 minutes')
      OR
      -- pending: 마지막 시도 후 5분 이상 경과
      (status = 'pending' AND last_attempted_at IS NOT NULL
       AND last_attempted_at < now() - INTERVAL '5 minutes')
      OR
      -- analyzing: 마지막 시도 후 5분 이상 경과
      (status = 'analyzing'
       AND last_attempted_at < now() - INTERVAL '5 minutes')
    );

  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;

-- pg_cron 확장이 있으면 10분마다 자동 실행 (Supabase Pro 이상)
-- SELECT cron.schedule('cleanup-stuck-analyses', '*/10 * * * *',
--   'SELECT public.cleanup_stuck_analyses()');

-- 수동 실행:
-- SELECT public.cleanup_stuck_analyses();
```

> **Note**: Supabase Free 플랜에서는 pg_cron 미지원. 대안으로 `usePostDetailAnalysis`에서 stuck 감지 시 클라이언트가 직접 호출하거나, Edge Function cron을 사용.

### 5.5 Sentry 개선: Fingerprinting + Throttle [결함 #7 해결]

**파일**: `src/shared/utils/logger.ts` (앱 레포)

```typescript
// ── Sentry 전송 throttle (같은 fingerprint 30초에 1번)
const sentryThrottle = new Map<string, number>();
const THROTTLE_MS = 30_000;

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

    // ── 핑거프린트 추출: "[API] searchPosts 에러:" → "API-searchPosts"
    const tagMatch = message.match(/\[(\w+)\]\s*(\S+)/);
    const fingerprint = tagMatch
      ? `${tagMatch[1]}-${tagMatch[2]}`
      : 'unknown';

    // ── Throttle: 같은 fingerprint는 30초에 1번만
    const now = Date.now();
    const lastSent = sentryThrottle.get(fingerprint) ?? 0;
    if (now - lastSent < THROTTLE_MS) return;
    sentryThrottle.set(fingerprint, now);

    if (errors.length > 0) {
      Sentry.captureException(errors[0], {
        extra: { fullMessage: message, ...extras },
        fingerprint: ['{{ default }}', fingerprint],
      });
    } else {
      Sentry.captureMessage(message, {
        level: 'error',
        extra: { args, ...extras },
        fingerprint: [fingerprint, message.slice(0, 80)],
      });
    }
  } catch {
    // Sentry 미설정 시 무시
  }
}
```

### 5.6 에러 메시지 보강

빈 에러 메시지 방지를 위해 API 레이어에서 fallback 메시지 생성.

**파일**: `src/shared/lib/api/posts.ts` 외 다수 (앱 레포)

```typescript
// ── 공통 헬퍼: 에러 메시지 추출
function extractErrorMessage(error: { message?: string; code?: string; details?: string; hint?: string }): string {
  return error.message
    || error.code
    || (error.details ? `details: ${error.details}` : '')
    || (error.hint ? `hint: ${error.hint}` : '')
    || 'unknown_supabase_error';
}

// 사용 예:
if (error) {
  const errorMsg = extractErrorMessage(error);
  logger.error('[API] searchPosts 에러:', errorMsg, {
    code: error.code,
    details: error.details,
    hint: error.hint,
  });
}
```

**적용 대상** (7곳):
- `searchPosts` — `api/posts.ts`
- `createPost` — `api/posts.ts` (2곳)
- `invokeSmartService` — `api/analysis.ts`
- `getPostAnalysis` — `api/analysis.ts`
- `fetchPosts` — `api/posts.ts`
- `fetchGroupPosts` — `api/posts.ts`

### 5.7 웹: Vercel 배포 + SSR 안전성 [이슈 #2 해결]

#### 즉시 조치: 배포

```bash
cd /home/gunny/apps/web-hermit-comm
git push origin main  # Vercel auto-deploy → isomorphic-dompurify 제거됨
```

#### SSR 안전성 보강 (권장)

**파일**: `src/features/posts/components/PostContent.tsx` (웹 레포)

```typescript
'use client'
import { useMemo } from 'react'

const ALLOWED_TAGS = ['p', 'br', 'strong', 'em', 'u', 's', 'a', 'ul', 'ol', 'li', 'h1', 'h2', 'h3', 'blockquote', 'img', 'pre', 'code']
const ALLOWED_ATTR = ['href', 'src', 'alt', 'class', 'target', 'rel']

export function PostContent({ html }: { html: string }) {
  const clean = useMemo(() => {
    if (typeof window === 'undefined') return html  // SSR: 원본 반환 (CSR에서 sanitize)
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const DOMPurify = require('dompurify')
    return DOMPurify.default.sanitize(html, { ALLOWED_TAGS, ALLOWED_ATTR })
  }, [html])

  return <div className="post-content" dangerouslySetInnerHTML={{ __html: clean }} />
}
```

> `dompurify` v3은 서버에서도 동작하지만, SSR에서 원본 반환 → CSR hydration 시 sanitize 방식이 더 안전. 게시글 HTML은 서버에서 이미 생성된 신뢰 가능 콘텐츠이므로 SSR에서 원본 반환해도 보안 리스크 없음.

---

## 6. 구현 우선순위

| 순서 | 작업 | 해결 결함 | 대상 | 난이도 |
|---|---|---|---|---|
| **1** | 웹 배포 (`git push`) | 이슈 #2 | 웹 | 즉시 |
| **2** | skip 시 상태 갱신 | #3 | Edge Function | 낮음 |
| **3** | fallback 세션 확인 + JWT 재시도 | #2 | 앱 analysis.ts | 중간 |
| **4** | 폴링 타임아웃 + fallback 재시도 | #4, #5, #6 | 앱 hook | 중간 |
| **5** | Sentry fingerprinting + throttle | #7 | 앱 logger.ts | 낮음 |
| **6** | 에러 메시지 보강 | #7 보조 | 앱 api/*.ts | 낮음 |
| **7** | stuck 상태 자동 복구 DB 함수 | #5 | 중앙 migration | 낮음 |
| **8** | PostContent SSR 안전성 | 이슈 #2 방어 | 웹 | 낮음 |

### 효과 예측

| 결함 | 현재 | 수정 후 |
|---|---|---|
| #1 webhook 타임아웃 | 영향 낮음 (fire-and-forget) | 변경 없음 (구조적 한계) |
| #2 JWT fallback 실패 | **분석 결과 미표시** | 세션 갱신 → 재시도 → 성공 |
| #3 skip 상태 미갱신 | **영구 pending** | done으로 종결 |
| #4 무한 폴링 | **배터리/쿼리 낭비** | 2분 제한 자동 중단 |
| #5 analyzing 무한 체류 | **복구 불가** | DB 함수로 5분 후 자동 failed |
| #6 fallback 1회 제한 | **1회 실패 시 포기** | 2회 재시도 (10초, 20초) |
| #7 Sentry 그룹핑 | **모든 에러 1개 이슈** | API별 개별 이슈 분리 |

---

## 7. 변경 파일 목록

### 앱 레포 (`gns-hermit-comm`)

| 파일 | 변경 내용 | 해결 결함 |
|---|---|---|
| `supabase/functions/_shared/analyze.ts` | skip 시 status 갱신 | #3 |
| `src/shared/lib/api/analysis.ts` | ensureValidSession + JWT 재시도 | #2 |
| `src/features/posts/hooks/usePostDetailAnalysis.ts` | 폴링 타임아웃 + 단계적 fallback | #4, #5, #6 |
| `src/shared/utils/logger.ts` | fingerprinting + throttle | #7 |
| `src/shared/lib/api/posts.ts` | extractErrorMessage 헬퍼 + 적용 | #7 보조 |

### 중앙 레포 (`supabase-hermit`)

| 파일 | 변경 내용 | 해결 결함 |
|---|---|---|
| `supabase/migrations/YYYYMMDD_fix_stuck_analysis.sql` | cleanup_stuck_analyses() 함수 | #5 |

### 웹 레포 (`web`)

| 파일 | 변경 내용 | 해결 이슈 |
|---|---|---|
| (배포만 필요) | `git push origin main` | 이슈 #2 |
| `src/features/posts/components/PostContent.tsx` | SSR 조건부 sanitize (선택) | 이슈 #2 방어 |

---

## 8. 검증 계획

### 감정분석 E2E 테스트

- [ ] 게시글 작성 → 10초 이내 감정 태그 표시 (정상 경로)
- [ ] 짧은 게시글 (10자 미만) → `done` + 빈 emotions (영구 pending 아님)
- [ ] 앱 백그라운드 5분+ → 복귀 후 게시글 열기 → 감정분석 fallback 성공 (JWT 갱신)
- [ ] Edge Function 강제 실패 시 → `failed` 상태 + 재시도 버튼 동작
- [ ] 2분 이상 pending 유지 → 폴링 자동 중단 확인
- [ ] `cleanup_stuck_analyses()` 수동 실행 → stuck 레코드 정리 확인

### Sentry 검증

- [ ] 배포 후 `reportToSentry` 이슈에 새 이벤트 미발생
- [ ] `API-searchPosts`, `API-invokeSmartService` 등 개별 이슈로 분리 확인
- [ ] 연속 에러 throttle 동작 (30초에 1건만 전송)
- [ ] 빈 에러 메시지 → code/details 포함 확인

### 웹 검증

- [ ] `ef6cd0b` 배포 후 `jsdom` 에러 발생 중단
- [ ] `/post/[id]` SSR 정상 렌더링
- [ ] WEB-HERMIT-COMM-3 이슈 resolve

### 모니터링

- 배포 후 48시간 Sentry 이벤트 추이 관찰
- `post_analysis` 테이블에서 `status='pending'` 또는 `status='analyzing'`인 레코드 0건 확인
- 감정분석 성공률 지표 추적 (done / total 비율)
