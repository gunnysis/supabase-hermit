// 은둔마을 공유 비즈니스 타입 — 중앙 프로젝트에서 생성, sync-to-projects.sh로 앱/웹에 배포
// 수정 시 반드시 이 파일에서만 수정하고 sync 실행할 것

/** 게시판 익명 모드 */
export type AnonMode = 'always_anon' | 'allow_choice' | 'require_name'

/** 감정 분석 상태 */
export type AnalysisStatus = 'pending' | 'analyzing' | 'done' | 'failed'

export interface Board {
  id: number
  name: string
  description?: string | null
  visibility: 'public' | 'private'
  anon_mode: AnonMode
  created_at: string
  updated_at: string
}

export interface Post {
  id: number
  title: string
  content: string
  author_id: string
  created_at: string
  updated_at?: string
  deleted_at?: string | null
  board_id?: number | null
  is_anonymous: boolean
  display_name: string
  comment_count?: number
  like_count?: number
  emotions?: string[] | null
  initial_emotions?: string[] | null
  image_url?: string | null
  post_type?: 'post' | 'daily'
  activities?: string[] | null
}

/** 좋아요·댓글 수 포함 게시글 (posts_with_like_count 뷰) */
export interface PostWithCounts extends Post {
  like_count: number
  comment_count: number
  emotions: string[] | null
  post_type: 'post' | 'daily'
  activities: string[] | null
}

export interface PostAnalysis {
  id: number
  post_id: number
  emotions: string[]
  analyzed_at: string | null
  status: AnalysisStatus
  retry_count: number
  error_reason: string | null
  last_attempted_at: string | null
}

export interface Comment {
  id: number
  post_id: number
  content: string
  author_id: string
  created_at: string
  updated_at?: string
  deleted_at?: string | null
  board_id?: number | null
  is_anonymous: boolean
  display_name: string
  parent_id?: number | null
}

export interface Reaction {
  id?: number
  post_id?: number
  reaction_type: string
  count: number
}

export interface UserReaction {
  id: number
  user_id: string
  post_id: number
  reaction_type: string
  created_at: string
}

export interface ToggleReactionResponse {
  reacted: boolean
  reaction_type: string
}

export interface AppAdmin {
  user_id: string
  created_at: string
}

export interface EmotionTrend {
  emotion: string
  cnt: number
  pct?: number
}

/** 감정 기반 추천 게시글 (get_recommended_posts_by_emotion RPC 반환 타입) */
export interface RecommendedPost {
  id: number
  title: string
  board_id: number | null
  like_count: number
  comment_count: number
  emotions: string[]
  created_at: string
  score?: number
}

/** 트렌딩 게시글 (get_trending_posts RPC 반환 타입) */
export interface TrendingPost {
  id: number
  title: string
  board_id: number | null
  like_count: number
  comment_count: number
  emotions: string[] | null
  created_at: string
  display_name: string
  score: number
}

export const REACTION_TYPES = ['like', 'heart', 'laugh', 'sad', 'surprise'] as const
export type ReactionType = (typeof REACTION_TYPES)[number]

// 요청 타입
export interface CreatePostRequest {
  title: string
  content: string
  board_id?: number | null
  is_anonymous?: boolean
  display_name?: string
  image_url?: string | null
  initial_emotions?: string[] | null
}

export interface CreateCommentRequest {
  content: string
  board_id?: number | null
  is_anonymous?: boolean
  display_name?: string
}

export interface CreateReactionRequest {
  reaction_type: string
}

export interface UpdatePostRequest {
  title?: string
  content?: string
  image_url?: string | null
  initial_emotions?: string[] | null
}

export interface UpdateCommentRequest {
  content: string
}

export interface UserPreferences {
  user_id: string
  preferred_emotions: string[]
  onboarding_completed: boolean
  theme_preference: 'light' | 'dark' | 'system'
  notification_enabled: boolean
  created_at: string
  updated_at: string
}

export interface EmotionCalendarDay {
  day: string
  emotions: string[]
  post_count: number
}

export interface EmotionTimelineEntry {
  day: string
  emotion: string
  cnt: number
}

/** 검색 정렬 옵션 */
export type SearchSort = 'relevance' | 'recent' | 'popular'

/** 검색 결과 게시글 (search_posts_v2 RPC 반환 타입) */
export interface SearchResult {
  id: number
  title: string
  content: string
  board_id: number | null
  like_count: number
  comment_count: number
  emotions: string[] | null
  created_at: string
  display_name: string
  author_id: string
  is_anonymous: boolean
  image_url: string | null
  initial_emotions: string[] | null
  title_highlight: string
  content_highlight: string
  relevance_score: number
}

/** In-App 알림 (notifications 테이블) */
export interface Notification {
  id: number
  type: NotificationType
  post_id: number | null
  comment_id: number | null
  actor_alias: string | null
  read: boolean
  created_at: string
}

/** 알림 타입 */
export type NotificationType = 'reaction' | 'comment' | 'reply'

/** 사용자 차단 (user_blocks 테이블) */
export interface UserBlock {
  id: number
  blocker_id: string
  blocked_alias: string
  created_at: string
}

/** 나의 패턴 인사이트 (get_daily_activity_insights RPC 반환 타입) */
export interface ActivityInsight {
  activity: string
  total_count: number
  emotions: { emotion: string; count: number }[]
  top_emotion: string
}

/** 나의 활동 요약 (get_my_activity_summary RPC 반환 타입) */
export interface ActivitySummary {
  post_count: number
  comment_count: number
  reaction_count: number
  streak_days: number
  first_post_at: string | null
}

// 응답 타입
export type GetPostsResponse = Post[]
export type GetPostResponse = Post
export type CreatePostResponse = Post
export type UpdatePostResponse = Post
export type GetCommentsResponse = Comment[]
export type CreateCommentResponse = Comment
export type UpdateCommentResponse = Comment
export type GetReactionsResponse = Reaction[]
export type CreateReactionResponse = Reaction

// 타입 가드 함수
export function isPost(obj: unknown): obj is Post {
  if (typeof obj !== 'object' || obj === null) return false
  const post = obj as Partial<Post>
  return (
    typeof post.id === 'number' &&
    typeof post.title === 'string' &&
    typeof post.content === 'string' &&
    typeof post.author_id === 'string' &&
    typeof post.created_at === 'string' &&
    typeof post.is_anonymous === 'boolean' &&
    typeof post.display_name === 'string'
  )
}

export function isComment(obj: unknown): obj is Comment {
  if (typeof obj !== 'object' || obj === null) return false
  const comment = obj as Partial<Comment>
  return (
    typeof comment.id === 'number' &&
    typeof comment.post_id === 'number' &&
    typeof comment.content === 'string' &&
    typeof comment.author_id === 'string' &&
    typeof comment.created_at === 'string' &&
    typeof comment.is_anonymous === 'boolean' &&
    typeof comment.display_name === 'string'
  )
}
