#!/usr/bin/env bash
# sync-to-projects.sh — 중앙 Supabase 프로젝트 → 앱/웹 레포로 migrations 동기화
#
# 사용법:
#   bash scripts/sync-to-projects.sh          # 양쪽 모두
#   bash scripts/sync-to-projects.sh --app    # 앱만
#   bash scripts/sync-to-projects.sh --web    # 웹만
#   bash scripts/sync-to-projects.sh --dry    # 변경 없이 확인만

set -euo pipefail

CENTRAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_REPO="/mnt/c/Users/Administrator/programming/apps/gns-hermit-comm"
WEB_REPO="/home/gunny/apps/web"

SYNC_APP=true
SYNC_WEB=true
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --app) SYNC_WEB=false ;;
    --web) SYNC_APP=false ;;
    --dry) DRY_RUN=true ;;
  esac
done

CENTRAL_MIGRATIONS="$CENTRAL/supabase/migrations"

echo "=== 은둔마을 Supabase 동기화 ==="
echo "중앙: $CENTRAL_MIGRATIONS"
$DRY_RUN && echo "🔍 DRY RUN 모드 (변경 없음)"
echo ""

sync_to_repo() {
  local name="$1"
  local target="$2/supabase/migrations"
  local added=0
  local skipped=0

  echo "--- [$name] ---"

  if [ ! -d "$target" ]; then
    echo "  ⚠️  대상 디렉터리 없음: $target"
    if ! $DRY_RUN; then
      mkdir -p "$target"
      echo "  📁 디렉터리 생성됨"
    fi
  fi

  # 중앙 → 대상: 없는 파일 복사
  for file in "$CENTRAL_MIGRATIONS"/*.sql; do
    local filename="$(basename "$file")"
    local dest="$target/$filename"

    if [ ! -f "$dest" ]; then
      echo "  ➕ 추가: $filename"
      $DRY_RUN || cp "$file" "$dest"
      added=$((added + 1))
    else
      # 내용 비교
      if ! diff -q "$file" "$dest" > /dev/null 2>&1; then
        echo "  ⚠️  내용 불일치: $filename"
        echo "     중앙 기준으로 덮어쓸까요? (중앙이 정본)"
        if ! $DRY_RUN; then
          cp "$file" "$dest"
          echo "     → 덮어씀"
          added=$((added + 1))
        fi
      else
        skipped=$((skipped + 1))
      fi
    fi
  done

  # 대상에만 있는 파일 경고 (중앙에 없는 migration = 위반)
  if [ -d "$target" ]; then
    for file in "$target"/*.sql; do
      [ -f "$file" ] || continue
      local filename="$(basename "$file")"
      if [ ! -f "$CENTRAL_MIGRATIONS/$filename" ]; then
        echo "  🚨 중앙에 없는 migration: $filename"
        echo "     → 중앙에 먼저 추가하세요 (이 파일은 정본이 아닙니다)"
      fi
    done
  fi

  echo "  결과: $added 추가, $skipped 동일"
  echo ""
}

$SYNC_APP && sync_to_repo "앱" "$APP_REPO"
$SYNC_WEB && sync_to_repo "웹" "$WEB_REPO"

echo "=== 동기화 완료 ==="
