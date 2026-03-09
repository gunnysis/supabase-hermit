# 유지보수 설계 v1 — 앱/웹/중앙 통합 점검

> 작성: 2026-03-08 | 3개 레포 전수 조사 기반 | 심층 분석 완료
> 갱신: 2026-03-08 | 선행 설계 문서 병합 완료
> 최종 점검: 2026-03-13 | 완료 항목 반영, 상호 참조 정합성 확인
> 작업 예정: 2026-03-13 | v1 설계 문서 구현 작업
> 설계 보강: 2026-03-08 | 프론트엔드 코드 조사 완료 — Phase 2/3/5/7/12 실제 라인 매핑 추가
> 디자인 설계: 2026-03-08 | 앱/웹 UI 전수 조사 — Phase 14 (앱 디자인) + Phase 15 (웹 디자인/접근성) 추가
> **리뷰 반영: 2026-03-09 | 개발 책임자 리뷰 기반 재구성 ([REVIEW-dev-lead-analysis.md](../memo/REVIEW-dev-lead-analysis.md))**
> **2차 리뷰 반영: 2026-03-09 | 구현 판단 개선 — 멱등성, CSP unsafe-eval, reactions 사전확인, Sentry Alert, 모니터링, MOTION 시각확인, NativeWind 호환**
> **구현 계획: 2026-03-09 | 실행 설계서 → [DESIGN-maintenance-v3-execution.md](DESIGN-maintenance-v3-execution.md)**

---

## 진행 현황

> Release 단위 체크리스트 — 전체 문서를 매번 읽지 않아도 현재 진행률 파악 가능

### Release 1: 보안/안정성 (Day 1)
- [ ] R1-1: npm audit fix + Expo 55 업그레이드 — 앱 (Phase 1a)
- [ ] R1-2: npm audit fix — 웹 (Phase 1b)
- [ ] R1-3: post_analysis RLS 강화 (Phase 6a)
- [ ] R1-4: reactions 쓰기 RLS 제거 (Phase 6c)
- [ ] R1-5: 웹 보안 헤더 + CSP (Phase 4)
- [ ] R1-6: Sentry PII 필터 (Phase 5b)
- [ ] 배포 + 24시간 모니터링

### Release 2: 코드 품질 (Day 2-3)
- [ ] R2-1: 중앙 shared 상수/유틸 보강 (Phase 2a/2b)
- [ ] R2-2: 앱 API 에러 처리 통일 (Phase 3)
- [ ] R2-3: 웹 API 에러 로깅 (Phase 5a)
- [ ] R2-4: ESLint 수정 (Phase 7a)
- [ ] R2-5: verify.sh 보강 (Phase 11c) ← **격상: 사실상 유일한 통합 테스트**
- [ ] R2-6: Edge Function 검증 스크립트 (Phase 7b)
- [ ] sync + 테스트 + 배포

### Release 3: 문서/스크립트 (Day 3)
- [ ] R3-1: SCHEMA.md 갱신 (Phase 8)
- [ ] 중앙 레포만 커밋

### Release 4: DB 제약조건 + 타입 (Day 4)
- [ ] R4-1: boards CHECK 제약조건 (Phase 12a)
- [ ] R4-2: view-transition.ts 타입 (Phase 12b)
- [ ] DB 마이그레이션 + 웹 커밋

### Release 5: 디자인/접근성 (Week 2)
- [ ] R5-1: 앱 MOTION 상수화 — **값 변경 없이** (Phase 14a 수정)
- [ ] R5-2: 앱 아이콘/그림자 색상 중앙화 (Phase 14b)
- [ ] R5-3: 앱 임의 폰트 크기 표준화 (Phase 14c)
- [ ] R5-4: 웹 prefers-reduced-motion (Phase 15a)
- [ ] R5-5: 웹 접근성 button 전환 (Phase 15b)
- [ ] R5-6: 웹 scrollbar CSS (Phase 15d)
- [ ] 앱/웹 각 커밋 (독립 배포 가능)

### Backlog (조건부)
- [ ] 앱 테스트 확장: 위험 기반 Tier 0-1만 우선 (Phase 10 + v2 Phase B 통합)
- [ ] 검색 최적화: 5,000건+ 시 (Phase 13)
- [ ] ~~Phase 15c (gradient CSS 변수)~~ — **제외: 현재 작동하는 코드의 대규모 리팩토링, ROI 낮음**
- [ ] ~~Phase 15e (PostCard memo)~~ — **제외: 14건 게시글에서 성능 차이 없음**
- [ ] 앱 접근성 보강 (Phase 14d/14e) — 여유 시 진행

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
| H7 | 앱 디자인 | MOTION 상수 정의만 되고 미사용 — 25+곳 하드코딩 spring 파라미터 | 6+ 컴포넌트 | 애니메이션 일관성 파괴, 전역 조정 불가 | Phase 14a |
| H8 | 앱 디자인 | 하드코딩 아이콘/그림자 색상 15+곳 | `ScreenHeader`, `PostDetailHeader`, `search.tsx` 등 | 테마 변경 시 누락 위험 | Phase 14b |
| H9 | 웹 접근성 | `prefers-reduced-motion` 미지원 — 모든 애니메이션 무조건 실행 | `globals.css`, 전체 애니메이션 컴포넌트 | 전정 장애 사용자 접근성 위반 | Phase 15a |

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
| M10 | 웹 접근성 | EmotionCalendar 셀 — div에 onClick, 키보드/스크린리더 불가 | `EmotionCalendar.tsx:63-74` | 키보드 내비게이션 실패 | Phase 15b |
| M11 | 웹 접근성 | AdminSecretTap — span에 onClick, 키보드 접근 불가 | `AdminSecretTap.tsx:31` | 키보드로 관리자 진입 불가 | Phase 15b |
| M12 | 웹 디자인 | 인라인 gradient 스타일 10+곳 — 디자인 시스템 우회 | `PostCard`, `EmotionWave`, `MoodSelector` 등 | 테마 일괄 변경 불가 | Phase 15c |
| M13 | 앱 디자인 | 임의 폰트 크기 `text-[Xpx]` 4곳 — Tailwind 표준 미사용 | `PostCard:97`, `SortTabs:76`, `ErrorView:51`, `SearchResultCard:47` | 타이포그래피 불일치 | Phase 14c |
| M14 | 웹 디자인 | scrollbar CSS 클래스 미정의 (`scrollbar-none`, `scrollbar-hide`) | `EmotionFilterBar.tsx:12`, `SearchView.tsx:173` | 크로스 브라우저 실패 가능 | Phase 15d |

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
| L10 | 앱 접근성 | 리액션 버튼 `accessibilityHint` 미설정 — 토글 동작 미안내 | `ReactionBar.tsx:43` | Phase 14d |
| L11 | 앱 디자인 | EmptyState 인라인 버튼 — `<Button>` 컴포넌트 미사용 | `EmptyState.tsx:33` | Phase 14e |
| L12 | 앱 디자인 | PostDetailHeader 터치 타겟 40x40pt — 최소 44pt 미달 | `PostDetailHeader.tsx:48` | Phase 14d |
| L13 | 앱 디자인 | `expo-image` 미사용 — package.json에 설치되었으나 Image 사용 | `PostCard.tsx:88-92` | Phase 14e |
| L14 | 웹 디자인 | PostCard `memo` 미적용 — 피드 리스트 성능 저하 가능 | `PostCard.tsx` | Phase 15e |
| L15 | 웹 접근성 | RichEditor 툴바 `aria-label`/`aria-pressed` 미설정 | `RichEditor.tsx:44` | Phase 15b |
| L16 | 웹 디자인 | z-index 스케일 미문서화 — Header/BottomNav/Dialog 모두 z-50 | 다수 컴포넌트 | Phase 15e |
| L17 | 웹 접근성 | view-transition.ts에 `prefers-reduced-motion` 체크 누락 | `view-transition.ts` | Phase 15a |

---

## 2.4 외부 서비스 플랜 현황

### Sentry — Developer (무료) 유지

> 현재 사용자 1명 → 5,000건/월 쿼터 충분. 업그레이드 불필요.

| 항목 | Developer (현재) | 비고 |
|---|---|---|
| 에러 쿼터 | 5,000건/월 | 사용자 1명 기준 충분 |
| Fingerprint Rules | 사용 가능 | 그루핑 조정 자유 |
| Rate Limiting | 사용 가능 | 쿼터 보호 가능 |

**Team 업그레이드 조건** (필요 시에만):
- 월 에러 2,500건 초과 (쿼터 50%) → Rate Limiting 설정 검토
- 월 에러 5,000건 근접 → Team ($26/mo) 업그레이드 검토
- 사용자 증가로 에러 급증 → Team 업그레이드 필수

### Vercel — 현재 Hobby (무료) 플랜

| 항목 | Hobby | Pro ($20/mo) |
|---|---|---|
| 서버리스 실행 | 100GB-hrs, 10초 타임아웃 | 1,000GB-hrs, 60초 |
| 대역폭 | 100GB/월 | 1TB/월 |
| 빌드 | 6,000분/월 | 24,000분/월 |

> nonce CSP(v2 Phase C)는 모든 페이지를 동적 렌더링하므로 Hobby 플랜에서 서버리스 제한 주의.
> 현재는 v1 Phase 4 정적 CSP 우선 적용.

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

# 3단계: jest-expo 체인 (CRITICAL) — Expo 55 업그레이드와 함께 해결
npm install expo@~55.0.5 jest-expo@~55.0.9 babel-preset-expo@^55.0.10
npm run test          # Jest 전체 통과 확인
npm start             # Metro 번들러 확인
```

> **3단계 상세**: jest-expo CRITICAL 취약점(`@tootallnate/once`)은 jest-expo → jsdom 체인에 존재.
> jest-expo v55에서도 동일 체인이지만, devDependency이므로 프로덕션 빌드에 포함되지 않음.
> `npm audit --omit=dev`로 프로덕션 취약점 0건 확인 가능.
> 근본 해결은 jsdom이 http-proxy-agent 5+로 업그레이드 시 (jsdom 측 이슈).
>
> Expo 55 Breaking Changes 분석 결과: **JS 레벨 breaking change 없음** (v2 Phase A §2b 참조).
> EXAppDelegateWrapper 제거, ReactNativeHostWrapper 삭제 등은 커스텀 네이티브 모듈에만 영향 — 앱에 없음.
> react-native 0.81.5, react 19.1.0 버전 변경 없음.
>
> 네이티브 빌드가 필요한 경우:
> ```bash
> eas build --platform android --profile preview
> eas build --platform ios --profile preview
> ```

**판단**: 1-2단계 즉시 처리 (6건). 3단계(Expo 55 + jest-expo)도 Release 1에서 함께 실행 — JS breaking change 없으므로 안전.

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

**적용 대상 (코드 조사 2026-03-08):**

앱 `usePostDetailAnalysis.ts` 매직넘버/문자열 **7곳**:
| line | 현재 | 변경 |
|---|---|---|
| 8 | `const MAX_POLLING_MS = 2 * 60 * 1000` | `ANALYSIS_CONFIG.MAX_POLLING_MS` |
| 11 | `const MAX_FALLBACK_RETRIES = 2` | `ANALYSIS_CONFIG.MAX_FALLBACK_RETRIES` |
| 14 | `const FALLBACK_DELAYS = [10_000, 20_000]` | `ANALYSIS_CONFIG.FALLBACK_DELAYS` |
| 41 | `staleTime: 5 * 60 * 1000` | `ANALYSIS_CONFIG.POLLING_INTERVAL_MS * 60` (또는 별도 상수) |
| 45 | `status === 'done'` | `ANALYSIS_STATUS.DONE` |
| 48 | `retryCount >= 3` | `ANALYSIS_CONFIG.MAX_RETRY_COUNT` |
| 56 | `5000` (폴링 간격) | `ANALYSIS_CONFIG.POLLING_INTERVAL_MS` |

추가로 line 97, 102-104의 `'done'`, `'pending'`, `'analyzing'`, `'failed'` 문자열도 `ANALYSIS_STATUS.*` 적용.

- Edge Function `_shared/analyze.ts`: 주석 참조 (Deno는 직접 import 불가)

#### 2b. 게시글/댓글 유효성 검증 (H3)

> **⚠️ 숨겨진 비용**: 앱/웹에서 **기존 Zod 스키마와 이중 검증** 가능성.
> Zod 스키마와의 관계 정리 필요 — validatePostInput이 Zod를 대체하는지, 보완하는지 명확히 해야 함.

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

> **참고**: 에러 메시지 변경 시 Sentry 이슈 그루핑이 바뀔 수 있으나, Sentry 설정에서 자유롭게 조정 가능 (Fingerprint Rules, Merge/Unmerge 등).
> 배포 후 Sentry 대시보드에서 새 그루핑 상태를 확인하고 필요 시 조정.

#### 3a. extractErrorMessage 공유 헬퍼 분리

**현재**: `posts.ts` line 18-31에만 존재하는 로컬 함수.

**코드 조사 결과** (2026-03-08): `helpers.ts` 미존재 확인. `posts.ts`의 로컬 함수를 추출.

> **리뷰 의견**: `posts.ts`에서 함수를 꺼내 `helpers.ts` 신규 파일 생성은 파일 1개를 위한 디렉터리 생성이 과도할 수 있음.
> 대안: `posts.ts` 내 유지하되 named export로 공유, 또는 기존 유틸 파일에 병합.
> → 현재 `api/` 디렉터리에 이미 5개 파일 존재하므로 `helpers.ts` 추가는 합리적. 유지.

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

**코드 조사 결과** (2026-03-08): 각 파일의 정확한 에러 패턴 확인.

| 파일 | 현재 패턴 | 에러 위치 (line) | 수정 내용 |
|---|---|---|---|
| `posts.ts` | `extractErrorMessage` + 로깅 ✓ (7곳) | 52,110,164,176,200,227,243 | helpers.ts에서 import로 변경, 로컬 함수 삭제 |
| `comments.ts` | `error.message`만 사용 | 27: `throw new APIError(500, error.message)`, 63: `logger.error(error.message)`, 88: `APIError` 래핑 | `extractErrorMessage` + `{ code, details, hint }` 로깅 추가 |
| `reactions.ts` | `throw error` raw (2곳) | 14: `getPostReactions`, 23: `toggleReaction` — logger/APIError import 없음 | `extractErrorMessage` + `APIError` 래핑 + `logger.error` 추가 + import 3개 추가 |
| `recommendations.ts` | `APIError`만, 로깅 없음 | 20: `throw new APIError(500, '추천 게시글 조회에 실패했습니다.')` | `logger.error` 추가 + import 추가 |
| `trending.ts` | `APIError`만, 로깅 없음 | 19: `throw new APIError(500, '트렌딩 게시글 조회에 실패했습니다.')` | `logger.error` 추가 + import 추가 |
| `analysis.ts` | 이미 완료 ✓ | — | 변경 없음 |

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

**코드 조사 결과** (2026-03-08): `next.config.ts`는 `withSentryConfig(nextConfig, {...})` 래핑 구조.
`nextConfig` 객체에 `images.remotePatterns`만 존재. `headers()` 함수를 `nextConfig`에 추가해야 함.

```typescript
// 현재 구조
const nextConfig: NextConfig = {
  images: { remotePatterns: [...] },
  // ← 여기에 headers() 추가
};
export default withSentryConfig(nextConfig, { ... });
```

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

> `unsafe-inline`은 Next.js 빌드 특성상 필요.
> `unsafe-eval`은 프로덕션에서 불필요할 수 있음 — 먼저 제거 후 빌드/실행하여 CSP 위반 에러 확인. 에러 없으면 제거 유지.
> nonce 기반 CSP는 v2 Phase C (Backlog).

**변경 파일:** `next.config.ts` — `headers()` 함수 추가

---

### Phase 5: 웹 에러 처리 & Sentry 보강 (M4, M5)

> 현재 Developer 무료 플랜 (5,000건/월) 유지. 사용자 1명 기준 쿼터 충분.
> 배포 후 쿼터 50% (2,500건) 초과 시 §2.4 기준에 따라 판단.

#### 5a. 웹 API 에러 로깅 개선 (M4)

**현황**: `postsApi.ts`에서 `if (error) throw error` — 컨텍스트 없음.

**코드 조사 결과** (2026-03-08): 에러 핸들링 **13곳** 확인 (기존 추정 6곳보다 많음).
| 함수 | 패턴 | 비고 |
|---|---|---|
| `getBoardPosts` | `throw error` | 컨텍스트 없음 |
| `getPost` | `throw error` | 컨텍스트 없음 |
| `createPost` | `throw error` | 컨텍스트 없음 |
| `updatePost` | `throw error` | 컨텍스트 없음 |
| `deletePost` (세션) | `throw new Error(메시지)` | 세션 만료 커스텀 에러 — 유지 |
| `deletePost` (RPC) | `throw new Error(메시지)` | RPC 에러 커스텀 — 유지 |
| `getPostAnalysis` | 에러 무시 | `null` 반환 — 유지 |
| `invokeAnalyzeOnDemand` | `throw error` | 컨텍스트 없음 |
| `getPostsByEmotion` | `throw error` | 컨텍스트 없음 |
| `getSimilarFeelingCount` | `throw error` | 컨텍스트 없음 |
| `getEmotionTrend` | `throw error` | 컨텍스트 없음 |
| `getRecommendedPosts` | `throw error` | 컨텍스트 없음 |
| `getTrendingPosts` | `throw error` | 컨텍스트 없음 |
| `searchPosts` | `throw error` | 컨텍스트 없음 |

**수정 대상**: `throw error`만 하는 10곳에 로깅 추가. `deletePost` 2곳과 `getPostAnalysis`는 이미 적절한 처리.

**수정 방향:**
```typescript
// postsApi.ts — 에러 발생 시 (10곳 적용)
if (error) {
  logger.error('[API] getPosts 에러:', error.message, {
    code: error.code,
    details: error.details,
    hint: error.hint,
  });
  throw error;
}
```

**필요 import 추가:** `import { logger } from '@/lib/logger'` (웹 레포 logger)

#### 5b. Sentry server config PII 필터 보강 (M5)

**현황**: `sentry.client.config.ts`는 `userId` 필드를 필터링하지만, `sentry.server.config.ts`는 누락.

**코드 조사 결과** (2026-03-08): server config는 **regex 기반** 필터 사용 (배열 `.some()` 아님).
```typescript
// 현재 sentry.server.config.ts (line 18)
if (/email|password|author|display_name/i.test(k)) {
  (event.extra as Record<string, unknown>)[k] = '[redacted]';
}
```

**sentry.server.config.ts 수정:**
```typescript
// Before
if (/email|password|author|display_name/i.test(k)) {

// After — userId 추가
if (/email|password|author|display_name|userId/i.test(k)) {
```

---

### Phase 6: DB 정비 (M6, M7, M9)

#### 6a. post_analysis RLS 강화 (M6)

**현황**: `SELECT USING (true)` — 비인증 사용자도 분석 메타데이터(status, error_reason, retry_count) 조회 가능.

**마이그레이션 추가 (독립 마이그레이션 — 롤백 단위 축소):**
```sql
-- 20260317000001_post_analysis_rls.sql ← Phase 6a만
-- post_analysis SELECT를 인증 사용자만 허용
DROP POLICY IF EXISTS "post_analysis_select" ON public.post_analysis;
CREATE POLICY "post_analysis_select" ON public.post_analysis
  FOR SELECT USING (auth.role() = 'authenticated');
```

> **⚠️ 배포 전 확인 필수**: 웹에서 SSR 시 anon key를 사용하는 경로가 있다면 데이터가 안 보이게 됨.
> 문서에서 "웹은 service_role_key 사용"이라 했지만, 실제로 모든 SSR 경로가 그런지 **웹 레포의 Supabase 클라이언트 생성 패턴 전수 조사** 필요.

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

**마이그레이션 (독립 마이그레이션 — Phase 6a와 분리):**
```sql
-- 20260317000002_reactions_rls_cleanup.sql ← Phase 6c만
-- reactions 직접 쓰기 정책 제거 (toggle_reaction RPC만 허용)
DROP POLICY IF EXISTS "reactions_insert" ON public.reactions;
DROP POLICY IF EXISTS "reactions_update" ON public.reactions;
DROP POLICY IF EXISTS "reactions_delete" ON public.reactions;

-- user_reactions 직접 쓰기 정책 제거
DROP POLICY IF EXISTS "user_reactions_insert" ON public.user_reactions;
DROP POLICY IF EXISTS "user_reactions_delete" ON public.user_reactions;
```

**사전 확인** (v3 조사 5):
앱/웹에서 `from('reactions')`, `from('user_reactions')` 직접 INSERT/UPDATE/DELETE 코드가 없는지 검색.
발견 시 RPC 호출로 교체 후 RLS 제거.

**영향 분석:**
- `toggle_reaction()`은 SECURITY DEFINER → RLS 우회 → 영향 없음 ✓
- `get_post_reactions()`은 SELECT만 → 영향 없음 ✓
- 클라이언트 직접 INSERT/DELETE 차단됨 → 의도한 동작 ✓

---

### Phase 7: 앱 코드 정리 (M1, M2)

#### 7a. ESLint 경고 수정 (M1)

**코드 조사 결과** (2026-03-08): 실제 코드 확인 완료.

**search.tsx:112-117 — 복잡한 의존성 배열:**
```typescript
// Before (line 112-117)
useEffect(() => {
  if (hasTextQuery && searchPages?.pages?.[0]?.length !== undefined) {
    addRecentSearch(trimmedQuery);
    setRecentSearches(getRecentSearches());
  }
}, [hasTextQuery, trimmedQuery, searchPages?.pages?.[0]?.length]);

// After — 옵셔널 체이닝을 변수로 추출
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

**마이그레이션 추가 (독립 마이그레이션 — Phase 6과 분리, Release 4):**
```sql
-- 20260318000001_boards_constraints.sql ← Phase 12a 단독
-- 멱등성 확보: 이미 존재하면 무시

-- boards.description 길이 제한 (500자)
DO $$ BEGIN
  ALTER TABLE public.boards
    ADD CONSTRAINT boards_description_length
    CHECK (description IS NULL OR char_length(description) <= 500);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- boards.name 길이 제한 (100자) — 기존 없음, 함께 추가
DO $$ BEGIN
  ALTER TABLE public.boards
    ADD CONSTRAINT boards_name_length
    CHECK (char_length(name) <= 100);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
```

**영향 분석:**
- 현재 boards 데이터: 1건 (자유게시판, description 26자) → 제약조건 충족 ✓
- `shared/constants.ts` VALIDATION과 동기화: `GROUP_NAME_MAX: 100`, `GROUP_DESC_MAX: 500` 재사용
- 앱/웹 UI에 이미 길이 제한 없음 → 프론트엔드 검증 추가 권장 (Phase 2의 VALIDATION 활용)

#### 12b. view-transition.ts 타입 안전성 (L7)

**코드 조사 결과** (2026-03-08): 실제 코드 구조 확인.

**현황:**
```typescript
// view-transition.ts:30 — 실제 코드
const transition = (document as any).startViewTransition(callback)
transition.finished.then(() => {
  document.documentElement.classList.remove('vt-back')
})
```

파일 전체 구조: `TransitionDirection` 타입 + `supportsViewTransitions()` 헬퍼 + `startViewTransition()` export 함수.
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

### Phase 14: 앱 디자인 일관성 (H7, H8, M13, L10-L13)

> 코드 조사: 2026-03-08 | 앱 레포 전수 조사 기반

#### 14a. MOTION 상수 적용 (H7) — 수정: 값 변경 없이 상수화만

> **⚠️ 숨겨진 비용**: friction 값 변경은 **모든 애니메이션의 체감 변경** — QA 필요, UX 회귀 위험.
> **원칙: 기존 하드코딩 값을 그대로 상수로 추출. 값 자체는 변경하지 않기.**
> 값 통일은 별도 디자인 QA 후 진행.

**현황**: `shared/constants.ts`에 MOTION 프리셋 정의 완료, **사용처 0곳**.
모든 컴포넌트가 자체 friction/tension 값을 하드코딩.

**하드코딩 현황** (25+곳):
| 파일 | 현재 값 | 매핑 가능 프리셋 |
|---|---|---|
| `Button.tsx` | friction: 8, tension: 300 | `MOTION.spring.quick` (tension: 300, friction: 20) — friction 차이 |
| `FloatingActionButton.tsx` | friction: 5, tension: 120 | `MOTION.spring.gentle` (tension: 120, friction: 14) — friction 차이 |
| `ReactionBar.tsx` | 3/300, 4/200, 5/120 (3종) | quick, bouncy, gentle — 모두 friction 불일치 |
| `PostCard.tsx` | 8/200, 4/150 (2종) | bouncy (8/200 일치) + 비표준 (4/150) |
| `SortTabs.tsx` | 7/180 | 비표준 — gentle과 bouncy 사이 |

**문제**: friction 값이 대부분 MOTION 프리셋과 다름.

**해결 방안 (2단계 접근):**
```typescript
// 1단계 (이번 Release): 기존 하드코딩 값을 그대로 상수화
// shared/constants.ts — MOTION 프리셋을 실제 사용값으로 맞춤
export const MOTION = {
  spring: {
    gentle:  { tension: 120, friction: 14 },
    bouncy:  { tension: 200, friction: 8 },
    quick:   { tension: 300, friction: 20 },
    // 실제 컴포넌트 하드코딩 값 기반 추가
    button:  { tension: 300, friction: 8 },   // Button.tsx 실제 값
    fab:     { tension: 120, friction: 5 },   // FloatingActionButton.tsx 실제 값
    card:    { tension: 200, friction: 8 },   // PostCard.tsx 실제 값
    cardAlt: { tension: 150, friction: 4 },   // PostCard.tsx 두 번째 값
    tab:     { tension: 180, friction: 7 },   // SortTabs.tsx 실제 값
  },
  // ...
} as const;

// 2단계 (별도 디자인 QA 후): 유사 값끼리 통합
// button(300/8) ≈ quick(300/20) → 디자인 QA에서 체감 비교 후 결정
```

**적용 대상**: Button, FloatingActionButton, ReactionBar, PostCard, SortTabs (6파일)
**핵심**: 값을 바꾸지 않고 상수로 추출만 → 애니메이션 체감 변화 없음

#### 14b. 아이콘/그림자 색상 중앙화 (H8)

**현황**: 15+곳에서 Ionicons 색상, shadowColor가 하드코딩.

**대표 패턴:**
```typescript
// 현재 (반복 산재)
color={isDark ? '#FFDB66' : '#997500'}  // ScreenHeader
color={isDark ? '#D6D3D1' : '#78716C'}  // search.tsx (4곳)
color={isDark ? '#78716C' : '#A8A29E'}  // search.tsx (3곳)
shadowColor: isDark ? '#FFC300' : '#997500' // Button, PostCard
```

**해결 방안 — `useThemeColors()` 확장:**
```typescript
// useThemeColors.ts에 추가
export function useThemeColors() {
  const isDark = useColorScheme() === 'dark';
  return {
    // 기존 반환값...
    icon: {
      primary: isDark ? '#FFDB66' : '#997500',      // happy 계열
      secondary: isDark ? '#D6D3D1' : '#78716C',    // stone 강조
      muted: isDark ? '#78716C' : '#A8A29E',         // stone 약
      destructive: isDark ? '#FF8F85' : '#FF7366',   // coral 계열
    },
    shadow: {
      primary: isDark ? '#FFC300' : '#997500',       // happy 계열
      muted: isDark ? '#000000' : '#9CA3AF',         // 기본 그림자
    },
  };
}
```

**적용 대상**: ScreenHeader, PostDetailHeader, search.tsx, Button, FloatingActionButton, PostCard (8+파일)

#### 14c. 임의 폰트 크기 표준화 (M13)

**현황**: Tailwind 표준 대신 `text-[Xpx]` 사용 4곳.

| 파일 | 현재 | 표준 매핑 |
|---|---|---|
| `SortTabs.tsx:76` | `text-[13px]` | `text-xs` (12px) — 1px 차이, xs로 통일 |
| `PostCard.tsx:97` | `text-[17px]` | `text-base` (16px) 또는 Tailwind 확장 |
| `ErrorView.tsx:51` | `text-[15px]` | `text-sm` (14px) — 1px 차이 |
| `SearchResultCard.tsx:47` | `text-[17px]` | `text-base` (16px) 또는 Tailwind 확장 |

**해결 방안:**
- `text-[13px]` → `text-xs`
- `text-[15px]` → `text-sm`
- `text-[17px]` → `tailwind.config.js`에 `fontSize: { md: '17px' }` 확장 (PostCard 제목은 의도적으로 약간 큰 사이즈)

#### 14d. 접근성 보강 (L10, L12)

**리액션 버튼 hint (L10):**
```typescript
// ReactionBar.tsx — 현재
accessibilityLabel={`${type} 리액션`}
// 수정
accessibilityLabel={`${type} 리액션${user_reacted ? ' (선택됨)' : ''}`}
accessibilityHint="탭하면 리액션을 토글합니다"
```

**터치 타겟 크기 (L12):**
```typescript
// PostDetailHeader.tsx:48 — 현재
className="w-10 h-10 ..."
// 수정 (44pt 최소 달성)
className="w-11 h-11 ..."
```

#### 14e. 기타 개선 (L11, L13)

**EmptyState 버튼 (L11)**: 인라인 `Pressable` → `<Button variant="primary" size="sm">` 사용.

**expo-image 마이그레이션 (L13)**: `package.json`에 `expo-image` 설치됨 (`line 49`)이나 미사용.
PostCard의 `<Image>` → `<Image>` (from `expo-image`) 전환 시 자동 캐싱/최적화 확보.
> ⚠️ expo-image API 호환성 확인 필요 (resizeMode → contentFit 등).

---

### Phase 15: 웹 디자인/접근성 (H9, M10-M14, L14-L17)

> 코드 조사: 2026-03-08 | 웹 레포 전수 조사 기반

#### 15a. prefers-reduced-motion 지원 (H9, L17)

**현황**: `globals.css`에 5+개 애니메이션 (@keyframes) 정의, `prefers-reduced-motion` 미디어 쿼리 전무.
`view-transition.ts`도 모션 선호도 미확인.

**globals.css에 추가:**
```css
/* 모션 감소 선호 사용자 — 모든 애니메이션 비활성화 */
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

**view-transition.ts 수정:**
```typescript
function supportsViewTransitions(): boolean {
  if (typeof document === 'undefined') return false;
  if (!('startViewTransition' in document)) return false;
  // prefers-reduced-motion 존중
  if (typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches) return false;
  return true;
}
```

#### 15b. 접근성 강화 (M10, M11, L15)

**EmotionCalendar 셀 (M10):**
```typescript
// 현재: <div title="..." style={...}> — 키보드/스크린리더 불가
// 수정: button 요소 + aria-label
<button
  onClick={() => onDayClick?.(day)}
  aria-label={`${day.day}: ${day.post_count}개 글, ${day.emotions?.[0] ?? '감정 없음'}`}
  style={{ width: 14, height: 14, borderRadius: 2, backgroundColor: ... }}
/>
```

**AdminSecretTap (M11):**
```typescript
// 현재: <span onClick={...} style={{ cursor: 'pointer' }}>
// 수정: button 요소 + 키보드 지원
<button
  onClick={handleClick}
  className="bg-transparent border-none p-0 cursor-default"
  aria-label="앱 정보"
  tabIndex={0}
>
```

**RichEditor 툴바 (L15):**
```typescript
// 현재: title="Bold" — 스크린리더 미인식
// 수정:
<button
  aria-label="굵게"
  aria-pressed={editor.isActive('bold')}
  onClick={() => editor.chain().focus().toggleBold().run()}
>
```

#### 15c. ~~인라인 gradient → CSS 변수 전환 (M12)~~ — 제외 (리뷰 반영)

> **제외 근거**: 현재 작동하는 코드의 대규모 리팩토링 (신규 파일 + globals.css 수정 + 10곳 리팩토링).
> 비용 대비 효과 낮음. 신규 코드에만 적용하고, 기존 코드는 점진적 마이그레이션 권장.

**현황**: 10+곳에서 인라인 `style={{ background: 'linear-gradient(...)' }}` 사용.

**대표 파일**: PostCard, PostDetailView, EmotionWave, MoodSelector, EmotionFilterBar, CommunityPulse, EmotionCalendar

**해결 방안 — CSS 변수 + 유틸 함수:**
```typescript
// lib/emotion-styles.ts (신규)
import { EMOTION_COLOR_MAP } from '@/lib/constants.generated';

/** 감정 gradient CSS 변수 생성 */
export function emotionGradientStyle(emotion: string | undefined) {
  if (!emotion) return undefined;
  const colors = EMOTION_COLOR_MAP[emotion];
  if (!colors) return undefined;
  return {
    '--emotion-gradient-from': colors.gradient[0],
    '--emotion-gradient-to': colors.gradient[1],
  } as React.CSSProperties;
}
```

```css
/* globals.css */
.emotion-gradient {
  background: linear-gradient(
    135deg,
    var(--emotion-gradient-from, transparent),
    var(--emotion-gradient-to, transparent)
  );
}
```

```tsx
// PostCard.tsx — 적용 예시
<div
  className="emotion-gradient h-1 rounded-full"
  style={emotionGradientStyle(post.emotions?.[0])}
/>
```

#### 15d. scrollbar CSS 클래스 정의 (M14)

**현황**: `scrollbar-none`, `scrollbar-hide` 클래스 사용되나 정의 없음.

**globals.css에 추가:**
```css
/* 스크롤바 숨김 유틸리티 */
.scrollbar-none::-webkit-scrollbar,
.scrollbar-hide::-webkit-scrollbar {
  display: none;
}
.scrollbar-none,
.scrollbar-hide {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
```

#### 15e. 기타 개선 (L16) — L14(PostCard memo) 제외

> **PostCard memo (L14) 제외 근거**: 14건 게시글에서 성능 차이 없음. 시기상조.

**z-index 스케일 문서화 (L16):**
| 레이어 | z-index | 용도 |
|---|---|---|
| 콘텐츠 | z-0 (기본) | 페이지 콘텐츠 |
| Badge | z-10 | Avatar badge |
| Indicator | z-[1] | SortTab indicator |
| ScrollToTop | z-40 | 스크롤 버튼 |
| Header/BottomNav | z-50 | 고정 내비게이션 |
| Dialog/Popover | z-50 | 모달/드롭다운 |

> Dialog와 Header가 같은 z-50 → Dialog는 Portal로 렌더링되므로 DOM 순서로 우선. 현재 충돌 없음.
> z-index 스케일을 `globals.css` 주석 또는 별도 문서에 기록.

---

## 4. 변경 파일 목록

### 중앙 레포 (7파일)
| 파일 | 작업 | Phase |
|---|---|---|
| `shared/constants.ts` | ANALYSIS_STATUS, ANALYSIS_CONFIG, VALIDATION 추가 + MOTION.spring 프리셋 보완 | 2, 14a |
| `shared/utils.ts` | validatePostInput, validateCommentInput 추가 | 2 |
| `docs/SCHEMA.md` | 마이그레이션 18-22, RPC, RLS, 제약조건 갱신 | 8 |
| `scripts/verify.sh` | Edge Function 감정 상수 + utils + palette 검증 추가 | 7b, 11c |
| `supabase/migrations/20260317000001_post_analysis_rls.sql` | post_analysis RLS 강화 (신규) | 6a |
| `supabase/migrations/20260317000002_reactions_rls_cleanup.sql` | reactions 쓰기 RLS 제거 (신규) | 6c |
| `supabase/migrations/20260318000001_boards_constraints.sql` | boards CHECK 제약조건 (신규) | 12a |
| `CLAUDE.md` | 마이그레이션 23, RLS 변경 반영 | 8 |
| `.gitignore` | `.env.local` 추가 (CI/CD 도입 시) | 11b |

### 앱 레포 (22파일)
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
| `src/shared/components/Button.tsx` | MOTION.spring 상수 적용 + shadow 색상 중앙화 | 14a, 14b |
| `src/shared/components/FloatingActionButton.tsx` | MOTION.spring 상수 적용 + shadow 색상 중앙화 | 14a, 14b |
| `src/features/posts/components/ReactionBar.tsx` | MOTION.spring 상수 적용 + accessibilityHint 추가 | 14a, 14d |
| `src/features/posts/components/PostCard.tsx` | MOTION.spring 상수 적용 + text-[17px] 표준화 | 14a, 14c |
| `src/shared/components/SortTabs.tsx` | MOTION.spring 상수 적용 + text-[13px] 표준화 | 14a, 14c |
| `src/shared/hooks/useThemeColors.ts` | icon/shadow 색상 반환값 확장 | 14b |
| `src/shared/components/ScreenHeader.tsx` | useThemeColors().icon 사용 | 14b |
| `src/features/posts/components/PostDetailHeader.tsx` | useThemeColors().icon 사용 + 터치 타겟 44pt | 14b, 14d |

### 웹 레포 (10파일 — 15c/15e 제외)
| 파일 | 작업 | Phase |
|---|---|---|
| `next.config.ts` | 보안 헤더 + CSP 추가 | 4 |
| `src/features/posts/api/postsApi.ts` | 에러 로깅 컨텍스트 추가 (10곳) + logger import | 5a |
| `sentry.server.config.ts` | userId PII 필터 추가 | 5b |
| `src/lib/view-transition.ts` | 타입 안전 캐스트 + prefers-reduced-motion 체크 | 12b, 15a |
| `package.json` | npm audit fix | 1b |
| `src/app/globals.css` | prefers-reduced-motion 미디어 쿼리 + scrollbar 유틸 | 15a, 15d |
| `src/features/posts/components/EmotionCalendar.tsx` | div → button, aria-label 추가 | 15b |
| `src/components/layout/AdminSecretTap.tsx` | span → button, 키보드 접근성 | 15b |
| `src/features/posts/components/RichEditor.tsx` | aria-label, aria-pressed 추가 | 15b |
| ~~`src/features/posts/components/PostCard.tsx`~~ | ~~memo 적용~~ | ~~15e~~ **제외** |
| ~~`src/lib/emotion-styles.ts`~~ | ~~감정 gradient CSS 변수 헬퍼~~ | ~~15c~~ **제외** |
| ~~`src/features/posts/components/PostDetailView.tsx`~~ | ~~인라인 gradient → CSS 변수~~ | ~~15c~~ **제외** |

---

## 5. 구현 순서 (Release 단위 — 리뷰 반영)

> Phase가 아니라 **Release로 관리**. 각 Release가 독립적으로 배포/롤백 가능.
> 원칙: 보안 먼저 → 변경 최소화 → 배포 단위로 사고 → 테스트는 위험 기반

```
━━━ Release 1: 보안/안정성 (Day 1) ━━━
1. npm audit fix + Expo 55 업그레이드 (앱) — Phase 1a
2. npm audit fix (웹) — Phase 1b
3. post_analysis RLS 강화 — Phase 6a
4. reactions 쓰기 RLS 제거 — Phase 6c
5. 웹 보안 헤더 + CSP — Phase 4
6. Sentry PII 필터 — Phase 5b
   → DB 마이그레이션 2개(분리) + 앱/웹 각 1커밋
   → 배포 + 24시간 모니터링

━━━ Release 2: 코드 품질 (Day 2-3) ━━━
6. 중앙 shared 상수/유틸 보강 — Phase 2a/2b
7. 앱 API 에러 처리 통일 — Phase 3
8. 웹 API 에러 로깅 — Phase 5a
9. ESLint 수정 — Phase 7a
10. verify.sh 보강 — Phase 11c (격상)
11. Edge Function 검증 스크립트 — Phase 7b
    → sync + 테스트 + 배포

━━━ Release 3: 문서/스크립트 (Day 3) ━━━
12. SCHEMA.md 갱신 — Phase 8
    → 중앙 레포만 커밋

━━━ Release 4: DB 제약조건 + 타입 (Day 4) ━━━
13. boards CHECK 제약조건 — Phase 12a
14. view-transition.ts 타입 — Phase 12b
    → DB 마이그레이션 1개(독립) + 웹 1커밋

━━━ Release 5: 디자인/접근성 (Week 2) ━━━
15. 앱 MOTION 상수화 (값 변경 없이) — Phase 14a 수정
16. 앱 아이콘/그림자 색상 중앙화 — Phase 14b
17. 앱 임의 폰트 크기 표준화 — Phase 14c
18. 웹 prefers-reduced-motion — Phase 15a
19. 웹 접근성 (button 전환) — Phase 15b
20. 웹 scrollbar CSS — Phase 15d
    → 앱/웹 각 1커밋 (독립 배포 가능)

━━━ Backlog (조건부) ━━━
- 앱 테스트 확장: 위험 기반 Tier 0-1만 우선 (Phase 10 + v2 B 통합)
- 검색 최적화: 5,000건+ 시 (Phase 13)
- PGroonga: 검색 품질 피드백 시 (v2 Phase E)
- nonce CSP: Vercel Pro 전환 시 (v2 Phase C)
- 디자인 토큰 문서: 팀 확장 시 (v2 Phase F)
```

### 변경 근거 요약 (리뷰 반영)

| 변경 | 이유 |
|---|---|
| Expo 55 → Release 1 포함 | JS breaking change 없음, jest-expo CRITICAL 취약점 해결 경로 명확화 |
| Phase 11c 격상 → Release 2 | verify.sh는 사실상 유일한 통합 테스트, sync 정합성 보장 |
| Phase 14a 수정 | friction 값 변경은 UX 회귀 위험, 값 유지하며 상수화만 |
| Phase 15c(gradient) 제외 | 현재 작동하는 코드의 대규모 리팩토링, ROI 낮음 |
| Phase 15e(PostCard memo) 제외 | 14건 게시글에서 성능 차이 없음 |
| Phase 10 + v2 B 통합 | 위험 기반으로 재구성, 7주 → 2주 핵심만 |
| DB 마이그레이션 3개 분리 | 롤백 단위 축소, 원인 특정 용이 |

### Release별 배포 체크리스트

#### Release 1 배포 체크리스트
- [ ] **사전**: 웹 SSR 경로별 Supabase 클라이언트 패턴 확인 (anon key vs service_role_key)
- [ ] DB 마이그레이션 dry-run 확인
- [ ] DB 마이그레이션 push — `20260317000001_post_analysis_rls.sql`
- [ ] DB 마이그레이션 push — `20260317000002_reactions_rls_cleanup.sql`
- [ ] 앱: Expo 55 업그레이드 (`npm install expo@~55.0.5 jest-expo@~55.0.9 babel-preset-expo@^55.0.10`)
- [ ] 앱: `npm test` 통과 + `npm start` Metro 확인 → push → OTA 배포
- [ ] 웹: `next build` 성공 확인 → push → Vercel 배포
- [ ] 롤백 계획: RLS 정책 복원 SQL 준비
- [ ] 모니터링: Sentry 대시보드 24시간 관찰, 그루핑 변경 시 Fingerprint Rules 조정

#### Release 2 배포 체크리스트
- [ ] shared/constants.ts, shared/utils.ts 수정 → sync
- [ ] 앱: `npm test` 통과
- [ ] 웹: `next build` 성공
- [ ] 앱/웹 커밋 → push → 배포
- [ ] **배포 후 1주**: Sentry 월간 쿼터 사용량 확인 (2,500건 이하 정상)

#### Release 4 배포 체크리스트
- [ ] DB 마이그레이션 dry-run 확인
- [ ] DB 마이그레이션 push — `20260318000001_boards_constraints.sql`
- [ ] 기존 boards 데이터가 제약조건 충족하는지 확인

---

## 6. 누락 항목 (리뷰에서 식별)

| 누락 | 영향 | 권장 |
|---|---|---|
| **에러 모니터링 기준선** | Phase 3/5에서 에러 처리 변경 시 Sentry 그루핑이 바뀜 | 배포 후 대시보드에서 그루핑 확인, 필요 시 Fingerprint Rules 조정 (무료 플랜에서 가능) |
| **성능 기준선** | Phase 13에서 "5,000건+ 시 최적화"라 했지만, 현재 검색 응답 시간 기록 없음 | `EXPLAIN ANALYZE`로 현재 쿼리 성능 기록 |
| **웹 SSR 경로별 RLS 영향 분석** | Phase 6a에서 "웹은 service_role_key 사용"이라 했지만, 모든 SSR 경로가 그런지 미확인 | 웹 레포의 Supabase 클라이언트 생성 패턴 전수 조사 |
| **shared/constants.ts 크기 관리** | Phase 2a에서 ANALYSIS_STATUS, ANALYSIS_CONFIG, VALIDATION을 추가하면 계속 비대해짐 | 도메인별 분리 기준 설정 (예: 200줄 초과 시 `constants/analysis.ts` 등으로 분리) |

예상 변경: **중앙 7파일, 앱 20파일, 웹 10파일** + DB 마이그레이션 3개(분리)

---

## 6. 범위 외 (향후 과제)

| 항목 | 상세 | 트리거 | 예상 노력 | 상태 |
|---|---|---|---|---|
| Expo 55 업그레이드 | expo 54→55, JS breaking change 없음 | ✅ 승인됨 | 낮음 (30분) | v2 Phase A |
| Hook/컴포넌트 테스트 | Feature hooks 25개 + 컴포넌트 25개 | ✅ 승인됨 | 중간 (7주) | v2 Phase B |
| Next.js nonce CSP | `unsafe-inline` 제거, nonce 기반 | Vercel Pro 전환 시 | 중간 | v2 Phase C |
| 한국어 검색 (PGroonga) | PGroonga extension ✅ 활성, search_posts_v3 설계 완료 | 검색 피드백 시 | 중간 | v2 Phase E |
| ~~RLS 재귀 패턴 통일~~ | ~~posts/comments RLS의 EXISTS → is_group_member()~~ | - | - | ✅ v2 Phase D에서 이미 완료 확인 |
| 디자인 토큰 문서화 | 타이포그래피 스케일, 간격, 애니메이션 토큰 정리 | 팀 확장 시 | 낮음 | v2 Phase F |
| Storybook / 컴포넌트 문서 | 공유 컴포넌트 시각 카탈로그 | 팀 확장 시 | 중간 | v2 Phase F |

> Phase 10-13에 편입된 항목(L1~L9)은 위 목록에서 제거됨.
> Phase 14-15에 편입된 항목(H7~H9, M10~M14, L10~L17)은 위 목록에서 제거됨.
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
