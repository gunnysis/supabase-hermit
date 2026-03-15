-- =============================================================
-- v2-3: 사용자 차단 (User Blocks)
-- 특정 별칭의 글/댓글을 내 화면에서 숨김
-- =============================================================

------------------------------------------------------------
-- 1. user_blocks 테이블
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_blocks (
  id BIGSERIAL PRIMARY KEY,
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_alias TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (blocker_id, blocked_alias)
);

-- RLS: 본인 차단 목록만 관리
ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own blocks"
  ON user_blocks FOR ALL
  USING ((SELECT auth.uid()) = blocker_id)
  WITH CHECK ((SELECT auth.uid()) = blocker_id);

------------------------------------------------------------
-- 2. 차단/해제 RPC
------------------------------------------------------------
CREATE OR REPLACE FUNCTION block_user(p_alias TEXT)
RETURNS void
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  INSERT INTO user_blocks (blocker_id, blocked_alias)
  VALUES ((SELECT auth.uid()), p_alias)
  ON CONFLICT (blocker_id, blocked_alias) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION unblock_user(p_alias TEXT)
RETURNS void
LANGUAGE sql SECURITY INVOKER
SET search_path = public
AS $$
  DELETE FROM user_blocks
  WHERE blocker_id = (SELECT auth.uid()) AND blocked_alias = p_alias;
$$;

------------------------------------------------------------
-- 3. 차단 목록 조회 RPC
------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_blocked_aliases()
RETURNS TEXT[]
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public
AS $$
  SELECT COALESCE(array_agg(blocked_alias), '{}')
  FROM user_blocks
  WHERE blocker_id = (SELECT auth.uid());
$$;
