// 은둔마을 공유 상수 — 중앙 프로젝트에서 생성, sync-to-projects.sh로 앱/웹에 배포
// 수정 시 반드시 이 파일에서만 수정하고 sync 실행할 것

/** 허용 감정 목록 (감정 분석 Edge Function 반환값과 동일) */
export const ALLOWED_EMOTIONS = [
  '고립감', '무기력', '불안', '외로움', '슬픔',
  '그리움', '두려움', '답답함', '설렘', '기대감',
  '안도감', '평온함', '즐거움',
] as const

export type AllowedEmotion = (typeof ALLOWED_EMOTIONS)[number]

/** 감정 이모지 맵 */
export const EMOTION_EMOJI: Record<string, string> = {
  고립감: '🫥', 무기력: '😶', 불안: '😰', 외로움: '😔', 슬픔: '😢',
  그리움: '💭', 두려움: '😨', 답답함: '😤', 설렘: '💫', 기대감: '🌱',
  안도감: '😮‍💨', 평온함: '😌', 즐거움: '😊',
}
