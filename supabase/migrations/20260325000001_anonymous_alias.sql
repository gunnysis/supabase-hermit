-- =============================================================
-- v2-0: 고정 익명 별칭 (Anonymous Alias)
-- 모든 사용자에게 고유 별칭 부여, 게시글/댓글에 고정 표시
-- =============================================================

------------------------------------------------------------
-- 1. 별칭 생성 함수
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
BEGIN
  -- 랜덤 형용사 + 동물
  v_adj := v_adjectives[1 + floor(random() * array_length(v_adjectives, 1))::INT];
  v_animal := v_animals[1 + floor(random() * array_length(v_animals, 1))::INT];
  v_alias := v_adj || ' ' || v_animal;

  -- 충돌 시 숫자 접미사
  WHILE EXISTS (SELECT 1 FROM user_preferences WHERE display_alias = v_alias) LOOP
    v_suffix := v_suffix + 1;
    v_alias := v_adj || ' ' || v_animal || ' ' || v_suffix::TEXT;
  END LOOP;

  RETURN v_alias;
END;
$$;

------------------------------------------------------------
-- 2. user_preferences에 display_alias 컬럼 추가
------------------------------------------------------------
ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS
  display_alias TEXT;

-- UNIQUE 제약 (충돌 방지 최종 안전망)
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_preferences_alias
  ON user_preferences (display_alias)
  WHERE display_alias IS NOT NULL;

------------------------------------------------------------
-- 3. 기존 사용자에게 별칭 자동 부여
------------------------------------------------------------
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT user_id FROM user_preferences WHERE display_alias IS NULL LOOP
    UPDATE user_preferences
    SET display_alias = generate_display_alias()
    WHERE user_id = r.user_id AND display_alias IS NULL;
  END LOOP;
END;
$$;

------------------------------------------------------------
-- 4. 신규 사용자 자동 별칭 부여 트리거
------------------------------------------------------------
CREATE OR REPLACE FUNCTION assign_alias_on_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.display_alias IS NULL THEN
    NEW.display_alias := generate_display_alias();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_alias ON user_preferences;
CREATE TRIGGER trg_assign_alias
  BEFORE INSERT ON user_preferences
  FOR EACH ROW
  EXECUTE FUNCTION assign_alias_on_insert();

------------------------------------------------------------
-- 5. 별칭 조회 RPC
------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_my_alias()
RETURNS TEXT
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public
AS $$
  SELECT display_alias FROM user_preferences
  WHERE user_id = (SELECT auth.uid());
$$;

------------------------------------------------------------
-- 6. 게시글 생성 시 display_name을 별칭으로 고정하는 트리거
------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_post_display_alias()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_alias TEXT;
BEGIN
  SELECT display_alias INTO v_alias
  FROM user_preferences
  WHERE user_id = NEW.author_id;

  IF v_alias IS NOT NULL THEN
    NEW.display_name := v_alias;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_post_alias ON posts;
CREATE TRIGGER trg_set_post_alias
  BEFORE INSERT ON posts
  FOR EACH ROW
  EXECUTE FUNCTION set_post_display_alias();

------------------------------------------------------------
-- 7. 댓글 생성 시 display_name을 별칭으로 고정하는 트리거
------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_comment_display_alias()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_alias TEXT;
BEGIN
  SELECT display_alias INTO v_alias
  FROM user_preferences
  WHERE user_id = NEW.author_id;

  IF v_alias IS NOT NULL THEN
    NEW.display_name := v_alias;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_comment_alias ON comments;
CREATE TRIGGER trg_set_comment_alias
  BEFORE INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION set_comment_display_alias();
