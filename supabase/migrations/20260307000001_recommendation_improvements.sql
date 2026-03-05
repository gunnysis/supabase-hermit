-- 추천 시스템 개선: 트렌딩 + 감정 발견 + 폴백 강화
-- - get_recommended_posts_by_emotion: 시간 감쇠, 참여도 가중, 폴백
-- - get_trending_posts: 홈 피드 트렌딩 섹션
-- - get_emotion_trend: pct 컬럼 추가
-- - idx_posts_trending: 트렌딩 조회 인덱스

-- 1. get_recommended_posts_by_emotion 개선 (반환 타입 변경이므로 DROP 후 재생성)
DROP FUNCTION IF EXISTS public.get_recommended_posts_by_emotion(BIGINT, INTEGER);
CREATE OR REPLACE FUNCTION public.get_recommended_posts_by_emotion(
  p_post_id BIGINT,
  p_limit INTEGER DEFAULT 10
) RETURNS TABLE(
  id BIGINT,
  title TEXT,
  board_id BIGINT,
  like_count INTEGER,
  comment_count INTEGER,
  emotions TEXT[],
  created_at TIMESTAMPTZ,
  score DOUBLE PRECISION
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_emotions TEXT[];
BEGIN
  SELECT COALESCE(pa.emotions, '{}') INTO v_emotions
  FROM post_analysis pa WHERE pa.post_id = p_post_id;

  -- 폴백: 감정 없으면 참여도+최신순 추천
  IF v_emotions IS NULL OR array_length(v_emotions, 1) IS NULL THEN
    RETURN QUERY
    SELECT v.id, v.title, v.board_id, v.like_count, v.comment_count,
      v.emotions, v.created_at,
      (v.like_count + v.comment_count * 2)::DOUBLE PRECISION
        / (1.0 + EXTRACT(EPOCH FROM (now() - v.created_at)) / 86400.0) AS score
    FROM posts_with_like_count v
    WHERE v.id != p_post_id AND v.group_id IS NULL
    ORDER BY score DESC, v.created_at DESC
    LIMIT p_limit;
    RETURN;
  END IF;

  -- 감정 겹침 + 참여도 + 시간 감쇠
  RETURN QUERY
  SELECT v.id, v.title, v.board_id, v.like_count, v.comment_count,
    v.emotions, v.created_at,
    (
      (SELECT COUNT(*) FROM unnest(v.emotions) e WHERE e = ANY(v_emotions))::DOUBLE PRECISION * 10.0
      + (v.like_count + v.comment_count * 2)::DOUBLE PRECISION
    ) / (1.0 + EXTRACT(EPOCH FROM (now() - v.created_at)) / 604800.0) AS score
  FROM posts_with_like_count v
  WHERE v.id != p_post_id
    AND v.group_id IS NULL
    AND v.emotions IS NOT NULL
    AND v.emotions && v_emotions
  ORDER BY score DESC, v.created_at DESC
  LIMIT p_limit;
END;
$$;

-- 2. get_trending_posts 신규
CREATE OR REPLACE FUNCTION public.get_trending_posts(
  p_hours INTEGER DEFAULT 72,
  p_limit INTEGER DEFAULT 10
) RETURNS TABLE(
  id BIGINT,
  title TEXT,
  board_id BIGINT,
  like_count INTEGER,
  comment_count INTEGER,
  emotions TEXT[],
  created_at TIMESTAMPTZ,
  display_name TEXT,
  score DOUBLE PRECISION
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
BEGIN
  RETURN QUERY
  SELECT v.id, v.title, v.board_id, v.like_count, v.comment_count,
    v.emotions, v.created_at, v.display_name,
    (v.like_count + v.comment_count * 2 + 1)::DOUBLE PRECISION
      / GREATEST(EXTRACT(EPOCH FROM (now() - v.created_at)) / 3600.0, 1.0) AS score
  FROM posts_with_like_count v
  WHERE v.group_id IS NULL
    AND v.created_at >= (now() - (p_hours || ' hours')::INTERVAL)
  ORDER BY score DESC
  LIMIT p_limit;
END;
$$;

-- 3. get_emotion_trend 개선 (반환 타입 변경이므로 DROP 후 재생성)
DROP FUNCTION IF EXISTS public.get_emotion_trend(INTEGER);
CREATE OR REPLACE FUNCTION public.get_emotion_trend(days INTEGER DEFAULT 7)
  RETURNS TABLE(emotion TEXT, cnt BIGINT, pct NUMERIC)
  LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_total BIGINT;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM post_analysis pa, unnest(pa.emotions)
  WHERE pa.analyzed_at >= (now() - (days || ' days')::INTERVAL);

  RETURN QUERY
  SELECT unnest(pa.emotions) AS emotion,
    COUNT(*)::BIGINT AS cnt,
    CASE WHEN v_total > 0
      THEN ROUND(COUNT(*)::NUMERIC / v_total * 100, 1)
      ELSE 0
    END AS pct
  FROM post_analysis pa
  WHERE pa.analyzed_at >= (now() - (days || ' days')::INTERVAL)
  GROUP BY 1
  ORDER BY 2 DESC
  LIMIT 5;
END;
$$;

-- 4. 트렌딩 조회 인덱스
CREATE INDEX IF NOT EXISTS idx_posts_trending
  ON public.posts (group_id, created_at DESC)
  WHERE deleted_at IS NULL;
