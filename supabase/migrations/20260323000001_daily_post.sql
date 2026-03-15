-- =============================================================
-- 오늘의 하루 (daily post) — 소통형 경량 게시글 포맷
-- posts 테이블 확장, 신규 테이블 0개
-- =============================================================

------------------------------------------------------------
-- 1. posts 테이블 확장
------------------------------------------------------------
ALTER TABLE posts ADD COLUMN IF NOT EXISTS post_type TEXT NOT NULL DEFAULT 'post';
ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_post_type_check;
ALTER TABLE posts ADD CONSTRAINT posts_post_type_check CHECK (post_type IN ('post', 'daily'));

ALTER TABLE posts ADD COLUMN IF NOT EXISTS activities TEXT[] DEFAULT '{}';

------------------------------------------------------------
-- 2. 인덱스
------------------------------------------------------------
-- 하루 1회 제한 (KST 기준, 경쟁 조건 방지)
CREATE UNIQUE INDEX IF NOT EXISTS idx_posts_daily_per_user_day
  ON posts (author_id, ((created_at AT TIME ZONE 'Asia/Seoul')::DATE))
  WHERE post_type = 'daily' AND deleted_at IS NULL;

-- 활동 태그 검색용
CREATE INDEX IF NOT EXISTS idx_posts_activities
  ON posts USING GIN(activities)
  WHERE post_type = 'daily';

-- post_type별 필터링용
CREATE INDEX IF NOT EXISTS idx_posts_type
  ON posts (post_type, created_at DESC)
  WHERE deleted_at IS NULL;

------------------------------------------------------------
-- 3. 감정분석 트리거 조건 수정 (daily 제외)
------------------------------------------------------------

-- 3a. pending 행 생성 — daily 제외
DROP TRIGGER IF EXISTS trg_create_pending_analysis ON posts;
CREATE TRIGGER trg_create_pending_analysis
  AFTER INSERT ON posts
  FOR EACH ROW
  WHEN (NEW.post_type = 'post')
  EXECUTE FUNCTION create_pending_analysis();

-- 3b. Edge Function 자동 호출 — daily 제외
DROP TRIGGER IF EXISTS analyze_post_on_insert ON posts;
CREATE TRIGGER analyze_post_on_insert
  AFTER INSERT ON posts
  FOR EACH ROW
  WHEN (NEW.post_type = 'post')
  EXECUTE FUNCTION supabase_functions.http_request(
    'https://qwrjebpsjjdxhhhllqcw.supabase.co/functions/v1/analyze-post',
    'POST', '{"Content-Type":"application/json"}', '{}', '5000'
  );

-- 3c. UPDATE 시 상태 전환 — daily 제외
DROP TRIGGER IF EXISTS trg_mark_analysis_analyzing ON posts;
CREATE TRIGGER trg_mark_analysis_analyzing
  AFTER UPDATE OF content, title ON posts
  FOR EACH ROW
  WHEN (NEW.post_type = 'post'
    AND (OLD.content IS DISTINCT FROM NEW.content
         OR OLD.title IS DISTINCT FROM NEW.title))
  EXECUTE FUNCTION mark_analysis_analyzing();

-- 3d. UPDATE 시 Edge Function 재호출 — daily 제외
DROP TRIGGER IF EXISTS analyze_post_on_update ON posts;
CREATE TRIGGER analyze_post_on_update
  AFTER UPDATE OF content, title ON posts
  FOR EACH ROW
  WHEN (NEW.post_type = 'post'
    AND (OLD.content IS DISTINCT FROM NEW.content
         OR OLD.title IS DISTINCT FROM NEW.title))
  EXECUTE FUNCTION supabase_functions.http_request(
    'https://qwrjebpsjjdxhhhllqcw.supabase.co/functions/v1/analyze-post',
    'POST', '{"Content-Type":"application/json"}', '{}', '5000'
  );

------------------------------------------------------------
-- 4. posts_with_like_count 뷰 재생성
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

------------------------------------------------------------
-- 5. create_daily_post() RPC
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
  v_user_id UUID := auth.uid();
  v_today_start TIMESTAMPTZ := (CURRENT_DATE AT TIME ZONE 'Asia/Seoul');
  v_today_end TIMESTAMPTZ := ((CURRENT_DATE + 1) AT TIME ZONE 'Asia/Seoul');
  v_existing BIGINT;
  v_post posts;
BEGIN
  IF v_user_id IS NULL THEN
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

  -- 오늘(KST) 이미 작성했는지 확인
  SELECT id INTO v_existing
  FROM posts
  WHERE author_id = v_user_id
    AND post_type = 'daily'
    AND deleted_at IS NULL
    AND created_at >= v_today_start
    AND created_at < v_today_end;

  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'Already posted today' USING ERRCODE = 'P0002';
  END IF;

  -- 게시글 생성
  INSERT INTO posts (
    title, content, author_id, board_id,
    is_anonymous, display_name,
    post_type, activities, initial_emotions
  ) VALUES (
    '', p_content, v_user_id, 12,
    true, '익명',
    'daily', COALESCE(p_activities, '{}'), p_emotions
  ) RETURNING * INTO v_post;

  -- 감정 분석 행 직접 생성 (AI skip, 사용자 선택 감정)
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
-- 6. update_daily_post() RPC
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
  v_user_id UUID := auth.uid();
  v_post posts;
BEGIN
  IF v_user_id IS NULL THEN
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

  -- 게시글 수정
  UPDATE posts
  SET content = p_content,
      activities = COALESCE(p_activities, '{}'),
      initial_emotions = p_emotions,
      updated_at = now()
  WHERE id = p_post_id
    AND author_id = v_user_id
    AND post_type = 'daily'
    AND deleted_at IS NULL
  RETURNING * INTO v_post;

  IF v_post.id IS NULL THEN
    RAISE EXCEPTION 'Post not found or not authorized';
  END IF;

  -- post_analysis 동기화
  UPDATE post_analysis
  SET emotions = p_emotions, analyzed_at = now()
  WHERE post_id = p_post_id;

  RETURN row_to_json(v_post);
END;
$$;

------------------------------------------------------------
-- 7. get_today_daily() RPC (SARGable 범위 쿼리)
------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_today_daily()
RETURNS JSON
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public
AS $$
  SELECT row_to_json(t) FROM (
    SELECT p.id, p.content, p.post_type, p.activities,
      p.initial_emotions, p.created_at,
      pa.emotions,
      COALESCE((SELECT SUM(r.count) FROM reactions r WHERE r.post_id = p.id), 0)::int AS like_count
    FROM posts p
    LEFT JOIN post_analysis pa ON pa.post_id = p.id
    WHERE p.author_id = (SELECT auth.uid())
      AND p.post_type = 'daily'
      AND p.deleted_at IS NULL
      AND p.created_at >= (CURRENT_DATE AT TIME ZONE 'Asia/Seoul')
      AND p.created_at < ((CURRENT_DATE + 1) AT TIME ZONE 'Asia/Seoul')
    LIMIT 1
  ) t;
$$;
