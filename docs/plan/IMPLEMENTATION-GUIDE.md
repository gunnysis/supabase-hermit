# 구현 지시 가이드 — 3월 13일~17일 작업 지시용

> 작성: 2026-03-09 | 사용자가 구현 지시를 내리기 위한 준비 + 일별 실행 + 확인/점검 방법

---

## 1. 사전 준비 (3월 13일 전에 완료)

> 현재 사용자 1명 → Sentry Developer (무료) 유지. 업그레이드 불필요.
> 총 월 비용: **$25/mo** (Supabase Pro만)

사전 준비 사항 없음. 바로 Day 1 작업 지시 가능.

---

## 2. 일별 작업 지시 + 확인/점검

> 각 날마다 새 Claude Code 세션에서 아래 지시를 내립니다.
> Claude는 해당 Release를 자율 실행하고, 완료 보고합니다.
> **확인/점검은 Claude가 자율 수행합니다.** 사용자 확인이 필요한 항목만 별도 표시.

---

### Day 1 — 3월 13일 (보안/안정성)

**지시:**
```
@docs/plan/expected/DESIGN-maintenance-v3-execution.md Release 1 실행해
```

**Claude 실행 내용:**
- 사전 조사 5건 (SSR 패턴, npm audit, Sentry 기준선, Zod, reactions)
- DB 마이그레이션 2개 (post_analysis RLS, reactions RLS 제거)
- 앱: npm audit + Expo 55 업그레이드
- 웹: npm audit + 보안 헤더 + Sentry PII
- 3개 레포 커밋 + 배포

**Claude 자율 점검:**
| # | 점검 항목 | 방법 | 실패 시 |
|---|---|---|---|
| 1 | DB 마이그레이션 dry-run 통과 | `bash scripts/db.sh push --dry-run` | SQL 수정 후 재시도 |
| 2 | DB push + gen-types + sync 성공 | `bash scripts/db.sh push` | 롤백 SQL 실행 |
| 3 | post_analysis 조회 정상 | 웹/앱에서 게시글 상세 → 감정 분석 표시 확인 (코드 레벨) | RLS 롤백 |
| 4 | 앱 테스트 통과 | `npm run test` | Expo 55 breaking change 대응 |
| 5 | 앱 Metro 번들러 정상 | `npm start` (또는 `npx expo start -c`) | babel-preset 버전 조정 |
| 6 | 앱 프로덕션 취약점 0건 | `npm audit --omit=dev` | overrides 적용 |
| 7 | 웹 빌드 성공 | `npx next build` | CSP unsafe-eval 조정 |
| 8 | 웹 보안 헤더 응답 확인 | 빌드 후 응답 헤더에 CSP, HSTS 등 포함 확인 | headers() 수정 |

**사용자 확인 (Day 1 저녁 또는 Day 2 아침):**
- [ ] 앱 실행 — 로그인 → 글 목록 → 글 상세 → 리액션 정상
- [ ] 웹 접속 — 페이지 정상 렌더링

---

### Day 2 — 3월 14일 (코드 품질)

**지시:**
```
@docs/plan/expected/DESIGN-maintenance-v3-execution.md Release 2 실행해
```

**Claude 실행 내용:**
- 중앙 shared 상수/유틸 보강 + sync
- 앱 API 에러 처리 통일 (6파일)
- 웹 에러 로깅 (10곳)
- ESLint 수정 + verify.sh 보강
- 3개 레포 커밋 + 배포

**Claude 자율 점검:**
| # | 점검 항목 | 방법 | 실패 시 |
|---|---|---|---|
| 1 | sync 후 앱/웹 빌드 성공 | sync → `npm run test` (앱) + `npx next build` (웹) | import 경로 수정 |
| 2 | ANALYSIS_STATUS/CONFIG 적용 확인 | usePostDetailAnalysis.ts에서 매직넘버 제거 확인 | 누락 라인 추가 적용 |
| 3 | 에러 처리 표준 패턴 일관성 | 6파일 모두 extractErrorMessage + logger.error + APIError 패턴 | 누락 파일 수정 |
| 4 | verify.sh 보강 항목 통과 | `bash scripts/verify.sh` — utils, palette, Edge Function 검증 | grep 패턴 수정 |
| 5 | ESLint 경고 0건 | 앱 빌드/린트에서 경고 없음 확인 | 추가 수정 |

**사용자 확인 (Day 2 저녁 또는 Day 3 아침):**
- [ ] 앱 실행 — 글 작성 → 댓글 → 에러 없이 동작

---

### Day 3 — 3월 15일 (문서 + DB 제약조건)

**지시:**
```
@docs/plan/expected/DESIGN-maintenance-v3-execution.md Release 3, 4 실행해
```

**Claude 실행 내용:**
- SCHEMA.md + CLAUDE.md 갱신
- boards CHECK 제약조건 마이그레이션
- view-transition.ts 타입 개선
- 중앙 + 웹 커밋 + 배포

**Claude 자율 점검:**
| # | 점검 항목 | 방법 | 실패 시 |
|---|---|---|---|
| 1 | SCHEMA.md 마이그레이션 수 정확 | 22+2(R1)+1(R4) = 25개 반영 확인 | 누락 항목 추가 |
| 2 | CLAUDE.md 정합성 | 마이그레이션 목록, RPC 수, shared 변경 반영 확인 | 갱신 |
| 3 | boards CHECK dry-run | `bash scripts/db.sh push --dry-run` | 멱등성 래핑 확인 |
| 4 | 기존 데이터 제약조건 위반 없음 | push 성공 확인 (기존 boards 데이터가 CHECK 통과) | 데이터 수정 후 재시도 |
| 5 | 웹 빌드 성공 | `npx next build` — view-transition 타입 오류 없음 | 타입 수정 |

**사용자 확인:**
- [ ] 별도 확인 불필요 (문서 + DB 제약조건은 사용자 체감 변화 없음)

---

### Day 4~5 — 3월 17일~ (디자인/접근성)

**지시:**
```
@docs/plan/expected/DESIGN-maintenance-v3-execution.md Release 5 실행해
```

**Claude 실행 내용:**
- MOTION 상수화 (값 변경 없이) + 색상 중앙화
- 폰트 크기 표준화
- 웹 prefers-reduced-motion + 접근성 button 전환 + scrollbar
- 앱/웹 각 커밋 + 배포

**Claude 자율 점검:**
| # | 점검 항목 | 방법 | 실패 시 |
|---|---|---|---|
| 1 | MOTION 값 정확성 | 각 컴포넌트의 기존 하드코딩 값 = 상수 값 일치 확인 | 상수 값 수정 |
| 2 | 앱 테스트 통과 | `npm run test` | 수정 |
| 3 | 웹 빌드 성공 | `npx next build` | 수정 |
| 4 | prefers-reduced-motion 적용 | globals.css에 미디어 쿼리 존재 확인 | 추가 |
| 5 | button 접근성 | EmotionCalendar, AdminSecretTap, RichEditor에 button + aria 확인 | 수정 |
| 6 | scrollbar CSS | `.scrollbar-none` 클래스 globals.css에 정의 확인 | 추가 |
| 7 | NativeWind 호환 | `text-md` 커스텀이 NativeWind에서 작동하는지 확인 | `text-[17px]` 유지 |

**사용자 확인 (R5 완료 후):**
- [ ] 앱 실행 — 버튼 탭, 카드 스와이프 등 애니메이션 체감 동일한지
- [ ] 웹 접속 — 레이아웃/폰트/스크롤 정상

---

## 3. 전체 완료 점검 (3월 17일 이후)

> R1~R5 전체 완료 후 Claude가 최종 점검을 수행합니다.

**지시:**
```
v3 전체 구현 완료 점검해. v1 진행 현황 체크박스 업데이트하고 최종 보고해.
```

**Claude 최종 점검:**
| # | 점검 항목 | 방법 |
|---|---|---|
| 1 | v1 진행 현황 체크박스 전체 업데이트 | R1-R5 항목 `[x]` 처리 |
| 2 | 3개 레포 정합성 | `bash scripts/verify.sh` 통과 |
| 3 | 앱 전체 테스트 | `npm run test` 통과 |
| 4 | 웹 빌드 | `npx next build` 성공 |
| 5 | Sentry 쿼터 확인 | 월간 사용량 확인 (2,500건 이하면 정상) |
| 6 | 마이그레이션 수 일치 | 중앙/앱/웹 migration 파일 수 동일 |
| 7 | CLAUDE.md/SCHEMA.md/MEMORY.md 갱신 | 문서화 규칙에 따라 최신 반영 |
| 8 | needs.md 정리 | 해결된 항목 제거, 파일 초기화 |

**사용자 최종 확인:**
- [ ] 앱 — 주요 동선 이상 없음
- [ ] 웹 — 주요 동선 이상 없음

---

## 4. 전체 타임라인

| 날짜 | Release | 지시 | Claude 점검 | 사용자 확인 |
|---|---|---|---|---|
| **3/13** | R1 | `Release 1 실행해` | 8항목 자율 점검 | 앱/웹 동선 |
| **3/14** | R2 | `Release 2 실행해` | 5항목 자율 점검 | 앱 동선 |
| **3/15** | R3+R4 | `Release 3, 4 실행해` | 5항목 자율 점검 | 불필요 |
| **3/17~** | R5 | `Release 5 실행해` | 7항목 자율 점검 | 앱 애니메이션 + 웹 레이아웃 |
| 3/17~ | 완료 점검 | `전체 완료 점검해` | 8항목 최종 점검 | 앱/웹 최종 |
| 이후 | Backlog | 별도 지시 | — | — |

---

## 5. 관련 문서

| 문서 | 용도 |
|---|---|
| [v3 실행 계획서](expected/DESIGN-maintenance-v3-execution.md) | Claude가 따르는 구현 계획 |
| [v1 상세 설계](expected/DESIGN-maintenance-v1.md) | 각 Phase 상세 설계 |
| [v2 장기 과제](expected/DESIGN-maintenance-v2.md) | Backlog 상세 |
| [리뷰 분석](memo/REVIEW-dev-lead-analysis.md) | 설계 품질 리뷰 + 개선안 |
