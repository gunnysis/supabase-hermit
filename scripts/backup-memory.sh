#!/usr/bin/env bash
# backup-memory.sh — Claude 메모리 → docs/reference/ 백업
# 변경 감지 기반: 메모리가 바뀌었을 때만 백업 파일 갱신
set -euo pipefail

CENTRAL_DIR="${CLAUDE_PROJECT_DIR:-/home/gunny/apps/supabase-hermit}"
MEMORY_DIR="/home/gunny/.claude/projects/-home-gunny-apps-supabase-hermit/memory"
BACKUP_FILE="$CENTRAL_DIR/docs/reference/memory-backup-latest.md"
CHECKSUM_FILE="$CENTRAL_DIR/.claude/.memory-checksum"

# ── 메모리 디렉토리 존재 확인 ──
if [ ! -d "$MEMORY_DIR" ]; then
  echo "⚠️  메모리 디렉토리 없음: $MEMORY_DIR"
  exit 0
fi

# ── 변경 감지 (전체 파일 MD5) ──
CURRENT_CHECKSUM=$(find "$MEMORY_DIR" -type f -name '*.md' -exec md5sum {} + 2>/dev/null | sort | md5sum | cut -d' ' -f1)
PREVIOUS_CHECKSUM=""
if [ -f "$CHECKSUM_FILE" ]; then
  PREVIOUS_CHECKSUM=$(cat "$CHECKSUM_FILE" 2>/dev/null || echo "")
fi

if [ "$CURRENT_CHECKSUM" = "$PREVIOUS_CHECKSUM" ]; then
  echo "✅ 메모리 변경 없음 — 백업 스킵"
  exit 0
fi

# ── 백업 파일 생성 ──
FILE_COUNT=$(find "$MEMORY_DIR" -type f -name '*.md' | wc -l)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

{
  echo "# Claude 메모리 백업"
  echo ""
  echo "> 자동 생성: $TIMESTAMP"
  echo "> 소스: \`~/.claude/projects/-home-gunny-apps-supabase-hermit/memory/\`"
  echo "> 파일 수: ${FILE_COUNT}개"
  echo "> 체크섬: \`${CURRENT_CHECKSUM}\`"
  echo ""
  echo "---"
  echo ""

  # MEMORY.md 먼저
  if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
    echo "## MEMORY.md (인덱스)"
    echo ""
    echo '```markdown'
    cat "$MEMORY_DIR/MEMORY.md"
    echo '```'
    echo ""
    echo "---"
    echo ""
  fi

  # 나머지 파일 (알파벳순)
  find "$MEMORY_DIR" -type f -name '*.md' ! -name 'MEMORY.md' | sort | while read -r file; do
    filename=$(basename "$file")
    echo "## $filename"
    echo ""
    echo '```markdown'
    cat "$file"
    echo '```'
    echo ""
    echo "---"
    echo ""
  done
} > "$BACKUP_FILE"

# ── 체크섬 저장 ──
mkdir -p "$(dirname "$CHECKSUM_FILE")"
echo "$CURRENT_CHECKSUM" > "$CHECKSUM_FILE"

echo "✅ 메모리 백업 완료: $BACKUP_FILE (${FILE_COUNT}개 파일, $TIMESTAMP)"
