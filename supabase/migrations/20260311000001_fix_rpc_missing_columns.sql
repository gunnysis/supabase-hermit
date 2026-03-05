-- =============================================================================
-- 20260311000001_fix_rpc_missing_columns.sql
-- get_posts_by_emotion RPC에 content 등 컬럼 추가 (PostCard 렌더링 crash 수정)
-- 반환 타입 변경이므로 DROP 후 재생성
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_posts_by_emotion(TEXT, INT, INT);

CREATE FUNCTION public.get_posts_by_emotion(
  p_emotion TEXT,
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0
)
RETURNS TABLE(
  id BIGINT,
  title TEXT,
  content TEXT,
  board_id BIGINT,
  like_count INT,
  comment_count INT,
  emotions TEXT[],
  created_at TIMESTAMPTZ,
  display_name TEXT,
  author_id UUID,
  is_anonymous BOOLEAN,
  image_url TEXT,
  initial_emotions TEXT[],
  group_id BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  RETURN QUERY
  SELECT v.id, v.title, v.content, v.board_id, v.like_count, v.comment_count,
    v.emotions, v.created_at, v.display_name,
    v.author_id, v.is_anonymous, v.image_url, v.initial_emotions, v.group_id
  FROM posts_with_like_count v
  WHERE v.group_id IS NULL
    AND v.emotions IS NOT NULL
    AND p_emotion = ANY(v.emotions)
  ORDER BY v.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;
