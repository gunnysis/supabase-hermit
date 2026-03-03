#!/usr/bin/env bash
# db.sh — Supabase DB 관리 래퍼 (토큰 자동 로드)
#
# 사용법:
#   bash scripts/db.sh push              # migration 적용 → 자동 gen-types + sync
#   bash scripts/db.sh push --dry-run    # dry-run (gen-types/sync 안 함)
#   bash scripts/db.sh pull              # remote → local diff
#   bash scripts/db.sh diff              # remote 스키마 diff
#   bash scripts/db.sh lint              # RLS/스키마 린트
#   bash scripts/db.sh status            # migration 상태 확인
#   bash scripts/db.sh gen-types         # DB 타입 생성

set -euo pipefail

CENTRAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CENTRAL"

# .env에서 토큰 로드
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  echo "❌ SUPABASE_ACCESS_TOKEN이 설정되지 않았습니다."
  echo "   .env 파일을 확인하세요."
  exit 1
fi

CMD="${1:-status}"
shift 2>/dev/null || true

# dry-run 여부 확인 (push에서 사용)
IS_DRY_RUN=false
for arg in "$@"; do
  [ "$arg" = "--dry-run" ] && IS_DRY_RUN=true
done

case "$CMD" in
  push)
    echo "=== db push ==="
    npx supabase db push --linked "$@"

    # dry-run이 아닌 경우에만 자동 gen-types + sync
    if ! $IS_DRY_RUN; then
      echo ""
      echo "=== 자동 후처리: gen-types → sync ==="
      bash "$CENTRAL/scripts/gen-types.sh"
      echo ""
      bash "$CENTRAL/scripts/sync-to-projects.sh"
    fi
    ;;
  pull)
    echo "=== db pull (schema diff → new migration) ==="
    npx supabase db pull --linked "$@"
    ;;
  diff)
    echo "=== db diff ==="
    npx supabase db diff --linked "$@"
    ;;
  lint)
    echo "=== db lint ==="
    npx supabase db lint --linked "$@"
    ;;
  gen-types)
    bash "$CENTRAL/scripts/gen-types.sh"
    ;;
  status)
    echo "=== migration status ==="
    echo "중앙 프로젝트: $CENTRAL"
    echo ""
    echo "로컬 마이그레이션:"
    ls -1 supabase/migrations/*.sql 2>/dev/null | while read f; do
      echo "  $(basename "$f")"
    done
    echo ""
    echo "Remote 상태:"
    npx supabase db push --linked --dry-run 2>&1
    ;;
  *)
    echo "사용법: bash scripts/db.sh {push|pull|diff|lint|status|gen-types}"
    exit 1
    ;;
esac
