-- =============================================================================
-- 20260306000001_remove_author_column.sql
-- posts, comments 테이블에서 중복 author(TEXT) 컬럼 제거
-- display_name 컬럼만 유지 (author_id UUID FK는 그대로)
-- =============================================================================

-- 1) posts_with_like_count 뷰를 DROP 후 재생성 (author 컬럼 제외)
--    CREATE OR REPLACE VIEW는 컬럼 삭제를 허용하지 않으므로 DROP 필요
DROP VIEW IF EXISTS public.posts_with_like_count;
CREATE VIEW public.posts_with_like_count
  WITH (security_invoker = true)
AS
SELECT
  p.id, p.title, p.content, p.author_id, p.created_at,
  p.board_id, p.group_id, p.is_anonymous, p.display_name, p.member_id, p.image_url,
  (COALESCE(
    (SELECT SUM(r.count) FROM public.reactions r WHERE r.post_id = p.id),
    0
  ))::integer AS like_count,
  (SELECT COUNT(*)::integer FROM public.comments c WHERE c.post_id = p.id AND c.deleted_at IS NULL) AS comment_count,
  pa.emotions
FROM public.posts p
LEFT JOIN public.post_analysis pa ON pa.post_id = p.id
WHERE p.deleted_at IS NULL;

-- 2) posts 테이블에서 author 컬럼 제거
ALTER TABLE public.posts DROP COLUMN author;

-- 3) comments 테이블에서 author 컬럼 제거
ALTER TABLE public.comments DROP COLUMN author;
