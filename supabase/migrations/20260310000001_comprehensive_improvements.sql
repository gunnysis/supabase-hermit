-- =============================================================================
-- 20260310000001_comprehensive_improvements.sql
-- 종합 개선: 공개 게시판 생성, 뷰 성능 최적화, 리액션 동시성, 검색 RPC
-- =============================================================================

-- ============================================================
-- Phase 1: 공개 게시판 생성
-- 현재 boards 2개 모두 private/group 소속 → 비그룹원 글 쓰기/읽기 불가
-- group_id IS NULL, visibility='public' 게시판 필요
-- ============================================================
INSERT INTO public.boards (name, description, visibility, anon_mode, group_id)
SELECT '자유게시판', '누구나 자유롭게 마음을 나눌 수 있는 공간입니다.', 'public', 'always_anon', NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.boards WHERE visibility = 'public' AND group_id IS NULL
);

-- ============================================================
-- Phase 2: posts_with_like_count 뷰 성능 최적화
-- 스칼라 서브쿼리 2개 → LEFT JOIN + GROUP BY로 전환
-- ============================================================
DROP VIEW IF EXISTS public.posts_with_like_count;
CREATE VIEW public.posts_with_like_count
  WITH (security_invoker = true)
AS
SELECT
  p.id, p.title, p.content, p.author_id, p.created_at,
  p.board_id, p.group_id, p.is_anonymous, p.display_name, p.member_id, p.image_url,
  p.initial_emotions,
  COALESCE(r_agg.total_reactions, 0)::integer AS like_count,
  COALESCE(c_agg.total_comments, 0)::integer AS comment_count,
  pa.emotions
FROM public.posts p
LEFT JOIN public.post_analysis pa ON pa.post_id = p.id
LEFT JOIN (
  SELECT r.post_id, SUM(r.count)::integer AS total_reactions
  FROM public.reactions r
  GROUP BY r.post_id
) r_agg ON r_agg.post_id = p.id
LEFT JOIN (
  SELECT c.post_id, COUNT(*)::integer AS total_comments
  FROM public.comments c
  WHERE c.deleted_at IS NULL
  GROUP BY c.post_id
) c_agg ON c_agg.post_id = p.id
WHERE p.deleted_at IS NULL;

-- ============================================================
-- Phase 3: toggle_reaction 동시성 안전 (Advisory Lock)
-- DELETE→INSERT 사이 레이스 컨디션 방지
-- ============================================================
CREATE OR REPLACE FUNCTION public.toggle_reaction(p_post_id BIGINT, p_type TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_existed BOOLEAN;
  v_lock_key BIGINT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Advisory lock: user_id 해시 + post_id로 고유 잠금
  v_lock_key := hashtext(v_user_id::text || ':' || p_post_id::text);
  PERFORM pg_advisory_xact_lock(v_lock_key);

  -- Try to delete existing
  DELETE FROM user_reactions
  WHERE user_id = v_user_id AND post_id = p_post_id AND reaction_type = p_type;
  v_existed := FOUND;

  IF v_existed THEN
    UPDATE reactions SET count = count - 1
    WHERE post_id = p_post_id AND reaction_type = p_type;
    DELETE FROM reactions
    WHERE post_id = p_post_id AND reaction_type = p_type AND count <= 0;
  ELSE
    INSERT INTO user_reactions(user_id, post_id, reaction_type)
    VALUES (v_user_id, p_post_id, p_type);
    INSERT INTO reactions(post_id, reaction_type, count) VALUES (p_post_id, p_type, 1)
    ON CONFLICT (post_id, reaction_type) DO UPDATE SET count = reactions.count + 1;
  END IF;

  RETURN jsonb_build_object(
    'action', CASE WHEN v_existed THEN 'removed' ELSE 'added' END
  );
END;
$$;

-- ============================================================
-- Phase 4: 게시글 검색 RPC (full-text search)
-- 제목+내용 한국어 검색 (ILIKE 기반, 향후 pg_bigm/pgroonga 확장 가능)
-- ============================================================
CREATE OR REPLACE FUNCTION public.search_posts(
  p_query TEXT,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
) RETURNS TABLE(
  id BIGINT,
  title TEXT,
  board_id BIGINT,
  like_count INTEGER,
  comment_count INTEGER,
  emotions TEXT[],
  created_at TIMESTAMPTZ,
  display_name TEXT,
  content_preview TEXT
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_pattern TEXT;
BEGIN
  -- 빈 검색어 방지
  IF p_query IS NULL OR length(trim(p_query)) < 2 THEN
    RETURN;
  END IF;

  v_pattern := '%' || trim(p_query) || '%';

  RETURN QUERY
  SELECT v.id, v.title, v.board_id, v.like_count, v.comment_count,
    v.emotions, v.created_at, v.display_name,
    left(regexp_replace(v.content, '<[^>]*>', '', 'g'), 200) AS content_preview
  FROM posts_with_like_count v
  WHERE v.group_id IS NULL
    AND (v.title ILIKE v_pattern OR v.content ILIKE v_pattern)
  ORDER BY v.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- 검색 성능 인덱스 (trigram) — pg_trgm 확장이 있으면 활용
DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
  CREATE INDEX IF NOT EXISTS idx_posts_title_trgm ON public.posts USING gin(title gin_trgm_ops);
  CREATE INDEX IF NOT EXISTS idx_posts_content_trgm ON public.posts USING gin(content gin_trgm_ops);
EXCEPTION WHEN OTHERS THEN
  -- pg_trgm 미설치 시 graceful fallback
  RAISE NOTICE 'pg_trgm extension not available, skipping trigram indexes';
END $$;

-- ============================================================
-- Phase 5: soft_delete에 관리자 권한 추가
-- app_admin 사용자도 소프트삭제 가능하도록
-- ============================================================
CREATE OR REPLACE FUNCTION public.soft_delete_post(p_post_id BIGINT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_admin BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT EXISTS(SELECT 1 FROM app_admin WHERE user_id = v_user_id) INTO v_is_admin;

  UPDATE posts
  SET deleted_at = now(), updated_at = now()
  WHERE id = p_post_id
    AND deleted_at IS NULL
    AND (author_id = v_user_id OR v_is_admin);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cannot delete post: not found, not authorized, or already deleted';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.soft_delete_comment(p_comment_id BIGINT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_admin BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT EXISTS(SELECT 1 FROM app_admin WHERE user_id = v_user_id) INTO v_is_admin;

  UPDATE comments
  SET deleted_at = now(), updated_at = now()
  WHERE id = p_comment_id
    AND deleted_at IS NULL
    AND (author_id = v_user_id OR v_is_admin);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cannot delete comment: not found, not authorized, or already deleted';
  END IF;
END;
$$;
