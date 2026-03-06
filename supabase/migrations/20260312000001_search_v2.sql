-- =============================================================================
-- 20260312000001_search_v2.sql
-- 검색 기능 개선: 풀텍스트 검색 + 관련도 정렬 + 하이라이트 + 서버 사이드 감정 필터
-- =============================================================================

-- 1) tsvector GIN 인덱스 (공개 게시글 대상)
CREATE INDEX IF NOT EXISTS idx_posts_fts
  ON posts
  USING GIN ((to_tsvector('simple', title) || to_tsvector('simple', content)))
  WHERE deleted_at IS NULL AND group_id IS NULL;

-- 2) search_posts_v2 RPC
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
  image_url TEXT,
  initial_emotions TEXT[],
  group_id BIGINT,
  title_highlight TEXT,
  content_highlight TEXT,
  relevance_score REAL
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_tsquery TSQUERY;
  v_pattern TEXT;
  v_trimmed TEXT;
BEGIN
  v_trimmed := trim(p_query);

  IF v_trimmed IS NULL OR length(v_trimmed) < 2 THEN
    RETURN;
  END IF;

  v_tsquery := plainto_tsquery('simple', v_trimmed);
  v_pattern := '%' || v_trimmed || '%';

  RETURN QUERY
  WITH matched AS (
    SELECT
      p.id,
      p.title,
      p.content,
      p.board_id,
      p.author_id,
      p.is_anonymous,
      p.display_name,
      p.image_url,
      p.initial_emotions,
      p.group_id,
      p.created_at,
      COALESCE(r_agg.total_reactions, 0)::integer AS like_count,
      COALESCE(c_agg.total_comments, 0)::integer AS comment_count,
      pa.emotions,
      -- 관련도 점수
      (
        COALESCE(ts_rank(
          setweight(to_tsvector('simple', p.title), 'A') ||
          setweight(to_tsvector('simple', p.content), 'B'),
          v_tsquery
        ), 0) * 10
        + CASE WHEN p.title ILIKE v_pattern THEN 5.0 ELSE 0.0 END
        + CASE WHEN p.title ILIKE v_trimmed || '%' THEN 3.0 ELSE 0.0 END
      )::REAL AS relevance_score,
      -- 하이라이트
      ts_headline('simple', p.title, v_tsquery,
        'StartSel=<<, StopSel=>>, MaxWords=50, MinWords=10, MaxFragments=1'
      ) AS title_highlight,
      ts_headline('simple', p.content, v_tsquery,
        'StartSel=<<, StopSel=>>, MaxWords=30, MinWords=10, MaxFragments=1'
      ) AS content_highlight
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
      AND p.group_id IS NULL
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
