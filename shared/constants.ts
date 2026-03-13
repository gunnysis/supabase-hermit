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

/** 감정별 고유 컬러 매핑 (gradient + category) */
export const EMOTION_COLOR_MAP: Record<string, {
  family: string; gradient: [string, string]; category: 'positive' | 'negative' | 'neutral'
}> = {
  '고립감': { family: 'lavender', gradient: ['#F3EBFF', '#E7D7FF'], category: 'negative' },
  '무기력': { family: 'lavender', gradient: ['#F9F5FF', '#F3EBFF'], category: 'negative' },
  '불안':   { family: 'coral',    gradient: ['#FFF1F0', '#FFE3E0'], category: 'negative' },
  '외로움': { family: 'lavender', gradient: ['#F3EBFF', '#DBC3FF'], category: 'negative' },
  '슬픔':   { family: 'lavender', gradient: ['#E7D7FF', '#DBC3FF'], category: 'negative' },
  '그리움': { family: 'peach',    gradient: ['#FFF7F0', '#FFDFC2'], category: 'neutral' },
  '두려움': { family: 'coral',    gradient: ['#FFE3E0', '#FFC7C2'], category: 'negative' },
  '답답함': { family: 'peach',    gradient: ['#FFEFE0', '#FFCFA3'], category: 'negative' },
  '설렘':   { family: 'happy',    gradient: ['#FFF9E6', '#FFE799'], category: 'positive' },
  '기대감': { family: 'mint',     gradient: ['#F0FFF9', '#D1FFF0'], category: 'positive' },
  '안도감': { family: 'mint',     gradient: ['#D1FFF0', '#A3FFE0'], category: 'positive' },
  '평온함': { family: 'cream',    gradient: ['#FFFEF5', '#FFF9D6'], category: 'positive' },
  '즐거움': { family: 'happy',    gradient: ['#FFF3CC', '#FFDB66'], category: 'positive' },
}

/** 모션 프리셋 (앱/웹 공유) */
export const MOTION = {
  spring: {
    gentle:  { tension: 120, friction: 14 },
    bouncy:  { tension: 200, friction: 8 },
    quick:   { tension: 300, friction: 20 },
    button:  { tension: 300, friction: 8 },
    release: { tension: 200, friction: 4 },
    fab:     { tension: 120, friction: 5 },
    card:    { tension: 200, friction: 8 },
    cardAlt: { tension: 150, friction: 4 },
    tab:     { tension: 180, friction: 7 },
  },
  timing: { fast: 150, medium: 250, slow: 400 },
  easing: {
    emphasized: 'cubic-bezier(0.16, 1, 0.3, 1)',
    standard: 'cubic-bezier(0.2, 0, 0, 1)',
  },
} as const

/** 감성적 빈 상태 메시지 */
export const EMPTY_STATE_MESSAGES = {
  feed: { title: '아직 이야기가 없어요', description: '첫 번째 이야기를 나눠보세요.\n당신의 마음을 들을 준비가 되어 있어요.' },
  emotion_filter: { title: '이 감정의 이야기가 아직 없어요', description: '비슷한 마음을 느끼고 있다면,\n용기 내어 이야기해 주세요.' },
  comments: { title: '아직 댓글이 없어요', description: '따뜻한 한마디가\n누군가에게 큰 위로가 될 수 있어요.' },
  recommendations: { title: '추천할 이야기를 찾고 있어요', description: '곧 비슷한 마음의 이야기를\n찾아드릴게요.' },
  search: { title: '검색 결과가 없어요', description: '다른 키워드로 검색하거나\n감정으로 탐색해보세요.' },
  search_emotion: { title: '이 감정의 이야기가 아직 없어요', description: '비슷한 마음을 느끼고 있다면,\n용기 내어 이야기해 주세요.' },
} as const

/** 시간대별 인사말 */
export const GREETING_MESSAGES = {
  morning:   { greeting: '좋은 아침이에요', message: '오늘 하루도 천천히 시작해요.' },
  afternoon: { greeting: '좋은 오후예요', message: '잠시 쉬어가도 괜찮아요.' },
  evening:   { greeting: '편안한 저녁이에요', message: '오늘 하루 수고했어요.' },
  night:     { greeting: '고요한 밤이에요', message: '마음이 편안해지길 바라요.' },
} as const

/** 검색 하이라이트 색상 (앱/웹 공유) */
export const SEARCH_HIGHLIGHT = {
  light: '#FFF3CC',
  dark: '#664E00',
} as const

/** 검색 정렬 옵션 (앱/웹 공유) */
export const SEARCH_SORT_OPTIONS = [
  { value: 'relevance', label: '관련도순' },
  { value: 'recent', label: '최신순' },
  { value: 'popular', label: '인기순' },
] as const

/** 검색 설정 */
export const SEARCH_CONFIG = {
  DEBOUNCE_MS: 400,
  PAGE_SIZE: 20,
  MIN_QUERY_LENGTH: 2,
  RECENT_MAX: 8,
  STALE_TIME_MS: 30_000,
  EMOTION_ONLY_LIMIT: 50,
  RESULT_TITLE_LINES: 2,
  RESULT_CONTENT_LINES: 3,
  RESULT_MAX_EMOTIONS: 2,
} as const

/** 관리자 관련 상수 */
export const ADMIN_CONSTANTS = {
  BOARD_NAME_MAX_LENGTH: 100,
  BOARD_DESC_MAX_LENGTH: 500,
} as const

/** 감정 분석 상태값 */
export const ANALYSIS_STATUS = {
  PENDING: 'pending',
  ANALYZING: 'analyzing',
  DONE: 'done',
  FAILED: 'failed',
} as const

/** 감정 분석 설정 */
export const ANALYSIS_CONFIG = {
  MAX_POLLING_MS: 2 * 60 * 1000,
  POLLING_INTERVAL_MS: 5_000,
  MAX_FALLBACK_RETRIES: 2,
  FALLBACK_DELAYS: [10_000, 20_000] as readonly number[],
  MAX_RETRY_COUNT: 3,
  STALE_TIME_MS: 5 * 60 * 1000,
  INNER_REFETCH_DELAY_MS: 3_000,
  COOLDOWN_SECONDS: 60,
} as const

/** 입력 길이 제한 */
export const VALIDATION = {
  POST_TITLE_MAX: 100,
  POST_CONTENT_MAX: 5_000,
  POST_CONTENT_MIN: 1,
  COMMENT_MAX: 1_000,
  COMMENT_MIN: 1,
} as const

/** 공유 색상 팔레트 (HEX) — 각 플랫폼에서 자체 방식으로 사용 */
export const SHARED_PALETTE = {
  happy:    { 50: '#FFF9E6', 100: '#FFF3CC', 200: '#FFE799', 300: '#FFDB66', 400: '#FFCF33', 500: '#FFC300', 600: '#CC9C00', 700: '#997500', 800: '#664E00', 900: '#332700' },
  coral:    { 50: '#FFF1F0', 100: '#FFE3E0', 200: '#FFC7C2', 300: '#FFABA3', 400: '#FF8F85', 500: '#FF7366', 600: '#E65C52', 700: '#CC453E', 800: '#B32E29', 900: '#991715' },
  mint:     { 50: '#F0FFF9', 100: '#D1FFF0', 200: '#A3FFE0', 300: '#75FFD1', 400: '#47FFC1', 500: '#19FFB2', 600: '#00E699', 700: '#00CC80', 800: '#00B366', 900: '#00994D' },
  lavender: { 50: '#F9F5FF', 100: '#F3EBFF', 200: '#E7D7FF', 300: '#DBC3FF', 400: '#CFAFFF', 500: '#C39BFF', 600: '#A77CE6', 700: '#8B5DCC', 800: '#6F3EB3', 900: '#531F99' },
  peach:    { 50: '#FFF7F0', 100: '#FFEFE0', 200: '#FFDFC2', 300: '#FFCFA3', 400: '#FFBF85', 500: '#FFAF66', 600: '#E69952', 700: '#CC833E', 800: '#B36D29', 900: '#995715' },
  cream:    { 50: '#FFFEF5', 100: '#FFFCEB', 200: '#FFF9D6', 300: '#FFF5C2', 400: '#FFF2AD', 500: '#FFEF99' },
} as const
