-- =============================================================
-- block_user 방어적 처리: 별칭 미존재 시 NOOP (Sentry GNS-P/Q 해결)
-- =============================================================

-- block_user: RAISE EXCEPTION → RETURN (별칭 미존재 시 조용히 무시)
CREATE OR REPLACE FUNCTION block_user(p_alias TEXT)
RETURNS void
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  -- 자기 자신 차단 방지
  IF p_alias = (SELECT display_alias FROM user_preferences WHERE user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Cannot block yourself' USING ERRCODE = 'P0001';
  END IF;

  -- 별칭 미존재 시 NOOP (차단 대상이 아직 별칭을 생성하지 않은 경우)
  IF NOT EXISTS (SELECT 1 FROM user_preferences WHERE display_alias = p_alias) THEN
    RETURN;
  END IF;

  INSERT INTO user_blocks (blocker_id, blocked_alias)
  VALUES ((SELECT auth.uid()), p_alias)
  ON CONFLICT (blocker_id, blocked_alias) DO NOTHING;
END;
$$;

COMMENT ON FUNCTION block_user(TEXT) IS '특정 별칭 차단 (미존재 시 NOOP, 자기 자신 차단 방지)';
