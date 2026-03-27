-- 이미지 기능 제거
-- 1. posts.image_url 데이터 NULL 처리
-- 2. Storage 버킷 정책 제거
-- 3. posts.image_url 컬럼 DROP
-- Note: Storage 버킷 자체 삭제 + 파일 삭제는 Dashboard에서 수동 처리 필요

-- 1. 기존 이미지 URL 데이터 NULL 처리
UPDATE public.posts SET image_url = NULL WHERE image_url IS NOT NULL;

-- 2. Storage RLS 정책 제거
DROP POLICY IF EXISTS "Authenticated users can upload post images" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view post images"              ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own post images"         ON storage.objects;

-- 3. 의존 뷰 먼저 제거 (image_url 컬럼 의존)
DROP VIEW IF EXISTS public.posts_with_like_count;

-- 4. posts.image_url 컬럼 제거
ALTER TABLE public.posts DROP COLUMN IF EXISTS image_url;

-- 5. posts_with_like_count 뷰 재생성 (image_url 없이)
CREATE VIEW public.posts_with_like_count
  WITH (security_invoker = true)
AS
SELECT
  p.id,
  p.title,
  p.content,
  p.author_id,
  p.created_at,
  p.board_id,
  p.is_anonymous,
  p.display_name,
  p.initial_emotions,
  p.post_type,
  p.activities,
  COALESCE(r_agg.total_reactions, 0)::integer AS like_count,
  COALESCE(c_agg.total_comments,  0)::integer AS comment_count,
  pa.emotions
FROM public.posts p
LEFT JOIN (
  SELECT post_id, SUM(count) AS total_reactions
  FROM public.reactions
  GROUP BY post_id
) r_agg ON r_agg.post_id = p.id
LEFT JOIN (
  SELECT post_id, COUNT(*) AS total_comments
  FROM public.comments
  WHERE deleted_at IS NULL
  GROUP BY post_id
) c_agg ON c_agg.post_id = p.id
LEFT JOIN public.post_analysis pa ON pa.post_id = p.id
WHERE p.deleted_at IS NULL;

-- 6. Storage 버킷(post-images) 삭제는 Supabase Dashboard에서 수동 처리
-- (SQL 직접 삭제 불가: "Direct deletion from storage tables is not allowed")
