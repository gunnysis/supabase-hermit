# 개발 책임자 리뷰 — v1/v2 유지보수 설계 분석

> 작성: 2026-03-09 | v1 (Phase 1-15) + v2 (Phase A-F) 전체 분석
> 관점: 개발 책임자로서의 판단, 구성 평가, 설계 품질 리뷰

---

## 1. 총평

### 1a. 강점

**조사 품질이 뛰어나다.** 3개 레포(중앙/앱/웹)를 전수 조사하여 H9개 + M14개 + L17개 = **총 40개 이슈**를 식별했고, 각각에 정확한 파일 위치(line 단위)와 코드 스니펫을 제시했다. 이 수준의 조사는 실무에서도 드물다.

**우선순위 분류가 합리적이다.** High/Medium/Low 3단계 + "범위 외" 분리는 적절하다. 특히 보안(Phase 1) → 공유 기반(Phase 2) → 개별 수정(Phase 3-7) → 문서(Phase 8) → 통합 검증(Phase 9) 순서는 의존성 그래프를 잘 반영한다.

**멱등성과 안전성을 일관 고려했다.** `DROP POLICY IF EXISTS`, `IF NOT EXISTS` 패턴, 영향 분석(앱/웹/Edge Function 각각 확인), npm audit의 단계적 접근 등 운영 안전성에 대한 인식이 좋다.

### 1b. 우려 사항

아래 5가지 구조적 문제를 식별했다. 각각의 상세 분석과 권장 사항을 이어서 기술한다.

| # | 우려 | 심각도 | 섹션 |
|---|---|---|---|
| C1 | Phase 과부하 — 15+6 = 21개 Phase가 단일 작업으로 혼재 | 높음 | §2 |
| C2 | ROI 불균형 — 일부 Phase의 비용 대비 효과가 낮음 | 중간 | §3 |
| C3 | 릴리스 전략 부재 — 배포 단위/롤백 계획 없음 | 높음 | §4 |
| C4 | 테스트 전략의 방향성 문제 | 중간 | §5 |
| C5 | 설계 문서 자체의 유지보수 비용 | 낮음 | §6 |

---

## 2. C1: Phase 과부하 — 재구성 제안

### 2a. 문제

v1의 15개 Phase와 v2의 6개 Phase는 규모와 성격이 극단적으로 다르다:

| Phase | 예상 작업량 | 성격 |
|---|---|---|
| Phase 1 (npm audit) | 10분 | 커맨드 1줄 |
| Phase 7a (ESLint) | 5분 | 라인 2개 수정 |
| Phase 14 (앱 디자인) | 수시간 | 8+파일, 25+곳 리팩토링 |
| Phase B (테스트 확장) | 7주 | 80+케이스 신규 작성 |

10분짜리와 7주짜리가 같은 "Phase"로 불리면 진행 상황 추적이 어렵고, 완료 기준이 모호해진다.

### 2b. 권장: 3-Tier 릴리스 단위로 재구성

실제 배포 가능한 **릴리스 단위**로 묶는 것이 실무적이다:

```
━━━ Release 1: 보안/안정성 (1일) ━━━
  Phase 1a/1b  npm audit fix (앱/웹 병렬)
  Phase 6a     post_analysis RLS 강화
  Phase 6c     reactions 쓰기 RLS 제거
  Phase 4      웹 보안 헤더
  Phase 5b     Sentry PII 필터
  → DB 마이그레이션 1개 + 앱/웹 각 1커밋

━━━ Release 2: 코드 품질 (1-2일) ━━━
  Phase 2a/2b  중앙 shared 상수/유틸 보강
  Phase 3      앱 API 에러 처리 통일
  Phase 5a     웹 API 에러 로깅
  Phase 7a     ESLint 수정
  Phase 7b     Edge Function 검증 스크립트
  → sync 후 앱/웹 각 1커밋

━━━ Release 3: 문서/스크립트 (반나절) ━━━
  Phase 8      SCHEMA.md 갱신
  Phase 11     verify.sh 보강
  → 중앙 레포만 커밋

━━━ Release 4: DB 제약조건 + 타입 (반나절) ━━━
  Phase 12a    boards CHECK 제약조건
  Phase 12b    view-transition.ts 타입
  → DB 마이그레이션 1개 + 웹 1커밋

━━━ Release 5: 디자인/접근성 (2-3일) ━━━
  Phase 14     앱 디자인 일관성
  Phase 15     웹 디자인/접근성
  → 앱/웹 각 1커밋 (독립 배포 가능)

━━━ Backlog (조건부) ━━━
  Phase 10     앱 테스트 확장
  Phase 13     검색 성능 최적화 (5,000건+)
  v2 Phase A   Expo 55
  v2 Phase B   Hook/컴포넌트 테스트
  v2 Phase C   nonce CSP
  v2 Phase E   PGroonga 검색
  v2 Phase F   디자인 토큰 문서화
```

**이점:**
- 각 Release가 독립적으로 배포/롤백 가능
- Release 1(보안)을 즉시 배포 → 나머지는 여유있게 진행
- 진행률이 "Release 2/5 완료"로 명확

---

## 3. C2: ROI 불균형 분석

### 3a. 높은 ROI (즉시 실행 권장)

| 항목 | 비용 | 효과 | 판단 |
|---|---|---|---|
| Phase 1 (npm audit) | 10분 | HIGH/CRITICAL 보안 취약점 해소 | **즉시 실행** |
| Phase 6a (post_analysis RLS) | SQL 5줄 | 비인증 메타데이터 노출 차단 | **즉시 실행** |
| Phase 6c (reactions RLS) | SQL 5줄 | RPC-only 정책 일관성 확보 | **즉시 실행** |
| Phase 4 (보안 헤더) | 코드 20줄 | 6개 보안 헤더 + CSP | **즉시 실행** |
| Phase 7a (ESLint) | 라인 2개 | CI 품질 경고 제거 | **즉시 실행** |

### 3b. 낮은 ROI (재고 필요)

| 항목 | 비용 | 효과 | 판단 |
|---|---|---|---|
| Phase 11b (.env.local 경로) | 스크립트 수정 | 1인 개발에서 이점 없음 | **보류 적절** (문서에서도 보류 판단) |
| Phase 12b (view-transition 타입) | 인터페이스 추가 | `as any` → 타입 안전, 하지만 기능 변화 없음 | **낮은 우선순위** |
| Phase 15c (gradient CSS 변수) | 신규 파일 + 10곳 리팩토링 | 미적 일관성, 하지만 현재 작동함 | **비용 대비 효과 낮음** |
| Phase 15e (PostCard memo) | 1줄 | 14건 게시글에서 성능 차이 없음 | **시기상조** |
| v2 Phase F (디자인 토큰 문서) | 문서 1개 | 1인 개발에서 참조할 사람 없음 | **보류 적절** |

### 3c. 숨겨진 비용이 큰 항목

| 항목 | 표면 비용 | 숨겨진 비용 | 권장 |
|---|---|---|---|
| Phase 14a (MOTION 상수 적용) | 6파일 수정 | **모든 애니메이션의 체감 변경** — QA 필요, friction 값 변경은 UX 회귀 위험 | 기존 하드코딩 값을 상수로 추출만 하고, 값 자체는 변경하지 않기 |
| Phase 2b (validatePostInput) | 순수 함수 2개 | 앱/웹에서 **기존 Zod 스키마와 이중 검증** 가능성 | Zod 스키마와의 관계 정리 필요 |
| Phase 3 (에러 처리 통일) | 6파일 | 에러 메시지 변경 → **Sentry 그루핑 재설정** 필요 | 점진적 배포, 기존 그룹 모니터링 |

---

## 4. C3: 릴리스 전략 부재

### 4a. 문제

문서에서 "Phase 9: 동기화 & 검증 & 배포"를 마지막에 모아놓았지만, 실제로는 Phase마다 배포 시점이 다르다:

- DB 마이그레이션 (Phase 6, 12) → **즉시 적용, 롤백 어려움**
- 앱 변경 (Phase 3, 7, 14) → **OTA 또는 네이티브 빌드**
- 웹 변경 (Phase 4, 5, 15) → **Vercel 자동 배포**
- 중앙 변경 (Phase 2, 8) → **sync 후 앱/웹에 전파**

### 4b. 권장: 배포 단위별 체크리스트

각 Release에 다음을 명시해야 한다:

```markdown
## Release 1 배포 체크리스트
- [ ] DB 마이그레이션 dry-run 확인
- [ ] DB 마이그레이션 push (자동 gen-types + sync)
- [ ] 웹: next build 성공 확인 → push → Vercel 배포
- [ ] 앱: npm test 통과 → push → OTA 배포
- [ ] 롤백 계획: RLS 정책 복원 SQL 준비
- [ ] 모니터링: Sentry 에러율 24시간 관찰
```

특히 **Phase 6 (RLS 변경)** 은 주의가 필요하다:
- `post_analysis SELECT`를 `auth.role() = 'authenticated'`로 변경하면, 만약 웹에서 서버 사이드 렌더링 시 anon key를 사용하는 경우가 있다면 **데이터가 안 보이게 된다**
- 문서에서 "웹은 service_role_key 사용"이라 했지만, 실제 코드를 배포 전에 반드시 확인해야 한다

### 4c. DB 마이그레이션 분리 권장

문서에서 Phase 6a(RLS) + Phase 6c(reactions) + Phase 12a(boards CHECK)를 하나의 마이그레이션에 넣으려 했지만:

```
20260317000001_rls_hardening.sql  ← Phase 6a + 6c + 12a 합본
```

이는 **롤백 단위가 너무 크다**. 권장:

```
20260317000001_post_analysis_rls.sql    ← Phase 6a만 (SELECT 정책 변경)
20260317000002_reactions_rls_cleanup.sql ← Phase 6c만 (쓰기 정책 제거)
20260318000001_boards_constraints.sql   ← Phase 12a (CHECK 추가, Release 4)
```

각 마이그레이션이 독립적이면 문제 발생 시 원인 특정이 쉽다.

---

## 5. C4: 테스트 전략 방향성

### 5a. v1 Phase 10 vs v2 Phase B 중복

v1 Phase 10은 "API 모듈 테스트 4개 추가 (20케이스)"를 다루고, v2 Phase B는 "Hook/컴포넌트 테스트 80케이스 추가"를 다룬다. 이 두 Phase의 관계가 불명확하다:

- v1 Phase 10은 Phase 3(에러 처리 통일) 이후 실행 → **수정 검증 테스트**
- v2 Phase B는 독립 실행 가능 → **커버리지 확장 테스트**

### 5b. 테스트 우선순위 재평가

현재 83케이스 → 163케이스 (50% 커버리지 목표)는 **1인 개발에서 유지보수 부담**이 될 수 있다.

**권장: 위험 기반 테스트 전략**

```
Tier 0 (필수): 돈/데이터에 직접 영향
  - toggle_reaction (돈은 아니지만 데이터 정합성)
  - soft_delete_post/comment (데이터 손실 방지)
  - useAuth (인증 실패 → 전체 앱 사용 불가)
  → 이 3개 Hook만 완전히 테스트해도 80% 위험 커버

Tier 1 (권장): 사용자 불만 직결
  - useCreatePost (글 작성 실패)
  - useBoardPosts (피드 안 보임)
  - usePostDetailAnalysis (이미 테스트 존재)

Tier 2 (여유 시): 품질 향상
  - 나머지 Hook/컴포넌트
```

v2 Phase B의 7주 로드맵(Tier 1-5 순차)보다, **위험 기반 Tier 0-1만 우선 구현**(2주)하고 나머지는 버그 발생 시 추가하는 것이 1인 개발에 현실적이다.

### 5c. E2E 테스트 부재

v1/v2 모두 **단위 테스트**에만 집중하고 있다. 그러나 이 프로젝트의 실제 위험은:
- Supabase RPC 호출이 정상 작동하는가?
- sync-to-projects.sh가 정확히 복사하는가?
- 마이그레이션 push 후 gen-types가 성공하는가?

이런 **통합 지점**은 단위 테스트로 잡을 수 없다. `verify.sh` 강화(Phase 11c)가 사실상 가장 ROI 높은 "테스트"인데, Low Priority로 분류되어 있다.

**권장:** Phase 11c(verify.sh 보강)를 Medium Priority로 격상하고, Phase 10(API 테스트)보다 먼저 실행.

---

## 6. C5: 설계 문서 자체의 유지보수

### 6a. 문제

v1 문서만 1,400+ 줄이다. v2까지 합치면 2,100+ 줄. 이 분량은:
- **구현하면서 참조하기 어렵다** — 스크롤해서 해당 Phase를 찾아야 함
- **완료 상태 추적이 문서 내 인라인 표시**(`✅ 완료`, `보류`)로만 되어 있어 전체 진행률 파악이 어려움
- **선행 설계 문서 5개가 아카이브**됐지만, v1이 그 내용을 "승계"하여 문서 간 추적이 필요

### 6b. 권장

1. **Phase별 체크박스 요약표**를 문서 최상단에 배치:
```markdown
## 진행 현황
- [x] R1-1: npm audit fix (앱)
- [x] R1-2: npm audit fix (웹)
- [ ] R1-3: post_analysis RLS
- [ ] R1-4: reactions RLS 제거
...
```

2. **구현 시 해당 Phase만 발췌**하여 작업하고, 완료 후 체크. 전체 문서를 매번 읽지 않아도 되는 구조.

3. **v2는 독립 문서로 유지**하되, v1 완료 후 v2의 "즉시 실행 가능" 항목만 v3(또는 maintenance-next)로 추출.

---

## 7. 항목별 설계 품질 리뷰

### 7a. 잘 설계된 항목

| 항목 | 이유 |
|---|---|
| Phase 2a (ANALYSIS_STATUS/CONFIG) | 매직넘버 7곳을 정확히 매핑, 앱/Edge Function 경계 고려 |
| Phase 6a (post_analysis RLS) | 영향 분석이 앱/웹/Edge 3곳 모두 확인 — 정확함 |
| Phase 4 (보안 헤더) | CSP 도메인 허용 목록이 실제 사용 서비스와 일치 |
| Phase 13a (2-stage CTE) | ts_headline 비용 분석이 정확, 트리거 조건(5,000건)이 합리적 |
| v2 Phase D (RLS 재귀) | 조사 후 "이미 완료, 작업 불필요" 결론 — 불필요한 작업을 만들지 않음 |
| v2 Phase E (PGroonga) | 5개 검색 엔진 비교가 공정, 단계적 로드맵이 현실적 |

### 7b. 보완이 필요한 항목

| 항목 | 문제 | 권장 |
|---|---|---|
| Phase 3a (helpers.ts 추출) | `posts.ts`에서 함수를 꺼내 `helpers.ts` 신규 파일 생성 — 파일 1개를 위한 디렉터리 생성은 과도 | `posts.ts` 내 유지하되 named export로 공유, 또는 기존 유틸 파일에 병합 |
| Phase 14a (MOTION 상수) | 기존 friction 값과 프리셋 값이 다른데, "프리셋 자체를 재조정"하겠다고 함 — **모든 애니메이션 체감이 바뀜** | 1단계: 기존 하드코딩 값을 그대로 상수화 (`MOTION.spring.button = {tension:300, friction:8}`), 2단계: 통일은 별도 디자인 QA 후 |
| Phase 15c (gradient CSS 변수) | 신규 파일(`emotion-styles.ts`) + globals.css 수정 + 10곳 리팩토링 — 현재 작동하는 코드를 대규모 변경 | 신규 코드에만 적용, 기존 코드는 점진적 마이그레이션 |
| v2 Phase B (테스트 7주) | 주차별 로드맵이 있지만 실제 완료 기준이 없음 | 각 Tier의 "Done" 기준 정의 (예: "Tier 1 완료 = 4 hooks, 8 케이스, npm test 통과") |
| v2 Phase C (nonce CSP) | TTFB 50ms → 200-400ms 성능 저하 인정하면서 설계를 상세히 기술 | 현 단계에서는 SRI hash 대안만 기록하고 상세 설계는 실행 결정 시 작성 |

### 7c. 빠진 항목

| 누락 | 영향 | 권장 |
|---|---|---|
| **에러 모니터링 기준선** | Phase 3/5에서 에러 처리를 변경하면 Sentry 대시보드가 리셋됨 | 변경 전 현재 에러율 스냅샷 기록, 변경 후 비교 |
| **성능 기준선** | Phase 13에서 "5,000건+ 시 최적화"라 했지만, 현재 검색 응답 시간 기록 없음 | `EXPLAIN ANALYZE`로 현재 쿼리 성능 기록 |
| **웹 SSR 경로별 RLS 영향 분석** | Phase 6a에서 "웹은 service_role_key 사용"이라 했지만, 실제로 모든 SSR 경로가 그런지 확인 필요 | 웹 레포의 Supabase 클라이언트 생성 패턴 전수 조사 |
| **shared/constants.ts 크기 관리** | Phase 2a에서 ANALYSIS_STATUS, ANALYSIS_CONFIG, VALIDATION을 추가하면 constants.ts가 계속 비대해짐 | 도메인별 분리 기준 설정 (예: 200줄 초과 시 `constants/analysis.ts` 등으로 분리) |

---

## 8. 최종 권장 실행 순서

개발 책임자로서의 판단을 반영한 **수정된 실행 순서:**

```
━━━ 즉시 (Day 1) ━━━
1. npm audit fix (앱/웹 병렬) — Phase 1
2. post_analysis RLS 강화 — Phase 6a
3. reactions 쓰기 RLS 제거 — Phase 6c
4. 웹 보안 헤더 + CSP — Phase 4
5. Sentry PII 필터 — Phase 5b
   → 배포 + 24시간 모니터링

━━━ 안정화 후 (Day 2-3) ━━━
6. 중앙 shared 상수/유틸 보강 — Phase 2a/2b
7. 앱 API 에러 처리 통일 — Phase 3
8. 웹 API 에러 로깅 — Phase 5a
9. ESLint 수정 — Phase 7a
10. verify.sh 보강 — Phase 11c (격상)
    → sync + 테스트 + 배포

━━━ 품질 개선 (Day 4-5) ━━━
11. SCHEMA.md 갱신 — Phase 8
12. Edge Function 검증 스크립트 — Phase 7b
13. boards CHECK 제약조건 — Phase 12a
14. view-transition.ts 타입 — Phase 12b
    → 배포

━━━ 디자인/접근성 (Week 2) ━━━
15. 앱 MOTION 상수화 (값 변경 없이) — Phase 14a 수정
16. 앱 아이콘/그림자 색상 중앙화 — Phase 14b
17. 웹 prefers-reduced-motion — Phase 15a
18. 웹 접근성 (button 전환) — Phase 15b
19. 웹 scrollbar CSS — Phase 15d
    → 배포

━━━ Backlog (조건부) ━━━
- 앱 테스트 확장: 위험 기반 Tier 0-1만 우선 (Phase 10 + v2 B 통합)
- 검색 최적화: 5,000건+ 시 (Phase 13)
- PGroonga: 검색 품질 피드백 시 (v2 Phase E)
- Expo 55: 다음 네이티브 빌드 시 (v2 Phase A)
- nonce CSP: Vercel Pro 전환 시 (v2 Phase C)
- 디자인 토큰 문서: 팀 확장 시 (v2 Phase F)
```

### 변경 근거 요약

| 변경 | 이유 |
|---|---|
| Phase 11c 격상 | verify.sh는 사실상 유일한 통합 테스트, sync 정합성 보장 |
| Phase 14a 수정 | friction 값 변경은 UX 회귀 위험, 값 유지하며 상수화만 |
| Phase 15c(gradient) 제외 | 현재 작동하는 코드의 대규모 리팩토링, ROI 낮음 |
| Phase 15e(PostCard memo) 제외 | 14건 게시글에서 성능 차이 없음 |
| Phase 10 + v2 B 통합 | 위험 기반으로 재구성, 7주 → 2주 핵심만 |
| DB 마이그레이션 분리 | 롤백 단위 축소, 원인 특정 용이 |

---

## 9. 결론

v1/v2 설계 문서는 **조사 품질과 기술적 깊이가 우수**하다. 다만 1인 개발 프로젝트에서 21개 Phase를 전부 실행하는 것은 비현실적이며, **릴리스 단위 재구성 + ROI 기반 선별 + 배포 전략 추가**가 필요하다.

핵심 원칙:
1. **보안 먼저** — Phase 1, 4, 5b, 6a, 6c는 무조건 즉시
2. **변경 최소화** — 작동하는 코드를 "예쁘게" 만드는 건 나중에
3. **배포 단위로 사고** — Phase가 아니라 Release로 관리
4. **테스트는 위험 기반** — 커버리지 숫자보다 실제 위험 커버
5. **문서는 실행을 위해** — 읽기 좋은 문서보다 실행 가능한 체크리스트
