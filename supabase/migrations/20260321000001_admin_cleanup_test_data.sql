-- ============================================
-- Migration: Admin Test Data Cleanup RPC
-- 관리자가 테스트 데이터(글/댓글)를 일괄 정리하는 함수
-- ============================================

-- 관리자 전용: 특정 사용자의 글을 hard delete (CASCADE로 댓글/리액션/분석 자동 삭제)
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
  -- 관리자 확인
  SELECT EXISTS(SELECT 1 FROM app_admin WHERE user_id = v_caller) INTO v_is_admin;
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Admin only';
  END IF;

  -- 최소 1개 필터 필수 (전체 삭제 방지)
  IF p_user_id IS NULL AND p_before IS NULL AND p_after IS NULL THEN
    RAISE EXCEPTION 'At least one filter required (user_id, before, or after)';
  END IF;

  DELETE FROM posts
  WHERE (p_user_id IS NULL OR user_id = p_user_id)
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

-- 관리자 전용: 특정 사용자의 댓글을 hard delete
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
  WHERE (p_user_id IS NULL OR user_id = p_user_id)
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
