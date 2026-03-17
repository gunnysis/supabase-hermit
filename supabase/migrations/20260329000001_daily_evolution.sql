-- =============================================================
-- 오늘의 하루 Evolution — Phase 1+2 DB 변경
-- P1-4: display_name 별칭 적용
-- P2-1: generated column (KST 날짜) + 새 RPC 2개
-- P2-3: 커스텀 활동 영속화
-- P2-4: 주간 감정 회고 RPC
-- =============================================================

------------------------------------------------------------
-- 1. KST 날짜 IMMUTABLE 헬퍼 함수
------------------------------------------------------------
CREATE OR REPLACE FUNCTION kst_date(ts TIMESTAMPTZ)
RETURNS DATE
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT ((ts + INTERVAL '9 hours'))::DATE;
$$;

------------------------------------------------------------
-- 2. posts.created_date_kst generated column
------------------------------------------------------------
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'posts' AND column_name = 'created_date_kst'
  ) THEN
    ALTER TABLE posts
    ADD COLUMN created_date_kst DATE
    GENERATED ALWAYS AS (kst_date(created_at)) STORED;
  END IF;
END $$;

-- 인덱스: 스트릭/캘린더/insights 쿼리 최적화
CREATE INDEX IF NOT EXISTS idx_posts_date_kst
  ON posts (author_id, created_date_kst DESC)
  WHERE deleted_at IS NULL;

------------------------------------------------------------
-- 3. user_preferences.custom_activities 컬럼
------------------------------------------------------------
ALTER TABLE user_preferences
  ADD COLUMN IF NOT EXISTS custom_activities TEXT[] DEFAULT '{}';

------------------------------------------------------------
-- 4. create_daily_post — display_alias 사용 + created_date_kst 활용
------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_daily_post(
  p_emotions TEXT[],
  p_activities TEXT[] DEFAULT '{}',
  p_content TEXT DEFAULT ''
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_today DATE := kst_date(now());
  v_existing BIGINT;
  v_alias TEXT;
  v_post posts;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 입력 검증
  IF array_length(p_emotions, 1) IS NULL OR array_length(p_emotions, 1) < 1 THEN
    RAISE EXCEPTION 'At least one emotion is required';
  END IF;
  IF array_length(p_emotions, 1) > 3 THEN
    RAISE EXCEPTION 'Maximum 3 emotions allowed';
  END IF;
  IF p_activities IS NOT NULL AND array_length(p_activities, 1) > 5 THEN
    RAISE EXCEPTION 'Maximum 5 activities allowed';
  END IF;
  IF length(p_content) > 200 THEN
    RAISE EXCEPTION 'Content too long (max 200)';
  END IF;

  -- 오늘(KST) 이미 작성했는지 확인 (generated column 활용)
  SELECT id INTO v_existing
  FROM posts
  WHERE author_id = v_uid
    AND post_type = 'daily'
    AND deleted_at IS NULL
    AND created_date_kst = v_today;

  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'Already posted today' USING ERRCODE = 'P0002';
  END IF;

  -- 별칭 조회 (없으면 '익명' 폴백)
  SELECT COALESCE(display_alias, '익명') INTO v_alias
  FROM user_preferences
  WHERE user_id = v_uid;

  IF v_alias IS NULL THEN
    v_alias := '익명';
  END IF;

  -- 게시글 생성
  INSERT INTO posts (
    title, content, author_id, board_id,
    is_anonymous, display_name,
    post_type, activities, initial_emotions
  ) VALUES (
    '', p_content, v_uid, 12,
    true, v_alias,
    'daily', COALESCE(p_activities, '{}'), p_emotions
  ) RETURNING * INTO v_post;

  -- 감정 분석 행 직접 생성 (AI skip)
  INSERT INTO post_analysis (post_id, emotions, status, analyzed_at)
  VALUES (v_post.id, p_emotions, 'done', now())
  ON CONFLICT (post_id) DO UPDATE
    SET emotions = EXCLUDED.emotions,
        status = 'done',
        analyzed_at = now();

  RETURN row_to_json(v_post);
END;
$$;

------------------------------------------------------------
-- 5. update_daily_post — 기존과 동일 (시그니처 유지)
------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_daily_post(
  p_post_id BIGINT,
  p_emotions TEXT[],
  p_activities TEXT[] DEFAULT '{}',
  p_content TEXT DEFAULT ''
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_post posts;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF array_length(p_emotions, 1) IS NULL OR array_length(p_emotions, 1) < 1 THEN
    RAISE EXCEPTION 'At least one emotion is required';
  END IF;
  IF array_length(p_emotions, 1) > 3 THEN
    RAISE EXCEPTION 'Maximum 3 emotions allowed';
  END IF;
  IF p_activities IS NOT NULL AND array_length(p_activities, 1) > 5 THEN
    RAISE EXCEPTION 'Maximum 5 activities allowed';
  END IF;
  IF length(p_content) > 200 THEN
    RAISE EXCEPTION 'Content too long (max 200)';
  END IF;

  UPDATE posts
  SET content = p_content,
      activities = COALESCE(p_activities, '{}'),
      initial_emotions = p_emotions,
      updated_at = now()
  WHERE id = p_post_id
    AND author_id = v_uid
    AND post_type = 'daily'
    AND deleted_at IS NULL
  RETURNING * INTO v_post;

  IF v_post.id IS NULL THEN
    RAISE EXCEPTION 'Post not found or not authorized';
  END IF;

  UPDATE post_analysis
  SET emotions = p_emotions, analyzed_at = now()
  WHERE post_id = p_post_id;

  RETURN row_to_json(v_post);
END;
$$;

------------------------------------------------------------
-- 6. get_today_daily — created_date_kst 활용
------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_today_daily()
RETURNS JSON
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public
AS $$
  SELECT row_to_json(t) FROM (
    SELECT p.id, p.content, p.post_type, p.activities,
      p.initial_emotions, p.created_at, p.display_name,
      pa.emotions,
      COALESCE((SELECT SUM(r.count) FROM reactions r WHERE r.post_id = p.id), 0)::int AS like_count
    FROM posts p
    LEFT JOIN post_analysis pa ON pa.post_id = p.id
    WHERE p.author_id = (SELECT auth.uid())
      AND p.post_type = 'daily'
      AND p.deleted_at IS NULL
      AND p.created_date_kst = kst_date(now())
    LIMIT 1
  ) t;
$$;

------------------------------------------------------------
-- 7. get_yesterday_daily_reactions (신규 — 클라이언트 KST 계산 제거)
------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_yesterday_daily_reactions()
RETURNS JSON
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_yesterday DATE := kst_date(now()) - 1;
  v_result JSON;
BEGIN
  SELECT json_build_object(
    'post_id', p.id,
    'like_count', COALESCE(r_sum.total, 0),
    'comment_count', COALESCE(c_cnt.total, 0)
  ) INTO v_result
  FROM posts p
  LEFT JOIN (
    SELECT post_id, SUM(count)::int AS total
    FROM reactions GROUP BY post_id
  ) r_sum ON r_sum.post_id = p.id
  LEFT JOIN (
    SELECT post_id, COUNT(*)::int AS total
    FROM comments WHERE deleted_at IS NULL GROUP BY post_id
  ) c_cnt ON c_cnt.post_id = p.id
  WHERE p.author_id = (SELECT auth.uid())
    AND p.post_type = 'daily'
    AND p.deleted_at IS NULL
    AND p.created_date_kst = v_yesterday
    AND (COALESCE(r_sum.total, 0) > 0 OR COALESCE(c_cnt.total, 0) > 0)
  LIMIT 1;

  RETURN v_result;
END;
$$;

------------------------------------------------------------
-- 8. get_same_mood_dailies (신규 — 직접 쿼리 → RPC 전환)
------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_same_mood_dailies(
  p_post_id BIGINT,
  p_emotions TEXT[]
)
RETURNS JSON
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public
AS $$
  SELECT COALESCE(json_agg(row_to_json(d)), '[]'::JSON)
  FROM (
    SELECT p.id, p.content, pa.emotions, p.activities
    FROM posts p
    LEFT JOIN post_analysis pa ON pa.post_id = p.id
    WHERE p.post_type = 'daily'
      AND p.deleted_at IS NULL
      AND p.created_date_kst = kst_date(now())
      AND p.id != p_post_id
      AND p.author_id != (SELECT auth.uid())
      AND pa.emotions && p_emotions
    ORDER BY p.created_at DESC
    LIMIT 3
  ) d;
$$;

------------------------------------------------------------
-- 9. get_weekly_emotion_summary (신규 — 주간 회고)
------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_weekly_emotion_summary(
  p_week_offset INT DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := (SELECT auth.uid());
  v_today DATE := kst_date(now());
  v_week_start DATE := v_today - EXTRACT(DOW FROM v_today)::INT - (7 * p_week_offset);
  v_week_end DATE := v_week_start + 6;
  v_result JSON;
BEGIN
  SELECT json_build_object(
    'week_start', v_week_start,
    'week_end', v_week_end,
    'days_logged', COUNT(DISTINCT p.created_date_kst),
    'top_emotions', (
      SELECT COALESCE(json_agg(json_build_object('emotion', sub.e, 'count', sub.cnt) ORDER BY sub.cnt DESC), '[]'::JSON)
      FROM (
        SELECT unnest(pa2.emotions) AS e, COUNT(*) AS cnt
        FROM posts p2
        JOIN post_analysis pa2 ON pa2.post_id = p2.id
        WHERE p2.author_id = v_uid
          AND p2.post_type = 'daily'
          AND p2.deleted_at IS NULL
          AND p2.created_date_kst BETWEEN v_week_start AND v_week_end
        GROUP BY unnest(pa2.emotions)
        ORDER BY cnt DESC
        LIMIT 5
      ) sub
    ),
    'top_activity', (
      SELECT sub2.act FROM (
        SELECT unnest(p3.activities) AS act, COUNT(*) AS cnt
        FROM posts p3
        WHERE p3.author_id = v_uid
          AND p3.post_type = 'daily'
          AND p3.deleted_at IS NULL
          AND p3.created_date_kst BETWEEN v_week_start AND v_week_end
        GROUP BY unnest(p3.activities)
        ORDER BY cnt DESC
        LIMIT 1
      ) sub2
    )
  ) INTO v_result
  FROM posts p
  WHERE p.author_id = v_uid
    AND p.post_type = 'daily'
    AND p.deleted_at IS NULL
    AND p.created_date_kst BETWEEN v_week_start AND v_week_end;

  RETURN v_result;
END;
$$;

------------------------------------------------------------
-- 10. get_daily_activity_insights — KST 타임존 적용 수정
------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_daily_activity_insights(
  p_days INT DEFAULT 30
)
RETURNS JSON
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := (SELECT auth.uid());
  v_today DATE := kst_date(now());
  v_start DATE := v_today - p_days;
  v_total INT;
  v_result JSON;
BEGIN
  -- daily 글 개수 확인
  SELECT COUNT(*) INTO v_total
  FROM posts
  WHERE author_id = v_uid
    AND post_type = 'daily'
    AND deleted_at IS NULL
    AND created_date_kst >= v_start;

  -- 7개 미만: 인사이트 불가
  IF v_total < 7 THEN
    RETURN json_build_object(
      'total_dailies', v_total,
      'activity_emotion_map', '[]'::JSON
    );
  END IF;

  SELECT json_build_object(
    'total_dailies', v_total,
    'activity_emotion_map', COALESCE((
      SELECT json_agg(row_to_json(sub) ORDER BY sub.count DESC)
      FROM (
        SELECT
          act.activity,
          COUNT(DISTINCT p.id)::INT AS count,
          (
            SELECT COALESCE(json_agg(json_build_object(
              'emotion', em.emotion,
              'pct', ROUND(em.cnt * 100.0 / COUNT(DISTINCT p2.id), 1)
            ) ORDER BY em.cnt DESC), '[]'::JSON)
            FROM (
              SELECT unnest(pa2.emotions) AS emotion, COUNT(*) AS cnt
              FROM posts p2
              JOIN post_analysis pa2 ON pa2.post_id = p2.id
              WHERE p2.author_id = v_uid
                AND p2.post_type = 'daily'
                AND p2.deleted_at IS NULL
                AND p2.created_date_kst >= v_start
                AND act.activity = ANY(p2.activities)
              GROUP BY unnest(pa2.emotions)
              ORDER BY cnt DESC
              LIMIT 3
            ) em
          ) AS emotions
        FROM posts p
        CROSS JOIN LATERAL unnest(p.activities) AS act(activity)
        WHERE p.author_id = v_uid
          AND p.post_type = 'daily'
          AND p.deleted_at IS NULL
          AND p.created_date_kst >= v_start
        GROUP BY act.activity
        HAVING COUNT(DISTINCT p.id) >= 3
        ORDER BY COUNT(DISTINCT p.id) DESC
        LIMIT 5
      ) sub
    ), '[]'::JSON)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

------------------------------------------------------------
-- 11. posts_with_like_count 뷰 재생성 (created_date_kst 포함)
------------------------------------------------------------
DROP VIEW IF EXISTS posts_with_like_count;
CREATE VIEW posts_with_like_count
  WITH (security_invoker = true)
AS
SELECT
  p.id, p.title, p.content, p.author_id, p.created_at,
  p.board_id, p.is_anonymous, p.display_name, p.image_url,
  p.initial_emotions,
  p.post_type,
  p.activities,
  p.created_date_kst,
  COALESCE(r_agg.total_reactions, 0)::integer AS like_count,
  COALESCE(c_agg.total_comments, 0)::integer AS comment_count,
  pa.emotions
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
WHERE p.deleted_at IS NULL;
