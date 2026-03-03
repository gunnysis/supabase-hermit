-- ============================================
-- Migration: Core Architecture Redesign
-- 은둔마을 웹/앱 코어 설계 개편
-- ============================================

-- ========== 1. REACTION SYSTEM: Atomic toggle RPC ==========
CREATE OR REPLACE FUNCTION toggle_reaction(p_post_id BIGINT, p_type TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_existed BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Try to delete existing user reaction
  DELETE FROM user_reactions
  WHERE user_id = v_user_id AND post_id = p_post_id AND reaction_type = p_type;
  v_existed := FOUND;

  IF v_existed THEN
    -- Decrement aggregate count
    UPDATE reactions SET count = count - 1
    WHERE post_id = p_post_id AND reaction_type = p_type;
    -- Clean up zero-count rows
    DELETE FROM reactions
    WHERE post_id = p_post_id AND reaction_type = p_type AND count <= 0;
  ELSE
    -- Insert user reaction
    INSERT INTO user_reactions(user_id, post_id, reaction_type)
    VALUES (v_user_id, p_post_id, p_type);
    -- Upsert aggregate count
    INSERT INTO reactions(post_id, reaction_type, count) VALUES (p_post_id, p_type, 1)
    ON CONFLICT (post_id, reaction_type) DO UPDATE SET count = reactions.count + 1;
  END IF;

  RETURN jsonb_build_object(
    'action', CASE WHEN v_existed THEN 'removed' ELSE 'added' END
  );
END;
$$;

-- ========== 2. REACTION SYSTEM: Get reactions with user state ==========
CREATE OR REPLACE FUNCTION get_post_reactions(p_post_id BIGINT)
RETURNS TABLE(reaction_type TEXT, count INT, user_reacted BOOLEAN)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    r.reaction_type,
    r.count,
    EXISTS(
      SELECT 1 FROM user_reactions ur
      WHERE ur.post_id = p_post_id
      AND ur.user_id = auth.uid()
      AND ur.reaction_type = r.reaction_type
    ) as user_reacted
  FROM reactions r
  WHERE r.post_id = p_post_id;
$$;

-- ========== 3. REACTION RLS: Remove dangerous public write access ==========
DROP POLICY IF EXISTS "Authenticated users can create reactions" ON reactions;
DROP POLICY IF EXISTS "Authenticated users can update reactions" ON reactions;
DROP POLICY IF EXISTS "Authenticated users can delete reactions" ON reactions;
-- Keep SELECT policy for backward compatibility

-- ========== 4. SOFT DELETE: RPC functions ==========
CREATE OR REPLACE FUNCTION soft_delete_post(p_post_id BIGINT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE posts
  SET deleted_at = now(), updated_at = now()
  WHERE id = p_post_id AND author_id = auth.uid() AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cannot delete post: not found, not authorized, or already deleted';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION soft_delete_comment(p_comment_id BIGINT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE comments
  SET deleted_at = now(), updated_at = now()
  WHERE id = p_comment_id AND author_id = auth.uid() AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cannot delete comment: not found, not authorized, or already deleted';
  END IF;
END;
$$;

-- ========== 5. SOFT DELETE: Remove hard DELETE policies ==========
DROP POLICY IF EXISTS "Users can delete own posts" ON posts;
DROP POLICY IF EXISTS "Users can delete own comments" ON comments;

-- ========== 6. GROUP MEMBERS: Expand SELECT policy ==========
DROP POLICY IF EXISTS "Users can read own group_members" ON group_members;

CREATE POLICY "Users can read group_members" ON group_members
FOR SELECT USING (
  auth.uid() = user_id
  OR (
    status = 'approved' AND left_at IS NULL AND EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = group_members.group_id
      AND gm.user_id = auth.uid()
      AND gm.status = 'approved'
      AND gm.left_at IS NULL
    )
  )
);

-- ========== 7. FK CASCADE: Fix posts and comments FKs ==========
ALTER TABLE posts DROP CONSTRAINT posts_board_id_fkey;
ALTER TABLE posts ADD CONSTRAINT posts_board_id_fkey
  FOREIGN KEY (board_id) REFERENCES boards(id) ON DELETE SET NULL;

ALTER TABLE posts DROP CONSTRAINT posts_group_id_fkey;
ALTER TABLE posts ADD CONSTRAINT posts_group_id_fkey
  FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE SET NULL;

ALTER TABLE comments DROP CONSTRAINT comments_board_id_fkey;
ALTER TABLE comments ADD CONSTRAINT comments_board_id_fkey
  FOREIGN KEY (board_id) REFERENCES boards(id) ON DELETE SET NULL;

ALTER TABLE comments DROP CONSTRAINT comments_group_id_fkey;
ALTER TABLE comments ADD CONSTRAINT comments_group_id_fkey
  FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE SET NULL;

-- ========== 8. CONSTRAINTS: Missing ones ==========
ALTER TABLE groups ADD CONSTRAINT groups_invite_code_unique UNIQUE (invite_code);

ALTER TABLE posts ADD CONSTRAINT posts_title_length CHECK (length(title) <= 200);
ALTER TABLE posts ADD CONSTRAINT posts_content_length CHECK (length(content) <= 100000);
ALTER TABLE comments ADD CONSTRAINT comments_content_length CHECK (length(content) <= 5000);
ALTER TABLE groups ADD CONSTRAINT groups_name_length CHECK (length(name) <= 100);
ALTER TABLE groups ADD CONSTRAINT groups_description_length CHECK (length(description) <= 1000);

-- ========== 9. INDEXES: Performance ==========
CREATE INDEX IF NOT EXISTS idx_post_analysis_emotions ON post_analysis USING GIN(emotions);
CREATE INDEX IF NOT EXISTS idx_posts_group_created_at ON posts(group_id, created_at DESC);
DROP INDEX IF EXISTS idx_post_analysis_post_id;

-- ========== 10. REALTIME: Add tables to publication ==========
-- post_analysis already added, add others needed for realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.reactions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_reactions;
