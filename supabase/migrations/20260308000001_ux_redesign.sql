-- UX 리디자인: initial_emotions, user_preferences, 감정 RPC들
-- Phase 2+3 통합 마이그레이션

-- 1. posts에 initial_emotions 추가
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS initial_emotions TEXT[] DEFAULT NULL;

-- 2. user_preferences 테이블
CREATE TABLE IF NOT EXISTS public.user_preferences (
  user_id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  preferred_emotions TEXT[] DEFAULT '{}',
  onboarding_completed BOOLEAN DEFAULT false,
  theme_preference TEXT DEFAULT 'system' CHECK (theme_preference IN ('light','dark','system')),
  notification_enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_prefs_select" ON public.user_preferences;
CREATE POLICY "user_prefs_select" ON public.user_preferences FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "user_prefs_insert" ON public.user_preferences;
CREATE POLICY "user_prefs_insert" ON public.user_preferences FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "user_prefs_update" ON public.user_preferences;
CREATE POLICY "user_prefs_update" ON public.user_preferences FOR UPDATE USING (auth.uid() = user_id);

-- 3. get_posts_by_emotion RPC
CREATE OR REPLACE FUNCTION public.get_posts_by_emotion(
  p_emotion TEXT,
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0
)
RETURNS TABLE(
  id BIGINT,
  title TEXT,
  board_id BIGINT,
  like_count INT,
  comment_count INT,
  emotions TEXT[],
  created_at TIMESTAMPTZ,
  display_name TEXT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  RETURN QUERY
  SELECT v.id, v.title, v.board_id, v.like_count, v.comment_count,
    v.emotions, v.created_at, v.display_name
  FROM posts_with_like_count v
  WHERE v.group_id IS NULL
    AND v.emotions IS NOT NULL
    AND p_emotion = ANY(v.emotions)
  ORDER BY v.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- 4. get_similar_feeling_count RPC
CREATE OR REPLACE FUNCTION public.get_similar_feeling_count(
  p_post_id BIGINT,
  p_days INT DEFAULT 30
)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_emotions TEXT[];
  v_author UUID;
  v_count INT;
BEGIN
  SELECT pa.emotions, p.author_id INTO v_emotions, v_author
  FROM post_analysis pa
  JOIN posts p ON p.id = pa.post_id
  WHERE pa.post_id = p_post_id;

  IF v_emotions IS NULL OR array_length(v_emotions, 1) IS NULL THEN
    RETURN 0;
  END IF;

  SELECT COUNT(DISTINCT p.author_id)::INT INTO v_count
  FROM posts p
  JOIN post_analysis pa ON pa.post_id = p.id
  WHERE p.author_id != v_author
    AND p.deleted_at IS NULL
    AND p.created_at >= (now() - (p_days || ' days')::INTERVAL)
    AND pa.emotions && v_emotions;

  RETURN v_count;
END;
$$;

-- 5. get_user_emotion_calendar RPC
CREATE OR REPLACE FUNCTION public.get_user_emotion_calendar(
  p_user_id UUID,
  p_start DATE DEFAULT (CURRENT_DATE - 30)::DATE,
  p_end DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(day DATE, emotions TEXT[], post_count INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  RETURN QUERY
  SELECT d.day::DATE,
    COALESCE(array_agg(DISTINCT e) FILTER (WHERE e IS NOT NULL), '{}')::TEXT[],
    COUNT(DISTINCT p.id)::INT
  FROM generate_series(p_start, p_end, '1 day'::INTERVAL) AS d(day)
  LEFT JOIN posts p ON p.author_id = p_user_id
    AND p.deleted_at IS NULL
    AND p.created_at::DATE = d.day::DATE
  LEFT JOIN post_analysis pa ON pa.post_id = p.id
  LEFT JOIN LATERAL unnest(pa.emotions) AS e ON TRUE
  GROUP BY d.day
  ORDER BY d.day;
END;
$$;

-- 6. get_emotion_timeline RPC
CREATE OR REPLACE FUNCTION public.get_emotion_timeline(p_days INT DEFAULT 7)
RETURNS TABLE(day DATE, emotion TEXT, cnt BIGINT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  RETURN QUERY
  SELECT pa.analyzed_at::DATE, unnest(pa.emotions), COUNT(*)::BIGINT
  FROM post_analysis pa
  WHERE pa.analyzed_at >= (now() - (p_days || ' days')::INTERVAL)
  GROUP BY 1, 2
  ORDER BY 1, 3 DESC;
END;
$$;

-- 7. get_my_activity_summary RPC
CREATE OR REPLACE FUNCTION public.get_my_activity_summary()
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_post_count INT;
  v_comment_count INT;
  v_reaction_count INT;
  v_streak INT;
BEGIN
  SELECT COUNT(*)::INT INTO v_post_count
  FROM posts WHERE author_id = v_uid AND deleted_at IS NULL;

  SELECT COUNT(*)::INT INTO v_comment_count
  FROM comments WHERE author_id = v_uid AND deleted_at IS NULL;

  SELECT COUNT(*)::INT INTO v_reaction_count
  FROM user_reactions WHERE user_id = v_uid;

  -- 연속 글쓰기 일수 (스트릭)
  WITH daily AS (
    SELECT DISTINCT created_at::DATE AS d
    FROM posts
    WHERE author_id = v_uid AND deleted_at IS NULL
    ORDER BY d DESC
  ),
  numbered AS (
    SELECT d, d - (ROW_NUMBER() OVER (ORDER BY d DESC))::INT * INTERVAL '1 day' AS grp
    FROM daily
  )
  SELECT COUNT(*)::INT INTO v_streak
  FROM numbered
  WHERE grp = (SELECT grp FROM numbered LIMIT 1);

  RETURN json_build_object(
    'post_count', v_post_count,
    'comment_count', v_comment_count,
    'reaction_count', v_reaction_count,
    'streak', COALESCE(v_streak, 0)
  );
END;
$$;

-- 8. 인덱스
CREATE INDEX IF NOT EXISTS idx_posts_author_deleted_created
  ON posts (author_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_post_analysis_analyzed_at
  ON post_analysis (analyzed_at DESC);
