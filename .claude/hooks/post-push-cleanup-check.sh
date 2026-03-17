#!/bin/bash
# post-push-cleanup-check.sh
# git push 후 자동 실행 — 테스트 데이터 존재 여부 체크
# 최근 3시간 내 생성된 게시글이 있으면 경고 출력

set -euo pipefail

# stdin에서 hook input 읽기
INPUT=$(cat)

# git push가 아니면 무시 (jq 없이 grep으로 판별)
if ! echo "$INPUT" | grep -q "git push"; then
  exit 0
fi

# 중앙 프로젝트 경로
CENTRAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# .env 로드
if [ -f "$CENTRAL/.env" ]; then
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    value="${value%\"}"
    value="${value#\"}"
    export "$key=$value" 2>/dev/null || true
  done < "$CENTRAL/.env"
fi

SUPABASE_URL="${EXPO_PUBLIC_SUPABASE_URL:-}"
SERVICE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"

if [ -z "$SUPABASE_URL" ] || [ -z "$SERVICE_KEY" ]; then
  exit 0
fi

# 최근 3시간 내 게시글 수 조회
THREE_HOURS_AGO=$(date -u -d '3 hours ago' '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -u -v-3H '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "")

if [ -z "$THREE_HOURS_AGO" ]; then
  exit 0
fi

# Supabase REST API로 count 조회 (HEAD + Prefer: count=exact)
HEADERS=$(curl -s -I \
  -H "apikey: ${SERVICE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_KEY}" \
  -H "Prefer: count=exact" \
  -H "Range: 0-0" \
  "${SUPABASE_URL}/rest/v1/posts?select=id&created_at=gte.${THREE_HOURS_AGO}" \
  2>/dev/null || echo "")

if [ -z "$HEADERS" ]; then
  exit 0
fi

# Content-Range: 0-0/N 에서 N 추출
COUNT=$(echo "$HEADERS" | grep -i "content-range" | sed 's/.*\///' | tr -d '[:space:]' || echo "0")

if [ -z "$COUNT" ] || [ "$COUNT" = "0" ] || [ "$COUNT" = "*" ]; then
  exit 0
fi

# 테스트 데이터 발견 시 경고
echo "" >&2
echo "⚠️  테스트 데이터 감지: 최근 3시간 내 생성된 게시글 ${COUNT}개" >&2
echo "   정리 필요 시: admin_cleanup_posts RPC 또는 관리자 대시보드 사용" >&2
echo "" >&2

exit 0
