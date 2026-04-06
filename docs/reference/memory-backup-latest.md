# Claude 메모리 백업

> 자동 생성: 2026-04-01 06:29:49
> 소스: `~/.claude/projects/-home-gunny-apps-supabase-hermit/memory/`
> 파일 수: 29개
> 체크섬: `effb516f59e00516bbe4b6fb85598f9d`

---

## MEMORY.md (인덱스)

```markdown
# 은둔마을 Supabase 중앙 프로젝트 메모리

> 정리일: 2026-03-22 | 파일 14개 | 백업: `docs/reference/memory-backup-latest.md` (자동)

## 사용자
- [user_profile.md](user_profile.md) — 무직 솔로 개발자, 대인기피/공황, 월 50만원 수익 목표, 새 서비스 기획 중

## 서비스 전략
| 파일 | 핵심 |
|------|------|
| [project_dev_freeze.md](project_dev_freeze.md) | 2026-03-22 기능 개발 동결. 전 서비스 무료 전환. 월 $0. 사용자 확보 우선 |
| [reference_service_plans.md](reference_service_plans.md) | 전체 서비스 플랜/계정/한도/CLI 접근 (Supabase Free, Vercel Hobby, Expo Starter, Sentry Dev, Gemini 무료) |
| [project_session_insight_20260322.md](project_session_insight_20260322.md) | 세션 교훈: 기능 과잉 vs 사용자 부재, 비용은 데이터로 확인, 개발 멈춤이 최선일 때 |
| [project_session_insight_20260329.md](project_session_insight_20260329.md) | 세션 교훈: 중복 빌드 금지, 에러 반복 금지, 로컬 PC 자원 활용, 배포 전 점검 먼저, lint 사전 확인 |
| [project_poetry_board_removal.md](project_poetry_board_removal.md) | 시 게시판 추가 1주 만에 제거 — 기능 과잉 사례, 서비스 정체성 판단 |
| [project_writing_experience.md](project_writing_experience.md) | 글 작성 UX 개선: 웹 임시저장 + 저장 상태 표시 (A안 감정선택/B안 프롬프트는 제거) |
| [project_editor_improvement.md](project_editor_improvement.md) | 에디터 2단계 개선: 웹 밑줄/링크/정렬+SVG아이콘, 앱 글자수수정/높이확대/프로그레스바, 읽기시간, 제목카운터 |
| [project_new_service_plan.md](project_new_service_plan.md) | 수익화: 인프런 텍스트 강의 (Supabase 풀스택) — velog 글 → 인프런 오픈, 월 50만원 목표 |

## 프로젝트 핵심
- 앱(Expo SDK 55) + 웹(Next.js 16) + 중앙(Supabase) 3개 레포
- 중앙: `/home/gunny/apps/supabase-hermit`
- 앱: `/mnt/c/Users/Administrator/programming/apps/gns-hermit-comm`
- 웹: `/home/gunny/apps/web-hermit-comm`
- Project ref: `qwrjebpsjjdxhhhllqcw`

## 역할
- Claude = 3개 프로젝트 전권 위임 (실무자+책임자)
- 승인 불필요, 자율 판단 후 결과 보고만

## 워크플로 & 규칙 (피드백)

| 파일 | 핵심 |
|------|------|
| [feedback_workflow.md](feedback_workflow.md) | 규모별 워크플로 자동 적용 (소5/중7/대반복) |
| [feedback_5role_checklist.md](feedback_5role_checklist.md) | 파악 단계에서 기획자/디자이너/개발자/경영자/책임자 5개 질문 |
| [feedback_deployment.md](feedback_deployment.md) | 배포 규칙: Vercel 수동배포, Edge Function --no-verify-jwt, 배포확인 필수 |
| [feedback_test_data.md](feedback_test_data.md) | 테스트 데이터 즉시 삭제 + 자동 감지 hook |
| [feedback_docs_rules.md](feedback_docs_rules.md) | **docs/ 전체 작성 규칙**: 4폴더+루트5문서 역할/갱신시점/archive 이력포맷/audit 읽기/SERVICES 갱신 (3개 통합) |
| [feedback_expo_upgrade.md](feedback_expo_upgrade.md) | Expo SDK 업그레이드 시 `npx expo install --fix` 필수 |
| [feedback_no_preset_words.md](feedback_no_preset_words.md) | 사용자 감정/말에 프리셋 상수 금지 |
| [feedback_v2_lessons.md](feedback_v2_lessons.md) | v2 교훈: 서비스 정체성, 사이드이펙트, 전수점검 후 한번에 |
| [feedback_sync_detail.md](feedback_sync_detail.md) | 앱/웹 동기화 세부 대조: 아이콘, 조건부 표시, 접근성, 문구 통일 |
| [feedback_side_effect_checklist.md](feedback_side_effect_checklist.md) | 검증 단계에서 사이드이펙트 6문항 자동 체크 (삭제연쇄/동기화/TZ/에러/캐시/호환성) |
| [feedback_track_todos.md](feedback_track_todos.md) | "다음에 할 것" 대화에서만 언급 금지 — tech-debt.md에 반드시 기록 |
| [feedback_vercel_deploy.md](feedback_vercel_deploy.md) | git push 후 vercel --prod 수동 배포 필수 (자동 배포 Canceled 빈번) |
| [feedback_error_diagnosis.md](feedback_error_diagnosis.md) | 에러 진단 시 실제 에러 메시지 먼저 확보 — 추측 기반 대규모 수정 금지 |
| [feedback_error_strategy.md](feedback_error_strategy.md) | 에러 3계층 방어: API throw + QueryCache 토스트 + SectionErrorBoundary |
| [feedback_service_first.md](feedback_service_first.md) | 기능 추가 전 "이 서비스에서 맞나?" 판단 선행 — 앱 제한 = 웹도 동일 |
| [feedback_service_review.md](feedback_service_review.md) | 동작 불가 점검 시 전체 체인 추적 + 닫기 경로 상태 초기화 + 복수 구현체 품질 편차 |
| [feedback_tab_bar_overlap.md](feedback_tab_bar_overlap.md) | 탭 화면 내 absolute/overlay 요소는 useTabBarHeight()로 탭바 높이 반영 필수 |
| [feedback_eas_build_command.md](feedback_eas_build_command.md) | 앱 배포: `eas build --platform android --profile production --auto-submit` (사용자 요청 시만) |
| [feedback_deploy_order.md](feedback_deploy_order.md) | 배포 전 서비스 전체 점검 필수. 앱 버전 올리기 선행. EAS 시크릿 FILE_BASE64 |

## 주의사항 (Quick Ref)
- WSL 환경 — `sed -i 's/\r$//'`
- shared/utils.ts — 외부 import 금지 (순수 함수만)
- boards id 시퀀스: 1, 2, 12

## 문서
- `CLAUDE.md` — 프로젝트 개요, 워크플로, 규칙 (가장 상세)
- `docs/audit/` — 코드 감사 스냅샷 4파일 (새 대화 시 먼저 읽기)
- `docs/SCHEMA.md` — DB 스키마 상세
- `docs/SERVICES.md` — 연동 서비스 플랜/비용/토큰
```

---

## feedback_5role_checklist.md

```markdown
---
name: 5역할 시점 질문 체크리스트
description: 모든 작업의 파악 단계에서 기획자/디자이너/개발자/경영자/책임자 5개 질문을 자동 통과시킴
type: feedback
---

1인 개발 프로젝트이므로, 모든 작업에서 **5가지 역할의 시점**으로 판단한다.

## 파악 단계에서 자동 실행하는 5역할 질문

| 역할 | 질문 | 통과 못 하면 |
|------|------|-------------|
| **기획자** | 이 작업이 사용자 문제를 해결하는가? | 작업 필요성 재검토, 사용자에게 보고 |
| **디자이너** | 사용자 경험이 자연스러운가? | UX 개선안 먼저 제시 |
| **개발자** | 기술적으로 안전하고 유지보수 가능한가? | 리스크/대안 보고 |
| **경영자** | 투입 대비 효과가 있는가? 우선순위가 맞는가? | 우선순위 조정 제안 |
| **책임자** | 배포 후 장애 리스크는? 롤백 계획은? | 롤백 계획 수립 후 진행 |

## 적용 방식

- **파악 단계**에서 5개 질문을 빠르게 판단
- 모두 통과하면 다음 단계로 진행
- 통과하지 못하는 항목이 있으면 작업 전에 사용자에게 보고
- 단순 버그 수정도 "지금 고칠 가치가 있는가" 경영자 시점 통과 필요
- 기능 추가 시 "사용자가 실제로 쓸 건가" 기획자 시점 필터링

**Why:** 1인 개발에서 제너럴리스트+스페셜리스트 모든 역할을 겸하므로, 역할 충돌(개발자 "리팩토링 필요" vs 경영자 "사용자에게 안 보이는데?") 시 판단 기준이 필요. 5개 질문이 자동 필터 역할을 한다.

**How to apply:** 워크플로의 "파악" 단계 진입 시 5개 질문을 내부적으로 체크. 결과는 파악 단계 요약에 간결하게 포함한다.
```

---

## feedback_deploy_order.md

```markdown
---
name: 배포 순서 및 사전 점검
description: 배포 전 서비스 전체 점검 필수. 앱 배포 시 버전 올리기 선행. auto-submit은 EAS 서버 시크릿으로 동작.
type: feedback
---

배포 전 반드시 서비스 전체 점검 및 개선 작업을 먼저 수행해야 한다.

**Why:** 사소한 문제가 있는 상태로 배포하면 안 됨. 배포는 마지막 단계.

**How to apply:**
1. 코드 변경 완료 후 → 서비스 전체 점검/개선 먼저
2. 점검 완료 후 → 배포 순서: DB migration push → git commit/push → Vercel 수동 배포 → 앱 EAS Build
3. 앱 스토어 배포 시: `NATIVE_VERSION` 올리기 → commit → push → `eas build --platform android --profile production --auto-submit`
4. `GOOGLE_SERVICE_ACCOUNT_KEY`는 EAS 서버 시크릿(FILE_BASE64)으로 설정됨 — 로컬 CLI 사전 검증에서 실패할 수 있으나 EAS 빌더에서는 정상 작동
5. `BUILD_NUMBER`는 `autoIncrement: true`로 EAS가 자동 관리
```

---

## feedback_deployment.md

```markdown
---
name: 배포 규칙 통합
description: 웹(Vercel)/앱(EAS)/Edge Function/DB 배포 시 필수 확인사항. 배포 성공까지 확인 후 작업 종료.
type: feedback
---

구현 후 반드시 **빌드 + 배포 성공까지 확인**하고 작업 종료한다.

## 웹 (Vercel)
- 플랜: Hobby (무료), 도메인: `www.eundunmaeul.store`
- git push 자동 배포가 Canceled 빈번 → **`vercel --prod --yes` 수동 배포 사용**
- 빌드 확인: `npm run build` 로컬 → push → 배포 상태 확인

## 앱 (EAS)
- pre-push hook이 테스트 실행 → push 성공 = 테스트 통과
- GitHub App 자동 빌드 트리거 인지

## Edge Function
- **반드시 `--no-verify-jwt` 플래그 사용**
- `npx supabase functions deploy <name> --no-verify-jwt --project-ref <ref>`
- 배포 후 verify_jwt 설정 확인: `curl -s "https://api.supabase.com/v1/projects/<ref>/functions" -H "Authorization: Bearer $TOKEN"`

## DB
- `bash scripts/db.sh push` → 성공 시 자동 gen-types + sync + verify

**Why:** v2 커밋 후 Vercel 타입 에러 배포 실패를 확인하지 않은 사고 + Edge Function --no-verify-jwt 누락으로 기능 완전 작동 불가 사고 경험.
```

---

## feedback_docs_rules.md

```markdown
---
name: docs/ 전체 작성 규칙
description: docs/ 4폴더 + 루트 문서 5개의 역할, 갱신 시점, 작성 포맷 통합 규칙
type: feedback
---

## docs/ 구조

```
docs/
├── SCHEMA.md              # DB 스키마 상세 (테이블/뷰/RPC/RLS/트리거/제약조건)
├── SCRIPTS.md             # 스크립트 사용법 (db.sh, gen-types.sh, sync, verify)
├── CLIENT-ARCHITECTURE.md # 앱/웹 클라이언트 연동 아키텍처
├── SERVICES.md            # 연동 서비스 플랜/비용/토큰/한도
├── plan/                  # 진행 예정/진행 중 설계 문서만
├── archive/               # 주제별 이력 문서 (01~06)
├── audit/                 # 코드 감사 스냅샷 (4파일)
└── reference/             # 외부 참조, 보류 설계, 메모리 백업
```

---

## 루트 문서 5개 — 역할과 갱신 시점

| 문서 | 역할 | 갱신 시점 |
|------|------|---------|
| **SCHEMA.md** | DB 스키마 단일 정본 | 마이그레이션 추가/RPC 변경 시 |
| **SCRIPTS.md** | 스크립트 사용법 | 스크립트 수정 시 |
| **CLIENT-ARCHITECTURE.md** | 앱/웹 연동 패턴 | 아키텍처 변경 시 |
| **SERVICES.md** | 서비스 플랜/비용/토큰 | 플랜 변경, 토큰 갱신, 비용 구조 변경 시 |

---

## plan/ — 활성 설계 문서

- **넣는 것**: 구현 예정 또는 진행 중인 설계 문서 (`DESIGN-*.md`)
- **빼는 것**: 구현 완료 → archive/ 이력에 흡수 후 **삭제** (archive로 이동 아님)
- **비어있는 게 정상**: 모든 설계가 완료되면 plan/은 빈 폴더

---

## archive/ — 주제별 이력 문서

### 현재 6개 파일

| 파일 | 범위 |
|------|------|
| `01-유지보수-이력.md` | 유지보수, 코드 품질, 타입 안전성, 리뷰, 서비스 점검 |
| `02-검색-이력.md` | 검색 기능, 리팩토링, 앱/웹 동기화 |
| `03-감정분석-이력.md` | 감정분석 파이프라인, 감정 칩 UI, 타임라인 |
| `04-인프라-이력.md` | 관리자, Sentry, EAS Build, Supabase Advisor |
| `05-마이페이지-이력.md` | 마이페이지, 오늘의하루(daily) |
| `06-가이드-이력.md` | 구현/리팩토링/감정분석 가이드 |

### 항목 포맷
```markdown
## 제목 (날짜)
- **범위**: 어떤 레포/모듈에 영향
- **핵심 작업**: 무엇을 했는지
- **결과**: 마이그레이션 번호, 배포, 테스트
- **교훈**: 왜 이렇게 됐고, 다음에 뭘 다르게 할지
```

### 규칙
- **교훈 필수** — 교훈 없는 이력은 로그일 뿐
- 기존 6개 중 가까운 주제에 추가, 없으면 `07-주제-이력.md` 신규
- 여러 주제 걸치면 핵심 1곳에만 (중복 금지)
- 코드 스니펫, 커밋 해시 넣지 않음
- DESIGN-*.md 잔여물은 이력 흡수 후 삭제

---

## audit/ — 코드 감사 스냅샷

| 파일 | 내용 |
|------|------|
| `central-audit.md` | 중앙 레포: 마이그레이션, RPC, 테이블, shared, 스크립트 |
| `web-audit.md` | 웹 레포: 파일 수, API, 훅, 컴포넌트, 의존성 |
| `app-audit.md` | 앱 레포: 파일 수, API, 훅, 컴포넌트, 의존성 |
| `tech-debt.md` | 3개 레포 기술부채 + 개선 백로그 (P0~P3) |

### 규칙
- **새 대화 시작 시 4파일 먼저 읽기** (전체 현황 파악)
- 작업 완료 후 변경된 레포의 audit + tech-debt 즉시 갱신
- 마이그레이션/RPC/컴포넌트 추가·삭제 시 수량·목록 업데이트
- 기술부채 해결 시 `[x]` 체크, 새 발견 시 적절한 P레벨에 추가

---

## reference/ — 외부 참조

- 외부 시스템 참조 (Supabase Advisor 리포트 등)
- 보류 중인 설계
- memory-backup-latest.md (메모리 자동 백업)
- 자주 갱신하지 않음, 필요할 때만 추가/업데이트

---

## 문서 갱신 체크리스트

작업 완료 시 해당하는 항목만 수행:

- [ ] 마이그레이션 추가 → CLAUDE.md 목록 + SCHEMA.md + central-audit.md
- [ ] RPC 추가/변경 → CLAUDE.md RPC 표 + SCHEMA.md
- [ ] shared/ 변경 → CLAUDE.md 동기화 대상 설명
- [ ] 서비스 플랜/비용 변경 → SERVICES.md
- [ ] 기술부채 해결 → tech-debt.md `[x]`
- [ ] 설계 문서 구현 완료 → archive/ 이력 흡수 + plan/ 삭제
- [ ] 앱/웹 파일 수 변동 → 해당 audit.md

**Why:** docs/ 규칙이 3개 메모리(archive_rules, audit_first, services_doc)에 분산 → 하나로 통합하여 일관성 확보. 2026-03-22.

**How to apply:** 작업 완료 → 커밋 전에 위 체크리스트 해당 항목 수행.
```

---

## feedback_eas_auto_submit_wsl.md

```markdown
---
name: EAS submit 로컬 키 파일 설정
description: eas submit 시 serviceAccountKeyPath는 로컬 .key/ 폴더의 JSON 파일 경로로 지정. WSL/로컬 PC 모두 사용 가능.
type: feedback
---

`eas submit`에서 `serviceAccountKeyPath`는 `.key/apps-2182e-4cfe31bef56b.json` 로컬 파일 경로로 지정.

**Why:** EAS 서버 시크릿(FILE_BASE64)은 빌드 환경에서만 접근 가능. submit CLI는 로컬 파일 경로가 필요. 환경변수 `$GOOGLE_SERVICE_ACCOUNT_KEY`는 로컬에서 resolve 불가.

**How to apply:**
- `eas.json`의 `serviceAccountKeyPath`: `"./.key/apps-2182e-4cfe31bef56b.json"`
- `.key/` 폴더는 `.gitignore`에 추가됨
- 빌드+제출 한 번에: `eas build --platform android --profile production` 후 `eas submit --platform android --profile production --latest`
- 사용자 요청 시에만 실행. 버전 올리기 선행.
- **절대 중복 빌드하지 않기** — 재시도 시 먼저 `eas build:cancel`로 취소 후 재실행
- WSL뿐 아니라 로컬 PC 작업 권한도 활용할 것 — 문제 해결 시 다양한 경로 시도
```

---

## feedback_eas_build_command.md

```markdown
---
name: EAS Build 배포 명령어
description: 앱 배포 시 eas build --platform android --profile production --auto-submit 사용
type: feedback
---

앱 배포 시 `eas build --platform android --profile production --auto-submit` 실행.

**Why:** 빌드 완료 후 Google Play Console에 자동 제출까지 한 번에 처리. 수동 업로드 불필요.

**How to apply:** 앱 레포(`/mnt/c/Users/Administrator/programming/apps/gns-hermit-comm`)에서 실행. 사용자가 명시적으로 앱 배포/EAS Build를 요청할 때만 사용. 자동으로 실행하지 않음.
```

---

## feedback_error_diagnosis.md

```markdown
---
name: 에러 진단 시 실제 에러 메시지 먼저 확인
description: 코드 분석만으로 에러 원인 추정하지 말고, 실제 에러 메시지를 먼저 확보 — 추측 기반 수정 반복 방지
type: feedback
---

에러 신고 접수 시 코드 구조 분석보다 **실제 에러 메시지 확보가 최우선**이다.

**Why:** 2026-03-18 마이페이지 "문제가 발생했습니다" 에러 → 에러 메시지 없이 코드 분석만으로 3차례 대규모 수정(ErrorBoundary, API throw 통일, UX 폴리시) 진행. 결과적으로 근본 원인이 코드가 아니라 배포 누락이었을 가능성. 실제 에러 메시지를 먼저 확인했으면 1차에 해결 가능했음.

**How to apply:**
1. 에러 신고 → 에러 메시지/스크린샷 요청
2. 없으면 error.tsx에 상세 표시 추가 → 배포 → 확인 요청
3. 에러 메시지 확보 후 정확한 원인에만 수정
4. 추측 기반 대규모 리팩토링 금지
```

---

## feedback_error_strategy.md

```markdown
---
name: 에러 처리 3계층 방어 체계 수립됨
description: API throw 표준화 + QueryCache 전역 토스트 + SectionErrorBoundary — 향후 새 API/컴포넌트 추가 시 이 패턴 따를 것
type: feedback
---

2026-03-18 수립된 에러 처리 표준:

1층: **API 함수는 모두 throw** — null/[] 조용한 반환 금지. Supabase error 있으면 throw.
2층: **QueryCache/MutationCache 전역 onError** — 에러 시 자동 토스트. `meta: { silent: true }`로 보조 쿼리는 토스트 억제.
3층: **SectionErrorBoundary** — 페이지 내 섹션 격리. 하나 실패해도 나머지 정상.

**How to apply:**
- 새 API 함수 추가 시 → 에러면 throw (null 반환 X)
- 새 useQuery 추가 시 → 보조 데이터면 `meta: { silent: true }`
- 새 페이지 섹션 추가 시 → SectionErrorBoundary로 감싸기
```

---

## feedback_expo_upgrade.md

```markdown
---
name: Expo SDK 업그레이드 절차
description: Expo SDK 업그레이드 시 반드시 npx expo install --fix 실행해야 함 — companion 패키지 누락으로 EAS Build 실패한 사례
type: feedback
---

Expo SDK 메이저 업그레이드 시 `npm install expo@~XX.0.0`만으로는 부족하다. 반드시 `npx expo install --fix`를 실행하여 모든 companion 패키지를 호환 버전으로 업데이트해야 한다.

**Why:** 2026-03-17 Build #64, #65가 expo-updates 29.x(SDK 54)와 Gradle 9.0의 Kotlin 2.2.0 비호환으로 실패. 코어 expo만 55로 올리고 22개 companion 패키지를 안 올린 것이 원인.

**How to apply:** Expo SDK 업그레이드 시 아래 절차 필수:
1. `npm install expo@~XX.0.0`
2. `npx expo install --fix` (★ 필수)
3. `npx expo install --check` → "Dependencies are up to date" 확인
4. `npx expo-doctor` 실행
5. 테스트 실행
6. `bash scripts/pre-build-check.sh` (앱 레포)
```

---

## feedback_no_preset_words.md

```markdown
---
name: 사용자 감정/말에 상수 프리셋 사용 금지
description: 개발자/AI가 미리 적어둔 문구를 사용자 감정 표현이나 대화에 사용하지 않음. 사람의 마음은 상수로 정의할 수 없다.
type: feedback
---

사용자의 감정이나 말을 대신하는 상수(프리셋 문구)를 만들지 않는다.

**Why:** 개발자나 AI가 "이 감정일 때 이런 말이 맞겠지"라고 추측한 문구는 실제 그 감정을 느끼는 사람의 마음과 다를 수 있다. "괜찮아요"가 위로인지 무심함인지는 상황마다 다르다. 남의 입에 넣어줄 말을 우리가 정하면 안 된다.

**How to apply:**
- 감정 반응형 placeholder (감정별 질문 상수) → 하지 않음
- 프리셋 댓글 버튼 ("나도 그랬어요", "괜찮아요") → 하지 않음
- AI가 생성한 공감 메시지 제안 → 하지 않음
- 대안: 사용자가 직접 쓰거나, 데이터 축적 후 실제 커뮤니티의 말을 보여주기
- 기존 리액션(heart, sad 등)은 OK — 말이 아니라 감정 표현이므로

**적용 범위:** 은둔마을 서비스 전체. "오늘의 하루" 뿐 아니라 모든 사용자 대면 텍스트에 해당.
```

---

## feedback_service_first.md

```markdown
---
name: 기능 추가 시 서비스 정체성 먼저 확인
description: 코드 구현 전에 "이 서비스에서 이 기능이 맞는가" 판단 필수 — 앱에서 의도적으로 제한한 것은 웹에서도 동일 적용
type: feedback
---

기능 하나를 추가하거나 수정할 때, 코드 레벨 해결에 들어가기 전에 반드시 물어야 할 질문:
**"은둔마을이라는 서비스에서 이게 맞나?"**

**Why:** 2026-03-18 웹 마이페이지에 로그아웃 버튼을 항상 표시하도록 구현. 앱에서는 `__DEV__`로 숨긴 것을 코드로 읽었는데, 그 의도(익명 서비스에서 로그아웃 = 데이터 영구 손실)를 웹에 적용하지 않았음. 서비스 정체성을 이해하면서도 구현에 반영 안 한 실수.

**How to apply:**
1. 앱에서 의도적으로 제한/숨김한 기능 → 웹에서도 동일 정책
2. 새 기능 추가 시 기획자 관점 질문: "익명 사용자에게 이게 위험한가?"
3. 코드 수준 판단 전에 서비스 수준 판단 선행
```

---

## feedback_service_review.md

```markdown
---
name: 서비스 시점 점검 교훈
description: 기능 동작 불가 점검 시 전체 체인 추적 + 닫기 경로 상태 초기화 + 동일 기능 복수 구현체 품질 편차 주의
type: feedback
---

서비스 시점에서 "동작 불가" 점검은 버튼 하나가 아니라 전체 동작 체인(UI → ref → 컴포넌트 → state → API → DB)을 끝까지 따라가야 한다.

**Why:** DailyBottomSheet 점검에서 버튼 자체는 정상이었지만, 시트를 제출 없이 닫을 때 상태 미초기화, useMemo 의존성 누락, 접근성 누락 등 서비스 품질 문제가 체인 중간에 숨어 있었다.

**How to apply:**
- "동작 불가" 요청 시 UI 이벤트 → 콜백 → 상태 관리 → API 호출 → DB RPC까지 전체 흐름을 한 번에 추적
- 모달/시트/다이얼로그는 반드시 "제출 없이 닫는 경로"의 상태 정리를 점검
- 같은 기능의 복수 구현체(BottomSheet vs FullPage 등)가 있으면 접근성·애니메이션·에러 처리의 품질 편차를 확인
```

---

## feedback_side_effect_checklist.md

```markdown
---
name: 사이드 이펙트 자동 체크리스트
description: 모든 구현 작업의 검증 단계에서 6가지 사이드 이펙트 질문을 자동으로 통과시킴
type: feedback
---

모든 구현 작업의 **검증 단계**에서 아래 6가지를 자동으로 체크한다.

## 검증 단계 자동 실행 — 사이드 이펙트 6문항

| # | 질문 | 검증 방법 |
|---|------|----------|
| 1 | **삭제/변경의 연쇄 효과** — 이 데이터가 삭제/변경되면 다른 테이블/뷰/알림에 영향은? | DB FK, CASCADE, 관련 테이블 확인 |
| 2 | **앱/웹 동기화** — 양쪽에 같은 변경이 반영됐는가? 아이콘, 문구, 조건부 표시, 접근성 동일한가? | 양쪽 파일 나란히 비교 (5항목 체크) |
| 3 | **타임존** — KST 날짜 비교가 정확한가? 서버/클라이언트 어디서 계산하는가? | RPC는 kst_date(), 클라이언트에 수동 KST 없는지 확인 |
| 4 | **에러 경로** — 실패 시 사용자에게 어떻게 보이는가? 조용히 실패하지 않는가? | onError 핸들러, Toast/Alert 존재 확인 |
| 5 | **캐시 정합성** — mutation 후 관련 쿼리 캐시를 모두 무효화했는가? staleTime 동안 오래된 데이터가 보이지 않는가? | invalidateQueries 키 목록 확인 |
| 6 | **새 라이브러리 호환성** — 설치한 패키지가 Expo SDK / Next.js 버전과 호환되는가? 런타임 에러 없는가? | tsc + 빌드 + 실제 동작 확인 (motion/react #310 사례) |

## 적용 방식

- 워크플로 "검증" 단계 진입 시 6문항을 내부적으로 체크
- 하나라도 문제가 있으면 구현으로 돌아가 수정 후 재검증
- TypeScript/테스트 통과만으로 검증 완료하지 않음 — 6문항 통과 후 배포

**Why:** DailyPostCard 리액션 아이콘 불일치, motion/react 무한 렌더, soft_delete 알림 orphan 등 tsc/테스트로는 잡히지 않는 사이드 이펙트가 반복 발생. 이 체크리스트가 마지막 방어선 역할.

**How to apply:** 검증 단계에서 6문항 빠르게 통과. 결과는 검증 섹션에 간결하게 포함. 문제 발견 시 즉시 수정 후 재배포.
```

---

## feedback_sync_detail.md

```markdown
---
name: 앱/웹 동기화 세부 사항 점검
description: 컴포넌트 구현 시 앱/웹 간 아이콘, 조건부 표시, 접근성, 텍스트가 동일한지 반드시 대조 확인
type: feedback
---

앱/웹에 같은 기능을 구현할 때, 세부 사항까지 동기화되었는지 반드시 대조 확인한다.

## 체크리스트

1. **아이콘/이모지 동일** — 한쪽에 ❤️💬가 있으면 다른 쪽에도
2. **조건부 표시 동일** — 0일 때 숨기기, 빈 배열일 때 숨기기 등
3. **접근성 동일** — 앱 accessibilityLabel ↔ 웹 aria-label
4. **텍스트/문구 동일** — "N명이 공감" 등 표현 통일
5. **스타일 패턴 유사** — 정확히 같을 순 없지만 시각적 의미가 동일

**Why:** DailyPostCard 리액션 영역에서 웹은 아이콘 없이 숫자만 표시, 0일 때도 표시하는 등 사소한 차이가 있었음. 이런 것들이 쌓이면 앱/웹 간 경험 차이가 생김.

**How to apply:** 앱/웹 동시 수정 시 양쪽 파일을 나란히 읽고 5개 항목 대조. 한쪽만 수정하고 끝내지 않는다.
```

---

## feedback_tab_bar_overlap.md

```markdown
---
name: feedback_tab_bar_overlap
description: 탭 화면 내 absolute/overlay 요소는 반드시 useTabBarHeight()로 탭바 높이를 반영해야 함
type: feedback
---

탭 화면(tabs/) 내 absolute 배치 또는 overlay 요소는 반드시 `useTabBarHeight()` 훅을 사용하여 탭바 높이를 반영해야 한다.

**Why:** 탭바가 `position: 'absolute'`로 콘텐츠 위에 떠 있으므로, 하단 요소들이 탭바와 겹치는 버그가 반복 발생했다 (DailyBottomSheet, FAB, PostList 스크롤 끝단).

**How to apply:**
- `@gorhom/bottom-sheet` → `bottomInset={tabBarHeight}`
- `FlashList`/`FlatList` → `contentContainerStyle={{ paddingBottom: tabBarHeight + N }}`
- Absolute FAB/버튼 → `bottom: tabBarHeight + N`
- 탭 화면이 아닌 standalone 화면(post/[id], edit, admin 등)에서는 불필요
- `useTabBarHeight()`는 `(tabs)/_layout.tsx`의 tabBarHeight 계산과 동일한 로직 사용
```

---

## feedback_test_data.md

```markdown
---
name: 테스트 데이터 관리
description: 프로덕션 DB의 테스트 데이터는 즉시 삭제 + git push 후 자동 감지 hook 경고 시 반드시 정리
type: feedback
---

테스트용 글/댓글/유저 생성은 허용하되, **테스트 직후 즉시 삭제**한다.

## 규칙

1. 생성 시 ID를 즉시 기록
2. curl 익명 로그인 테스트 시 유저 ID도 기록
3. **테스트 끝나면 바로 정리** — "나중에" 금지
4. 정리 방법: `admin_cleanup_posts`/`admin_cleanup_comments` RPC 또는 직접 DELETE
5. Auth 유저: `DELETE /auth/v1/admin/users/{id}`
6. 정리 완료를 사용자에게 보고

## 자동 감지 hook

- `.claude/hooks/post-push-cleanup-check.sh`가 git push 후 자동 실행
- 최근 3시간 내 생성된 게시글 감지 시 `⚠️ 테스트 데이터 감지` 경고
- 비차단(non-blocking) — push를 막지는 않지만 경고를 무시하지 말 것

**Why:** 테스트 데이터가 프로덕션에 남아 사용자가 수동 삭제한 사고 2회 발생 (2026-03-15).
```

---

## feedback_track_todos.md

```markdown
---
name: 미구현 항목은 tech-debt.md에 기록
description: 대화에서 "다음에 할 것"을 언급하면 반드시 tech-debt.md에도 기록. 대화는 휘발되지만 문서는 남는다.
type: feedback
---

"다음에 할 수 있는 것"을 대화에서만 언급하고 끝내지 않는다. 반드시 `docs/audit/tech-debt.md`에 기록한다.

**Why:** 대화는 세션이 끝나면 사라진다. 미구현 항목을 대화에서만 언급하면 다음 세션에서 누락된다. tech-debt.md가 유일한 추적 장소.

**How to apply:**
- 작업 완료 시 "아직 미구현" 항목이 있으면 → tech-debt.md P2/P3에 추가
- 설계 문서 삭제 시 → 미구현 항목을 tech-debt.md로 이동 후 삭제
- "다음에 할게요"라고 말한 순간 → tech-debt.md에 기록했는지 확인
```

---

## feedback_v2_lessons.md

```markdown
---
name: v2 작업에서 배운 교훈
description: 오늘의 하루 + v2 구현 과정에서의 실패와 교훈. 모든 작업에 적용.
type: feedback
---

## 서비스 정체성 먼저

기능을 만들기 전에 "이게 이 서비스의 정체성에 맞나?"를 먼저 묻는다.
- daily_checkins 별도 테이블 (개인 일지) → posts 확장 (소통 포맷)으로 전환한 것이 핵심이었음
- 기술적으로 가능한 것과 서비스에 맞는 것은 다르다

## 사람의 마음을 코드로 정의하지 않는다

프리셋 댓글, 감정별 프롬프트, AI 위로 메시지 — 두 번 만들고 두 번 지적받고 두 번 삭제했음.
- **한 번이면 충분했어야 한다**
- 사실만 보여주고 해석하지 않는다
- 상수로 미리 적어둔 문구는 실제 사람의 마음과 다르다

## 전체를 보고 한 번에 한다

ESLint/TypeScript 에러를 하나씩 고치고 커밋하고 실패하고 — 5번 반복.
- 긴급 땜질 대신 **설계 → 전수 점검 → 한 번에 구현**
- hooks 규칙, 타입 정합성, 린트, 빌드, 배포, 버전 — 전부 사전에 본다

## 사이드 이펙트를 먼저 생각한다

코드 변경의 직접 영향뿐 아니라 2차 영향까지:
- 버전 안 올리고 push → 빌드 자동 트리거 → v1 버전으로 빌드
- 타입 변경 → 해당 타입 쓰는 모든 컴포넌트 확인
- DB 변경 → 뷰, RPC, 트리거 전수 확인
- git push → pre-commit/pre-push hook + 자동 빌드 인지

## 추측으로 만들지 않는다

데이터 없이 기능을 만들면 안 쓰일 수 있다. 만들고 → 배포하고 → 관찰하고 → 데이터로 결정한다.

## 이 교훈들은 실패에서 왔다

실패는 성공의 어머니. 같은 실수를 반복하지 않는 것이 성장이다.
```

---

## feedback_vercel_deploy.md

```markdown
---
name: Vercel 수동 배포 반드시 실행
description: git push 후 vercel --prod 수동 배포 안 하면 변경사항이 실서비스에 반영 안 됨 — 배포 누락 사고 방지
type: feedback
---

웹 변경 후 `git push`만으로는 부족. 반드시 `vercel --prod --yes` 수동 배포까지 실행해야 실서비스에 반영된다.

**Why:** 2026-03-18 마이페이지 에러 수정 3차례 배포했으나, vercel --prod를 안 해서 실서비스에 전혀 반영되지 않았음. 사용자가 "계속 에러" 보고 → 코드 원인 아닌 배포 누락이었을 가능성 높음. feedback_deployment.md에도 있지만 실제 작업에서 빠졌음.

**How to apply:** 웹 레포 커밋+푸시 후 마지막 단계에서 반드시:
```bash
cd /home/gunny/apps/web-hermit-comm && npx vercel --prod --yes
```
배포 완료 로그(status ● Ready) 확인 후 작업 종료.
```

---

## feedback_workflow.md

```markdown
---
name: 작업 워크플로 — 규모별 분기
description: 모든 작업에 규모별 워크플로를 자동 적용. 소규모 5단계, 중규모 7단계, 대규모 반복 구현+통합검증
type: feedback
---

모든 작업에 아래 워크플로를 **말 안 해도 자동 적용**한다.

## 규모별 워크플로

### 소규모 (파일 1~3개, 단순 수정)
```
파악 → 구현 → 검증 → 배포 → 기록
```

### 중규모 (파일 4~10개)
```
파악 → 설계 → 구현 → 검증 → 배포 → 확인 → 기록
```

### 대규모 (모듈 추가, DB 마이그레이션 포함)
```
파악 → 설계 → [구현 → 검증]×반복 → 통합검증 → 배포 → 확인 → 기록
```

## 각 단계 정의

| 단계 | 하는 일 | 산출물 |
|------|---------|--------|
| **파악** | audit 읽기, 코드 탐색, 문제 범위 확정 | 현황 요약 |
| **설계** | 우선순위 판단, 수정 계획, 리스크 평가 | 설계 문서 (필요시) |
| **구현** | 코드 수정 | 변경된 파일 |
| **검증** | tsc, jest, lint, 수동 확인 | 테스트 통과 |
| **통합검증** | 대규모 작업 시 전체 모듈 cross-check | 통합 테스트 통과 |
| **배포** | commit, push, vercel/EAS | 배포 URL/커밋 해시 |
| **확인** | 배포 성공 확인, 문제시 롤백 판단 | 배포 상태 |
| **기록** | audit/tech-debt/MEMORY 갱신, 설계문서 정리 | 갱신된 문서 |

**Why:** 사용자가 이전에 사용하던 9단계 워크플로("점검→판단→개선→구현→점검→디버깅→배포→점검→문서화")에서 중복되는 "점검" 3회를 각각 파악/검증/확인으로 명확히 분리하고, 소규모 작업의 오버헤드를 제거하기 위해 규모별 분기를 도입.

**How to apply:** 작업 지시를 받으면 먼저 규모를 판단하고, 해당 워크플로를 단계별로 실행. 각 단계 전환 시 "## N단계: 단계명" 헤더로 진행 상황을 표시한다.
```

---

## project_dev_freeze.md

```markdown
---
name: 개발 동결 및 서비스 전략 전환
description: 2026-03-22 기능 개발 중단, 사용자 확보 우선 전략으로 전환
type: project
---

2026-03-22 기준, 기능 개발 동결 + 전 서비스 무료 플랜 전환 완료.

**서비스 플랜 (2026-03-22 확인, 전부 무료):**
- Supabase: Free (Pro→Free 다운그레이드, 월 $25 절감)
- Vercel: Hobby Plus ($0)
- Expo/EAS: Starter ($0)
- Sentry: Developer ($0, 에러 한도 13% 사용)
- Gemini API: 무료 티어 (gemini-2.5-flash)
- 월 고정비: $0

**Supabase Free 주의사항:**
- 7일 비활성 시 프로젝트 자동 일시정지 (재활성화 대기 필요)
- DB 500MB, 대역폭 2GB, Edge Function 50만/월, Realtime 200만/월
- 현재 데이터: posts 22, comments 3 — Free로 충분

**배경:**
- 기능은 이미 서비스 가능 수준 (감정 게시글, AI 분석, daily, 리액션/댓글/답글/알림, 익명 별칭, 차단, 검색, 트렌딩, 추천, 스트릭, 주간/월간 리포트)
- 사용자 확보가 안 된 상태에서 기능 추가는 비용만 증가

**현재 전략:**
1. 새 기능 개발 중단 — 버그 수정과 안정화만 허용
2. 전 서비스 무료 플랜 운영 — 월 고정비 $0
3. 사용자 확보에 집중 — 기존 기능으로 마케팅/홍보
4. 수익화는 사용자(DAU 50~100+) 확보 후 검토

**Why:** 비용 $0 달성 + 사용자 부족. "더 만들면 더 좋아진다"가 아니라 "있는 걸로 사람을 모을 수 있나"가 우선.
**How to apply:** 새 기능 요청 시 이 전략을 상기. 버그/안정화 외 개발은 사용자 확보 상황 확인 후 판단. Supabase Pro 재업그레이드는 사용자 증가로 Free 한도 초과 시.
```

---

## project_editor_improvement.md

```markdown
---
name: 에디터 개선 (2026-03-28)
description: 앱/웹 리치 텍스트 에디터 2단계 개선 — 기능 추가 + UX 품질 향상
type: project
---

## Phase 1 — 기능 추가

**웹 (Tiptap 3.20)**:
- `@tiptap/extension-underline` — 밑줄 (Ctrl+U)
- `@tiptap/extension-link` — 링크 삽입/제거 (인라인 URL 입력 바)
- `@tiptap/extension-text-align` — 좌/중/우 정렬

**앱 (TenTap 1.0.1)**:
- 글자수 카운트: HTML length → 순수 텍스트 length 수정

## Phase 2 — UX 품질

**웹**:
- 정렬 아이콘: 텍스트(≡) → SVG 아이콘 (좌/중/우 시각적 구분)
- 링크 아이콘: 텍스트(🔗) → SVG chain 아이콘
- 읽기 시간 표시: "약 N분 읽기" (500자/분 기준)

**앱**:
- maxHeight: 400px → 600px (긴 글 작성 공간 확대)
- 프로그레스 바 추가 (웹과 동일)
- 읽기 시간 표시 추가

**앱/웹 공통**:
- 제목 글자 수 카운터: "00/100" (90자 넘으면 amber 경고)
- 작성 화면 + 수정 화면 모두 적용

**Why:** 에디터는 글 작성 서비스의 핵심. 기본 도구만으로는 사용자 표현력이 제한됨.

**How to apply:**
- 웹 PostContent에 `style` attr 허용 추가 (text-align 렌더링)
- 앱 PostBody는 기존에 `<u>`, inline style, `<a>` 모두 지원 — 변경 불필요
- 향후 고려: 앱에도 Link/Underline/TextAlign 커스텀 도구 추가 (TenTap custom toolbar)
```

---

## project_new_service_plan.md

```markdown
---
name: 새 서비스 수익화 계획
description: 인프런 텍스트 강의 (Supabase 풀스택) — 블로그 글로 강의하는 방향 확정
type: project
---

2026-04-01 새 수익 서비스 방향 논의 결과:

- 은둔마을은 유지하되 별도 수익 서비스 기획
- 여러 방향 검토 후 **인프런 텍스트 기반 강의**로 방향 확정
- 주제: "Supabase로 실전 풀스택 앱 만들기" (은둔마을 경험 기반)
- 실행 계획: velog 무료 글 → 반응 확인 → 인프런 강의 오픈
- 수익 목표: 월 50만원 이상 (55,000원 x 15명/월)

**Why:** 대인기피/공황으로 대면 불가, 영상 없이 텍스트만으로 강의 가능, 문서화 능력 상위 5%, 한국어 Supabase 심화 강의 부재
**How to apply:** 사용자가 강의 관련 작업 요청 시 이 맥락 활용. 커리큘럼 초안은 대화에서 이미 제시함 (1부 설계 / 2부 구현 / 3부 운영 / 4부 배포)
```

---

## project_poetry_board_removal.md

```markdown
---
name: 시 게시판 제거 (2026-03-28)
description: board_id=13 시 게시판 기능 추가 후 1주 만에 제거 — 기능 과잉 사례
type: project
---

시 게시판(board_id=13)을 2026-04-02에 추가했으나, 2026-03-28(실제 작업일)에 제거.

**Why:** 개발 동결 방침(2026-03-22) 하에서 사용자 없이 기능만 늘리는 것은 역효과. 시 게시판은 서비스 정체성(감정 공유 커뮤니티)과 맞지 않는 부가 기능으로 판단.

**How to apply:**
- 기능 추가 전 "이 서비스에서 맞나?" 판단은 feedback_service_first.md와 일치
- 게시판 탭 UI는 PUBLIC_BOARDS 배열 1개일 때 자동 제거됨 — 향후 게시판 추가 시 탭 UI 복원 필요
- 마이그레이션 49번(#49): board_id=13 게시글을 자유게시판(12)으로 이관 후 board 삭제
```

---

## project_session_insight_20260322.md

```markdown
---
name: 2026-03-22 세션 교훈
description: 기능 과잉 vs 사용자 부재, 비용 불안 vs 데이터 확인, 개발 멈춤이 최선일 때가 있다
type: project
---

2026-03-22 서비스 점검 세션에서 얻은 교훈.

**1. 기능은 넘치는데 사용자가 없다**
- RPC 35개, 마이그레이션 46개, 컴포넌트 90+개 — 기술적으로 충분한 서비스
- 실제 데이터: posts 22, comments 3 — 사실상 테스트 수준
- 더 만드는 건 의미 없고, 있는 걸로 사람을 모아야 하는 시점

**2. 비용 불안은 데이터로 해소된다**
- "비용이 커질 것 같다"는 불안 → 실제 확인하니 Supabase Pro $25만 유료, 나머지 전부 무료
- Sentry 한도 13% 사용, Gemini 무료 티어 충분
- 추측이 아니라 CLI/API로 실제 수치를 확인하면 판단이 명확해짐

**3. 버그처럼 보이는 것 ≠ 실제 버그**
- Sentry 18개 미해결 이슈 → 분석 결과 대부분 Supabase 일시적 불안정 + 에러 처리 패턴 비일관성
- 진짜 코드 버그는 거의 없었고, 에러 보고 체계가 불완전해서 "버그처럼 보였을 뿐"
- 에러 처리 패턴 통일만으로 진단력이 크게 향상됨

**4. 개발을 멈추는 게 때로는 최선의 개발 판단**
- 기능 동결 + 전 서비스 무료 전환 → 월 $0 운영
- 안정화/버그 수정만 허용, 나머지 시간은 사용자 확보에 투자
- "더 만들면 더 좋아진다"는 개발자 본능을 억제하는 것도 실력

**Why:** 이 교훈들은 향후 "기능 추가 vs 사용자 확보" 판단 시점에 다시 참고할 가치가 있음.
**How to apply:** 새 기능 요청 시 "사용자가 늘었는가?"를 먼저 확인. 데이터 없이 비용/규모 판단하지 않기.
```

---

## project_session_insight_20260329.md

```markdown
---
name: 2026-03-28~29 세션 교훈
description: 배포 절차 실수, 로컬 PC 활용 미흡, 중복 실행, 사전 점검 순서 등 반성 및 교훈
type: project
---

## 배포에서의 실수

1. **EAS Build 3중 실행** — 백그라운드 2건 + 포그라운드 1건을 동시에 실행하여 빌드 크레딧 낭비. 재시도 시 반드시 기존 빌드를 `eas build:cancel`로 취소 후 재실행해야 한다.

2. **앱 버전 올리기 누락** — 스토어 배포 시 `NATIVE_VERSION` 올리는 절차를 잊음. app.config.js 주석에 명확히 적혀 있었는데 읽지 않았다. 배포 전 반드시 버전 확인.

3. **동일 에러 반복 시도** — `serviceAccountKeyPath` 에러가 처음 발생했을 때 원인을 분석하고 해결했어야 하는데, 같은 명령을 3번 반복 실행. 에러가 나면 멈추고 원인을 파악한 뒤 해결하고 재시도.

4. **로컬 PC 작업 권한 활용 실패** — 사용자가 "WSL뿐 아니라 로컬 PC 작업 권한도 있다"고 두 번이나 말했는데, 끝까지 WSL에서만 시도. `.key` 파일을 찾아 로컬 경로로 설정하는 간단한 해결책을 사용자가 직접 알려줌. **주어진 권한과 자원을 최대한 활용하여 문제를 스스로 해결해야 한다.**

## 작업 순서에서의 교훈

5. **배포 전 서비스 전체 점검 먼저** — 코드 변경 후 바로 배포하려 했으나, 사용자가 "서비스 전체 점검부터 해"라고 지적. 배포는 마지막 단계이며, 점검/개선이 먼저다.

6. **DB lint를 사전에 점검했어야** — search_posts_v2의 image_url 참조 에러는 검색 기능을 깨뜨리는 심각한 문제였다. 마이그레이션 push 후 반드시 `db.sh lint`를 실행하여 확인했어야 한다.

7. **FlashList estimatedItemSize 타입 확인 미흡** — 코드 리뷰에서 발견한 개선점을 실제 타입과 대조하지 않고 적용하여 pre-commit 실패. 외부 라이브러리의 prop 변경은 반드시 타입/문서를 먼저 확인.

## 긍정적 교훈

8. **전수 점검의 가치** — 코드를 다시 읽고 냉정하게 분석한 결과 HTML 엔티티 카운트, draft status 영구 고정, 정렬 아이콘 3개 동일 등 실질적 문제를 발견하고 수정할 수 있었다.

9. **성능 개선의 우선순위** — Realtime 이중 호출, PostCard 미메모이제이션, search O(n*m) 등 실제 영향이 큰 문제를 발견하여 수정. 이론적 개선보다 실측 가능한 문제에 집중하는 것이 효과적.

## 행동 원칙 (다음 세션부터)

- 배포 전: 서비스 전체 점검 → DB lint → 3레포 정합성 → 타입 체크 → 테스트 → 그 다음 배포
- 에러 발생 시: 멈추고 → 원인 분석 → 해결 → 재시도 (같은 명령 반복 금지)
- 재시도 전: 진행 중인 작업 취소 먼저
- 문제 해결 시: WSL, 로컬 PC, 대시보드 등 가용 자원 모두 활용
- 외부 라이브러리: 타입/문서 확인 후 적용
```

---

## project_writing_experience.md

```markdown
---
name: 글 작성 UX 개선 (2026-03-28)
description: 웹 임시저장 + 앱/웹 저장 상태 표시 구현. 감정 선택(A안)은 제거됨.
type: project
---

글 작성 경험 2가지 개선 구현 완료:

1. **웹 임시저장**: useDraft 훅 (localStorage, 1초 debounce). 페이지 진입 시 토스트로 복원 여부 확인.
2. **저장 상태 표시**: 앱/웹 모두 DraftStatus ('idle'|'saving'|'saved') 반환. 에디터 우상단 "☁️ 저장됨" / "✏️ 저장 중..." 표시.

**제거된 안:**
- A안(감정 먼저 선택 + initial_emotions) — 사용자 요청으로 제거
- B안(글감 프롬프트 65개) — A안에 의존하므로 함께 제거
- EMOTION_CHIP_CONFIG, WRITING_PROMPTS 상수 삭제

**How to apply:**
- 설계 문서: `docs/plan/DESIGN-writing-experience.md` (A/B안은 Phase 2 후보로 유지)
- 웹 useDraft: `web-hermit-comm/src/features/posts/hooks/useDraft.ts`
- 앱 useDraft 변경: DraftStatus + status 반환 추가
```

---

## reference_service_plans.md

```markdown
---
name: 서비스 플랜 및 접근 정보
description: 2026-03-22 확인된 전체 서비스 플랜, 계정, 한도, CLI 접근 방법
type: reference
---

## 서비스 플랜 (2026-03-22 전부 무료 전환)

| 서비스 | 플랜 | 월 비용 | 계정 |
|--------|------|--------|------|
| Supabase | Free (Pro→Free 다운그레이드) | $0 | qkr133456@gmail.com |
| Vercel | Hobby Plus | $0 | qkr133456@gmail.com |
| Expo/EAS | Starter | $0 | parkgunny |
| Sentry | Developer | $0 | qkr133456@gmail.com (org: gunnys) |
| Gemini API | 무료 티어 | $0 | Google API Key 기반 |

## Supabase Free 한도

| 항목 | 한도 |
|------|------|
| DB 크기 | 500MB |
| 대역폭 | 2GB |
| Edge Function 호출 | 50만/월 |
| Realtime 메시지 | 200만/월 |
| Auth MAU | 5만 |
| **비활성 일시정지** | **7일 비활성 시 자동** |

## Sentry 사용량 (30일, 2026-03-22 기준)

| 카테고리 | accepted | 월 한도 | 사용률 |
|---------|----------|--------|--------|
| Errors | 633 | 5,000 | 12.7% |
| Transactions | 266 | 10,000 | 2.7% |
| Replays | 1 | 50 | 2% |

## Sentry 프로젝트

| 프로젝트 | slug | 플랫폼 |
|---------|------|--------|
| 앱 | gns-hermit-comm | react-native |
| 웹 | web-hermit-comm | javascript-nextjs |

## DB 데이터 규모 (2026-03-22)

| 테이블 | row 수 |
|--------|--------|
| posts | 22 |
| comments | 3 |
| notifications | 156 |
| post_analysis | 22 |
| reactions | 52 |
| user_reactions | 202 |
| user_preferences | 0 |

## CLI 접근

- **Supabase**: `source .env && npx supabase login --token "$SUPABASE_ACCESS_TOKEN"`
- **Sentry**: `sentry auth status` (토큰 만료 2026-04-07)
- **Vercel**: .env의 VERCEL_ACCESS_TOKEN으로 API 호출
- **Expo**: .env의 EXPO_ACCESS_TOKEN으로 GraphQL API 호출
- **토큰들**: 중앙 레포 `.env`에 모두 보관
```

---

