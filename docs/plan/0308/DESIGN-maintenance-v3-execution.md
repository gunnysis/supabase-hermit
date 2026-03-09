# 유지보수 구현 실행 설계 v3 — Claude 자율 실행 계획서

> 작성: 2026-03-09 | v1 설계 + v2 연구 + 리뷰 반영 → 구현 실행 단계 구체화
> 실행 주체: **Claude Code — 모든 구현/판단/배포 권한 일임**
> 기반: [DESIGN-maintenance-v1.md](DESIGN-maintenance-v1.md), [DESIGN-maintenance-v2.md](DESIGN-maintenance-v2.md), [REVIEW-dev-lead-analysis.md](../memo/REVIEW-dev-lead-analysis.md)

---

## 실행 원칙

1. **자율 판단** — 조사 결과에 따라 실행 계획을 스스로 조정. 추가 확인 불필요.
2. **실패 시 자체 해결** — 에러 발생 시 원인 분석 → 수정 → 재시도. 막힐 때만 보고.
3. **커밋/배포 자율** — 각 Release 완료 시 커밋 + push 자체 판단으로 실행.
4. **비용 발생은 보고** — 유료 플랜 업그레이드가 필요한 시점에 현황과 함께 보고.

---

## 0. 인프라 + 비용 현황

### 0a. 현재 인프라

| 서비스 | 현재 플랜 | 월 비용 | 한도 |
|---|---|---|---|
| **Supabase** | Pro | $25/mo | pg_cron, PGroonga 활성, 8GB DB |
| **Vercel** | Hobby (무료) | $0 | 서버리스 100GB-hrs, 10초 타임아웃 |
| **Sentry** | Developer (무료) | $0 | 5,000 에러/월, 1명, 이메일 알림만 |
| **EAS Build** | Free tier | $0 | 월 30빌드, 큐 대기 |

### 0b. 코드베이스

| 레포 | 경로 | 상태 |
|---|---|---|
| 중앙 | `/home/gunny/apps/supabase-hermit` | 마이그레이션 22개, shared 3파일 (constants 117줄, utils 31줄, types 290줄) |
| 앱 | `/mnt/c/Users/Administrator/programming/apps/gns-hermit-comm` | Expo 54, 테스트 17파일 83케이스 |
| 웹 | `/home/gunny/apps/web` | Next.js 16.1.6, Sentry 연동 |

### 0c. 비용 준비 — 구현 착수 전 완료

> Release 1 시작 전에 아래 플랜 전환을 모두 완료한다.
> 구현 중 플랜 제한에 걸려 작업이 중단되는 상황을 원천 차단.

**전환 대상:**

| 서비스 | 현재 | 전환 | 월 비용 | 이유 |
|---|---|---|---|---|
| **Sentry** | Developer (무료) | **Team** | **$26/mo** | Phase 3/5 에러 로깅 개선 → 5,000건/월 쿼터 부족 가능. Slack 알림 + GitHub 연동 + Discover로 배포 후 모니터링 품질 확보 |
| Supabase | Pro | 유지 | $25/mo | 이미 충분 |
| Vercel | Hobby | 유지 | $0 | Phase 4 정적 CSP로 충분. nonce CSP(Backlog) 실행 시 재평가 |
| EAS Build | Free | 유지 | $0 | 월 30빌드 충분. OTA 배포 우선 |

**전환 후 총 월 비용: $51/mo** (Supabase $25 + Sentry $26)

**Sentry Team 전환 시 설정:**
1. Sentry 대시보드 → Settings → Subscription → Team 플랜 선택
2. Slack 연동: Settings → Integrations → Slack → 에러 알림 채널 연결
3. GitHub 연동: Settings → Integrations → GitHub → 레포 연결
4. Alert Rule: 에러 100건/1시간 초과 시 Slack 알림

**전환 완료 후 구현 착수.**

---

## 1. 사전 조사 — Release 1 착수 직전 자체 수행

> 아래 4건을 실행하고 결과에 따라 자체 판단으로 계획 조정.

### 조사 1: 웹 SSR Supabase 클라이언트 패턴

**목적**: Phase 6a(post_analysis RLS `auth.role() = 'authenticated'`)가 웹 SSR을 깨뜨리지 않는지 확인.

**실행**:
```
웹 레포 전수 조사:
1. createServerClient / createClient 호출 검색
2. anon key vs service_role_key 사용처 분류
3. post_analysis 테이블 조회하는 SSR 경로 식별
```

**자체 판단**:
- 모든 SSR이 service_role_key → Phase 6a 바로 진행
- anon key 경로 발견 → 해당 경로를 service_role_key로 수정 후 진행 (추가 커밋)

### 조사 2: npm audit 현황

```bash
cd /mnt/c/Users/Administrator/programming/apps/gns-hermit-comm && npm audit 2>/dev/null
cd /home/gunny/apps/web && npm audit 2>/dev/null
```

**자체 판단**: `npm audit fix`로 해결 안 되는 건 → overrides 또는 수동 업그레이드 적용.

### 조사 3: Sentry 쿼터 기준선

**실행**: Sentry CLI 또는 대시보드에서 현재 월간 에러 수 확인. 기록만 해두면 됨.

### 조사 4: Zod 스키마 현황

```
앱 레포에서 postSchema, commentSchema 검색:
- 이미 길이 검증 있으면 → validatePostInput은 서버 fallback용으로 명확화 (주석 추가)
- 없으면 → validatePostInput이 1차 검증, 앱/웹 Zod 스키마에서 import 활용
```

---

## 2. Release 1 — 보안/안정성 (Day 1)

### Step 1-1: 사전 조사 4건 실행 → 결과에 따라 자체 조정

### Step 1-2: DB 마이그레이션 작성 + Push (중앙)

**생성할 파일** (독립 마이그레이션 2개):
```
supabase/migrations/20260317000001_post_analysis_rls.sql
  → post_analysis SELECT를 auth.role() = 'authenticated'로 변경

supabase/migrations/20260317000002_reactions_rls_cleanup.sql
  → reactions/user_reactions 직접 쓰기 RLS 5개 정책 DROP
```

**실행**:
```bash
bash scripts/db.sh push --dry-run   # 확인
bash scripts/db.sh push              # 적용 (자동 gen-types + sync + verify)
```

**롤백 SQL** (문제 발생 시 즉시 적용):
```sql
-- 20260317000001 롤백
DROP POLICY IF EXISTS "post_analysis_select" ON public.post_analysis;
CREATE POLICY "post_analysis_select" ON public.post_analysis
  FOR SELECT USING (true);

-- 20260317000002 롤백: 원본 rls.sql에서 쓰기 정책 복원
```

### Step 1-3: 앱 — npm audit + Expo 55

```bash
cd /mnt/c/Users/Administrator/programming/apps/gns-hermit-comm
npm audit fix
npm install expo@~55.0.5 jest-expo@~55.0.9 babel-preset-expo@^55.0.10
npm run test          # 통과 확인
npm start             # Metro 확인
npm audit --omit=dev  # 프로덕션 취약점 0건 확인
```

**실패 대응** (자체 해결):
- 테스트 실패 → Expo 55 breaking changes 확인 (v2 §2b), 코드 수정
- Metro 실패 → babel-preset-expo 버전 조정
- audit fix 불완전 → `npm install tar@latest`, 또는 overrides

### Step 1-4: 웹 — npm audit + 보안 헤더 + Sentry PII

```bash
cd /home/gunny/apps/web
npm audit fix
```

**코드 변경 3파일**:
1. `package.json` — audit fix 결과
2. `next.config.ts` — `headers()` 함수 추가 (6개 보안 헤더 + CSP)
3. `sentry.server.config.ts` — PII regex에 `userId` 추가

```bash
npx next build  # 빌드 확인
```

### Step 1-5: 3개 레포 커밋 + Push

```
중앙: DB 마이그레이션 2개 커밋
앱: npm audit + Expo 55 커밋 → push → OTA 배포
웹: npm audit + 보안 헤더 + Sentry 커밋 → push → Vercel 자동 배포
```

**배포 후 확인** (다음 Release 착수 전):
- Sentry 에러율 급증 없는지
- 앱 기본 동선 (로그인 → 게시글 → 리액션) 정상
- 웹 SSR 정상 렌더링
- post_analysis 조회 정상

**비용**: $0 (추가 비용 없음)

---

## 3. Release 2 — 코드 품질 (Day 2-3)

### Step 2-1: 중앙 shared 수정

**shared/constants.ts** 추가 (~48줄 추가):
- `ANALYSIS_STATUS` — 4개 상태값 상수
- `ANALYSIS_CONFIG` — 8개 설정 상수
- `VALIDATION` — 5개 길이 제한 상수

**shared/utils.ts** 추가 (~30줄 추가):
- `validatePostInput()` — 게시글 제목/내용 검증
- `validateCommentInput()` — 댓글 검증

조사 4 결과에 따라 Zod 관계 주석 추가.

### Step 2-2: Sync + 앱 상수 적용

```bash
bash scripts/sync-to-projects.sh
```

**앱 `usePostDetailAnalysis.ts`** — 매직넘버/문자열 7+곳을 ANALYSIS_STATUS/CONFIG로 교체:

| 줄 | 현재 | 변경 |
|---|---|---|
| 8 | `const MAX_POLLING_MS = 2 * 60 * 1000` | `ANALYSIS_CONFIG.MAX_POLLING_MS` |
| 11 | `const MAX_FALLBACK_RETRIES = 2` | `ANALYSIS_CONFIG.MAX_FALLBACK_RETRIES` |
| 14 | `const FALLBACK_DELAYS = [10_000, 20_000]` | `ANALYSIS_CONFIG.FALLBACK_DELAYS` |
| 45 | `status === 'done'` | `ANALYSIS_STATUS.DONE` |
| 48 | `retryCount >= 3` | `ANALYSIS_CONFIG.MAX_RETRY_COUNT` |
| 56 | `5000` (폴링 간격) | `ANALYSIS_CONFIG.POLLING_INTERVAL_MS` |
| 97+ | `'done'`, `'pending'` 등 | `ANALYSIS_STATUS.*` |

### Step 2-3: 앱 API 에러 처리 통일

**실행 순서**:
1. `src/shared/lib/api/helpers.ts` 생성 — extractErrorMessage 추출
2. `posts.ts` — helpers import, 로컬 함수 삭제
3. `comments.ts` — 3곳 에러 처리 통일
4. `reactions.ts` — 2곳 에러 처리 + APIError + logger
5. `recommendations.ts` — logger.error 추가
6. `trending.ts` — logger.error 추가

**표준 패턴**:
```typescript
if (error) {
  const errorMsg = extractErrorMessage(error);
  logger.error('[API] functionName:', errorMsg, {
    code: error.code, details: error.details, hint: error.hint,
  });
  throw new APIError(500, errorMsg);
}
```

### Step 2-4: 웹 에러 로깅

**postsApi.ts** — `throw error`만 하는 10곳에 `logger.error` 추가.
`import { logger } from '@/lib/logger'` 필요.

### Step 2-5: ESLint 수정 (앱)

- `search.tsx` — 옵셔널 체이닝을 변수로 추출
- `EmotionCalendar.tsx` — 미사용 `EMOTION_EMOJI` import 제거

### Step 2-6: verify.sh 보강 (중앙)

추가 검증 3건:
1. `utils.generated.ts` ↔ `shared/utils.ts` 동기화
2. `shared-palette.js` ↔ `shared/palette.cjs` 동기화 (앱만)
3. Edge Function `VALID_EMOTIONS` ↔ 중앙 `ALLOWED_EMOTIONS` 비교

### Step 2-7: 검증 + 커밋 + Push

```bash
bash scripts/verify.sh
cd /mnt/c/Users/Administrator/programming/apps/gns-hermit-comm && npm run test
cd /home/gunny/apps/web && npx next build
```

통과 시 3개 레포 커밋 + push.

**비용 판단 (Release 2 배포 후)**:
```
Sentry 쿼터 확인:
  ≤3,000건/월 → 조치 없음
  3,001-5,000건/월 → Rate Limiting 설정 자체 적용
  >5,000건/월 → 보고: "Sentry Team($26/mo, 50K건) 필요. 이점: Slack 알림, GitHub 연동, Discover."
```

---

## 4. Release 3 — 문서 (Day 3)

### Step 3-1: SCHEMA.md 갱신

수정 범위:
1. 헤더: "17개" → "24개" (Release 1 마이그레이션 2개 포함)
2. 마이그레이션 18-24번 추가
3. RPC: `cleanup_stuck_analyses()` 추가
4. groups RLS: UPDATE/DELETE 정책
5. groups 제약조건: `invite_code` CHECK
6. search_posts v1 문서 제거
7. search_posts_v2 ILIKE 이스케이프
8. post_analysis RLS 변경 반영
9. reactions 직접 쓰기 정책 제거 반영

### Step 3-2: CLAUDE.md 갱신

- 마이그레이션 수 + 목록 갱신
- RLS 변경 반영
- shared 추가 내용 반영 (ANALYSIS_STATUS, CONFIG, VALIDATION, validatePostInput 등)

커밋 + push.

**비용**: $0

---

## 5. Release 4 — DB 제약조건 + 웹 타입 (Day 4)

### Step 4-1: boards CHECK 마이그레이션

**파일**: `supabase/migrations/20260318000001_boards_constraints.sql`

```sql
ALTER TABLE public.boards
  ADD CONSTRAINT boards_description_length
  CHECK (description IS NULL OR char_length(description) <= 500);

ALTER TABLE public.boards
  ADD CONSTRAINT boards_name_length
  CHECK (char_length(name) <= 100);
```

Push 전 기존 데이터 확인 (현재 1건, 26자 → 안전).

### Step 4-2: view-transition.ts 타입 (웹)

- `ViewTransition` + `DocumentWithViewTransition` 인터페이스 추가
- `as any` → `as unknown as DocumentWithViewTransition`

### Step 4-3: Push + 검증 + 커밋

```bash
bash scripts/db.sh push
cd /home/gunny/apps/web && npx next build
```

**비용**: $0

---

## 6. Release 5 — 디자인/접근성 (Week 2)

### Step 5-1: MOTION 프리셋 확장 (중앙)

**shared/constants.ts** — 기존 3개 + 실제 사용값 5개 추가:
```typescript
spring: {
  gentle:  { tension: 120, friction: 14 },
  bouncy:  { tension: 200, friction: 8 },
  quick:   { tension: 300, friction: 20 },
  button:  { tension: 300, friction: 8 },    // Button.tsx 실제 값
  fab:     { tension: 120, friction: 5 },    // FloatingActionButton.tsx
  card:    { tension: 200, friction: 8 },    // PostCard.tsx
  cardAlt: { tension: 150, friction: 4 },    // PostCard 두 번째
  tab:     { tension: 180, friction: 7 },    // SortTabs.tsx
}
```

**절대 원칙: 기존 하드코딩 값을 그대로 상수화. 값 변경 금지.**

### Step 5-2: Sync + 앱 적용 (6파일)

```bash
bash scripts/sync-to-projects.sh
```

| 파일 | 하드코딩 → 상수 |
|---|---|
| Button.tsx | `{tension:300, friction:8}` → `MOTION.spring.button` |
| FloatingActionButton.tsx | `{tension:120, friction:5}` → `MOTION.spring.fab` |
| ReactionBar.tsx | 3종 → `MOTION.spring.*` |
| PostCard.tsx | 2종 → `MOTION.spring.card/cardAlt` |
| SortTabs.tsx | `{tension:180, friction:7}` → `MOTION.spring.tab` |

### Step 5-3: useThemeColors 확장 + 적용 (앱 8+파일)

**useThemeColors.ts**에 `icon`/`shadow` 반환값 추가 후, ScreenHeader, PostDetailHeader, search.tsx, Button, FloatingActionButton, PostCard 등에서 하드코딩 색상 교체.

### Step 5-4: 폰트 크기 표준화 (앱 4파일)

| 현재 | 변경 |
|---|---|
| `text-[13px]` (SortTabs) | `text-xs` |
| `text-[15px]` (ErrorView) | `text-sm` |
| `text-[17px]` (PostCard, SearchResultCard) | tailwind.config.js에 `md: '17px'` 확장 |

### Step 5-5: prefers-reduced-motion (웹)

- `globals.css` — 모션 감소 미디어 쿼리 추가
- `view-transition.ts` — `matchMedia` 체크 추가

### Step 5-6: 접근성 button 전환 (웹 3파일)

| 파일 | `<div/span onClick>` → `<button>` + `aria-label` |
|---|---|
| EmotionCalendar.tsx | 캘린더 셀 button 전환 |
| AdminSecretTap.tsx | span → button, tabIndex |
| RichEditor.tsx | aria-label, aria-pressed |

### Step 5-7: scrollbar CSS (웹)

`globals.css`에 `.scrollbar-none`, `.scrollbar-hide` 정의.

### Step 5-8: 검증 + 커밋 + Push

```bash
cd /mnt/c/Users/Administrator/programming/apps/gns-hermit-comm && npm run test
cd /home/gunny/apps/web && npx next build
```

앱/웹 독립 배포 가능.

**비용**: $0

---

## 7. Backlog — 트리거 조건 충족 시 자율 실행

| 항목 | 트리거 | 비용 |
|---|---|---|
| **테스트 확장** (Phase 10 + v2 B) | Release 2 후 여유 시 | $0 |
| **검색 최적화** (Phase 13) | posts 5,000건+ | $0 |
| **PGroonga** (v2 Phase E) | 검색 품질 피드백 3건+ | $0 |
| **nonce CSP** (v2 Phase C) | 보안 감사 요구 또는 SRI 안정화 | **보고 필요**: Vercel Pro $20/mo |
| **디자인 토큰 문서** (v2 Phase F) | 팀 2인+ 확장 | $0 |

### 테스트 확장 상세 (위험 기반 2주)

| 주차 | Tier | 대상 | 케이스 | Done 기준 |
|---|---|---|---|---|
| 1 | 0 | toggle_reaction, soft_delete, useAuth | ~15 | 3 hooks 테스트, `npm test` 통과 |
| 2 | 1 | useCreatePost, useBoardPosts + API 4모듈 | ~20 | 2 hooks + 4 API, `npm test` 통과 |

신규 테스트 파일 4개:
- `tests/shared/lib/api/comments.test.ts`
- `tests/shared/lib/api/reactions.test.ts`
- `tests/shared/lib/api/recommendations.test.ts`
- `tests/shared/lib/api/trending.test.ts`

---

## 8. 전체 타임라인

```
━━━ Day 0: 사전 조사 (30분) ━━━
  자체 수행 → 결과에 따라 계획 자동 조정

━━━ Day 1: Release 1 — 보안/안정성 ━━━
  DB 마이그레이션 2개 (15분)
  DB push + gen-types + sync (10분)
  앱 npm audit + Expo 55 (30분)
  웹 npm audit + 보안 헤더 + Sentry PII (30분)
  3개 레포 커밋 + 배포 (15분)

━━━ Day 2-3: Release 2 — 코드 품질 ━━━
  중앙 shared 수정 + sync (20분)
  앱 상수 적용 + 에러 처리 6파일 (60분)
  웹 에러 로깅 10곳 (20분)
  ESLint + verify.sh (20분)
  검증 + 배포 (15분)
  → Sentry 쿼터 모니터링 (초과 시에만 보고)

━━━ Day 3: Release 3 — 문서 ━━━
  SCHEMA.md + CLAUDE.md 갱신 (40분)

━━━ Day 4: Release 4 — DB + 타입 ━━━
  boards CHECK + view-transition 타입 (35분)

━━━ Week 2: Release 5 — 디자인/접근성 ━━━
  MOTION 상수화 + 색상 중앙화 (70분)
  폰트 + 접근성 + 모션 + 스크롤바 (45분)

━━━ 이후: Backlog ━━━
  각 트리거 충족 시 자율 실행
```

---

## 9. 변경 파일 요약

### 중앙 (8파일 + 마이그레이션 3개)

| 파일 | Release | 작업 |
|---|---|---|
| `shared/constants.ts` | R2, R5 | ANALYSIS_STATUS/CONFIG/VALIDATION + MOTION 확장 |
| `shared/utils.ts` | R2 | validatePostInput, validateCommentInput |
| `scripts/verify.sh` | R2 | utils + palette + Edge Function 검증 |
| `docs/SCHEMA.md` | R3 | 마이그레이션 18-24, RPC, RLS, 제약조건 |
| `CLAUDE.md` | R3 | 스키마 변경 반영 |
| `20260317000001_post_analysis_rls.sql` | R1 | post_analysis RLS 강화 |
| `20260317000002_reactions_rls_cleanup.sql` | R1 | reactions 쓰기 RLS 제거 |
| `20260318000001_boards_constraints.sql` | R4 | boards CHECK 제약조건 |

### 앱 (20파일)

| 파일 | Release | 작업 |
|---|---|---|
| `package.json` | R1 | npm audit fix + Expo 55 |
| `src/shared/lib/api/helpers.ts` (신규) | R2 | extractErrorMessage |
| `src/shared/lib/api/posts.ts` | R2 | helpers import |
| `src/shared/lib/api/comments.ts` | R2 | 에러 처리 통일 |
| `src/shared/lib/api/reactions.ts` | R2 | 에러 처리 + APIError |
| `src/shared/lib/api/recommendations.ts` | R2 | logger 추가 |
| `src/shared/lib/api/trending.ts` | R2 | logger 추가 |
| `src/features/posts/hooks/usePostDetailAnalysis.ts` | R2 | ANALYSIS_STATUS/CONFIG |
| `src/app/search.tsx` | R2 | ESLint 수정 |
| `src/features/posts/components/EmotionCalendar.tsx` | R2 | 미사용 import 제거 |
| `src/shared/components/Button.tsx` | R5 | MOTION + shadow |
| `src/shared/components/FloatingActionButton.tsx` | R5 | MOTION + shadow |
| `src/features/posts/components/ReactionBar.tsx` | R5 | MOTION + a11y |
| `src/features/posts/components/PostCard.tsx` | R5 | MOTION + 폰트 |
| `src/shared/components/SortTabs.tsx` | R5 | MOTION + 폰트 |
| `src/shared/hooks/useThemeColors.ts` | R5 | icon/shadow 확장 |
| `src/shared/components/ScreenHeader.tsx` | R5 | icon 색상 |
| `src/features/posts/components/PostDetailHeader.tsx` | R5 | icon + 44pt |
| `src/shared/components/ErrorView.tsx` | R5 | 폰트 크기 |
| `src/features/search/components/SearchResultCard.tsx` | R5 | 폰트 크기 |

### 웹 (10파일)

| 파일 | Release | 작업 |
|---|---|---|
| `package.json` | R1 | npm audit fix |
| `next.config.ts` | R1 | 보안 헤더 + CSP |
| `sentry.server.config.ts` | R1 | PII 필터 |
| `src/features/posts/api/postsApi.ts` | R2 | 에러 로깅 10곳 |
| `src/lib/view-transition.ts` | R4, R5 | 타입 + reduced-motion |
| `src/app/globals.css` | R5 | reduced-motion + scrollbar |
| `src/features/posts/components/EmotionCalendar.tsx` | R5 | button + a11y |
| `src/components/layout/AdminSecretTap.tsx` | R5 | button + a11y |
| `src/features/posts/components/RichEditor.tsx` | R5 | aria-label/pressed |

---

## 10. 제외 항목 (ROI 기반)

| 항목 | 제외 근거 |
|---|---|
| Phase 15c (gradient CSS 변수) | 신규 파일 + 10곳 리팩토링, 현재 작동하는 코드 대규모 변경 |
| Phase 15e (PostCard memo) | 14건 게시글에서 성능 차이 없음 |
| Phase 11b (.env.local 경로) | 1인 개발에서 이점 없음 |
| v2 Phase F (디자인 토큰 문서) | 1인 개발, 참조자 없음 |

---

## 11. 보고 기준

> Claude는 아래 상황에서만 보고. 나머지는 자율 실행.

| 상황 | 보고 내용 |
|---|---|
| **유료 플랜 전환 필요** | 서비스명, 현재/목표 플랜, 월 비용, 전환 이유, 이점 |
| **롤백 실행** | 어떤 마이그레이션/배포를 왜 롤백했는지, 현재 상태 |
| **설계 변경** | v1/v2 설계와 다른 방향으로 구현한 이유 (조사 결과에 의한 판단) |
| **Release 완료** | 완료 요약, 변경 파일 수, 테스트 결과, 다음 Release 착수 여부 |
| **해결 불가 blocker** | 시도한 방법, 실패 원인, 선택지 제시 |
