-- 마이페이지 RPC 최적화 마이그레이션
-- 1. get_emotion_timeline: KST 타임존 적용 + SECURITY INVOKER
-- 2. get_my_activity_summary: SECURITY INVOKER 전환
-- 3. get_user_emotion_calendar: 범위 비교 최적화 + SECURITY INVOKER

-- 1. get_emotion_timeline: KST 타임존 + INVOKER
CREATE OR REPLACE FUNCTION public.get_emotion_timeline(p_days INT DEFAULT 7)
RETURNS TABLE(day DATE, emotion TEXT, cnt BIGINT)
LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'public' AS $$
BEGIN
  RETURN QUERY
  SELECT (pa.analyzed_at AT TIME ZONE 'Asia/Seoul')::DATE,
         unnest(pa.emotions),
         COUNT(*)::BIGINT
  FROM post_analysis pa
  WHERE pa.analyzed_at >= ((now() AT TIME ZONE 'Asia/Seoul')::DATE - p_days) AT TIME ZONE 'Asia/Seoul'
  GROUP BY 1, 2
  ORDER BY 1, 3 DESC;
END;
$$;

-- 2. get_my_activity_summary: INVOKER 전환 (본문 동일)
CREATE OR REPLACE FUNCTION public.get_my_activity_summary()
RETURNS JSON
LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'public' AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_post_count INT;
  v_comment_count INT;
  v_reaction_count INT;
  v_streak INT;
BEGIN
  SELECT COUNT(*)::INT INTO v_post_count
  FROM posts WHERE author_id = v_uid AND deleted_at IS NULL;

  SELECT COUNT(*)::INT INTO v_comment_count
  FROM comments WHERE author_id = v_uid AND deleted_at IS NULL;

  SELECT COUNT(*)::INT INTO v_reaction_count
  FROM user_reactions WHERE user_id = v_uid;

  -- 연속 글쓰기 일수 (스트릭)
  WITH daily AS (
    SELECT DISTINCT (created_at AT TIME ZONE 'Asia/Seoul')::DATE AS d
    FROM posts
    WHERE author_id = v_uid AND deleted_at IS NULL
    ORDER BY d DESC
  ),
  numbered AS (
    SELECT d, d - (ROW_NUMBER() OVER (ORDER BY d DESC))::INT * INTERVAL '1 day' AS grp
    FROM daily
  )
  SELECT COUNT(*)::INT INTO v_streak
  FROM numbered
  WHERE grp = (SELECT grp FROM numbered LIMIT 1);

  RETURN json_build_object(
    'post_count', v_post_count,
    'comment_count', v_comment_count,
    'reaction_count', v_reaction_count,
    'streak', COALESCE(v_streak, 0)
  );
END;
$$;

-- 3. get_user_emotion_calendar: 범위 비교 + INVOKER
CREATE OR REPLACE FUNCTION public.get_user_emotion_calendar(
  p_user_id UUID,
  p_start DATE DEFAULT (CURRENT_DATE - 30)::DATE,
  p_end DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(day DATE, emotions TEXT[], post_count INT)
LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'public' AS $$
BEGIN
  RETURN QUERY
  SELECT d.day::DATE,
    COALESCE(array_agg(DISTINCT e) FILTER (WHERE e IS NOT NULL), '{}')::TEXT[],
    COUNT(DISTINCT p.id)::INT
  FROM generate_series(p_start, p_end, '1 day'::INTERVAL) AS d(day)
  LEFT JOIN posts p ON p.author_id = p_user_id
    AND p.deleted_at IS NULL
    AND p.created_at >= d.day::TIMESTAMPTZ
    AND p.created_at < (d.day + INTERVAL '1 day')::TIMESTAMPTZ
  LEFT JOIN post_analysis pa ON pa.post_id = p.id
  LEFT JOIN LATERAL unnest(pa.emotions) AS e ON TRUE
  GROUP BY d.day
  ORDER BY d.day;
END;
$$;
