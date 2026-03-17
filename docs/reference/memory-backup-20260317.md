# Claude 메모리 백업 — 2026-03-17

> 소스: `~/.claude/projects/-home-gunny-apps-supabase-hermit/memory/`
> 정리 전 스냅샷 (16개 파일)

---

## 파일 목록

| # | 파일 | 타입 | 설명 |
|---|------|------|------|
| 1 | MEMORY.md | index | 메모리 인덱스 |
| 2 | architecture.md | project | 3개 프로젝트 아키텍처 (구버전) |
| 3 | feedback_5role_checklist.md | feedback | 5역할 시점 질문 체크리스트 |
| 4 | feedback_archive_cleanup.md | feedback | 완료 설계 문서 삭제 규칙 |
| 5 | feedback_audit_first.md | feedback | 새 대화 시 audit 먼저 읽기 |
| 6 | feedback_deploy_verification.md | feedback | 배포 완료 확인 필수 |
| 7 | feedback_docs_structure.md | feedback | docs/ 4폴더 구조 준수 |
| 8 | feedback_edge_function_deploy.md | feedback | Edge Function --no-verify-jwt |
| 9 | feedback_expo_upgrade.md | feedback | Expo SDK 업그레이드 절차 |
| 10 | feedback_no_preset_words.md | feedback | 사용자 감정에 프리셋 금지 |
| 11 | feedback_no_test_data_in_prod.md | feedback | 테스트 데이터 삭제 필수 |
| 12 | feedback_side_effects.md | feedback | 사이드 이펙트 고려 |
| 13 | feedback_test_data_auto_check.md | feedback | 테스트 데이터 자동 감지 hook |
| 14 | feedback_v2_lessons.md | feedback | v2 작업 교훈 |
| 15 | feedback_workflow.md | feedback | 규모별 워크플로 |
| 16 | project_vercel_hobby.md | reference | Vercel Hobby 플랜 정보 |

---

## 정리 내역 (2026-03-17)

### 삭제 (2개)
- `architecture.md` → CLAUDE.md에 최신 정보 존재, 구버전 데이터(SDK 54, 22 마이그레이션)
- `feedback_side_effects.md` → `feedback_v2_lessons.md`에 동일 내용 포함

### 통합 (5개 → 2개)
- `feedback_no_test_data_in_prod.md` + `feedback_test_data_auto_check.md` → `feedback_test_data.md`
- `feedback_deploy_verification.md` + `feedback_edge_function_deploy.md` + `project_vercel_hobby.md` → `feedback_deployment.md`
- `feedback_archive_cleanup.md` + `feedback_docs_structure.md` → `feedback_docs.md`

### 결과: 16개 → 10개 (38% 감소)
