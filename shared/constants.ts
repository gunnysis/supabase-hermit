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

/** 반응 타입별 색상 계열 매핑 */
export const REACTION_COLOR_MAP = {
  like: 'happy',
  heart: 'coral',
  laugh: 'peach',
  sad: 'lavender',
  surprise: 'mint',
} as const

export type ReactionColorKey = keyof typeof REACTION_COLOR_MAP

/** 공유 색상 팔레트 (HEX) — 각 플랫폼에서 자체 방식으로 사용 */
export const SHARED_PALETTE = {
  happy:    { 50: '#FFF9E6', 100: '#FFF3CC', 200: '#FFE799', 300: '#FFDB66', 400: '#FFCF33', 500: '#FFC300', 600: '#CC9C00', 700: '#997500', 800: '#664E00', 900: '#332700' },
  coral:    { 50: '#FFF1F0', 100: '#FFE3E0', 200: '#FFC7C2', 300: '#FFABA3', 400: '#FF8F85', 500: '#FF7366', 600: '#E65C52', 700: '#CC453E', 800: '#B32E29', 900: '#991715' },
  mint:     { 50: '#F0FFF9', 100: '#D1FFF0', 200: '#A3FFE0', 300: '#75FFD1', 400: '#47FFC1', 500: '#19FFB2', 600: '#00E699', 700: '#00CC80', 800: '#00B366', 900: '#00994D' },
  lavender: { 50: '#F9F5FF', 100: '#F3EBFF', 200: '#E7D7FF', 300: '#DBC3FF', 400: '#CFAFFF', 500: '#C39BFF', 600: '#A77CE6', 700: '#8B5DCC', 800: '#6F3EB3', 900: '#531F99' },
  peach:    { 50: '#FFF7F0', 100: '#FFEFE0', 200: '#FFDFC2', 300: '#FFCFA3', 400: '#FFBF85', 500: '#FFAF66', 600: '#E69952', 700: '#CC833E', 800: '#B36D29', 900: '#995715' },
  cream:    { 50: '#FFFEF5', 100: '#FFFCEB', 200: '#FFF9D6', 300: '#FFF5C2', 400: '#FFF2AD', 500: '#FFEF99' },
} as const
