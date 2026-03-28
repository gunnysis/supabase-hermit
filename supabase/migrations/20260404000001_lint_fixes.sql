-- DB lint 에러 수정
-- 1) search_posts_v2: image_url 컬럼 제거 (20260402000002에서 DROP됨)
-- 2) admin_cleanup_posts/comments: user_id → author_id
-- 3) create_daily_post: 미사용 변수 v_deleted_existing 제거

-- ─── 1. search_posts_v2: image_url 제거 (RETURNS TABLE 변경이므로 DROP 필요) ──

DROP FUNCTION IF EXISTS public.search_posts_v2(TEXT, TEXT, TEXT, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION public.search_posts_v2(
  p_query TEXT,
  p_emotion TEXT DEFAULT NULL,
  p_sort TEXT DEFAULT 'relevance',
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
  initial_emotions TEXT[],
  title_highlight TEXT,
  content_highlight TEXT,
  relevance_score REAL
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_tsquery TSQUERY;
  v_pattern TEXT;
  v_trimmed TEXT;
  v_escaped TEXT;
BEGIN
  v_trimmed := trim(p_query);

  IF v_trimmed IS NULL OR length(v_trimmed) < 2 THEN
    RETURN;
  END IF;

  v_tsquery := plainto_tsquery('simple', v_trimmed);

  v_escaped := replace(replace(v_trimmed, '%', '\%'), '_', '\_');
  v_pattern := '%' || v_escaped || '%';

  RETURN QUERY
  WITH matched AS (
    SELECT
      p.id,
      p.title,
      p.content,
      p.board_id,
      COALESCE(r_agg.total_reactions, 0)::integer AS like_count,
      COALESCE(c_agg.total_comments, 0)::integer AS comment_count,
      pa.emotions,
      p.created_at,
      p.display_name,
      p.author_id,
      p.is_anonymous,
      p.initial_emotions,
      ts_headline('simple', p.title, v_tsquery,
        'StartSel=<<, StopSel=>>, MaxWords=50, MinWords=10, MaxFragments=1'
      ) AS title_highlight,
      ts_headline('simple', p.content, v_tsquery,
        'StartSel=<<, StopSel=>>, MaxWords=30, MinWords=10, MaxFragments=1'
      ) AS content_highlight,
      (
        COALESCE(ts_rank(
          setweight(to_tsvector('simple', p.title), 'A') ||
          setweight(to_tsvector('simple', p.content), 'B'),
          v_tsquery
        ), 0) * 10
        + CASE WHEN p.title ILIKE v_pattern THEN 5.0 ELSE 0.0 END
        + CASE WHEN p.title ILIKE v_escaped || '%' THEN 3.0 ELSE 0.0 END
      )::REAL AS relevance_score
    FROM posts p
    LEFT JOIN post_analysis pa ON pa.post_id = p.id
    LEFT JOIN (
      SELECT r.post_id, SUM(r.count)::integer AS total_reactions
      FROM reactions r GROUP BY r.post_id
    ) r_agg ON r_agg.post_id = p.id
    LEFT JOIN (
      SELECT c.post_id, COUNT(*)::integer AS total_comments
      FROM comments c WHERE c.deleted_at IS NULL GROUP BY c.post_id
    ) c_agg ON c_agg.post_id = p.id
    WHERE p.deleted_at IS NULL
      AND (
        (to_tsvector('simple', p.title) || to_tsvector('simple', p.content)) @@ v_tsquery
        OR p.title ILIKE v_pattern
        OR p.content ILIKE v_pattern
      )
      AND (p_emotion IS NULL OR p_emotion = ANY(pa.emotions))
  )
  SELECT m.*
  FROM matched m
  ORDER BY
    CASE
      WHEN p_sort = 'relevance' THEN -m.relevance_score
      WHEN p_sort = 'popular' THEN -(m.like_count + m.comment_count * 2)::REAL
      ELSE NULL
    END,
    m.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION public.search_posts_v2(TEXT, TEXT, TEXT, INTEGER, INTEGER) IS
  '게시글 검색 v2: 풀텍스트 + 관련도 + 하이라이트 + 감정 필터';

-- ─── 2. admin_cleanup_posts: user_id → author_id ──────────────────────────────

CREATE OR REPLACE FUNCTION admin_cleanup_posts(
  p_user_id UUID DEFAULT NULL,
  p_before TIMESTAMPTZ DEFAULT NULL,
  p_after TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := (SELECT auth.uid());
  v_is_admin BOOLEAN;
  v_deleted_count INT;
BEGIN
  SELECT EXISTS(SELECT 1 FROM app_admin WHERE user_id = v_caller) INTO v_is_admin;
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Admin only';
  END IF;

  IF p_user_id IS NULL AND p_before IS NULL AND p_after IS NULL THEN
    RAISE EXCEPTION 'At least one filter required (user_id, before, or after)';
  END IF;

  DELETE FROM posts
  WHERE (p_user_id IS NULL OR author_id = p_user_id)
    AND (p_before IS NULL OR created_at < p_before)
    AND (p_after IS NULL OR created_at > p_after);

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'deleted_posts', v_deleted_count,
    'filters', jsonb_build_object(
      'user_id', p_user_id,
      'before', p_before,
      'after', p_after
    )
  );
END;
$$;

-- ─── 3. admin_cleanup_comments: user_id → author_id ───────────────────────────

CREATE OR REPLACE FUNCTION admin_cleanup_comments(
  p_user_id UUID DEFAULT NULL,
  p_before TIMESTAMPTZ DEFAULT NULL,
  p_after TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := (SELECT auth.uid());
  v_is_admin BOOLEAN;
  v_deleted_count INT;
BEGIN
  SELECT EXISTS(SELECT 1 FROM app_admin WHERE user_id = v_caller) INTO v_is_admin;
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Admin only';
  END IF;

  IF p_user_id IS NULL AND p_before IS NULL AND p_after IS NULL THEN
    RAISE EXCEPTION 'At least one filter required (user_id, before, or after)';
  END IF;

  DELETE FROM comments
  WHERE (p_user_id IS NULL OR author_id = p_user_id)
    AND (p_before IS NULL OR created_at < p_before)
    AND (p_after IS NULL OR created_at > p_after);

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'deleted_comments', v_deleted_count,
    'filters', jsonb_build_object(
      'user_id', p_user_id,
      'before', p_before,
      'after', p_after
    )
  );
END;
$$;
