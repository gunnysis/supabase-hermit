-- ============================================================
-- Migration: Supabase Advisor 권고사항 수정
-- Performance: RLS initplan 최적화 (auth.uid() → (select auth.uid()))
-- Security: get_post_reactions search_path 설정
-- Security: Extensions public → extensions 스키마 이동
-- ============================================================

-- ============================================================
-- 1. Performance: RLS initplan 최적화
--    auth.uid()/auth.role()를 (select ...) 래핑 → 쿼리당 1회 실행
-- ============================================================

-- 1a. user_preferences 정책
DROP POLICY IF EXISTS "user_prefs_select" ON public.user_preferences;
CREATE POLICY "user_prefs_select" ON public.user_preferences
  FOR SELECT USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_prefs_insert" ON public.user_preferences;
CREATE POLICY "user_prefs_insert" ON public.user_preferences
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_prefs_update" ON public.user_preferences;
CREATE POLICY "user_prefs_update" ON public.user_preferences
  FOR UPDATE USING ((select auth.uid()) = user_id);

-- 1b. posts UPDATE 정책
DROP POLICY IF EXISTS "Users can update own posts" ON public.posts;
CREATE POLICY "Users can update own posts" ON public.posts
  FOR UPDATE
  USING ((select auth.uid()) = author_id)
  WITH CHECK ((select auth.uid()) = author_id);

-- 1c. comments UPDATE 정책
DROP POLICY IF EXISTS "Users can update own comments" ON public.comments;
CREATE POLICY "Users can update own comments" ON public.comments
  FOR UPDATE
  USING ((select auth.uid()) = author_id)
  WITH CHECK ((select auth.uid()) = author_id);

-- 1d. post_analysis SELECT 정책
DROP POLICY IF EXISTS "post_analysis_select" ON public.post_analysis;
CREATE POLICY "post_analysis_select" ON public.post_analysis
  FOR SELECT USING ((select auth.role()) = 'authenticated');

-- ============================================================
-- 2. Security: get_post_reactions search_path 설정
-- ============================================================

CREATE OR REPLACE FUNCTION get_post_reactions(p_post_id BIGINT)
RETURNS TABLE(reaction_type TEXT, count INT, user_reacted BOOLEAN)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
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

-- ============================================================
-- 3. Security: Extensions → extensions 스키마 이동
--    Supabase hosted 환경에서 extensions 스키마가 search_path에
--    기본 포함되어 있어 기존 쿼리에 영향 없음.
-- ============================================================

DO $$
BEGIN
  -- extensions 스키마 생성 (이미 존재할 수 있음)
  CREATE SCHEMA IF NOT EXISTS extensions;

  -- pg_trgm 이동
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm'
    AND extnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  ) THEN
    ALTER EXTENSION pg_trgm SET SCHEMA extensions;
    RAISE NOTICE 'pg_trgm moved to extensions schema';
  END IF;

  -- pgroonga 이동
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pgroonga'
    AND extnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  ) THEN
    ALTER EXTENSION pgroonga SET SCHEMA extensions;
    RAISE NOTICE 'pgroonga moved to extensions schema';
  END IF;

EXCEPTION
  WHEN others THEN
    -- Supabase hosted 환경에서 ALTER EXTENSION SET SCHEMA가
    -- 권한 부족으로 실패할 수 있음 → 경고만 출력
    RAISE WARNING 'Extension schema migration skipped: %', SQLERRM;
END;
$$;
