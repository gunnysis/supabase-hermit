# 유지보수 설계 v1 — 앱/웹/중앙 통합 점검

> 작성: 2026-03-08 | 3개 레포 전수 조사 기반 | 심층 분석 완료
> 갱신: 2026-03-08 | 선행 설계 문서 병합 완료
> 최종 점검: 2026-03-13 | 완료 항목 반영, 상호 참조 정합성 확인
> 작업 예정: 2026-03-13 | v1 설계 문서 구현 작업

---

## 0. 선행 설계 (구현 완료 → 아카이브)

아래 설계 문서들은 모두 구현 완료되어 `../../complete/`(`docs/complete/`)에 아카이브됨.
본 문서는 이들의 미완료 항목과 향후 과제를 승계한다.

| 문서 | 주요 내용 | 완료 시점 | 미완료 → 승계 |
|---|---|---|---|
| `DESIGN-sentry-error-fixes.md` | 7개 결함 수정 (DOMPurify, logger, error context, invokeSmartService 반환타입, usePostDetailAnalysis 폴링 등) + Sentry 2건 (PII, 앱 구조 태그) | 2026-03-15 | 없음 (전체 구현 완료) |
| `DESIGN-search-refactor.md` | Phase 0-3: v1 DROP, 상수 중앙화, 유틸 분리, 앱/웹 컴포넌트 최적화 | 2026-03-14 | Phase 4 (검색 성능 최적화) → L2, L8, L9로 승계 |
| `DESIGN-service-improvement-v2-revised.md` | DOMPurify ESM, 무한스크롤, author 제거, 검색 분리 | 2026-03-15 | 없음 |
| `DESIGN-admin-redesign.md` | groups RLS, invite_code CHECK, 히든 도어 | 2026-03-13 | 없음 |
| `DESIGN-analysis-retry.md` | 분석 상태 추적, 재시도, cleanup_stuck_analyses | 2026-03-11 | pg_cron 스케줄 → M7으로 승계 |

---

## 1. 조사 범위

| 레포 | 파일 수 | 주요 영역 |
|---|---|---|
| 중앙 (`supabase-hermit`) | 마이그레이션 22개, shared 3개, scripts 4개 | DB 스키마, 문서, 동기화, RLS, 인덱스 |
| 앱 (`gns-hermit-comm`) | src/ 전체, Edge Functions 4개, 테스트 17개 | API 레이어, hooks, 에러 처리, 보안 취약점 |
| 웹 (`web`) | src/ 116개 파일, Sentry 3개 | SSR 안전성, 보안 헤더, 에러 처리 |

---

## 2. 발견 사항 전체

### 2.1 즉시 수정 (High Priority)

| # | 영역 | 문제 | 위치 | 영향 | 해결 Phase |
|---|---|---|---|---|---|
| H1 | 앱 API | comments.ts, reactions.ts 에러 처리 불일치 | `api/comments.ts`, `api/reactions.ts` | Sentry 그루핑 실패, 디버깅 불가 | Phase 3 |
| H2 | 중앙 문서 | SCHEMA.md 5개 마이그레이션 미반영 (18-22) | `docs/SCHEMA.md` | 스키마 이해도 저하 | Phase 8 |
| H3 | 중앙 shared | 게시글/댓글 유효성 검증 함수 부재 | `shared/utils.ts` | 앱/웹 간 검증 불일치 | Phase 2b |
| H4 | 중앙 shared | 분석 상태 상수 미중앙화 | `shared/constants.ts` | 매직 문자열 산재 | Phase 2a |
| H5 | 앱 보안 | npm audit 취약점 8건 (HIGH 2, CRITICAL 1) | `package.json` 의존성 체인 | 보안 위험 | Phase 1a |
| H6 | 웹 보안 | npm audit 취약점 5건 (HIGH 5) | hono, serialize-javascript 등 | 보안 위험 | Phase 1b |

### 2.2 개선 권장 (Medium Priority)

| # | 영역 | 문제 | 위치 | 영향 | 해결 Phase |
|---|---|---|---|---|---|
| M1 | 앱 코드 | ESLint 경고 3건 | `search.tsx:117`, `EmotionCalendar.tsx:5` | CI 품질 | Phase 7a |
| M2 | 앱 Edge | VALID_EMOTIONS 수동 동기화 — 자동 검증 부재 | `_shared/analyze.ts:11` | 감정 불일치 위험 | Phase 7b |
| M3 | 웹 보안 | Next.js 보안 헤더 미설정 (CSP, HSTS 등) | `next.config.ts` | 보안 표면 노출 | Phase 4 |
| M4 | 웹 API | 에러 로깅에 `{ code, details, hint }` 컨텍스트 부재 | `postsApi.ts` | 디버깅 어려움 | Phase 5a |
| M5 | 웹 Sentry | server config에 userId PII 필터 누락 | `sentry.server.config.ts` | PII 유출 위험 | Phase 5b |
| M6 | 중앙 DB | post_analysis SELECT RLS `USING (true)` | `rls.sql:118` | 비인증 메타데이터 노출 | Phase 6a |
| M7 | 중앙 DB | ~~cleanup_stuck_analyses 미스케줄~~ ✅ pg_cron 등록 완료 | `20260316000001` | ~~stuck 분석 수동 정리~~ | Phase 6b ✅ |
| M8 | 앱 API | recommendations.ts, trending.ts 에러 로깅 부재 | `api/recommendations.ts`, `api/trending.ts` | Sentry 미보고 | Phase 3b |
| M9 | 중앙 DB | reactions/user_reactions 직접 쓰기 RLS 잔존 | `rls.sql:63-74` | RPC-only 정책 위반 | Phase 6c |

### 2.3 참고/향후 (Low Priority)

| # | 영역 | 내용 | 해결 Phase |
|---|---|---|---|
| L1 | 앱 테스트 | API 레이어, 검색, 트렌딩, 추천 테스트 부재 | Phase 10 |
| L2 | 중앙 DB | search_posts_v2 ts_headline 전건 실행 (5,000건+ 최적화) | Phase 13a |
| L3 | 중앙 문서 | SCHEMA.md search_posts v1 문서 잔존 (DROP 완료) | Phase 8 |
| L4 | 중앙 스크립트 | sync-to-projects.sh WSL 경로 하드코딩 | Phase 11 |
| L5 | 중앙 스크립트 | verify.sh에 shared/utils.ts + palette.js 검증 누락 | Phase 11 |
| L6 | 중앙 DB | boards.description 길이 CHECK 제약조건 부재 | Phase 12 |
| L7 | 웹 | view-transition.ts `(document as any)` 타입 캐스트 | Phase 12 |
| L8 | 중앙 DB | ~~pg_trgm 인덱스~~ ✅ pg_trgm v1.6 활성 + 인덱스 존재 확인 | Phase 13b ✅ |
| L9 | 중앙 DB | 한국어 검색 품질 — pgroonga 또는 custom dictionary (search-refactor Phase 4 승계) | Phase 13c |

---

## 3. 구현 계획

### Phase 1: 보안 취약점 해결 (H5, H6)

#### 1a. 앱 npm audit 대응

**현황** (8건):
| 패키지 | 심각도 | 문제 | 경로 |
|---|---|---|---|
| minimatch | HIGH | ReDoS via wildcards | @expo/cli → minimatch@3 |
| tar | HIGH | Hardlink/Symlink 임의 파일 접근 | 직접 의존성 |
| @tootallnate/once | CRITICAL | 제어 흐름 스코핑 결함 | jest-expo → jsdom 체인 |
| ajv | Moderate | ReDoS ($data 옵션) | expo-dev-launcher |

**해결 방안:**
```bash
# 1단계: 안전한 자동 수정 (breaking change 없음)
npm audit fix

# 2단계: tar 직접 업그레이드
npm install tar@latest

# 3단계: jest-expo 체인 (CRITICAL) — expo SDK 업그레이드 필요
# jest-expo@47 → jest-expo@54+ 로 expo와 함께 업그레이드
# ⚠️ expo 54→55 메이저 업그레이드 시 별도 계획 필요 (이번 범위 외)
```

**판단**: `npm audit fix`로 해결 가능한 6건 즉시 처리. jest-expo 체인(CRITICAL)은 expo 55 업그레이드와 함께 진행 (별도 작업).

#### 1b. 웹 npm audit 대응

**현황** (5건 HIGH):
| 패키지 | 심각도 | 문제 |
|---|---|---|
| hono ≤4.12.3 | HIGH | Cookie injection, SSE injection, 임의 파일 접근 |
| @hono/node-server | HIGH | encoded slash로 인증 우회 |
| serialize-javascript ≤7.0.2 | HIGH | RegExp/Date RCE |
| express-rate-limit | HIGH | IPv6 매핑 우회 |

**해결 방안:**
```bash
cd /home/gunny/apps/web
npm audit fix
# hono, serialize-javascript 등 transitive dependency 자동 해결
```

**판단**: 모두 transitive dependency이므로 `npm audit fix`로 해결 시도. 실패 시 overrides 적용.

---

### Phase 2: 중앙 shared 보강 (H3, H4)

#### 2a. 분석 상태 상수 (H4)

**shared/constants.ts에 추가:**
```typescript
/** post_analysis.status 상태값 */
export const ANALYSIS_STATUS = {
  PENDING: 'pending',
  ANALYZING: 'analyzing',
  DONE: 'done',
  FAILED: 'failed',
} as const;

export type AnalysisStatus = (typeof ANALYSIS_STATUS)[keyof typeof ANALYSIS_STATUS];

/** 분석 설정 상수 */
export const ANALYSIS_CONFIG = {
  /** Edge Function 재분석 방지 쿨다운 (초) */
  COOLDOWN_SECONDS: 60,
  /** DB 최대 재시도 횟수 (failed 후 포기) */
  MAX_RETRY_COUNT: 3,
  /** stuck 판정 기준 시간 (분) — cleanup_stuck_analyses 사용 */
  STUCK_TIMEOUT_MINUTES: 5,
  /** 분석 최소 글자 수 (미만 시 content_too_short) */
  MIN_CONTENT_LENGTH: 10,
  /** 클라이언트 폴링 간격 (ms) — pending/analyzing 상태 */
  POLLING_INTERVAL_MS: 5_000,
  /** 클라이언트 폴링 최대 시간 (ms) — 이후 강제 중단 */
  MAX_POLLING_MS: 2 * 60 * 1_000,
  /** 클라이언트 fallback 지연 스케줄 (ms) */
  FALLBACK_DELAYS: [10_000, 20_000] as readonly number[],
  /** 클라이언트 fallback 최대 재시도 */
  MAX_FALLBACK_RETRIES: 2,
} as const;

/** 게시글/댓글 길이 제한 (DB CHECK 제약조건과 동기화) */
export const VALIDATION = {
  POST_TITLE_MAX: 100,
  POST_CONTENT_MAX: 5_000,
  COMMENT_MAX: 1_000,
  GROUP_NAME_MAX: 100,
  GROUP_DESC_MAX: 500,
} as const;
```

> VALIDATION은 이미 shared/types.ts에서 앱/웹의 Zod 스키마에 사용 중.
> ANALYSIS_STATUS/CONFIG는 신규 추가.

**적용 대상:**
- 앱 `usePostDetailAnalysis.ts`: 매직넘버 5곳 → `ANALYSIS_CONFIG.*`
- 앱 `usePostDetailAnalysis.ts`: 문자열 `'done'`, `'pending'` 등 → `ANALYSIS_STATUS.*`
- Edge Function `_shared/analyze.ts`: 주석 참조 (Deno는 직접 import 불가)

#### 2b. 게시글/댓글 유효성 검증 (H3)

**shared/utils.ts에 추가:**
```typescript
/** 게시글 입력 유효성 검증 (DB CHECK 제약조건 동기화) */
export function validatePostInput(input: {
  title: string;
  content: string;
}): { valid: boolean; errors: string[] } {
  const errors: string[] = [];
  const titleTrimmed = input.title.trim();
  const contentTrimmed = input.content.trim();

  if (!titleTrimmed) errors.push('제목을 입력해주세요');
  else if (titleTrimmed.length > 100) errors.push('제목은 100자 이내로 입력해주세요');

  if (!contentTrimmed) errors.push('내용을 입력해주세요');
  else if (contentTrimmed.length > 5000) errors.push('내용은 5000자 이내로 입력해주세요');

  return { valid: errors.length === 0, errors };
}

/** 댓글 입력 유효성 검증 */
export function validateCommentInput(content: string): {
  valid: boolean;
  error?: string;
} {
  const trimmed = content.trim();
  if (!trimmed) return { valid: false, error: '댓글을 입력해주세요' };
  if (trimmed.length > 1000) return { valid: false, error: '댓글은 1000자 이내로 입력해주세요' };
  return { valid: true };
}
```

> 외부 import 없는 순수 함수. shared/utils.ts 규칙 준수.
> 길이 상수는 DB CHECK 제약조건과 일치 (마이그레이션 04 posts_title_length 등).

---

### Phase 3: 앱 API 에러 처리 통일 (H1, M8)

#### 3a. extractErrorMessage 공유 헬퍼 분리

**현재**: `posts.ts`에만 존재하는 로컬 함수.

**신규 파일 `src/shared/lib/api/helpers.ts`:**
```typescript
/** Supabase 에러에서 메시지 추출 (빈 문자열 방지) */
export function extractErrorMessage(error: {
  message?: string;
  code?: string;
  details?: string;
  hint?: string;
}): string {
  return (
    error.message ||
    error.code ||
    (error.details ? `details: ${error.details}` : '') ||
    (error.hint ? `hint: ${error.hint}` : '') ||
    'unknown_supabase_error'
  );
}
```

#### 3b. 에러 처리 통일 대상 (6개 파일)

| 파일 | 현재 패턴 | 수정 내용 |
|---|---|---|
| `posts.ts` | `extractErrorMessage` + 로깅 ✓ | helpers.ts에서 import로 변경 |
| `comments.ts` (3곳) | `error.message`만 로깅 | `extractErrorMessage` + `{ code, details, hint }` 추가 |
| `reactions.ts` (2곳) | `throw error` (raw) | `extractErrorMessage` + `APIError` 래핑 + 로깅 |
| `recommendations.ts` (1곳) | `APIError`만, 로깅 없음 | `logger.error` 추가 |
| `trending.ts` (1곳) | `APIError`만, 로깅 없음 | `logger.error` 추가 |
| `analysis.ts` | 이미 완료 ✓ | 변경 없음 |

**표준 패턴 (모든 API 함수에 적용):**
```typescript
if (error) {
  const errorMsg = extractErrorMessage(error);
  logger.error('[API] functionName 에러:', errorMsg, {
    code: error.code,
    details: error.details,
    hint: error.hint,
  });
  throw new APIError(500, errorMsg);
}
```

---

### Phase 4: 웹 보안 헤더 추가 (M3)

**현황**: `next.config.ts`에 보안 헤더가 전혀 없음. CSP, HSTS, X-Content-Type-Options 등 미설정.

**next.config.ts에 headers() 추가:**
```typescript
async headers() {
  return [
    {
      source: '/(.*)',
      headers: [
        { key: 'X-Content-Type-Options', value: 'nosniff' },
        { key: 'X-Frame-Options', value: 'DENY' },
        { key: 'X-XSS-Protection', value: '1; mode=block' },
        { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        {
          key: 'Permissions-Policy',
          value: 'camera=(), microphone=(), geolocation=()',
        },
        {
          key: 'Strict-Transport-Security',
          value: 'max-age=31536000; includeSubDomains',
        },
      ],
    },
  ];
},
```

**CSP 설계**: Supabase + Sentry + Vercel Analytics 허용

```typescript
{
  key: 'Content-Security-Policy',
  value: [
    "default-src 'self'",
    "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://va.vercel-scripts.com",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob: https://*.supabase.co",
    "font-src 'self'",
    "connect-src 'self' https://*.supabase.co wss://*.supabase.co https://*.sentry.io https://va.vercel-scripts.com",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action 'self'",
  ].join('; '),
}
```

> `unsafe-inline`/`unsafe-eval`은 Next.js 빌드 특성상 필요. nonce 기반 CSP는 Next.js 15+ 에서만 안정 지원.

**변경 파일:** `next.config.ts` — `headers()` 함수 추가

---

### Phase 5: 웹 에러 처리 & Sentry 보강 (M4, M5)

#### 5a. 웹 API 에러 로깅 개선 (M4)

**현황**: `postsApi.ts`에서 `if (error) throw error` — 컨텍스트 없음.

**수정 방향:**
```typescript
// postsApi.ts — 에러 발생 시
if (error) {
  logger.error('[API] getPosts 에러:', error.message, {
    code: error.code,
    details: error.details,
    hint: error.hint,
  });
  throw error;
}
```

**적용 대상:** `postsApi.ts`의 모든 에러 핸들링 (6곳)

#### 5b. Sentry server config PII 필터 보강 (M5)

**현황**: `sentry.client.config.ts`는 `userId` 필드를 필터링하지만, `sentry.server.config.ts`는 누락.

**sentry.server.config.ts 수정:**
```typescript
// Before (line 11)
if (['email', 'password', 'author', 'display_name'].some(k => key.includes(k))) {

// After
if (['email', 'password', 'author', 'display_name', 'userId'].some(k => key.includes(k))) {
```

---

### Phase 6: DB 정비 (M6, M7, M9)

#### 6a. post_analysis RLS 강화 (M6)

**현황**: `SELECT USING (true)` — 비인증 사용자도 분석 메타데이터(status, error_reason, retry_count) 조회 가능.

**마이그레이션 추가:**
```sql
-- post_analysis SELECT를 인증 사용자만 허용
DROP POLICY IF EXISTS "post_analysis_select" ON public.post_analysis;
CREATE POLICY "post_analysis_select" ON public.post_analysis
  FOR SELECT USING (auth.role() = 'authenticated');
```

**영향 분석:**
- 앱: 모든 사용자가 익명 인증 → `auth.role() = 'authenticated'` 충족 ✓
- 웹: 서버 사이드에서 service_role_key 사용 시 RLS 우회 → 영향 없음 ✓
- Edge Function: SECURITY DEFINER → RLS 우회 → 영향 없음 ✓
- 비인증 접근만 차단 → 의도한 동작 ✓

#### 6b. cleanup_stuck_analyses 자동 스케줄 (M7)

**현황**: 함수만 정의, 수동 실행만 가능. 주석에 pg_cron 예시만 존재.

**방안 1: Supabase Dashboard에서 pg_cron 설정** (권장)
```sql
-- Supabase Dashboard > SQL Editor에서 실행
SELECT cron.schedule(
  'cleanup-stuck-analyses',
  '*/10 * * * *',
  'SELECT public.cleanup_stuck_analyses()'
);
```
> Supabase Pro plan에서 pg_cron 기본 활성화. cron extension이 이미 있으면 바로 사용 가능.

**방안 2: 마이그레이션으로 추가** (pg_cron extension 필요)
```sql
-- 마이그레이션에 추가 (idempotent)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('cleanup-stuck-analyses');
    PERFORM cron.schedule(
      'cleanup-stuck-analyses',
      '*/10 * * * *',
      'SELECT public.cleanup_stuck_analyses()'
    );
  END IF;
END $$;
```

**방안 3: 외부 크론 (Vercel Cron 또는 GitHub Actions)**
```yaml
# .github/workflows/cleanup.yml
on:
  schedule:
    - cron: '*/10 * * * *'
jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - run: |
          curl -X POST "$SUPABASE_URL/rest/v1/rpc/cleanup_stuck_analyses" \
            -H "apikey: $SUPABASE_SERVICE_KEY" \
            -H "Authorization: Bearer $SUPABASE_SERVICE_KEY"
```

**✅ 완료** (2026-03-08): pg_cron 활성화 + 스케줄 등록 완료.

```
jobid: 1 | schedule: */10 * * * * | command: SELECT public.cleanup_stuck_analyses()
nodename: localhost | database: postgres | active: true
```

> 10분마다 stuck 상태(5분 이상 pending/analyzing) 분석을 자동 정리.

#### 6c. reactions/user_reactions 직접 쓰기 RLS 제거 (M9)

**현황**: CLAUDE.md에서 "리액션은 RPC만 사용"이라 명시했지만, 실제로는 INSERT/UPDATE/DELETE RLS 정책이 남아있음.

**마이그레이션:**
```sql
-- reactions 직접 쓰기 정책 제거 (toggle_reaction RPC만 허용)
DROP POLICY IF EXISTS "reactions_insert" ON public.reactions;
DROP POLICY IF EXISTS "reactions_update" ON public.reactions;
DROP POLICY IF EXISTS "reactions_delete" ON public.reactions;

-- user_reactions 직접 쓰기 정책 제거
DROP POLICY IF EXISTS "user_reactions_insert" ON public.user_reactions;
DROP POLICY IF EXISTS "user_reactions_delete" ON public.user_reactions;
```

**영향 분석:**
- `toggle_reaction()`은 SECURITY DEFINER → RLS 우회 → 영향 없음 ✓
- `get_post_reactions()`은 SELECT만 → 영향 없음 ✓
- 클라이언트 직접 INSERT/DELETE 차단됨 → 의도한 동작 ✓

---

### Phase 7: 앱 코드 정리 (M1, M2)

#### 7a. ESLint 경고 수정 (M1)

**search.tsx:117 — 복잡한 의존성 배열:**
```typescript
// Before
useEffect(() => { ... }, [hasTextQuery, trimmedQuery, searchPages?.pages?.[0]?.length]);

// After
const firstPageLength = searchPages?.pages?.[0]?.length;
useEffect(() => {
  if (hasTextQuery && firstPageLength !== undefined) {
    addRecentSearch(trimmedQuery);
    setRecentSearches(getRecentSearches());
  }
}, [hasTextQuery, trimmedQuery, firstPageLength]);
```

**EmotionCalendar.tsx:5 — 미사용 import:**
```typescript
// Before
import { EMOTION_COLOR_MAP, EMOTION_EMOJI } from '@/shared/lib/constants';
// After
import { EMOTION_COLOR_MAP } from '@/shared/lib/constants';
```

#### 7b. Edge Function 동기화 검증 스크립트 (M2)

**현재**: 주석으로 경고만 존재. 자동 검증 없음.

**verify.sh에 감정 상수 검증 추가:**
```bash
# Edge Function VALID_EMOTIONS ↔ 중앙 ALLOWED_EMOTIONS 비교
echo "  [emotions] Edge Function ↔ 중앙 상수 비교..."
CENTRAL_EMOTIONS=$(grep -A20 'ALLOWED_EMOTIONS' "$CENTRAL/shared/constants.ts" \
  | grep -oP "'[^']+'" | sort)
EDGE_EMOTIONS=$(grep -A10 'VALID_EMOTIONS' "$APP_REPO/supabase/functions/_shared/analyze.ts" \
  | grep -oP "'[^']+'" | sort)
if [ "$CENTRAL_EMOTIONS" != "$EDGE_EMOTIONS" ]; then
  echo "  ✗ VALID_EMOTIONS 불일치!"
  diff <(echo "$CENTRAL_EMOTIONS") <(echo "$EDGE_EMOTIONS")
  FAIL=$((FAIL + 1))
else
  echo "  = VALID_EMOTIONS 일치"
fi
```

---

### Phase 8: SCHEMA.md 갱신 (H2, L3)

**수정 범위:**
1. 헤더: "마이그레이션 17개" → "마이그레이션 22개", 날짜 갱신
2. 마이그레이션 테이블에 추가:
   - 18: `20260313000001_admin_groups_rls_fix.sql` — groups UPDATE/DELETE RLS + invite_code CHECK
   - 19: `20260314000001_drop_search_posts_v1.sql` — search_posts v1 DROP
   - 20: `20260315000001_search_v2_ilike_escape.sql` — ILIKE 와일드카드 이스케이프
   - 21: `20260315000002_fix_search_v2_column_order.sql` — CTE 컬럼 순서 수정
   - 22: `20260316000001_cleanup_stuck_analyses.sql` — stuck 분석 자동 정리
3. RPC 함수 섹션: `cleanup_stuck_analyses()` 추가
4. groups RLS: UPDATE/DELETE 정책 추가
5. groups 제약조건: `groups_invite_code_length` CHECK 추가
6. search_posts v1 문서 제거 (L3)
7. search_posts_v2 ILIKE 이스케이프 설명 보강

---

### Phase 9: 동기화 & 검증 & 배포

```
1. shared/constants.ts, shared/utils.ts 수정 → sync-to-projects.sh
2. 앱 수정 → npm test (154+ tests)
3. 웹 수정 → next build
4. DB 마이그레이션 push (RLS 강화, 리액션 정책 제거)
5. pg_cron 스케줄 설정 ✅ 완료 (cleanup-stuck-analyses, */10 * * * *)
6. 앱 커밋 → push → OTA 배포
7. 웹 커밋 → push → Vercel 자동 배포
8. 중앙 커밋 → push
```

---

### Phase 10: 앱 테스트 확장 (L1)

#### 10a. 현황 분석

**현재 테스트 17개 (83 케이스):**
| 영역 | 파일 수 | 커버리지 |
|---|---|---|
| API wrapper (`api.test.ts`) | 1 | getPosts, createPost, getPostAnalysis, getEmotionTrend, invokeSmartService, healthCheck |
| Admin/Community API | 2 | createGroupWithBoard, getMyManagedGroups, deleteGroup, getBoards, joinGroupByInviteCode |
| Hooks (posts) | 2 | usePostDetailAnalysis (6케이스), useRealtimePosts (5케이스) |
| 컴포넌트 | 3 | Button, ErrorView, Loading |
| 유틸/스키마 | 6 | format, html, validate, anonymous, schemas |
| 통합 테스트 | 2 | groups.invite, tabs |
| 인증 | 1 | auth |

**테스트 부재 (우선순위순):**
| 우선도 | 대상 | 이유 |
|---|---|---|
| ★★★ | `api/comments.ts` | 3곳 에러 핸들링 통일 후 검증 필요 |
| ★★★ | `api/reactions.ts` | RPC 호출 + APIError 래핑 검증 |
| ★★☆ | `api/recommendations.ts` | 에러 시 빈 배열 반환 검증 |
| ★★☆ | `api/trending.ts` | 에러 시 빈 배열 반환 검증 |
| ★☆☆ | Feature hooks (10개) | useCreatePost, useDraft, useEmotionTrend 등 |
| ★☆☆ | Feature 컴포넌트 (20+) | PostCard, ReactionBar, EmotionFilterBar 등 |

#### 10b. 1단계 — API 모듈 단위 테스트 (Phase 3 이후 실행)

Phase 3에서 에러 처리를 통일한 후 아래 테스트를 추가한다.

**`tests/shared/lib/api/comments.test.ts` (신규):**
```typescript
import { api } from '@/shared/lib/api';
import { supabase } from '@/shared/lib/supabase';

jest.mock('@/shared/lib/supabase', () => ({ /* 기존 api.test.ts 패턴 */ }));

describe('comments API', () => {
  // 기존 api.test.ts의 beforeEach 패턴 재사용
  describe('getComments', () => {
    it('댓글 목록을 반환한다', async () => { /* ... */ });
    it('에러 시 APIError를 던진다', async () => { /* ... */ });
    it('에러 로그에 code/details/hint가 포함된다', async () => { /* ... */ });
  });
  describe('createComment', () => {
    it('댓글 생성 후 데이터를 반환한다', async () => { /* ... */ });
    it('에러 시 extractErrorMessage로 메시지를 추출한다', async () => { /* ... */ });
  });
  describe('softDeleteComment', () => {
    it('soft_delete_comment RPC를 호출한다', async () => { /* ... */ });
  });
});
```

**`tests/shared/lib/api/reactions.test.ts` (신규):**
```typescript
describe('reactions API', () => {
  describe('toggleReaction', () => {
    it('toggle_reaction RPC를 호출한다', async () => { /* ... */ });
    it('에러 시 APIError로 래핑된다', async () => { /* ... */ });
    it('에러 로그에 컨텍스트가 포함된다', async () => { /* ... */ });
  });
  describe('getPostReactions', () => {
    it('get_post_reactions RPC 결과를 반환한다', async () => { /* ... */ });
  });
});
```

**`tests/shared/lib/api/recommendations.test.ts` (신규):**
```typescript
describe('recommendations API', () => {
  it('추천 게시글을 반환한다', async () => { /* ... */ });
  it('에러 시 빈 배열을 반환한다', async () => { /* ... */ });
  it('에러 시 logger.error를 호출한다', async () => { /* ... */ });
});
```

**`tests/shared/lib/api/trending.test.ts` (신규):**
```typescript
describe('trending API', () => {
  it('트렌딩 게시글을 반환한다', async () => { /* ... */ });
  it('에러 시 빈 배열을 반환한다', async () => { /* ... */ });
  it('에러 시 logger.error를 호출한다', async () => { /* ... */ });
});
```

#### 10c. 2단계 — Hook 테스트 (향후)

> Feature hooks 테스트는 `@testing-library/react-hooks` + `@tanstack/react-query` 의존.
> 커버리지 50% 목표 시 진행. 현재 범위에서는 API 모듈 테스트까지만 포함.

**예상 테스트 파일 4개, 케이스 ~20개 추가 → 총 ~103 케이스**

---

### Phase 11: 스크립트 이식성 개선 (L4, L5)

#### 11a. 현황

**sync-to-projects.sh 경로 처리:**
```bash
# 현재 (lines 24-26)
CENTRAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_REPO="${HERMIT_APP_REPO:-/mnt/c/Users/Administrator/programming/apps/gns-hermit-comm}"
WEB_REPO="${HERMIT_WEB_REPO:-/home/gunny/apps/web}"
```
- 환경변수 오버라이드 이미 존재 (`HERMIT_APP_REPO`, `HERMIT_WEB_REPO`)
- 하드코딩 기본값이 WSL 전용 (`/mnt/c/`)

**verify.sh 경로 처리:**
```bash
# 현재 (lines 18-19) — 동일 패턴
APP_REPO="${HERMIT_APP_REPO:-/mnt/c/Users/Administrator/programming/apps/gns-hermit-comm}"
WEB_REPO="${HERMIT_WEB_REPO:-/home/gunny/apps/web}"
```

**verify.sh 검증 누락:**
- `shared/utils.ts` → `utils.generated.ts` 동기화 검증 ✗ (sync는 하지만 verify 안 함)
- `shared-palette.js` 검증 ✗ (앱 전용, sync는 하지만 verify 안 함)

#### 11b. 해결 방안 — 경로 이식성 (L4)

**방안 1: `.env.local` 파일 도입** (권장)
```bash
# .env.local (git 제외, 개발자별 설정)
HERMIT_APP_REPO=/mnt/c/Users/Administrator/programming/apps/gns-hermit-comm
HERMIT_WEB_REPO=/home/gunny/apps/web
```

```bash
# sync-to-projects.sh / verify.sh 상단에 추가
ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env.local"
if [ -f "$ENV_FILE" ]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

# 기본값 제거 → 환경변수 필수
APP_REPO="${HERMIT_APP_REPO:?'HERMIT_APP_REPO를 .env.local 또는 환경변수에 설정하세요'}"
WEB_REPO="${HERMIT_WEB_REPO:?'HERMIT_WEB_REPO를 .env.local 또는 환경변수에 설정하세요'}"
```

> `.gitignore`에 `.env.local` 추가 필요.

**방안 2: 현행 유지** (최소 변경)
- 이미 환경변수 오버라이드 가능
- CI/CD 도입 전까지는 현재 패턴으로 충분
- 다른 개발자 합류 시 방안 1로 전환

**판단**: 현재 1인 개발 → 방안 2 유지. CI/CD 또는 팀 확장 시 방안 1 적용.

#### 11c. 해결 방안 — verify.sh 검증 보강 (L5)

**utils.generated.ts 검증 추가:**
```bash
# verify.sh — constants 검증 블록 바로 아래에 추가

# --- utils.generated.ts ---
if [ "$TARGET" = "app" ]; then
  UTILS_DEST="$REPO/src/shared/lib/utils.generated.ts"
else
  UTILS_DEST="$REPO/src/lib/utils.generated.ts"
fi
compare_files "utils.generated.ts" "$CENTRAL/shared/utils.ts" "$UTILS_DEST"
```

**palette.js 검증 추가 (앱만):**
```bash
# verify.sh — 앱 전용 블록에 추가
if [ "$TARGET" = "app" ]; then
  PALETTE_DEST="$REPO/src/shared/lib/shared-palette.js"
  if [ -f "$PALETTE_DEST" ]; then
    compare_files "shared-palette.js" "$CENTRAL/shared/palette.cjs" "$PALETTE_DEST"
  fi
fi
```

**변경 파일:** `scripts/verify.sh` — `compare_files` 호출 2건 추가

---

### Phase 12: DB 제약조건 + 웹 타입 안전성 (L6, L7)

#### 12a. boards.description CHECK 제약조건 (L6)

**현황:**
```sql
-- boards 테이블 (20260301000001_schema.sql)
description TEXT,  -- ← 길이 제한 없음
-- 기존 CHECK: boards_visibility_check, boards_anon_mode_check만 존재
```

**마이그레이션 추가:**
```sql
-- 20260317000001_rls_hardening.sql에 포함 (Phase 6과 같은 마이그레이션)
-- 또는 별도 마이그레이션으로 분리

-- boards.description 길이 제한 (500자)
ALTER TABLE public.boards
  ADD CONSTRAINT boards_description_length
  CHECK (description IS NULL OR char_length(description) <= 500);

-- boards.name 길이 제한 (100자) — 기존 없음, 함께 추가
ALTER TABLE public.boards
  ADD CONSTRAINT boards_name_length
  CHECK (char_length(name) <= 100);
```

**영향 분석:**
- 현재 boards 데이터: 1건 (자유게시판, description 26자) → 제약조건 충족 ✓
- `shared/constants.ts` VALIDATION과 동기화: `GROUP_NAME_MAX: 100`, `GROUP_DESC_MAX: 500` 재사용
- 앱/웹 UI에 이미 길이 제한 없음 → 프론트엔드 검증 추가 권장 (Phase 2의 VALIDATION 활용)

#### 12b. view-transition.ts 타입 안전성 (L7)

**현황:**
```typescript
// view-transition.ts:30
const transition = (document as any).startViewTransition(callback)
```

`document.startViewTransition`은 View Transitions API (Chrome 111+)로, TypeScript DOM 타입에 아직 완전 반영되지 않아 `as any` 캐스트 사용 중.

**해결 방안:**

```typescript
// view-transition.ts — 타입 선언 추가
interface ViewTransition {
  finished: Promise<void>;
  ready: Promise<void>;
  updateCallbackDone: Promise<void>;
}

interface DocumentWithViewTransition extends Document {
  startViewTransition(callback: () => void | Promise<void>): ViewTransition;
}

function supportsViewTransitions(): boolean {
  return typeof document !== 'undefined' && 'startViewTransition' in document
}

export function startViewTransition(
  callback: () => void | Promise<void>,
  direction: TransitionDirection = 'forward',
) {
  if (!supportsViewTransitions()) {
    callback()
    return
  }

  if (direction === 'back') {
    document.documentElement.classList.add('vt-back')
  }

  const doc = document as unknown as DocumentWithViewTransition
  const transition = doc.startViewTransition(callback)
  transition.finished.then(() => {
    document.documentElement.classList.remove('vt-back')
  })
}
```

> `as any` → `as unknown as DocumentWithViewTransition` 로 타입 안전성 확보.
> View Transitions API가 TypeScript DOM lib에 정식 추가되면 인터페이스 제거 가능.

**확인 결과**: `@types/dom-view-transitions` 패키지 미존재 → 위 인터페이스 방식 적용.

**변경 파일:** `src/lib/view-transition.ts` — 타입 캐스트 개선

---

### Phase 13: 검색 성능 최적화 (L2, L8, L9) — 조건부 실행

> ⚠️ 이 Phase는 공개 게시글 5,000건 이상 시 실행. 현재 데이터 규모에서는 불필요.

#### 13a. ts_headline 2-stage CTE (L2)

**현황**: `search_posts_v2`에서 `ts_headline()`이 매칭된 모든 행에 실행됨.
5,000건 이상에서 성능 저하 예상 (ts_headline은 비용이 높은 함수).

**해결 방안 — 2-stage CTE:**
```sql
CREATE OR REPLACE FUNCTION public.search_posts_v2(
  p_query TEXT, p_emotion TEXT DEFAULT NULL,
  p_sort TEXT DEFAULT 'relevance',
  p_limit INTEGER DEFAULT 20, p_offset INTEGER DEFAULT 0
) RETURNS TABLE( /* 기존과 동일 */ )
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_tsquery TSQUERY;
  v_pattern TEXT;
BEGIN
  IF char_length(trim(p_query)) < 2 THEN RETURN; END IF;

  v_tsquery := plainto_tsquery('simple', p_query);
  v_pattern := '%' || replace(replace(trim(p_query), '%', '\%'), '_', '\_') || '%';

  RETURN QUERY
  WITH
  -- Stage 1: 필터링 + 정렬 + 페이지네이션 (ts_headline 없이)
  matched AS (
    SELECT p.id, p.title, p.content, p.board_id, p.created_at,
           p.display_name, p.author_id, p.is_anonymous, p.image_url,
           p.initial_emotions, p.group_id,
           pa.emotions,
           COALESCE(r.like_count, 0)::INTEGER AS like_count,
           COALESCE(c.comment_count, 0)::INTEGER AS comment_count,
           (
             ts_rank(
               setweight(to_tsvector('simple', p.title), 'A') ||
               setweight(to_tsvector('simple', p.content), 'B'),
               v_tsquery
             ) * 10
             + CASE WHEN p.title ILIKE v_pattern THEN 5.0 ELSE 0 END
             + CASE WHEN p.title ILIKE v_pattern || '%' THEN 3.0 ELSE 0 END
           )::REAL AS relevance_score
    FROM posts p
    LEFT JOIN post_analysis pa ON pa.post_id = p.id
    LEFT JOIN (SELECT post_id, SUM(count)::INTEGER AS like_count FROM reactions GROUP BY post_id) r ON r.post_id = p.id
    LEFT JOIN (SELECT post_id, COUNT(*)::INTEGER AS comment_count FROM comments WHERE deleted_at IS NULL GROUP BY post_id) c ON c.post_id = p.id
    WHERE p.deleted_at IS NULL AND p.group_id IS NULL
      AND (p_emotion IS NULL OR p_emotion = ANY(pa.emotions))
      AND (
        (to_tsvector('simple', p.title) || to_tsvector('simple', p.content)) @@ v_tsquery
        OR p.title ILIKE v_pattern
        OR p.content ILIKE v_pattern
      )
    ORDER BY
      CASE WHEN p_sort = 'relevance' THEN relevance_score END DESC NULLS LAST,
      CASE WHEN p_sort = 'latest' THEN extract(epoch FROM p.created_at) END DESC NULLS LAST,
      p.created_at DESC
    LIMIT p_limit OFFSET p_offset
  )
  -- Stage 2: 페이지네이션 결과(최대 20건)에만 ts_headline 적용
  SELECT m.id, m.title, m.content, m.board_id,
         m.like_count, m.comment_count, m.emotions,
         m.created_at, m.display_name, m.author_id,
         m.is_anonymous, m.image_url, m.initial_emotions, m.group_id,
         ts_headline('simple', m.title, v_tsquery,
           'MaxWords=50, MinWords=10, MaxFragments=1, StartSel=<<, StopSel=>>') AS title_highlight,
         ts_headline('simple', m.content, v_tsquery,
           'MaxWords=30, MinWords=10, MaxFragments=1, StartSel=<<, StopSel=>>') AS content_highlight,
         m.relevance_score
  FROM matched m;
END;
$$;
```

**성능 개선**: ts_headline이 전체 매칭 행 → 최대 20행(p_limit)으로 축소.
5,000건 기준 약 250배 호출 감소 예상.

**트리거**: `SELECT COUNT(*) FROM posts WHERE deleted_at IS NULL AND group_id IS NULL` > 5,000

#### 13b. pg_trgm 인덱스 활용 확인 (L8) — ✅ 해결 완료

**확인 결과**: pg_trgm v1.6 활성 확인. 마이그레이션 20260310000001에서 인덱스 생성됨.

```sql
-- 이미 존재하는 인덱스
idx_posts_title_trgm   — GIN (title gin_trgm_ops)
idx_posts_content_trgm — GIN (content gin_trgm_ops)
```

**결론**: L8 추가 작업 불필요. ILIKE 검색 시 pg_trgm 인덱스 자동 활용됨.

#### 13c. 한국어 검색 품질 (L9)

**현황**: `search_posts_v2`는 `'simple'` lexer 사용. 한국어에 대해:
- 형태소 분석 없음 (복합 명사 분리 불가)
- 조사 처리 없음 ("힘들었다" ≠ "힘들")
- ILIKE 폴백으로 부분 보완되지만, FTS 랭킹에서 한국어 정확도 낮음

**방안 비교:**

| 방안 | 장점 | 단점 | 난이도 |
|---|---|---|---|
| **현행 유지 (simple + ILIKE)** | 변경 없음, 안정적 | 형태소 미지원 | - |
| **PGroonga** | 한/중/일 형태소 분석, CJK 최적화 | ✅ Supabase Pro 지원 (활성화 완료) | 낮음 |
| **pg_bigm** | 2-gram 기반, 한국어 부분 매칭 | Supabase 미지원, precision 낮음 | 중간 |
| **앱 레벨 전처리** | DB 변경 없음 | 클라이언트 복잡도 증가 | 중간 |
| **외부 검색 엔진 (Meilisearch)** | 한국어 토크나이저 내장, 오타 허용 | 인프라 추가, 동기화 필요, 비용 | 높음 |

**권장 전략 (단계적):**

1. **현재**: simple + ILIKE + pg_trgm — 충분한 품질 (사용자 수 적음)
2. **중기**: PGroonga (✅ extension 활성 완료, search_posts_v3 설계 완료 → v2 Phase E 참조)
3. **장기 (10,000+ 사용자)**: 외부 검색 엔진 도입 검토 (Meilisearch/Typesense)

> **확인 결과**: 공개 게시글 14건, 검색 품질 피드백 없음 → 현행 유지.
> Phase 13 전체 보류. 데이터 5,000건+ 도달 시 재평가.
> 한국어 검색 심층 연구는 [DESIGN-maintenance-v2.md](DESIGN-maintenance-v2.md) Phase E 참조.

---

## 4. 변경 파일 목록

### 중앙 레포 (7파일)
| 파일 | 작업 | Phase |
|---|---|---|
| `shared/constants.ts` | ANALYSIS_STATUS, ANALYSIS_CONFIG, VALIDATION 추가 | 2 |
| `shared/utils.ts` | validatePostInput, validateCommentInput 추가 | 2 |
| `docs/SCHEMA.md` | 마이그레이션 18-22, RPC, RLS, 제약조건 갱신 | 8 |
| `scripts/verify.sh` | Edge Function 감정 상수 + utils + palette 검증 추가 | 7b, 11c |
| `supabase/migrations/20260317000001_rls_hardening.sql` | post_analysis RLS + reactions 쓰기 제거 + boards CHECK (신규) | 6, 12a |
| `CLAUDE.md` | 마이그레이션 23, RLS 변경 반영 | 8 |
| `.gitignore` | `.env.local` 추가 (CI/CD 도입 시) | 11b |

### 앱 레포 (14파일)
| 파일 | 작업 | Phase |
|---|---|---|
| `src/shared/lib/api/helpers.ts` | extractErrorMessage 추출 (신규) | 3a |
| `src/shared/lib/api/posts.ts` | helpers에서 import | 3b |
| `src/shared/lib/api/comments.ts` | 에러 처리 3곳 통일 | 3b |
| `src/shared/lib/api/reactions.ts` | 에러 처리 2곳 통일 + APIError 래핑 | 3b |
| `src/shared/lib/api/recommendations.ts` | logger.error 추가 | 3b |
| `src/shared/lib/api/trending.ts` | logger.error 추가 | 3b |
| `src/features/posts/hooks/usePostDetailAnalysis.ts` | ANALYSIS_STATUS/CONFIG 상수 적용 | 2 |
| `src/app/search.tsx` | ESLint 의존성 배열 수정 | 7a |
| `src/features/posts/components/EmotionCalendar.tsx` | 미사용 import 제거 | 7a |
| `package.json` | npm audit fix | 1a |
| `tests/shared/lib/api/comments.test.ts` | 댓글 API 테스트 (신규) | 10b |
| `tests/shared/lib/api/reactions.test.ts` | 리액션 API 테스트 (신규) | 10b |
| `tests/shared/lib/api/recommendations.test.ts` | 추천 API 테스트 (신규) | 10b |
| `tests/shared/lib/api/trending.test.ts` | 트렌딩 API 테스트 (신규) | 10b |

### 웹 레포 (5파일)
| 파일 | 작업 | Phase |
|---|---|---|
| `next.config.ts` | 보안 헤더 + CSP 추가 | 4 |
| `src/features/posts/api/postsApi.ts` | 에러 로깅 컨텍스트 추가 (6곳) | 5a |
| `sentry.server.config.ts` | userId PII 필터 추가 | 5b |
| `src/lib/view-transition.ts` | `(document as any)` → 타입 안전 캐스트 | 12b |
| `package.json` | npm audit fix | 1b |

---

## 5. 구현 순서

```
Phase 1   보안 취약점 (npm audit fix)           ← 앱/웹 병렬
    ↓
Phase 2   중앙 shared 보강                      ← 상수/유틸 추가
    ↓
Phase 3   앱 API 에러 처리 통일                  ← helpers.ts + 6파일
    ↓
Phase 4   웹 보안 헤더                           ← next.config.ts
    ↓
Phase 5   웹 에러 처리 & Sentry                  ← postsApi.ts + sentry
    ↓
Phase 6   DB 정비 (RLS + 크론)                   ← 마이그레이션 + pg_cron
    ↓
Phase 7   앱 코드 정리                           ← ESLint + Edge 검증
    ↓
Phase 8   문서 갱신                              ← SCHEMA.md + CLAUDE.md
    ↓
Phase 9   동기화 & 검증 & 배포                    ← sync + test + deploy
    ↓
Phase 10  앱 테스트 확장                          ← API 모듈 테스트 4개
    ↓
Phase 11  스크립트 이식성                         ← verify.sh 보강
    ↓
Phase 12  DB 제약조건 + 웹 타입                   ← boards CHECK + view-transition
    ↓
Phase 13  검색 성능 최적화 (조건부)               ← 5,000건+ 시 실행
```

예상 변경: **중앙 7파일, 앱 14파일, 웹 5파일** + DB 마이그레이션 1개 + pg_cron 스케줄

---

## 6. 범위 외 (향후 과제)

| 항목 | 상세 | 트리거 | 예상 노력 | 상태 |
|---|---|---|---|---|
| Expo 55 업그레이드 | expo 54→55, JS breaking change 없음 | ✅ 승인됨 | 낮음 (30분) | v2 Phase A |
| Hook/컴포넌트 테스트 | Feature hooks 25개 + 컴포넌트 25개 | ✅ 승인됨 | 중간 (7주) | v2 Phase B |
| Next.js nonce CSP | `unsafe-inline` 제거, nonce 기반 | Vercel Pro 전환 시 | 중간 | v2 Phase C |
| 한국어 검색 (PGroonga) | PGroonga extension ✅ 활성, search_posts_v3 설계 완료 | 검색 피드백 시 | 중간 | v2 Phase E |
| ~~RLS 재귀 패턴 통일~~ | ~~posts/comments RLS의 EXISTS → is_group_member()~~ | - | - | ✅ v2 Phase D에서 이미 완료 확인 |

> Phase 10-13에 편입된 항목(L1~L9)은 위 목록에서 제거됨.
> 위 향후 과제의 심층 연구 및 설계는 **[DESIGN-maintenance-v2.md](../DESIGN-maintenance-v2.md)** 참조.

---

## 7. 사용자 확인 항목 (확인 완료)

| # | 항목 | 결과 | 영향 |
|---|---|---|---|
| Q1 | pg_trgm 활성화 여부 | ✅ 활성 (v1.6) | L8 해결 완료, 인덱스 존재 |
| Q2 | pg_cron 활성화 여부 | ✅ 활성 + 스케줄 등록 완료 | M7 해결 완료 (10분 간격 자동 실행) |
| Q3 | Supabase 플랜 | **Pro** | pg_cron 활성화 가능 |
| Q4 | 공개 게시글 수 | **14건** | Phase 13 전체 보류 (5,000건+ 시 재평가) |
| Q5 | @types/dom-view-transitions | 패키지 미존재 | Phase 12b: 인터페이스 방식 적용 |
| Q6 | 검색 품질 피드백 | 확인 불가 | Phase 13c 보류 |

> Phase 1~12는 즉시 실행 가능. Phase 13은 데이터 규모 도달 시 실행.
