-- =============================================================================
-- 20260331000001_daily_v2.sql
-- Daily v2: 히스토리 조회 + 월간 감정 리포트
-- =============================================================================

-- ============================================================
-- 1. get_my_daily_history — 내 daily 게시글 히스토리 (역순)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_daily_history(
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0
)
RETURNS TABLE(
  id BIGINT,
  emotions TEXT[],
  activities TEXT[],
  content TEXT,
  created_date_kst DATE,
  created_at TIMESTAMPTZ,
  like_count INT,
  comment_count INT
)
LANGUAGE sql SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    p.id,
    pa.emotions,
    p.activities,
    p.content,
    p.created_date_kst,
    p.created_at,
    COALESCE(r_agg.total, 0)::INT AS like_count,
    COALESCE(c_agg.total, 0)::INT AS comment_count
  FROM posts p
  LEFT JOIN post_analysis pa ON pa.post_id = p.id
  LEFT JOIN (
    SELECT r.post_id, SUM(r.count)::INT AS total
    FROM reactions r
    WHERE r.reaction_type = 'heart'
    GROUP BY r.post_id
  ) r_agg ON r_agg.post_id = p.id
  LEFT JOIN (
    SELECT c.post_id, COUNT(*)::INT AS total
    FROM comments c
    WHERE c.deleted_at IS NULL
    GROUP BY c.post_id
  ) c_agg ON c_agg.post_id = p.id
  WHERE p.author_id = (SELECT auth.uid())
    AND p.post_type = 'daily'
    AND p.deleted_at IS NULL
  ORDER BY p.created_date_kst DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

COMMENT ON FUNCTION public.get_my_daily_history(INT, INT) IS
  '내 daily 게시글 히스토리 (역순, 페이지네이션). like_count는 heart만 집계';

-- ============================================================
-- 2. get_monthly_emotion_report — 월간 감정/활동 리포트
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_monthly_emotion_report(
  p_year INT,
  p_month INT
)
RETURNS JSON
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_start DATE;
  v_end DATE;
  v_result JSON;
BEGIN
  v_start := make_date(p_year, p_month, 1);
  v_end := (v_start + INTERVAL '1 month')::DATE;

  SELECT json_build_object(
    'year', p_year,
    'month', p_month,
    'days_in_month', (v_end - v_start),
    'days_logged', COUNT(DISTINCT p.created_date_kst),
    'top_emotions', (
      SELECT COALESCE(json_agg(row_to_json(e)), '[]'::JSON)
      FROM (
        SELECT emotion, COUNT(*) AS count
        FROM posts p2
        JOIN post_analysis pa2 ON pa2.post_id = p2.id,
        LATERAL unnest(pa2.emotions) AS emotion
        WHERE p2.author_id = (SELECT auth.uid())
          AND p2.post_type = 'daily'
          AND p2.deleted_at IS NULL
          AND p2.created_date_kst >= v_start
          AND p2.created_date_kst < v_end
        GROUP BY emotion
        ORDER BY count DESC
        LIMIT 5
      ) e
    ),
    'top_activities', (
      SELECT COALESCE(json_agg(row_to_json(a)), '[]'::JSON)
      FROM (
        SELECT activity, COUNT(*) AS count
        FROM posts p3,
        LATERAL unnest(p3.activities) AS activity
        WHERE p3.author_id = (SELECT auth.uid())
          AND p3.post_type = 'daily'
          AND p3.deleted_at IS NULL
          AND p3.created_date_kst >= v_start
          AND p3.created_date_kst < v_end
        GROUP BY activity
        ORDER BY count DESC
        LIMIT 5
      ) a
    ),
    'total_reactions', (
      SELECT COALESCE(SUM(r.count), 0)::INT
      FROM reactions r
      JOIN posts p4 ON p4.id = r.post_id
      WHERE p4.author_id = (SELECT auth.uid())
        AND p4.post_type = 'daily'
        AND p4.deleted_at IS NULL
        AND p4.created_date_kst >= v_start
        AND p4.created_date_kst < v_end
        AND r.reaction_type = 'heart'
    ),
    'total_comments', (
      SELECT COUNT(*)::INT
      FROM comments c
      JOIN posts p5 ON p5.id = c.post_id
      WHERE p5.author_id = (SELECT auth.uid())
        AND p5.post_type = 'daily'
        AND p5.deleted_at IS NULL
        AND p5.created_date_kst >= v_start
        AND p5.created_date_kst < v_end
        AND c.deleted_at IS NULL
    )
  ) INTO v_result
  FROM posts p
  WHERE p.author_id = (SELECT auth.uid())
    AND p.post_type = 'daily'
    AND p.deleted_at IS NULL
    AND p.created_date_kst >= v_start
    AND p.created_date_kst < v_end;

  RETURN COALESCE(v_result, json_build_object(
    'year', p_year,
    'month', p_month,
    'days_in_month', (v_end - v_start),
    'days_logged', 0,
    'top_emotions', '[]'::JSON,
    'top_activities', '[]'::JSON,
    'total_reactions', 0,
    'total_comments', 0
  ));
END;
$$;

COMMENT ON FUNCTION public.get_monthly_emotion_report(INT, INT) IS
  '월간 감정/활동 리포트 — 기록일수, Top 5 감정/활동, 총 반응/댓글 수';

-- Done.
