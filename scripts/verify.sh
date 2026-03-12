#!/usr/bin/env bash
# verify.sh — 레포 간 정합성 검증
#
# 중앙/앱/웹 레포의 마이그레이션, 타입, 상수가 동기화되었는지 확인
#
# 사용법:
#   bash scripts/verify.sh              # 전체 검증
#   bash scripts/verify.sh --quiet      # 요약만 출력
#   bash scripts/verify.sh --app        # 앱만 검증
#   bash scripts/verify.sh --web        # 웹만 검증
#
# 환경변수:
#   HERMIT_APP_REPO, HERMIT_WEB_REPO로 레포 경로 커스터마이즈 가능

set -euo pipefail

CENTRAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_REPO="${HERMIT_APP_REPO:-/mnt/c/Users/Administrator/programming/apps/gns-hermit-comm}"
WEB_REPO="${HERMIT_WEB_REPO:-/home/gunny/apps/web-hermit-comm}"

CHECK_APP=true
CHECK_WEB=true
QUIET=false

for arg in "$@"; do
  case "$arg" in
    --app) CHECK_WEB=false ;;
    --web) CHECK_APP=false ;;
    --quiet) QUIET=true ;;
  esac
done

ERRORS=0
WARNINGS=0

log() { $QUIET || echo "$@"; }
log_always() { echo "$@"; }

# 파일 해시 비교 (헤더 줄 수 무시하는 옵션 포함)
compare_files() {
  local label="$1"
  local src="$2"
  local dst="$3"
  local skip_lines="${4:-0}"  # 비교 시 무시할 상단 줄 수

  if [ ! -f "$src" ]; then
    log "  !! 소스 없음: $src"
    ERRORS=$((ERRORS + 1))
    return
  fi

  if [ ! -f "$dst" ]; then
    log "  !! 대상 없음: $dst"
    ERRORS=$((ERRORS + 1))
    return
  fi

  local src_hash dst_hash
  if [ "$skip_lines" -gt 0 ]; then
    src_hash="$(tail -n +"$((skip_lines + 1))" "$src" | md5sum | cut -d' ' -f1)"
    dst_hash="$(tail -n +"$((skip_lines + 1))" "$dst" | md5sum | cut -d' ' -f1)"
  else
    src_hash="$(md5sum "$src" | cut -d' ' -f1)"
    dst_hash="$(md5sum "$dst" | cut -d' ' -f1)"
  fi

  if [ "$src_hash" = "$dst_hash" ]; then
    log "  = $label"
  else
    log "  !! $label — 불일치"
    ERRORS=$((ERRORS + 1))
  fi
}

# 마이그레이션 수 검증
verify_migrations() {
  local name="$1"
  local repo="$2"
  local central_dir="$CENTRAL/supabase/migrations"
  local target_dir="$repo/supabase/migrations"

  log "  [migrations]"

  if [ ! -d "$target_dir" ]; then
    log "    !! 대상 migrations 디렉터리 없음"
    ERRORS=$((ERRORS + 1))
    return
  fi

  local central_count target_count
  central_count=$(ls -1 "$central_dir"/*.sql 2>/dev/null | wc -l)
  target_count=$(ls -1 "$target_dir"/*.sql 2>/dev/null | wc -l)

  if [ "$central_count" != "$target_count" ]; then
    log "    !! 파일 수 불일치: 중앙=$central_count, $name=$target_count"
    ERRORS=$((ERRORS + 1))
  else
    log "    = 파일 수 일치 ($central_count)"
  fi

  # 개별 파일 해시 비교
  local mismatched=0
  for file in "$central_dir"/*.sql; do
    [ -f "$file" ] || continue
    local filename="$(basename "$file")"
    local dest="$target_dir/$filename"
    if [ ! -f "$dest" ]; then
      log "    !! 누락: $filename"
      mismatched=$((mismatched + 1))
    elif ! diff -q "$file" "$dest" > /dev/null 2>&1; then
      log "    !! 내용 불일치: $filename"
      mismatched=$((mismatched + 1))
    fi
  done

  if [ "$mismatched" -gt 0 ]; then
    ERRORS=$((ERRORS + mismatched))
  fi
}

# 레포별 검증
verify_repo() {
  local name="$1"
  local repo="$2"

  log "--- [$name] $repo ---"

  if [ ! -d "$repo" ]; then
    log "  !! 레포 경로 없음"
    ERRORS=$((ERRORS + 1))
    log ""
    return
  fi

  verify_migrations "$name" "$repo"

  # config.toml
  compare_files "config.toml" \
    "$CENTRAL/supabase/config.toml" \
    "$repo/supabase/config.toml"

  # database.gen.ts (헤더 3줄 무시)
  compare_files "database.gen.ts" \
    "$CENTRAL/types/database.gen.ts" \
    "$repo/src/types/database.gen.ts" \
    3

  # shared 파일들
  local constants_target types_target
  if [ "$name" = "앱" ]; then
    constants_target="$repo/src/shared/lib/constants.generated.ts"
  else
    constants_target="$repo/src/lib/constants.generated.ts"
  fi
  types_target="$repo/src/types/database.types.ts"

  compare_files "constants.generated.ts" \
    "$CENTRAL/shared/constants.ts" \
    "$constants_target"

  compare_files "database.types.ts" \
    "$CENTRAL/shared/types.ts" \
    "$types_target"

  # utils.generated.ts
  local utils_target
  if [ "$name" = "앱" ]; then
    utils_target="$repo/src/shared/lib/utils.generated.ts"
  else
    utils_target="$repo/src/lib/utils.generated.ts"
  fi
  compare_files "utils.generated.ts" \
    "$CENTRAL/shared/utils.ts" \
    "$utils_target"

  # shared-palette.js (앱만, 소스와 대상 모두 존재할 때만)
  if [ "$name" = "앱" ] && [ -f "$CENTRAL/shared/palette.cjs" ] && [ -f "$repo/shared-palette.js" ]; then
    compare_files "shared-palette.js" \
      "$CENTRAL/shared/palette.cjs" \
      "$repo/shared-palette.js"
  fi

  log ""
}

log "=== 레포 간 정합성 검증 ==="
log "중앙: $CENTRAL"
log ""

if $CHECK_APP; then verify_repo "앱" "$APP_REPO"; fi
if $CHECK_WEB; then verify_repo "웹" "$WEB_REPO"; fi

# 결과 요약
if [ "$ERRORS" -eq 0 ]; then
  log_always "검증 완료: 모든 파일 동기화 상태"
  exit 0
else
  log_always "검증 완료: $ERRORS 건 불일치 발견 (bash scripts/sync-to-projects.sh 실행 필요)"
  exit 1
fi
