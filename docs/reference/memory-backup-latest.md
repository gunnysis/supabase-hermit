# Claude 메모리 백업

> 자동 생성: 2026-03-22 02:33:38
> 소스: `~/.claude/projects/-home-gunny-apps-supabase-hermit/memory/`
> 파일 수: 20개
> 체크섬: `acf735f758dae353c46937faf1870039`

---

## MEMORY.md (인덱스)

```markdown
# 은둔마을 Supabase 중앙 프로젝트 메모리

> 정리일: 2026-03-17 | 파일 13개 | 백업: `docs/reference/memory-backup-latest.md` (자동)

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
| [feedback_docs.md](feedback_docs.md) | docs/ 4폴더 구조 + 완료 설계문서 삭제 |
| [feedback_audit_first.md](feedback_audit_first.md) | 새 대화 시 audit 4파일 먼저 읽기 |
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
| [feedback_archive_cleanup.md](feedback_archive_cleanup.md) | 작업 종료 시 아카이브 자동 정리: 같은 주제 설계 1개만, 나머지 이력에 흡수 |
| [feedback_service_review.md](feedback_service_review.md) | 동작 불가 점검 시 전체 체인 추적 + 닫기 경로 상태 초기화 + 복수 구현체 품질 편차 |
| [feedback_tab_bar_overlap.md](feedback_tab_bar_overlap.md) | 탭 화면 내 absolute/overlay 요소는 useTabBarHeight()로 탭바 높이 반영 필수 |

## 주의사항 (Quick Ref)
- WSL 환경 — `sed -i 's/\r$//'`
- shared/utils.ts — 외부 import 금지 (순수 함수만)
- boards id 시퀀스: 1, 2, 12

## 문서
- `CLAUDE.md` — 프로젝트 개요, 워크플로, 규칙 (가장 상세)
- `docs/audit/` — 코드 감사 스냅샷 4파일 (새 대화 시 먼저 읽기)
- `docs/SCHEMA.md` — DB 스키마 상세
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

## feedback_archive_cleanup.md

```markdown
---
name: 설계 완료 후 아카이브 자동 정리
description: 같은 주제 설계 문서가 여러 개 생기면 이력 문서에 흡수 + 파편 삭제 — 작업 종료 시 자동 수행
type: feedback
---

작업 종료 시 `docs/archive/` 정리를 자동 수행한다.

**규칙:**
1. 같은 주제의 DESIGN-*.md가 2개 이상이면 → 최종본 1개만 남기고 나머지 삭제
2. 삭제되는 문서의 핵심 내용은 해당 이력 문서(XX-이력.md)에 흡수
3. 이력 문서에는 **교훈**을 반드시 포함 (무엇을 했는지 + 왜 반복됐는지)

**Why:** 2026-03-18 마이페이지 설계가 4개로 파편화됨 (sync → error-strategy → ux-polish → comprehensive). 처음부터 충분히 연구하지 않아 매번 새 설계를 만들었고, 아카이브에 같은 주제 문서가 쌓여 혼란 유발.

**How to apply:** 작업 완료 후 커밋 전에:
```
ls docs/archive/DESIGN-*.md  # 같은 주제 문서 확인
# 최종본만 남기고 나머지 삭제
# 이력 문서에 교훈 포함하여 흡수
```
```

---

## feedback_audit_first.md

```markdown
---
name: audit 파일 먼저 읽기
description: 새 대화 시작 시 docs/audit/ 4개 파일을 먼저 읽어 전체 현황 파악 후 작업 시작. 탐색 에이전트 3개 대신 Read 4회로 대체.
type: feedback
---

새 대화에서 작업 시작 전 반드시 `docs/audit/` 스냅샷 4개를 먼저 읽을 것.

**Why:** 매번 3개 레포를 탐색 에이전트로 분석하면 2~3분 소모. audit 파일을 미리 유지하면 Read 4회(수초)로 전체 현황 파악 가능.

**How to apply:**
1. 대화 시작 시: `docs/audit/{central,web,app}-audit.md` + `tech-debt.md` 읽기
2. 작업 완료 후: 변경된 레포의 audit 파일 + tech-debt.md 즉시 갱신
3. 마이그레이션/타입/컴포넌트 추가/삭제 시: 해당 audit의 수량/목록 업데이트
4. 기술부채 해결 시: tech-debt.md에서 `[x]` 체크
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

## feedback_docs.md

```markdown
---
name: 문서화 규칙
description: docs/ 4폴더 구조 준수 + 완료 설계 문서는 이력 기록 후 삭제 (archive 보관 안 함)
type: feedback
---

## docs/ 4폴더 구조

| 폴더 | 용도 |
|------|------|
| `docs/plan/` | 진행 예정/진행 중 설계 문서만 (활성) |
| `docs/archive/` | 주제별 이력 문서 (01~06, 날짜+범위+핵심+결과+교훈) |
| `docs/reference/` | 외부 참조, 보류 중 설계, 메모리 백업 |
| `docs/audit/` | 코드 감사 스냅샷 (4파일) |

## 완료 설계 문서 처리

1. 이력 문서(01~06)에 항목 추가
2. 이력 기록 확인 후 → plan/의 설계 문서 **삭제** (archive로 이동하지 않음)
3. 새 주제면 `07-주제-이력.md` 생성
4. plan/에는 진행 중인 문서만 존재

**Why:** archive/에 이력 + 원본이 공존하면 중복. 7개 폴더가 난잡했던 경험 → 4개로 간소화 (2026-03-17).
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

