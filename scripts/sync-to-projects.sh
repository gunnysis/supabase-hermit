#!/usr/bin/env bash
# sync-to-projects.sh — 중앙 Supabase 프로젝트 → 앱/웹 레포로 동기화
#
# 동기화 대상:
#   1. migrations (SQL 파일)
#   2. config.toml (Supabase 프로젝트 설정)
#   3. types/database.gen.ts (자동 생성 DB 타입)
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
CENTRAL_CONFIG="$CENTRAL/supabase/config.toml"
CENTRAL_TYPES="$CENTRAL/types/database.gen.ts"
CENTRAL_SHARED_CONSTANTS="$CENTRAL/shared/constants.ts"
CENTRAL_SHARED_TYPES="$CENTRAL/shared/types.ts"

echo "=== 은둔마을 Supabase 동기화 ==="
echo "중앙: $CENTRAL"
$DRY_RUN && echo "🔍 DRY RUN 모드 (변경 없음)"
echo ""

# 총 변경 카운터
TOTAL_CHANGES=0

# --- A) Migrations 동기화 ---
sync_migrations() {
  local name="$1"
  local target="$2/supabase/migrations"
  local added=0
  local skipped=0

  echo "  [migrations]"

  if [ ! -d "$target" ]; then
    echo "    ⚠️  대상 디렉터리 없음: $target"
    if ! $DRY_RUN; then
      mkdir -p "$target"
      echo "    📁 디렉터리 생성됨"
    fi
  fi

  for file in "$CENTRAL_MIGRATIONS"/*.sql; do
    [ -f "$file" ] || continue
    local filename="$(basename "$file")"
    local dest="$target/$filename"

    if [ ! -f "$dest" ]; then
      echo "    ➕ 추가: $filename"
      $DRY_RUN || cp "$file" "$dest"
      added=$((added + 1))
    else
      if ! diff -q "$file" "$dest" > /dev/null 2>&1; then
        echo "    🔄 덮어쓰기: $filename"
        $DRY_RUN || cp "$file" "$dest"
        added=$((added + 1))
      else
        skipped=$((skipped + 1))
      fi
    fi
  done

  # 대상에만 있는 파일 경고
  if [ -d "$target" ]; then
    for file in "$target"/*.sql; do
      [ -f "$file" ] || continue
      local filename="$(basename "$file")"
      if [ ! -f "$CENTRAL_MIGRATIONS/$filename" ]; then
        echo "    🚨 중앙에 없는 migration: $filename"
      fi
    done
  fi

  echo "    결과: $added 변경, $skipped 동일"
  TOTAL_CHANGES=$((TOTAL_CHANGES + added))
}

# --- B) config.toml 동기화 ---
sync_config() {
  local name="$1"
  local target="$2/supabase/config.toml"

  echo "  [config.toml]"

  if [ ! -f "$CENTRAL_CONFIG" ]; then
    echo "    ⚠️  중앙 config.toml 없음, 건너뜀"
    return
  fi

  # 대상 supabase 디렉터리 확인
  local target_dir="$(dirname "$target")"
  if [ ! -d "$target_dir" ]; then
    echo "    📁 디렉터리 생성: $target_dir"
    $DRY_RUN || mkdir -p "$target_dir"
  fi

  if [ ! -f "$target" ]; then
    echo "    ➕ 추가: config.toml"
    $DRY_RUN || cp "$CENTRAL_CONFIG" "$target"
    TOTAL_CHANGES=$((TOTAL_CHANGES + 1))
  elif ! diff -q "$CENTRAL_CONFIG" "$target" > /dev/null 2>&1; then
    echo "    🔄 덮어쓰기: config.toml"
    $DRY_RUN || cp "$CENTRAL_CONFIG" "$target"
    TOTAL_CHANGES=$((TOTAL_CHANGES + 1))
  else
    echo "    ✓ 동일"
  fi
}

# --- C) types 동기화 ---
sync_types() {
  local name="$1"
  local target="$2/src/types/database.gen.ts"

  echo "  [types]"

  if [ ! -f "$CENTRAL_TYPES" ]; then
    echo "    ⚠️  중앙 types 없음 (bash scripts/gen-types.sh 먼저 실행)"
    return
  fi

  local target_dir="$(dirname "$target")"
  if [ ! -d "$target_dir" ]; then
    echo "    📁 디렉터리 생성: $target_dir"
    $DRY_RUN || mkdir -p "$target_dir"
  fi

  if [ ! -f "$target" ]; then
    echo "    ➕ 추가: database.gen.ts"
    $DRY_RUN || cp "$CENTRAL_TYPES" "$target"
    TOTAL_CHANGES=$((TOTAL_CHANGES + 1))
  elif ! diff -q "$CENTRAL_TYPES" "$target" > /dev/null 2>&1; then
    echo "    🔄 덮어쓰기: database.gen.ts"
    $DRY_RUN || cp "$CENTRAL_TYPES" "$target"
    TOTAL_CHANGES=$((TOTAL_CHANGES + 1))
  else
    echo "    ✓ 동일"
  fi
}

# --- D) shared 상수/타입 동기화 ---
sync_shared() {
  local name="$1"
  local repo="$2"

  echo "  [shared]"

  # 앱: src/shared/lib/constants.generated.ts, src/types/database.types.ts
  # 웹: src/lib/constants.generated.ts, src/types/database.types.ts
  local constants_target types_target
  if [ "$name" = "앱" ]; then
    constants_target="$repo/src/shared/lib/constants.generated.ts"
    types_target="$repo/src/types/database.types.ts"
  else
    constants_target="$repo/src/lib/constants.generated.ts"
    types_target="$repo/src/types/database.types.ts"
  fi

  # 상수 파일
  if [ -f "$CENTRAL_SHARED_CONSTANTS" ]; then
    local target_dir="$(dirname "$constants_target")"
    [ -d "$target_dir" ] || { $DRY_RUN || mkdir -p "$target_dir"; }

    if [ ! -f "$constants_target" ]; then
      echo "    ➕ 추가: $(basename "$constants_target")"
      $DRY_RUN || cp "$CENTRAL_SHARED_CONSTANTS" "$constants_target"
      TOTAL_CHANGES=$((TOTAL_CHANGES + 1))
    elif ! diff -q "$CENTRAL_SHARED_CONSTANTS" "$constants_target" > /dev/null 2>&1; then
      echo "    🔄 덮어쓰기: $(basename "$constants_target")"
      $DRY_RUN || cp "$CENTRAL_SHARED_CONSTANTS" "$constants_target"
      TOTAL_CHANGES=$((TOTAL_CHANGES + 1))
    else
      echo "    ✓ constants 동일"
    fi
  fi

  # 타입 파일
  if [ -f "$CENTRAL_SHARED_TYPES" ]; then
    local target_dir="$(dirname "$types_target")"
    [ -d "$target_dir" ] || { $DRY_RUN || mkdir -p "$target_dir"; }

    if [ ! -f "$types_target" ]; then
      echo "    ➕ 추가: $(basename "$types_target")"
      $DRY_RUN || cp "$CENTRAL_SHARED_TYPES" "$types_target"
      TOTAL_CHANGES=$((TOTAL_CHANGES + 1))
    elif ! diff -q "$CENTRAL_SHARED_TYPES" "$types_target" > /dev/null 2>&1; then
      echo "    🔄 덮어쓰기: $(basename "$types_target")"
      $DRY_RUN || cp "$CENTRAL_SHARED_TYPES" "$types_target"
      TOTAL_CHANGES=$((TOTAL_CHANGES + 1))
    else
      echo "    ✓ types 동일"
    fi
  fi
}

# --- 레포별 동기화 실행 ---
sync_to_repo() {
  local name="$1"
  local repo="$2"

  echo "--- [$name] $repo ---"

  if [ ! -d "$repo" ]; then
    echo "  ❌ 레포 경로 없음: $repo"
    echo ""
    return
  fi

  sync_migrations "$name" "$repo"
  sync_config "$name" "$repo"
  sync_types "$name" "$repo"
  sync_shared "$name" "$repo"
  echo ""
}

$SYNC_APP && sync_to_repo "앱" "$APP_REPO"
$SYNC_WEB && sync_to_repo "웹" "$WEB_REPO"

# --- 검증 리포트 ---
echo "=== 동기화 결과 ==="
CENTRAL_COUNT=$(ls -1 "$CENTRAL_MIGRATIONS"/*.sql 2>/dev/null | wc -l)
echo "중앙 migration 수: $CENTRAL_COUNT"

if $SYNC_APP && [ -d "$APP_REPO/supabase/migrations" ]; then
  APP_COUNT=$(ls -1 "$APP_REPO/supabase/migrations"/*.sql 2>/dev/null | wc -l)
  echo "앱 migration 수:  $APP_COUNT"
  [ "$CENTRAL_COUNT" != "$APP_COUNT" ] && echo "  ⚠️  파일 수 불일치!"
fi

if $SYNC_WEB && [ -d "$WEB_REPO/supabase/migrations" ]; then
  WEB_COUNT=$(ls -1 "$WEB_REPO/supabase/migrations"/*.sql 2>/dev/null | wc -l)
  echo "웹 migration 수:  $WEB_COUNT"
  [ "$CENTRAL_COUNT" != "$WEB_COUNT" ] && echo "  ⚠️  파일 수 불일치!"
fi

echo ""
if [ "$TOTAL_CHANGES" -eq 0 ]; then
  echo "✅ 모든 파일이 이미 동기화되어 있습니다."
else
  $DRY_RUN && echo "🔍 $TOTAL_CHANGES 개 변경 예정 (dry run)" || echo "✅ $TOTAL_CHANGES 개 파일 동기화 완료"
fi
