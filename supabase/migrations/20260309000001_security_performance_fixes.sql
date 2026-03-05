-- 보안/성능/안정성 강화 마이그레이션
-- - boards RLS 가시성 검사 추가
-- - 인덱스 추가 (user_reactions, app_admin, boards)
-- - get_emotion_trend: 삭제된 게시글 제외
-- - get_recommended_posts_by_emotion: CTE 기반 최적화
-- - 리액션 타입 CHECK 제약조건
-- - boards 이름 유니크 인덱스

-- ============================================================
-- Phase 1: 보안 — boards RLS 가시성 검사
-- ============================================================
DROP POLICY IF EXISTS "Everyone can read boards" ON public.boards;
DROP POLICY IF EXISTS "boards_select" ON public.boards;
CREATE POLICY "boards_select" ON public.boards FOR SELECT
  USING (
    visibility = 'public'
    OR group_id IS NULL
    OR public.is_group_member(group_id)
  );

-- ============================================================
-- Phase 2: 성능 — 인덱스 추가
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_user_reactions_post_type
  ON public.user_reactions(post_id, reaction_type);

CREATE INDEX IF NOT EXISTS idx_app_admin_user_id
  ON public.app_admin(user_id);

CREATE INDEX IF NOT EXISTS idx_boards_visibility
  ON public.boards(visibility) WHERE group_id IS NULL;

-- ============================================================
-- Phase 2: 성능 — get_emotion_trend 삭제 게시글 제외
-- ============================================================
DROP FUNCTION IF EXISTS public.get_emotion_trend(INTEGER);
CREATE OR REPLACE FUNCTION public.get_emotion_trend(days INTEGER DEFAULT 7)
  RETURNS TABLE(emotion TEXT, cnt BIGINT, pct NUMERIC)
  LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_total BIGINT;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM post_analysis pa
  JOIN posts p ON p.id = pa.post_id AND p.deleted_at IS NULL,
  LATERAL unnest(pa.emotions) AS e
  WHERE pa.analyzed_at >= (now() - (days || ' days')::INTERVAL);

  IF v_total = 0 THEN RETURN; END IF;

  RETURN QUERY
  SELECT e AS emotion,
    COUNT(*)::BIGINT AS cnt,
    ROUND(COUNT(*)::NUMERIC / v_total * 100, 1) AS pct
  FROM post_analysis pa
  JOIN posts p ON p.id = pa.post_id AND p.deleted_at IS NULL,
  LATERAL unnest(pa.emotions) AS e
  WHERE pa.analyzed_at >= (now() - (days || ' days')::INTERVAL)
  GROUP BY e
  ORDER BY cnt DESC
  LIMIT 5;
END;
$$;

-- ============================================================
-- Phase 2: 성능 — get_recommended_posts_by_emotion CTE 최적화
-- ============================================================
DROP FUNCTION IF EXISTS public.get_recommended_posts_by_emotion(BIGINT, INTEGER);
CREATE OR REPLACE FUNCTION public.get_recommended_posts_by_emotion(
  p_post_id BIGINT,
  p_limit INTEGER DEFAULT 10
) RETURNS TABLE(
  id BIGINT,
  title TEXT,
  board_id BIGINT,
  like_count INTEGER,
  comment_count INTEGER,
  emotions TEXT[],
  created_at TIMESTAMPTZ,
  score DOUBLE PRECISION
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_emotions TEXT[];
BEGIN
  SELECT COALESCE(pa.emotions, '{}') INTO v_emotions
  FROM post_analysis pa WHERE pa.post_id = p_post_id;

  -- 폴백: 감정 없으면 참여도+최신순 추천
  IF v_emotions IS NULL OR array_length(v_emotions, 1) IS NULL THEN
    RETURN QUERY
    SELECT v.id, v.title, v.board_id, v.like_count, v.comment_count,
      v.emotions, v.created_at,
      (v.like_count + v.comment_count * 2)::DOUBLE PRECISION
        / (1.0 + EXTRACT(EPOCH FROM (now() - v.created_at)) / 86400.0) AS score
    FROM posts_with_like_count v
    WHERE v.id != p_post_id AND v.group_id IS NULL
    ORDER BY score DESC, v.created_at DESC
    LIMIT p_limit;
    RETURN;
  END IF;

  -- CTE로 match_score 1회 계산
  RETURN QUERY
  WITH scored AS (
    SELECT v.id, v.title, v.board_id, v.like_count, v.comment_count,
      v.emotions, v.created_at,
      (
        cardinality(ARRAY(
          SELECT unnest(v.emotions) INTERSECT SELECT unnest(v_emotions)
        ))::DOUBLE PRECISION * 10.0
        + (v.like_count + v.comment_count * 2)::DOUBLE PRECISION
      ) / (1.0 + EXTRACT(EPOCH FROM (now() - v.created_at)) / 604800.0) AS score
    FROM posts_with_like_count v
    WHERE v.id != p_post_id
      AND v.group_id IS NULL
      AND v.emotions IS NOT NULL
      AND v.emotions && v_emotions
  )
  SELECT s.id, s.title, s.board_id, s.like_count, s.comment_count,
    s.emotions, s.created_at, s.score
  FROM scored s
  ORDER BY s.score DESC, s.created_at DESC
  LIMIT p_limit;
END;
$$;

-- ============================================================
-- Phase 4: 제약조건
-- ============================================================

-- 리액션 타입 검증
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'reactions_type_check'
  ) THEN
    ALTER TABLE public.reactions ADD CONSTRAINT reactions_type_check
      CHECK (reaction_type IN ('like','heart','laugh','sad','surprise'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_reactions_type_check'
  ) THEN
    ALTER TABLE public.user_reactions ADD CONSTRAINT user_reactions_type_check
      CHECK (reaction_type IN ('like','heart','laugh','sad','surprise'));
  END IF;
END $$;

-- 게시판 이름 유니크 (그룹 내)
CREATE UNIQUE INDEX IF NOT EXISTS idx_boards_name_group
  ON public.boards(name, COALESCE(group_id, 0));
