-- =============================================================================
-- 20260319000001_remove_group_board_system.sql
-- 그룹 게시판 기능 완전 제거
--
-- 제거 대상: groups, group_members 테이블, 관련 컬럼/FK/인덱스/RLS/함수/트리거
-- 보존 대상: boards 테이블 (공개 게시판 id=12), posts.board_id, comments.board_id
-- =============================================================================

-- ============================================================
-- Phase 1: RLS 정책 제거 — groups, group_members
-- ============================================================
DROP POLICY IF EXISTS "Everyone can read groups" ON public.groups;
DROP POLICY IF EXISTS "Only app_admin can create groups as owner" ON public.groups;
DROP POLICY IF EXISTS "Owner can update own groups" ON public.groups;
DROP POLICY IF EXISTS "Owner can delete own groups" ON public.groups;

DROP POLICY IF EXISTS "Users can read own group_members" ON public.group_members;
DROP POLICY IF EXISTS "Users can read group_members" ON public.group_members;
DROP POLICY IF EXISTS "Users can join groups" ON public.group_members;
DROP POLICY IF EXISTS "Users can update own group_members" ON public.group_members;

-- ============================================================
-- Phase 2: posts/comments RLS 단순화 — group_id 조건 제거
-- ============================================================
DROP POLICY IF EXISTS "Everyone can read posts" ON public.posts;
CREATE POLICY "Everyone can read posts" ON public.posts FOR SELECT
  USING (deleted_at IS NULL);

DROP POLICY IF EXISTS "Everyone can read comments" ON public.comments;
CREATE POLICY "Everyone can read comments" ON public.comments FOR SELECT
  USING (deleted_at IS NULL);

-- ============================================================
-- Phase 3: boards RLS 단순화 — group_id/is_group_member 조건 제거
-- ============================================================
DROP POLICY IF EXISTS "boards_select" ON public.boards;
DROP POLICY IF EXISTS "Everyone can read boards" ON public.boards;
CREATE POLICY "boards_select" ON public.boards FOR SELECT
  USING (true);

-- ============================================================
-- Phase 4: 인덱스 제거 — group/member 관련
-- ============================================================
DROP INDEX IF EXISTS public.idx_posts_group_id;
DROP INDEX IF EXISTS public.idx_posts_member_id;
DROP INDEX IF EXISTS public.idx_posts_group_created_at;
DROP INDEX IF EXISTS public.idx_posts_trending;
DROP INDEX IF EXISTS public.idx_comments_group_id;
DROP INDEX IF EXISTS public.idx_boards_group_id;
DROP INDEX IF EXISTS public.idx_boards_visibility;
DROP INDEX IF EXISTS public.idx_groups_owner_id;
DROP INDEX IF EXISTS public.idx_groups_invite_code;
DROP INDEX IF EXISTS public.idx_group_members_user_id;
DROP INDEX IF EXISTS public.idx_group_members_lookup;
DROP INDEX IF EXISTS public.idx_group_members_approved;
DROP INDEX IF EXISTS public.idx_group_members_left_at;

-- FTS 인덱스 재생성 (group_id IS NULL 조건 제거)
DROP INDEX IF EXISTS public.idx_posts_fts;
CREATE INDEX idx_posts_fts
  ON public.posts
  USING GIN ((to_tsvector('simple', title) || to_tsvector('simple', content)))
  WHERE deleted_at IS NULL;

-- boards visibility 인덱스 재생성 (group_id IS NULL 조건 제거)
CREATE INDEX idx_boards_visibility
  ON public.boards(visibility);

-- trending 인덱스 재생성 (group_id 제거)
CREATE INDEX idx_posts_trending
  ON public.posts(created_at DESC)
  WHERE deleted_at IS NULL;

-- ============================================================
-- Phase 5: 트리거 제거 — groups
-- ============================================================
DROP TRIGGER IF EXISTS trg_groups_updated_at ON public.groups;

-- ============================================================
-- Phase 5.5: 뷰 DROP — 컬럼 DROP 전에 의존 뷰 제거 필수
-- ============================================================
DROP VIEW IF EXISTS public.posts_with_like_count;

-- ============================================================
-- Phase 6: FK 제약조건 제거 → 컬럼 DROP
-- ============================================================
-- posts: group_id, member_id 컬럼 제거
ALTER TABLE public.posts DROP COLUMN IF EXISTS group_id;
ALTER TABLE public.posts DROP COLUMN IF EXISTS member_id;

-- comments: group_id 컬럼 제거
ALTER TABLE public.comments DROP COLUMN IF EXISTS group_id;

-- boards: group_id 컬럼 제거
ALTER TABLE public.boards DROP COLUMN IF EXISTS group_id;

-- ============================================================
-- Phase 7: 테이블 DROP — group_members 먼저 (FK 의존)
-- ============================================================
DROP TABLE IF EXISTS public.group_members CASCADE;
DROP TABLE IF EXISTS public.groups CASCADE;

-- ============================================================
-- Phase 8: 함수 DROP — 그룹 전용
-- ============================================================
DROP FUNCTION IF EXISTS public.is_group_member(BIGINT);
DROP FUNCTION IF EXISTS public.cleanup_orphan_group_members(INTEGER);

-- ============================================================
-- Phase 9: 뷰 재생성 — group_id, member_id 컬럼 제거
-- ============================================================
DROP VIEW IF EXISTS public.posts_with_like_count;
CREATE VIEW public.posts_with_like_count
  WITH (security_invoker = true)
AS
SELECT
  p.id, p.title, p.content, p.author_id, p.created_at,
  p.board_id, p.is_anonymous, p.display_name, p.image_url,
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
-- Phase 10: RPC 함수 재생성 — group_id 참조 제거
-- ============================================================

-- get_recommended_posts_by_emotion: group_id IS NULL 조건 제거
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

  IF v_emotions IS NULL OR array_length(v_emotions, 1) IS NULL THEN
    RETURN QUERY
    SELECT v.id, v.title, v.board_id, v.like_count, v.comment_count,
      v.emotions, v.created_at,
      (v.like_count + v.comment_count * 2)::DOUBLE PRECISION
        / (1.0 + EXTRACT(EPOCH FROM (now() - v.created_at)) / 86400.0) AS score
    FROM posts_with_like_count v
    WHERE v.id != p_post_id
    ORDER BY score DESC, v.created_at DESC
    LIMIT p_limit;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT v.id, v.title, v.board_id, v.like_count, v.comment_count,
    v.emotions, v.created_at,
    (
      (SELECT COUNT(*) FROM unnest(v.emotions) e WHERE e = ANY(v_emotions))::DOUBLE PRECISION * 10.0
      + (v.like_count + v.comment_count * 2)::DOUBLE PRECISION
    ) / (1.0 + EXTRACT(EPOCH FROM (now() - v.created_at)) / 604800.0) AS score
  FROM posts_with_like_count v
  WHERE v.id != p_post_id
    AND v.emotions IS NOT NULL
    AND v.emotions && v_emotions
  ORDER BY score DESC, v.created_at DESC
  LIMIT p_limit;
END;
$$;

-- get_trending_posts: group_id IS NULL 조건 제거
DROP FUNCTION IF EXISTS public.get_trending_posts(INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION public.get_trending_posts(
  p_hours INTEGER DEFAULT 72,
  p_limit INTEGER DEFAULT 10
) RETURNS TABLE(
  id BIGINT,
  title TEXT,
  board_id BIGINT,
  like_count INTEGER,
  comment_count INTEGER,
  emotions TEXT[],
  created_at TIMESTAMPTZ,
  display_name TEXT,
  score DOUBLE PRECISION
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
BEGIN
  RETURN QUERY
  SELECT v.id, v.title, v.board_id, v.like_count, v.comment_count,
    v.emotions, v.created_at, v.display_name,
    (v.like_count + v.comment_count * 2 + 1)::DOUBLE PRECISION
      / GREATEST(EXTRACT(EPOCH FROM (now() - v.created_at)) / 3600.0, 1.0) AS score
  FROM posts_with_like_count v
  WHERE v.created_at >= (now() - (p_hours || ' hours')::INTERVAL)
  ORDER BY score DESC
  LIMIT p_limit;
END;
$$;

-- get_posts_by_emotion: group_id IS NULL 조건 제거
DROP FUNCTION IF EXISTS public.get_posts_by_emotion(TEXT, INT, INT);
CREATE OR REPLACE FUNCTION public.get_posts_by_emotion(
  p_emotion TEXT,
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0
) RETURNS TABLE(
  id BIGINT,
  title TEXT,
  board_id BIGINT,
  like_count INT,
  comment_count INT,
  emotions TEXT[],
  created_at TIMESTAMPTZ,
  display_name TEXT
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  RETURN QUERY
  SELECT v.id, v.title, v.board_id, v.like_count, v.comment_count,
    v.emotions, v.created_at, v.display_name
  FROM posts_with_like_count v
  WHERE v.emotions IS NOT NULL
    AND p_emotion = ANY(v.emotions)
  ORDER BY v.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- search_posts_v2: group_id 반환값 + 필터 제거
DROP FUNCTION IF EXISTS public.search_posts_v2(TEXT, TEXT, TEXT, INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION public.search_posts_v2(
  p_query TEXT,
  p_emotion TEXT DEFAULT NULL,
  p_sort TEXT DEFAULT 'relevance',
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
) RETURNS TABLE(
  id BIGINT,
  title TEXT,
  content TEXT,
  board_id BIGINT,
  like_count INTEGER,
  comment_count INTEGER,
  emotions TEXT[],
  created_at TIMESTAMPTZ,
  display_name TEXT,
  author_id UUID,
  is_anonymous BOOLEAN,
  image_url TEXT,
  initial_emotions TEXT[],
  title_highlight TEXT,
  content_highlight TEXT,
  relevance_score REAL
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_tsquery TSQUERY;
  v_pattern TEXT;
  v_trimmed TEXT;
  v_escaped TEXT;
BEGIN
  v_trimmed := trim(p_query);

  IF v_trimmed IS NULL OR length(v_trimmed) < 2 THEN
    RETURN;
  END IF;

  v_tsquery := plainto_tsquery('simple', v_trimmed);

  v_escaped := replace(replace(v_trimmed, '%', '\%'), '_', '\_');
  v_pattern := '%' || v_escaped || '%';

  RETURN QUERY
  WITH matched AS (
    SELECT
      p.id,
      p.title,
      p.content,
      p.board_id,
      COALESCE(r_agg.total_reactions, 0)::integer AS like_count,
      COALESCE(c_agg.total_comments, 0)::integer AS comment_count,
      pa.emotions,
      p.created_at,
      p.display_name,
      p.author_id,
      p.is_anonymous,
      p.image_url,
      p.initial_emotions,
      ts_headline('simple', p.title, v_tsquery,
        'StartSel=<<, StopSel=>>, MaxWords=50, MinWords=10, MaxFragments=1'
      ) AS title_highlight,
      ts_headline('simple', p.content, v_tsquery,
        'StartSel=<<, StopSel=>>, MaxWords=30, MinWords=10, MaxFragments=1'
      ) AS content_highlight,
      (
        COALESCE(ts_rank(
          setweight(to_tsvector('simple', p.title), 'A') ||
          setweight(to_tsvector('simple', p.content), 'B'),
          v_tsquery
        ), 0) * 10
        + CASE WHEN p.title ILIKE v_pattern THEN 5.0 ELSE 0.0 END
        + CASE WHEN p.title ILIKE v_escaped || '%' THEN 3.0 ELSE 0.0 END
      )::REAL AS relevance_score
    FROM posts p
    LEFT JOIN post_analysis pa ON pa.post_id = p.id
    LEFT JOIN (
      SELECT r.post_id, SUM(r.count)::integer AS total_reactions
      FROM reactions r GROUP BY r.post_id
    ) r_agg ON r_agg.post_id = p.id
    LEFT JOIN (
      SELECT c.post_id, COUNT(*)::integer AS total_comments
      FROM comments c WHERE c.deleted_at IS NULL GROUP BY c.post_id
    ) c_agg ON c_agg.post_id = p.id
    WHERE p.deleted_at IS NULL
      AND (
        (to_tsvector('simple', p.title) || to_tsvector('simple', p.content)) @@ v_tsquery
        OR p.title ILIKE v_pattern
        OR p.content ILIKE v_pattern
      )
      AND (p_emotion IS NULL OR p_emotion = ANY(pa.emotions))
  )
  SELECT m.*
  FROM matched m
  ORDER BY
    CASE
      WHEN p_sort = 'relevance' THEN -m.relevance_score
      WHEN p_sort = 'popular' THEN -(m.like_count + m.comment_count * 2)::REAL
      ELSE NULL
    END,
    m.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- ============================================================
-- Phase 11: boards 제약조건 정리 — 이제 group_id 없음
-- boards_constraints는 유지 (name/description 길이 CHECK)
-- ============================================================

-- Done.
