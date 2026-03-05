// 은둔마을 공유 비즈니스 타입 — 중앙 프로젝트에서 생성, sync-to-projects.sh로 앱/웹에 배포
// 수정 시 반드시 이 파일에서만 수정하고 sync 실행할 것

/** 게시판 익명 모드 */
export type AnonMode = 'always_anon' | 'allow_choice' | 'require_name'

/** 그룹 참여 방식 */
export type JoinMode = 'invite_only' | 'request_approve' | 'code_join'

/** 그룹 멤버 역할 */
export type MemberRole = 'owner' | 'member' | 'moderator'

/** 그룹 멤버 상태 */
export type MemberStatus = 'pending' | 'approved' | 'rejected' | 'left'

/** 감정 분석 상태 */
export type AnalysisStatus = 'pending' | 'completed' | 'failed' | 'skipped'

export interface Group {
  id: number
  name: string
  description: string | null
  owner_id: string
  join_mode: JoinMode
  invite_code: string | null
  created_at: string
  updated_at: string
}

export interface Board {
  id: number
  name: string
  description?: string | null
  visibility: 'public' | 'private'
  anon_mode: AnonMode
  /** 그룹 전용 게시판일 때 설정 */
  group_id?: number | null
  created_at: string
  updated_at: string
}

export interface GroupMember {
  id: number
  group_id: number
  user_id: string
  role: MemberRole
  status: MemberStatus
  nickname: string | null
  joined_at: string
  left_at: string | null
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
  group_id?: number | null
  member_id?: number | null
  is_anonymous: boolean
  display_name: string
  comment_count?: number
  like_count?: number
  emotions?: string[] | null
  image_url?: string | null
}

/** 좋아요·댓글 수 포함 게시글 (posts_with_like_count 뷰) */
export interface PostWithCounts extends Post {
  like_count: number
  comment_count: number
  emotions: string[] | null
}

export interface PostAnalysis {
  id: number
  post_id: number
  emotions: string[]
  analyzed_at: string
  status?: AnalysisStatus
  confidence?: number
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
  group_id?: number | null
  is_anonymous: boolean
  display_name: string
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
}

export const REACTION_TYPES = ['like', 'heart', 'laugh', 'sad', 'surprise'] as const
export type ReactionType = (typeof REACTION_TYPES)[number]

// 요청 타입
export interface CreatePostRequest {
  title: string
  content: string
  board_id?: number | null
  group_id?: number | null
  is_anonymous?: boolean
  display_name?: string
  image_url?: string | null
}

export interface CreateCommentRequest {
  content: string
  board_id?: number | null
  group_id?: number | null
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
}

export interface UpdateCommentRequest {
  content: string
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
