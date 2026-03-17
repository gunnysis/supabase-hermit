-- =============================================================
-- get_today_daily: comment_count 추가 + like_count heart만 집계
-- =============================================================

CREATE OR REPLACE FUNCTION get_today_daily()
RETURNS JSON
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public
AS $$
  SELECT row_to_json(t) FROM (
    SELECT p.id, p.content, p.post_type, p.activities,
      p.initial_emotions, p.created_at, p.display_name,
      pa.emotions,
      COALESCE((SELECT SUM(r.count) FROM reactions r WHERE r.post_id = p.id AND r.reaction_type = 'heart'), 0)::int AS like_count,
      COALESCE((SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.deleted_at IS NULL), 0)::int AS comment_count
    FROM posts p
    LEFT JOIN post_analysis pa ON pa.post_id = p.id
    WHERE p.author_id = (SELECT auth.uid())
      AND p.post_type = 'daily'
      AND p.deleted_at IS NULL
      AND p.created_date_kst = kst_date(now())
    LIMIT 1
  ) t;
$$;
