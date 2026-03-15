-- =============================================================
-- v2 기능 점검 후 개선 마이그레이션
-- P0: 타임존 로직, 별칭 레이스 컨디션
-- P1: 알림 actor_alias NULL, 페이지네이션, 차단 검증
-- =============================================================

------------------------------------------------------------
-- 1. create_daily_post() 타임존 로직 수정 (P0)
------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_daily_post(
  p_emotions TEXT[],
  p_activities TEXT[] DEFAULT '{}',
  p_content TEXT DEFAULT ''
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_kst_today DATE := (now() AT TIME ZONE 'Asia/Seoul')::DATE;
  v_today_start TIMESTAMPTZ := v_kst_today::TIMESTAMP AT TIME ZONE 'Asia/Seoul';
  v_today_end TIMESTAMPTZ := (v_kst_today + 1)::TIMESTAMP AT TIME ZONE 'Asia/Seoul';
  v_existing BIGINT;
  v_post posts;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 입력 검증
  IF array_length(p_emotions, 1) IS NULL OR array_length(p_emotions, 1) < 1 THEN
    RAISE EXCEPTION 'At least one emotion is required';
  END IF;
  IF array_length(p_emotions, 1) > 3 THEN
    RAISE EXCEPTION 'Maximum 3 emotions allowed';
  END IF;
  IF p_activities IS NOT NULL AND array_length(p_activities, 1) > 5 THEN
    RAISE EXCEPTION 'Maximum 5 activities allowed';
  END IF;
  IF length(p_content) > 200 THEN
    RAISE EXCEPTION 'Content too long (max 200)';
  END IF;

  -- 오늘(KST) 이미 작성했는지 확인
  SELECT id INTO v_existing
  FROM posts
  WHERE author_id = v_user_id
    AND post_type = 'daily'
    AND deleted_at IS NULL
    AND created_at >= v_today_start
    AND created_at < v_today_end;

  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'Already posted today' USING ERRCODE = 'P0002';
  END IF;

  -- 게시글 생성
  INSERT INTO posts (
    title, content, author_id, board_id,
    is_anonymous, display_name,
    post_type, activities, initial_emotions
  ) VALUES (
    '', p_content, v_user_id, 12,
    true, '익명',
    'daily', COALESCE(p_activities, '{}'), p_emotions
  ) RETURNING * INTO v_post;

  -- 감정 분석 행 직접 생성 (AI skip, 사용자 선택 감정)
  INSERT INTO post_analysis (post_id, emotions, status, analyzed_at)
  VALUES (v_post.id, p_emotions, 'done', now())
  ON CONFLICT (post_id) DO UPDATE
    SET emotions = EXCLUDED.emotions,
        status = 'done',
        analyzed_at = now();

  RETURN row_to_json(v_post);
END;
$$;

------------------------------------------------------------
-- 2. get_today_daily() 타임존 로직 수정 (P0)
------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_today_daily()
RETURNS JSON
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public
AS $$
  SELECT row_to_json(t) FROM (
    SELECT p.id, p.content, p.post_type, p.activities,
      p.initial_emotions, p.created_at,
      pa.emotions,
      COALESCE((SELECT SUM(r.count) FROM reactions r WHERE r.post_id = p.id), 0)::int AS like_count
    FROM posts p
    LEFT JOIN post_analysis pa ON pa.post_id = p.id
    WHERE p.author_id = (SELECT auth.uid())
      AND p.post_type = 'daily'
      AND p.deleted_at IS NULL
      AND p.created_at >= ((now() AT TIME ZONE 'Asia/Seoul')::DATE)::TIMESTAMP AT TIME ZONE 'Asia/Seoul'
      AND p.created_at < (((now() AT TIME ZONE 'Asia/Seoul')::DATE + 1))::TIMESTAMP AT TIME ZONE 'Asia/Seoul'
    LIMIT 1
  ) t;
$$;

------------------------------------------------------------
-- 3. generate_display_alias() 레이스 컨디션 수정 (P0)
--    UNIQUE 위반 시 최대 3회 재시도
------------------------------------------------------------
CREATE OR REPLACE FUNCTION generate_display_alias()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_adjectives TEXT[] := ARRAY[
    '조용한','따뜻한','빛나는','단단한','부드러운','깊은','고요한','맑은','순수한','활기찬',
    '차분한','소박한','온화한','신중한','느긋한','수줍은','평화로운','담백한','은은한','투명한',
    '잔잔한','고운','서늘한','묵직한','가벼운','아련한','선명한','소슬한','포근한','청명한'
  ];
  v_animals TEXT[] := ARRAY[
    '고양이','고래','여우','부엉이','토끼','사슴','하늘소','반딧불','두루미','바람새',
    '수달','곰','거북이','다람쥐','고슴도치','판다','펭귄','올빼미','참새','나비',
    '해파리','달팽이','무당벌레','잠자리','도마뱀','개미','벌새','두더지','카멜레온','해달'
  ];
  v_adj TEXT;
  v_animal TEXT;
  v_alias TEXT;
  v_suffix INT := 0;
  v_attempt INT := 0;
BEGIN
  LOOP
    v_attempt := v_attempt + 1;
    IF v_attempt > 3 THEN
      -- 최대 재시도 초과 시 타임스탬프 기반 별칭
      RETURN '익명 ' || extract(epoch from now())::BIGINT;
    END IF;

    -- 랜덤 형용사 + 동물
    v_adj := v_adjectives[1 + floor(random() * array_length(v_adjectives, 1))::INT];
    v_animal := v_animals[1 + floor(random() * array_length(v_animals, 1))::INT];
    v_alias := v_adj || ' ' || v_animal;

    -- 충돌 시 숫자 접미사
    v_suffix := 0;
    WHILE EXISTS (SELECT 1 FROM user_preferences WHERE display_alias = v_alias) LOOP
      v_suffix := v_suffix + 1;
      v_alias := v_adj || ' ' || v_animal || ' ' || v_suffix::TEXT;
    END LOOP;

    -- UNIQUE 인덱스로 최종 안전망 (TOCTOU 방지)
    BEGIN
      RETURN v_alias;
    EXCEPTION WHEN unique_violation THEN
      -- 재시도
      CONTINUE;
    END;
  END LOOP;
END;
$$;

------------------------------------------------------------
-- 4. 알림 트리거: actor_alias COALESCE (P1)
------------------------------------------------------------
CREATE OR REPLACE FUNCTION notify_on_reaction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_post_author UUID;
  v_actor_alias TEXT;
BEGIN
  -- 게시글 작성자 조회
  SELECT author_id INTO v_post_author
  FROM posts WHERE id = NEW.post_id;

  -- 본인 리액션은 알림 안 함
  IF v_post_author = NEW.user_id THEN RETURN NEW; END IF;

  -- 리액터 별칭 (없으면 '익명')
  SELECT COALESCE(display_alias, '익명') INTO v_actor_alias
  FROM user_preferences WHERE user_id = NEW.user_id;

  IF v_actor_alias IS NULL THEN v_actor_alias := '익명'; END IF;

  INSERT INTO notifications (user_id, type, post_id, actor_alias)
  VALUES (v_post_author, 'reaction', NEW.post_id, v_actor_alias);

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION notify_on_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_post_author UUID;
  v_parent_author UUID;
  v_actor_alias TEXT;
BEGIN
  -- 댓글 작성자 별칭 (없으면 '익명')
  SELECT COALESCE(display_alias, '익명') INTO v_actor_alias
  FROM user_preferences WHERE user_id = NEW.author_id;

  IF v_actor_alias IS NULL THEN v_actor_alias := '익명'; END IF;

  -- 답글인 경우: 부모 댓글 작성자에게 알림
  IF NEW.parent_id IS NOT NULL THEN
    SELECT author_id INTO v_parent_author
    FROM comments WHERE id = NEW.parent_id;

    IF v_parent_author IS NOT NULL AND v_parent_author != NEW.author_id THEN
      INSERT INTO notifications (user_id, type, post_id, comment_id, actor_alias)
      VALUES (v_parent_author, 'reply', NEW.post_id, NEW.id, v_actor_alias);
    END IF;
  END IF;

  -- 게시글 작성자에게 알림 (답글이든 일반 댓글이든)
  SELECT author_id INTO v_post_author
  FROM posts WHERE id = NEW.post_id;

  IF v_post_author IS NOT NULL AND v_post_author != NEW.author_id THEN
    -- 답글이고 부모 작성자 = 게시글 작성자이면 중복 방지
    IF NEW.parent_id IS NOT NULL AND v_parent_author = v_post_author THEN
      -- 이미 reply 알림 보냄, comment 알림 스킵
      NULL;
    ELSE
      INSERT INTO notifications (user_id, type, post_id, comment_id, actor_alias)
      VALUES (v_post_author, 'comment', NEW.post_id, NEW.id, v_actor_alias);
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

------------------------------------------------------------
-- 5. get_notifications() ORDER BY tie-breaker (P1)
------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_notifications(
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0
)
RETURNS TABLE(
  id BIGINT,
  type TEXT,
  post_id BIGINT,
  comment_id BIGINT,
  actor_alias TEXT,
  read BOOLEAN,
  created_at TIMESTAMPTZ
)
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public
AS $$
  SELECT n.id, n.type, n.post_id, n.comment_id, n.actor_alias, n.read, n.created_at
  FROM notifications n
  WHERE n.user_id = (SELECT auth.uid())
  ORDER BY n.created_at DESC, n.id DESC
  LIMIT p_limit OFFSET p_offset;
$$;

------------------------------------------------------------
-- 6. block_user() 별칭 존재 검증 (P1)
------------------------------------------------------------
CREATE OR REPLACE FUNCTION block_user(p_alias TEXT)
RETURNS void
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  -- 존재하는 별칭인지 검증
  IF NOT EXISTS (SELECT 1 FROM user_preferences WHERE display_alias = p_alias) THEN
    RAISE EXCEPTION 'Alias not found' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO user_blocks (blocker_id, blocked_alias)
  VALUES ((SELECT auth.uid()), p_alias)
  ON CONFLICT (blocker_id, blocked_alias) DO NOTHING;
END;
$$;
