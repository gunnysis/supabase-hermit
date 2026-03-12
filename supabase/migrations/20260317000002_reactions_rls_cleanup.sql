-- reactions/user_reactions 직접 쓰기 RLS 정책 제거
-- 모든 쓰기는 toggle_reaction() SECURITY DEFINER RPC를 통해서만 수행
-- 앱/웹 모두 RPC만 사용하는 것 확인 완료 (조사 5)

-- reactions 테이블: INSERT/UPDATE/DELETE 정책 제거 (SELECT 유지)
DROP POLICY IF EXISTS "Authenticated users can create reactions" ON public.reactions;
DROP POLICY IF EXISTS "Authenticated users can update reactions" ON public.reactions;
DROP POLICY IF EXISTS "Authenticated users can delete reactions" ON public.reactions;

-- user_reactions 테이블: INSERT/DELETE 정책 제거 (SELECT 유지)
DROP POLICY IF EXISTS "user_reactions_insert" ON public.user_reactions;
DROP POLICY IF EXISTS "user_reactions_delete" ON public.user_reactions;
