-- =============================================================================
-- 20260311000001_analysis_status_retry.sql
-- 감정분석 재시도 및 실패 증상 개선
--
-- 변경:
--   1. post_analysis에 status/retry_count/error_reason/last_attempted_at 컬럼 추가
--   2. 게시글 INSERT 시 pending 행 자동 생성 트리거
--   3. 게시글 UPDATE (content/title) 시 analyzing으로 전환 트리거
--   4. posts_with_like_count 뷰에 analysis_status 추가
--   5. 상태별 인덱스
-- =============================================================================

-- ============================================================
-- Phase 1: post_analysis 상태 관리 컬럼 추가
-- ============================================================
ALTER TABLE public.post_analysis
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'done'
    CHECK (status IN ('pending', 'analyzing', 'done', 'failed')),
  ADD COLUMN IF NOT EXISTS retry_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS error_reason TEXT,
  ADD COLUMN IF NOT EXISTS last_attempted_at TIMESTAMPTZ;

-- 기존 데이터: emotions 있으면 done (DEFAULT), 없으면 그대로 done 유지
-- 분석 누락 게시글에 pending 행 삽입
INSERT INTO public.post_analysis (post_id, status, emotions)
SELECT p.id, 'pending', '{}'
FROM public.posts p
LEFT JOIN public.post_analysis pa ON p.id = pa.post_id
WHERE pa.post_id IS NULL AND p.deleted_at IS NULL
ON CONFLICT (post_id) DO NOTHING;

-- 상태별 조회 인덱스 (failed/pending 모니터링용)
CREATE INDEX IF NOT EXISTS idx_post_analysis_status
  ON public.post_analysis (status)
  WHERE status IN ('pending', 'failed');

-- ============================================================
-- Phase 2: 게시글 INSERT 시 pending 행 자동 생성
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_pending_analysis()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.post_analysis (post_id, status, emotions)
  VALUES (NEW.id, 'pending', '{}')
  ON CONFLICT (post_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_pending_analysis ON public.posts;
CREATE TRIGGER trg_create_pending_analysis
  AFTER INSERT ON public.posts
  FOR EACH ROW
  EXECUTE FUNCTION public.create_pending_analysis();

-- ============================================================
-- Phase 3: 게시글 UPDATE (content/title) 시 analyzing 전환
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_analysis_analyzing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.post_analysis
  SET status = 'analyzing',
      last_attempted_at = now()
  WHERE post_id = NEW.id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mark_analysis_analyzing ON public.posts;
CREATE TRIGGER trg_mark_analysis_analyzing
  AFTER UPDATE OF content, title ON public.posts
  FOR EACH ROW
  WHEN (OLD.content IS DISTINCT FROM NEW.content OR OLD.title IS DISTINCT FROM NEW.title)
  EXECUTE FUNCTION public.mark_analysis_analyzing();

-- ============================================================
-- Phase 4: posts_with_like_count 뷰에 analysis_status 추가
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
  pa.emotions,
  COALESCE(pa.status, 'pending') AS analysis_status
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
