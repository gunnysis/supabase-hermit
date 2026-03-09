# 개발 책임자 리뷰 — v1/v2/v3 유지보수 설계 분석

> 초판: 2026-03-09 | v1 (Phase 1-15) + v2 (Phase A-F) 전체 분석
> **2차 리뷰: 2026-03-09 | 리뷰 반영 후 expected/ 문서 재분석 + 구현 판단 + 설계 개선**
> **3차 현행화: 2026-03-09 | Sentry 무료 유지 결정 반영 (사용자 1명 → 사전 업그레이드 불필요)**
> 관점: 개발 책임자 + 구현 실무자 (Claude 전권 위임 기반)
> 대상: `docs/plan/expected/` — v1, v2, v3 (실행 계획서)

---

## 1. 리뷰 반영 검증 — 5대 우려사항 해소 상태

### 1a. 반영 결과 평가

| # | 우려 | 반영 상태 | 판정 | 잔여 리스크 |
|---|---|---|---|---|
| C1 | Phase 과부하 | ✅ **해소** — 5 Release + Backlog 재구성, 체크박스 진행표 추가 | 적절 | 없음 |
| C2 | ROI 불균형 | ✅ **해소** — 15c/15e 제외, 14a 값 유지 원칙, 11c 격상 | 적절 | §2a 참조 |
| C3 | 릴리스 전략 부재 | ✅ **해소** — 마이그레이션 3개 분리, 배포 체크리스트, 롤백 SQL | 적절 | §2b 참조 |
| C4 | 테스트 전략 | ✅ **해소** — 위험 기반 Tier 0-1 (2주), Done 기준 명시 | 적절 | 없음 |
| C5 | 문서 유지보수 | ✅ **해소** — Release별 체크박스, v3 실행 문서 분리 | 적절 | 없음 |

### 1b. 추가 개선 — Expo 55 / Sentry / 비용 통합

리뷰 이후 사용자 피드백으로 추가 반영된 3건:

| 항목 | 초판 리뷰 판단 | 반영 결과 | 평가 |
|---|---|---|---|
| Expo 55 "범위 외" → 구체 계획 | Backlog으로 분류 | **R1에 통합** — JS breaking change 없음 확인, 30분 작업 | **좋은 판단** — jest-expo CRITICAL 취약점 체인 해소도 겸함 |
| Sentry 플랜 정보 부재 | 언급 없음 | **§2.4 추가** — Developer 무료 유지 + 조건부 업그레이드 기준 | **필요했던 정보** — 쿼터 관리 기준 명확화 |
| 비용 준비 복잡 | 4단계 조건부 | **단순화** — 사용자 1명, Developer 무료 유지. 사전 비용 결정 없음 | **현실적** — 불필요한 비용 제거 ($26/mo 절약) |

---

## 2. 구현 관점 심층 분석 — expected/ 문서 재평가

### 2a. Release 1 구현 판단

**보안/안정성 Release — 가장 중요, 가장 위험**

| 항목 | 설계 품질 | 구현 시 주의 | 판단 |
|---|---|---|---|
| npm audit (앱/웹) | 우수 — 단계적 접근, devDeps 분리 | transitive dependency 해결 안 되면 overrides 필요. `--force` 사용 시 peer dep 충돌 주의 | **실행 가능** |
| Expo 55 | 우수 — breaking changes 전수 분석 | Metro 번들러 캐시 초기화 필요할 수 있음 (`npx expo start -c`) | **실행 가능** |
| post_analysis RLS | 우수 — 영향 분석 3곳 완료 | **⚠️ SSR 전수 조사 필수** — v3 조사 1에서 커버하지만, 조사 결과에 따라 코드 수정 추가 | **조건부 실행** |
| reactions RLS 제거 | 우수 — SECURITY DEFINER 우회 확인 | DROP만이므로 안전. 단, 혹시 직접 INSERT하는 레거시 코드가 없는지 앱/웹 `user_reactions` 검색 필요 | **실행 가능** |
| 보안 헤더 | 양호 — CSP 도메인 정확 | `unsafe-eval` 필요 여부 재확인 — Next.js 16에서 제거 가능할 수 있음. 빌드 후 콘솔 에러 확인 | **실행 가능** |
| Sentry PII 필터 | 단순 — regex 1줄 추가 | 즉시 실행 | **실행 가능** |

**구현 순서 최적화 (설계 개선)**:
```
1. 조사 1 (SSR 패턴) → 결과에 따라 6a 조정
2. 조사 2 (npm audit 현황) → 최신 취약점 확인
3. DB 마이그레이션 2개 push (6a, 6c)
4. 앱: npm audit + Expo 55 (병렬 가능)
5. 웹: npm audit + 보안 헤더 + PII (병렬 가능)
6. 3개 레포 커밋 + 배포
```

> **개선점**: 4, 5를 병렬 실행하면 Day 1 완료 가능. 설계 문서에서도 병렬 가능으로 기술되어 있으나 순차 표기 — 구현 시 병렬 활용.

### 2b. Release 2 구현 판단

**코드 품질 Release — 가장 파일 수 많음, 동기화 의존성 주의**

| 항목 | 설계 품질 | 구현 시 주의 | 판단 |
|---|---|---|---|
| ANALYSIS_STATUS/CONFIG | 우수 — 7곳 매핑 정확 | sync 후 앱의 import 경로가 `constants.generated.ts`에서 `constants.ts` barrel을 거쳐야 함. 직접 import하면 sync 시 경로 깨짐 | **실행 가능** |
| validatePostInput | 양호 — 순수 함수 | **⚠️ Zod 이중 검증** — 조사 4에서 Zod 스키마 확인 필수. 있으면 validatePostInput은 서버 fallback 용도로 한정 | **조건부** |
| helpers.ts 추출 | 양호 — 리뷰 의견 반영 | `api/` 디렉터리에 5개 파일 + helpers.ts = 합리적. 단, helpers가 1함수만이면 posts.ts named export가 더 간결 | **실행 가능** |
| 에러 처리 통일 | 양호 — 표준 패턴 명확 | **Sentry 그루핑 변경** — Fingerprint Rules로 조정 (무료 플랜에서 가능) | **실행 가능** |
| verify.sh 보강 | 우수 — 격상 판단 적절 | bash grep 패턴이 constants.ts 구조 변경에 취약 — JSON 파싱이 아닌 grep이므로 false positive 가능 | **실행 가능, 로버스트 확인** |
| Edge Function 검증 | 양호 | `grep -oP`는 macOS에서 지원 안 함 — WSL 전용이면 OK, 범용이면 `grep -oE` 사용 | **환경 의존 주의** |

**숨겨진 위험 식별**:

1. **sync 순서 의존성**: shared/constants.ts 수정 → sync → 앱에서 import → 빌드. sync 전에 앱을 빌드하면 실패. v3에서 순서가 명확하나, 병렬 실행 시 주의.

2. **ESLint 수정 (search.tsx)**: `firstPageLength` 변수 추출 시 `useMemo` 또는 `useCallback` 필요 여부 검토 — React strict mode에서 불필요한 리렌더 가능성.

### 2c. Release 3-4 구현 판단

| 항목 | 판단 | 비고 |
|---|---|---|
| SCHEMA.md 갱신 | **실행 가능** — 기계적 작업 | v3에서 마이그레이션 수를 "24개"로 기술했지만, 실제 22+2(R1) = 24개 정확 |
| CLAUDE.md 갱신 | **실행 가능** | Release별 완료 후 즉시 갱신하는 습관 (문서화 규칙에 명시됨) |
| boards CHECK | **실행 가능** — 기존 데이터 1건, 안전 | `IF NOT EXISTS` 패턴은 CHECK에 적용 불가 — 이미 존재하면 에러. 멱등성을 위해 `DO $$ BEGIN ... EXCEPTION WHEN duplicate_object THEN NULL; END $$` 래핑 권장 |
| view-transition 타입 | **실행 가능** | `as any` → `as unknown as DocumentWithViewTransition`은 더 안전하지만, View Transitions API가 표준화되면 타입 자체가 불필요해짐. 주석으로 명시 |

**설계 개선 — boards CHECK 멱등성**:
```sql
-- 현재 설계
ALTER TABLE public.boards
  ADD CONSTRAINT boards_description_length
  CHECK (description IS NULL OR char_length(description) <= 500);

-- 개선: 멱등성 확보
DO $$ BEGIN
  ALTER TABLE public.boards
    ADD CONSTRAINT boards_description_length
    CHECK (description IS NULL OR char_length(description) <= 500);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
```

### 2d. Release 5 구현 판단

**디자인/접근성 — 가장 광범위, UX 회귀 위험**

| 항목 | 설계 품질 | 구현 시 주의 | 판단 |
|---|---|---|---|
| MOTION 상수화 | **개선됨** — 값 변경 금지 원칙 확립 | 5개 신규 프리셋(button, fab, card, cardAlt, tab)이 실제 하드코딩 값과 정확히 일치하는지 구현 시 재확인 | **실행 가능** |
| useThemeColors 확장 | 양호 | `icon`/`shadow` 키 추가 시 타입 확장 필요. 기존 소비자 코드에 영향 없음 (optional 필드) | **실행 가능** |
| 폰트 크기 표준화 | 양호 | `text-[17px]` → `text-md` 확장은 tailwind.config.js 수정 필요. NativeWind 호환 확인 | **실행 가능** |
| prefers-reduced-motion | 우수 — 접근성 필수 | `@media (prefers-reduced-motion: reduce)` + `transition: none !important` 패턴. view-transition.ts에도 `matchMedia` 추가 | **실행 가능** |
| button 전환 (접근성) | 우수 | EmotionCalendar 셀의 div→button은 스타일 리셋 필요 (`appearance: none`, 패딩/마진 초기화) | **실행 가능** |
| scrollbar CSS | 단순 | `.scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }` + webkit pseudo | **실행 가능** |

**숨겨진 위험**:
- MOTION 상수 적용 후 앱에서 애니메이션 체감이 미묘하게 바뀌지 않는지 시각 확인 필요
- button 전환 시 기존 CSS가 div 기반이면 button 기본 스타일과 충돌 가능

---

## 3. v3 실행 계획서 설계 품질 리뷰

### 3a. 강점

| 항목 | 평가 |
|---|---|
| **자율 판단 원칙 4개** | 명확하고 실행 가능. 특히 "실패 시 자체 해결, 막힐 때만 보고"가 좋음 |
| **사전 조사 5건** | R1 착수 전 위험 제거 — SSR 패턴, npm audit, Sentry 쿼터 확인, Zod 관계, reactions 직접 접근 |
| **롤백 SQL 사전 준비** | 각 마이그레이션별 롤백 SQL 제공 — 장애 시 즉시 복원 가능 |
| **비용 단순화** | 사전 비용 결정 없음 — Developer 무료 유지, 조건부 업그레이드 |
| **보고 기준 5개** | 불필요한 보고 제거, 필요 시에만 — 자율 실행에 적합 |
| **변경 파일 요약** | 중앙 8+3, 앱 20, 웹 10 — 전체 스코프 가시화 |

### 3b. 개선 필요 항목

| 항목 | 문제 | 개선안 |
|---|---|---|
| **조사 1 실패 시 분기** | "anon key 경로 발견 → 수정 후 진행"이지만, 수정 범위가 클 수 있음 | 수정이 3파일 이상이면 별도 커밋으로 분리, 수정 내용을 needs.md에 기록 |
| **Expo 55 테스트 범위** | "npm test + npm start"만 기술 | OTA 배포 전 최소 검증: 로그인 → 글 목록 → 글 작성 → 리액션 동선 확인 추가 |
| **Release 간 대기** | "배포 후 24시간 모니터링"이 R1에만 있음 | R2(에러 처리 변경)도 최소 수시간 모니터링 필요 — Sentry 그루핑 변경 영향 |
| **verify.sh grep 패턴** | macOS 비호환 가능성 | WSL 전용이므로 현재 OK, 향후 이식 시 `grep -oE` 사용 주석 추가 |
| **tailwind.config.js 수정** | R5에서 `text-md: '17px'` 추가하지만 NativeWind 호환 미확인 | 구현 시 NativeWind 문서 확인 → 미지원이면 커스텀 유틸 클래스 사용 |

### 3c. 타임라인 현실성

```
설계: Day 0(30분) + Day 1 + Day 2-3 + Day 3 + Day 4 + Week 2
실제 예상: +20% 버퍼 → Day 0-5 + Week 2
```

| Release | 설계 예상 | 실제 예상 | 버퍼 사유 |
|---|---|---|---|
| R1 | Day 1 | Day 1-2 | SSR 조사 결과에 따라 추가 수정, Expo 55 Metro 캐시 이슈 가능 |
| R2 | Day 2-3 | Day 2-4 | 6파일 에러 처리 통일 + sync + 테스트가 예상보다 많음 (앱 7곳 + 웹 10곳) |
| R3 | Day 3 | Day 4 | SCHEMA.md 갱신은 기계적이지만 22→24 마이그레이션 반영 분량 큼 |
| R4 | Day 4 | Day 4-5 | boards CHECK 멱등성 처리 + view-transition 타입 |
| R5 | Week 2 | Week 2 | 디자인 변경은 시각 확인 필요 — 자동화 어려움 |

**결론**: 설계 타임라인은 낙관적이나 **허용 범위 내**. 20% 버퍼로 Day 5 + Week 2 완료 현실적.

---

## 4. 추가 연구 — 구현 시 발견 가능한 이슈

### 4a. shared/constants.ts 비대화 관리

**현황**: 117줄 → R2에서 +48줄(ANALYSIS) + R5에서 +15줄(MOTION) = **~180줄**

**판단**: 200줄 미만이므로 현재 분리 불필요. 단, 향후 기준:
- 200줄 초과 시 → `shared/constants/` 디렉터리로 분리
- 분리 시 barrel export (`shared/constants/index.ts`) 유지 → sync 스크립트 수정 필요
- 현재 sync는 `shared/constants.ts` 단일 파일 기준 → 디렉터리 전환 시 sync 대응 필요

**결론**: R2/R5에서는 단일 파일 유지. 분리는 Backlog 트리거.

### 4b. Edge Function과 shared 상수 동기화 한계

**문제**: Edge Function은 Deno 런타임 → 중앙 `shared/constants.ts` 직접 import 불가.
`VALID_EMOTIONS` 같은 상수가 Edge Function에 하드코딩되어 있고, verify.sh에서 grep 비교로 검증.

**개선안**:
1. Edge Function 배포 시 `shared/constants.ts`에서 값을 추출하여 `_shared/constants.ts` 자동 생성
2. 또는 verify.sh 검증으로 충분 (현재 접근) — grep 패턴이 깨지지 않도록 상수 형식 유지

**판단**: verify.sh 검증이 현실적. 자동 생성은 오버엔지니어링.

### 4c. CSP `unsafe-eval` 제거 가능성

**현재 설계**: `script-src 'self' 'unsafe-inline' 'unsafe-eval'`
**연구**: Next.js 16.1.6에서는 프로덕션 빌드 시 `unsafe-eval` 없이 작동할 수 있음.
- 개발 모드에서만 `unsafe-eval` 필요 (Fast Refresh)
- 프로덕션: webpack/turbopack 번들은 eval 미사용

**구현 시 판단**: R1 보안 헤더 적용 시 `unsafe-eval` 없이 빌드 → CSP 위반 에러 발생하는지 확인. 에러 없으면 제거.

### 4d. reactions RLS 제거 후 직접 접근 차단 검증

**우려**: reactions/user_reactions의 INSERT/UPDATE/DELETE 정책 제거 후, 혹시 RPC 외에 직접 INSERT하는 코드가 있으면 장애.

**검증 방법** (구현 전):
```bash
# 앱/웹에서 reactions/user_reactions 직접 조작 검색
grep -r "from('reactions')" --include="*.ts" --include="*.tsx" | grep -v "select\|test\|\.d\.ts"
grep -r "from('user_reactions')" --include="*.ts" --include="*.tsx" | grep -v "select\|test\|\.d\.ts"
```

만약 발견되면 → RPC 호출로 교체 후 RLS 제거.

---

## 5. 최종 구현 판정

### 5a. 즉시 실행 가능 (설계 충분)

| Release | 판정 | 조건 |
|---|---|---|
| R1 | ✅ **실행 가능** | 사전 조사 4건 완료 후 |
| R2 | ✅ **실행 가능** | R1 배포 후 안정 확인 |
| R3 | ✅ **실행 가능** | R2 완료 후 |
| R4 | ✅ **실행 가능** | boards CHECK 멱등성 래핑 추가 |
| R5 | ✅ **실행 가능** | 시각 확인 필요 (자동화 어려움) |

### 5b. 설계 개선 반영 사항 (구현 시 자율 적용)

| # | 개선 | 적용 시점 |
|---|---|---|
| I1 | boards CHECK 멱등성 `DO $$ BEGIN ... EXCEPTION` 래핑 | R4 마이그레이션 작성 시 |
| I2 | CSP `unsafe-eval` 제거 시도 → 실패 시 유지 | R1 보안 헤더 작성 시 |
| I3 | reactions 직접 조작 코드 검색 → 없으면 진행, 있으면 RPC 교체 | R1 사전 조사 확장 |
| I4 | Sentry 쿼터 모니터링 — 2,500건 초과 시 Rate Limiting 검토 | R2 배포 후 |
| I5 | R2 배포 후 Sentry 모니터링 수시간 (R1만이 아님) | R2 배포 후 |
| I6 | MOTION 상수 적용 후 앱 애니메이션 시각 확인 | R5 앱 배포 전 |
| I7 | NativeWind `text-md` 커스텀 호환 확인 | R5 폰트 표준화 시 |

### 5c. 리스크 매트릭스 (구현 시 발생 가능 이슈)

| 리스크 | 확률 | 영향 | 대응 |
|---|---|---|---|
| SSR에서 anon key로 post_analysis 조회 | 낮음 | 높음 (데이터 미표시) | 조사 1에서 사전 탐지, service_role로 교체 |
| Expo 55 Metro 번들러 캐시 문제 | 중간 | 낮음 | `npx expo start -c` 캐시 초기화 |
| npm audit fix로 peer dep 충돌 | 중간 | 중간 | `--legacy-peer-deps` 또는 overrides |
| Sentry 그루핑 대규모 변경 | 높음 | 낮음 | Fingerprint Rules 사전 설정 (무료 플랜 지원) |
| button 전환 시 CSS 충돌 | 중간 | 낮음 | `appearance: none` + 스타일 리셋 |
| shared/constants.ts sync 후 빌드 실패 | 낮음 | 중간 | barrel import 경로 확인, sync 후 즉시 빌드 테스트 |

---

## 6. 결론

### 6a. 초판 리뷰 대비 개선 사항

| 차원 | 초판 | 현재 (expected/) |
|---|---|---|
| 구조 | 21 Phase 혼재 | 5 Release + Backlog ✅ |
| 배포 | 전략 부재 | 체크리스트 + 롤백 SQL ✅ |
| ROI | 불균형 | 15c/15e 제외, 11c 격상 ✅ |
| 테스트 | 7주 과대 | 위험 기반 2주 ✅ |
| 비용 | 미고려 | Developer 무료 유지, 조건부 업그레이드 ✅ |
| 실행 | 설계만 | v3 자율 실행 계획서 ✅ |
| Expo 55 | "범위 외" | R1 통합 ✅ |

### 6b. 구현 판정

**모든 Release 실행 가능.** 설계 품질이 구현에 충분하며, §5b의 7개 설계 개선을 구현 시 자율 적용하면 된다.

### 6c. 핵심 원칙 (유지)

1. **보안 먼저** — R1은 무조건 즉시
2. **변경 최소화** — 작동하는 코드를 "예쁘게" 만드는 건 R5 이후
3. **배포 단위로 사고** — Phase가 아니라 Release로 관리
4. **테스트는 위험 기반** — 커버리지 숫자보다 실제 위험 커버
5. **문서는 실행을 위해** — 읽기 좋은 문서보다 실행 가능한 체크리스트
6. **자율 판단, 결과 책임** — 구현/디버깅/설계 전권, 문제 시 자체 해결
