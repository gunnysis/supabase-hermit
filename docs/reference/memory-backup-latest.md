# 은둔마을 Supabase 중앙 프로젝트 메모리

> 정리일: 2026-03-22 | 파일 14개 | 백업: `docs/reference/memory-backup-latest.md` (자동)

## 서비스 전략
| 파일 | 핵심 |
|------|------|
| [project_dev_freeze.md](project_dev_freeze.md) | 2026-03-22 기능 개발 동결. 전 서비스 무료 전환. 월 $0. 사용자 확보 우선 |
| [reference_service_plans.md](reference_service_plans.md) | 전체 서비스 플랜/계정/한도/CLI 접근 (Supabase Free, Vercel Hobby, Expo Starter, Sentry Dev, Gemini 무료) |
| [project_session_insight_20260322.md](project_session_insight_20260322.md) | 세션 교훈: 기능 과잉 vs 사용자 부재, 비용은 데이터로 확인, 개발 멈춤이 최선일 때 |
| [project_poetry_board_removal.md](project_poetry_board_removal.md) | 시 게시판 추가 1주 만에 제거 — 기능 과잉 사례, 서비스 정체성 판단 |
| [project_writing_experience.md](project_writing_experience.md) | 글 작성 UX 개선: 웹 임시저장 + 저장 상태 표시 (A안 감정선택/B안 프롬프트는 제거) |
| [project_editor_improvement.md](project_editor_improvement.md) | 에디터 2단계 개선: 웹 밑줄/링크/정렬+SVG아이콘, 앱 글자수수정/높이확대/프로그레스바, 읽기시간, 제목카운터 |

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
