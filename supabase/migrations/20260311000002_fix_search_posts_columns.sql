-- =============================================================================
-- 20260311000002_fix_search_posts_columns.sql
-- search_posts RPC에 누락 컬럼 추가 (PostCard 렌더링 crash 수정)
-- 반환 타입 변경이므로 DROP 후 재생성
-- =============================================================================

DROP FUNCTION IF EXISTS public.search_posts(TEXT, INTEGER, INTEGER);

CREATE FUNCTION public.search_posts(
  p_query TEXT,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
) RETURNS TABLE(
  id BIGINT,
  title TEXT,
  content TEXT,
  board_id BIGINT,
  like_count INTEGER,
  comment_count INTEGER,
  emotions TEXT[],
  created_at TIMESTAMPTZ,
  display_name TEXT,
  author_id UUID,
  is_anonymous BOOLEAN,
  image_url TEXT,
  initial_emotions TEXT[],
  group_id BIGINT
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_pattern TEXT;
BEGIN
  -- 빈 검색어 방지
  IF p_query IS NULL OR length(trim(p_query)) < 2 THEN
    RETURN;
  END IF;

  v_pattern := '%' || trim(p_query) || '%';

  RETURN QUERY
  SELECT v.id, v.title, v.content, v.board_id, v.like_count, v.comment_count,
    v.emotions, v.created_at, v.display_name,
    v.author_id, v.is_anonymous, v.image_url, v.initial_emotions, v.group_id
  FROM posts_with_like_count v
  WHERE v.group_id IS NULL
    AND (v.title ILIKE v_pattern OR v.content ILIKE v_pattern)
  ORDER BY v.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;
