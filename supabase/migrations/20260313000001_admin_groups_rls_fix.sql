-- =============================================================================
-- 20260313000001_admin_groups_rls_fix.sql — 관리자 그룹 관리 RLS + 제약조건
--
-- Phase 0: groups UPDATE/DELETE RLS 정책 추가 + invite_code 길이 CHECK
-- 멱등 패턴: DROP POLICY IF EXISTS → CREATE POLICY
-- =============================================================================

-- ============================================================
-- groups UPDATE: owner만 수정 가능
-- ============================================================
DROP POLICY IF EXISTS "Owner can update own groups" ON public.groups;
CREATE POLICY "Owner can update own groups" ON public.groups FOR UPDATE
  USING ((SELECT auth.uid()) = owner_id)
  WITH CHECK ((SELECT auth.uid()) = owner_id);

-- ============================================================
-- groups DELETE: owner만 삭제 가능
-- ============================================================
DROP POLICY IF EXISTS "Owner can delete own groups" ON public.groups;
CREATE POLICY "Owner can delete own groups" ON public.groups FOR DELETE
  USING ((SELECT auth.uid()) = owner_id);

-- ============================================================
-- invite_code 길이 제약 (4~50자, NULL 허용)
-- 기존 데이터 중 4자 미만인 행을 6자 랜덤 코드로 갱신 후 제약 추가
-- ============================================================
UPDATE public.groups
  SET invite_code = upper(substr(md5(random()::text), 1, 6))
  WHERE invite_code IS NOT NULL AND length(invite_code) < 4;

ALTER TABLE public.groups DROP CONSTRAINT IF EXISTS groups_invite_code_length;
ALTER TABLE public.groups ADD CONSTRAINT groups_invite_code_length
  CHECK (invite_code IS NULL OR length(invite_code) BETWEEN 4 AND 50);
