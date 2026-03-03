-- =============================================================================
-- 20260301000002_rls.sql — 은둔마을 RLS 정책 베이스라인
--
-- 모든 테이블 RLS 활성화 + 정책 정의.
-- DROP POLICY IF EXISTS → CREATE POLICY 멱등 패턴 적용.
-- =============================================================================

ALTER TABLE public.posts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reactions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boards        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_admin     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_analysis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_reactions ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- posts
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Everyone can read posts"              ON public.posts;
DROP POLICY IF EXISTS "Authenticated users can create posts" ON public.posts;
DROP POLICY IF EXISTS "Users can update own posts"           ON public.posts;
DROP POLICY IF EXISTS "Users can delete own posts"           ON public.posts;

CREATE POLICY "Everyone can read posts" ON public.posts FOR SELECT
  USING (deleted_at IS NULL AND (group_id IS NULL OR EXISTS (
    SELECT 1 FROM public.group_members gm
    WHERE gm.group_id = posts.group_id AND gm.user_id = (SELECT auth.uid()) AND gm.status = 'approved'
  )));
CREATE POLICY "Authenticated users can create posts" ON public.posts FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = author_id);
CREATE POLICY "Users can update own posts" ON public.posts FOR UPDATE
  USING ((SELECT auth.uid()) = author_id AND deleted_at IS NULL)
  WITH CHECK ((SELECT auth.uid()) = author_id);
CREATE POLICY "Users can delete own posts" ON public.posts FOR DELETE
  USING ((SELECT auth.uid()) = author_id);

-- ----------------------------------------------------------------------------
-- comments
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Everyone can read comments"              ON public.comments;
DROP POLICY IF EXISTS "Authenticated users can create comments" ON public.comments;
DROP POLICY IF EXISTS "Users can update own comments"           ON public.comments;
DROP POLICY IF EXISTS "Users can delete own comments"           ON public.comments;

CREATE POLICY "Everyone can read comments" ON public.comments FOR SELECT
  USING (deleted_at IS NULL AND (group_id IS NULL OR EXISTS (
    SELECT 1 FROM public.group_members gm
    WHERE gm.group_id = comments.group_id AND gm.user_id = (SELECT auth.uid()) AND gm.status = 'approved'
  )));
CREATE POLICY "Authenticated users can create comments" ON public.comments FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = author_id);
CREATE POLICY "Users can update own comments" ON public.comments FOR UPDATE
  USING ((SELECT auth.uid()) = author_id AND deleted_at IS NULL)
  WITH CHECK ((SELECT auth.uid()) = author_id);
CREATE POLICY "Users can delete own comments" ON public.comments FOR DELETE
  USING ((SELECT auth.uid()) = author_id);

-- ----------------------------------------------------------------------------
-- reactions
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Everyone can read reactions"              ON public.reactions;
DROP POLICY IF EXISTS "Authenticated users can create reactions" ON public.reactions;
DROP POLICY IF EXISTS "Authenticated users can update reactions" ON public.reactions;
DROP POLICY IF EXISTS "Authenticated users can delete reactions" ON public.reactions;

CREATE POLICY "Everyone can read reactions"              ON public.reactions FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create reactions" ON public.reactions FOR INSERT
  WITH CHECK (auth.role() IN ('authenticated', 'anon'));
CREATE POLICY "Authenticated users can update reactions" ON public.reactions FOR UPDATE
  USING (auth.role() IN ('authenticated', 'anon'));
CREATE POLICY "Authenticated users can delete reactions" ON public.reactions FOR DELETE
  USING (auth.role() IN ('authenticated', 'anon'));

-- ----------------------------------------------------------------------------
-- boards
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Everyone can read boards"         ON public.boards;
DROP POLICY IF EXISTS "Only app_admin can create boards" ON public.boards;

CREATE POLICY "Everyone can read boards"         ON public.boards FOR SELECT USING (true);
CREATE POLICY "Only app_admin can create boards" ON public.boards FOR INSERT
  WITH CHECK ((SELECT auth.uid()) IN (SELECT user_id FROM public.app_admin));

-- ----------------------------------------------------------------------------
-- groups
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Everyone can read groups"                  ON public.groups;
DROP POLICY IF EXISTS "Only app_admin can create groups as owner" ON public.groups;

CREATE POLICY "Everyone can read groups"                  ON public.groups FOR SELECT USING (true);
CREATE POLICY "Only app_admin can create groups as owner" ON public.groups FOR INSERT
  WITH CHECK ((SELECT auth.uid()) IN (SELECT user_id FROM public.app_admin) AND owner_id = (SELECT auth.uid()));

-- ----------------------------------------------------------------------------
-- group_members
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can read own group_members"   ON public.group_members;
DROP POLICY IF EXISTS "Users can join groups"              ON public.group_members;
DROP POLICY IF EXISTS "Users can update own group_members" ON public.group_members;

CREATE POLICY "Users can read own group_members"   ON public.group_members FOR SELECT USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can join groups"              ON public.group_members FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can update own group_members" ON public.group_members FOR UPDATE
  USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);

-- ----------------------------------------------------------------------------
-- app_admin
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can read own app_admin row" ON public.app_admin;
CREATE POLICY "Users can read own app_admin row" ON public.app_admin FOR SELECT USING ((SELECT auth.uid()) = user_id);

-- ----------------------------------------------------------------------------
-- post_analysis
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "post_analysis_select" ON public.post_analysis;
CREATE POLICY "post_analysis_select" ON public.post_analysis FOR SELECT USING (true);

-- ----------------------------------------------------------------------------
-- user_reactions
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "user_reactions_select" ON public.user_reactions;
DROP POLICY IF EXISTS "user_reactions_insert" ON public.user_reactions;
DROP POLICY IF EXISTS "user_reactions_delete" ON public.user_reactions;

CREATE POLICY "user_reactions_select" ON public.user_reactions FOR SELECT USING (true);
CREATE POLICY "user_reactions_insert" ON public.user_reactions FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "user_reactions_delete" ON public.user_reactions FOR DELETE USING ((SELECT auth.uid()) = user_id);
