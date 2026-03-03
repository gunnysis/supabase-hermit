-- =============================================================================
-- Fix: infinite recursion in group_members SELECT policy
--
-- 원인: core_redesign에서 group_members SELECT 정책이 자기 자신을 조회
--       → posts/comments 정책도 group_members 참조 → 연쇄 500 에러
-- 해결: SECURITY DEFINER 함수로 RLS 우회 멤버십 체크
-- =============================================================================

-- 1. Helper function: RLS를 우회하여 멤버십 확인
CREATE OR REPLACE FUNCTION is_group_member(p_group_id BIGINT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM group_members
    WHERE group_id = p_group_id
    AND user_id = auth.uid()
    AND status = 'approved'
    AND left_at IS NULL
  );
$$;

-- 2. group_members: 재귀 정책 교체
DROP POLICY IF EXISTS "Users can read group_members" ON group_members;
DROP POLICY IF EXISTS "Users can read own group_members" ON group_members;

CREATE POLICY "Users can read group_members" ON group_members
FOR SELECT USING (
  -- 자기 행은 항상 볼 수 있음
  (SELECT auth.uid()) = user_id
  OR (
    -- 같은 그룹의 승인된 멤버도 볼 수 있음 (SECURITY DEFINER 함수로 재귀 방지)
    status = 'approved' AND left_at IS NULL
    AND is_group_member(group_id)
  )
);

-- 3. posts: group_members 직접 조회 대신 함수 사용
DROP POLICY IF EXISTS "Everyone can read posts" ON posts;
CREATE POLICY "Everyone can read posts" ON posts FOR SELECT
  USING (
    deleted_at IS NULL
    AND (group_id IS NULL OR is_group_member(group_id))
  );

-- 4. comments: 동일 패턴 적용
DROP POLICY IF EXISTS "Everyone can read comments" ON comments;
CREATE POLICY "Everyone can read comments" ON comments FOR SELECT
  USING (
    deleted_at IS NULL
    AND (group_id IS NULL OR is_group_member(group_id))
  );
