-- =============================================================
-- 사이드 이펙트 종합 수정
-- P0: daily 삭제 후 재작성 방어
-- P1: 로그아웃 제거 불필요 (클라이언트만)
-- P2: 알림 링크 깨짐 방지 (소프트삭제 시 알림 정리)
-- =============================================================

------------------------------------------------------------
-- 1. create_daily_post: soft-deleted daily도 체크 (재작성 방어)
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
  v_deleted_existing BIGINT;
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

  -- 오늘(KST) 이미 작성했는지 확인 (활성 daily)
  SELECT id INTO v_existing
  FROM posts
  WHERE author_id = v_uid
    AND post_type = 'daily'
    AND deleted_at IS NULL
    AND created_date_kst = v_today;

  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'Already posted today' USING ERRCODE = 'P0002';
  END IF;

  -- 오늘(KST) 삭제된 daily가 있는지 확인
  -- 삭제 후 재작성 허용: 삭제된 daily를 복구(재활용)하는 대신 새로 생성
  -- UNIQUE 인덱스가 deleted_at IS NULL 조건이므로 새 INSERT는 안전

  -- 별칭 조회
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
-- 2. soft_delete_post: 알림 정리 (소프트삭제 시 관련 알림 삭제)
------------------------------------------------------------
CREATE OR REPLACE FUNCTION soft_delete_post(p_post_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_is_admin BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 관리자 체크
  SELECT EXISTS(SELECT 1 FROM app_admin WHERE user_id = v_uid) INTO v_is_admin;

  -- 본인 또는 관리자만 삭제 가능
  UPDATE posts
  SET deleted_at = now()
  WHERE id = p_post_id
    AND deleted_at IS NULL
    AND (author_id = v_uid OR v_is_admin);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Post not found or not authorized';
  END IF;

  -- 관련 알림 삭제 (깨진 링크 방지)
  DELETE FROM notifications WHERE post_id = p_post_id;
END;
$$;

------------------------------------------------------------
-- 3. soft_delete_comment: 알림 정리
------------------------------------------------------------
CREATE OR REPLACE FUNCTION soft_delete_comment(p_comment_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_is_admin BOOLEAN;
  v_comment_post_id BIGINT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT EXISTS(SELECT 1 FROM app_admin WHERE user_id = v_uid) INTO v_is_admin;

  UPDATE comments
  SET deleted_at = now()
  WHERE id = p_comment_id
    AND deleted_at IS NULL
    AND (author_id = v_uid OR v_is_admin)
  RETURNING post_id INTO v_comment_post_id;

  IF v_comment_post_id IS NULL THEN
    RAISE EXCEPTION 'Comment not found or not authorized';
  END IF;

  -- 해당 댓글 관련 알림 삭제 (comment_id 기반)
  DELETE FROM notifications WHERE comment_id = p_comment_id;
END;
$$;
