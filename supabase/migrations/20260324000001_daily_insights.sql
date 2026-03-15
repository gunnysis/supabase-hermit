-- =============================================================
-- 나의 패턴: 활동-감정 상관관계 인사이트 RPC
-- =============================================================

CREATE OR REPLACE FUNCTION get_daily_activity_insights(
  p_days INT DEFAULT 30
)
RETURNS JSON
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := (SELECT auth.uid());
  v_since DATE := CURRENT_DATE - p_days;
  v_total INT;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM posts
  WHERE author_id = v_user_id AND post_type = 'daily'
    AND deleted_at IS NULL AND created_at::DATE >= v_since;

  IF v_total < 7 THEN
    RETURN json_build_object(
      'total_dailies', v_total,
      'activity_emotion_map', '[]'::JSON
    );
  END IF;

  RETURN json_build_object(
    'total_dailies', v_total,
    'activity_emotion_map', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
      FROM (
        SELECT
          a AS activity,
          COUNT(DISTINCT p.id)::INT AS count,
          (
            SELECT COALESCE(json_agg(json_build_object(
              'emotion', sub.emotion, 'pct', sub.pct
            )), '[]'::JSON)
            FROM (
              SELECT e AS emotion,
                ROUND(COUNT(*)::NUMERIC * 100
                  / NULLIF(SUM(COUNT(*)) OVER(), 0)) AS pct
              FROM posts p2
              JOIN post_analysis pa ON pa.post_id = p2.id,
              LATERAL unnest(pa.emotions) AS e
              WHERE p2.author_id = v_user_id AND p2.post_type = 'daily'
                AND p2.deleted_at IS NULL AND p2.created_at::DATE >= v_since
                AND a = ANY(p2.activities)
              GROUP BY e ORDER BY COUNT(*) DESC LIMIT 2
            ) sub
          ) AS emotions
        FROM posts p, unnest(p.activities) AS a
        WHERE p.author_id = v_user_id AND p.post_type = 'daily'
          AND p.deleted_at IS NULL AND p.created_at::DATE >= v_since
        GROUP BY a HAVING COUNT(DISTINCT p.id) >= 3
        ORDER BY COUNT(DISTINCT p.id) DESC LIMIT 5
      ) t
    )
  );
END;
$$;
