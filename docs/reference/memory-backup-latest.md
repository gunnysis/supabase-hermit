# Claude 메모리 백업

> 자동 생성: 2026-03-17 20:37:59
> 소스: `~/.claude/projects/-home-gunny-apps-supabase-hermit/memory/`
> 파일 수: 10개
> 체크섬: `35f1634ae5008bb50d891375691a367a`

---

## MEMORY.md (인덱스)

```markdown
# 은둔마을 Supabase 중앙 프로젝트 메모리

> 정리일: 2026-03-17 | 파일 10개 | 백업: `docs/reference/memory-backup-20260317.md`

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

