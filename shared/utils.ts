// 은둔마을 공유 순수 유틸 함수 — 중앙 프로젝트에서 생성, sync-to-projects.sh로 앱/웹에 배포
// 수정 시 반드시 이 파일에서만 수정하고 sync 실행할 것
// 주의: 외부 import 없는 순수 함수만 추가할 것 (sync 후 빌드 안전성)

/** 초대 코드 자동 생성 (6자리 영숫자 대문자) */
export function generateInviteCode(): string {
  return Math.random().toString(36).slice(2, 8).toUpperCase()
}

/** 그룹 생성 입력 검증 — 유효하면 null, 에러 시 메시지 반환 */
export function validateGroupInput(input: {
  name: string
  inviteCode?: string
  description?: string
}): string | null {
  const name = input.name.trim()
  if (!name) return '그룹 이름을 입력해주세요.'
  if (name.length > 100) return '그룹 이름은 100자 이내로 입력해주세요.'

  if (input.inviteCode?.trim()) {
    const code = input.inviteCode.trim()
    if (code.length < 4) return '초대 코드는 4자 이상이어야 합니다.'
    if (code.length > 50) return '초대 코드는 50자 이내로 입력해주세요.'
  }

  if (input.description && input.description.length > 500) {
    return '설명은 500자 이내로 입력해주세요.'
  }

  return null
}
