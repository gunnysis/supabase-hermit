-- =============================================================
-- v2-2: In-App 알림 (Notifications)
-- =============================================================

------------------------------------------------------------
-- 1. notifications 테이블
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('reaction', 'comment', 'reply')),
  post_id BIGINT REFERENCES posts(id) ON DELETE CASCADE,
  comment_id BIGINT REFERENCES comments(id) ON DELETE CASCADE,
  actor_alias TEXT,
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: 본인 알림만 조회/수정
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own notifications"
  ON notifications FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 인덱스: 미읽음 우선 조회
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications (user_id, created_at DESC)
  WHERE read = false;

CREATE INDEX IF NOT EXISTS idx_notifications_user_all
  ON notifications (user_id, created_at DESC);

------------------------------------------------------------
-- 2. 리액션 시 알림 생성 트리거
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

  -- 리액터 별칭
  SELECT display_alias INTO v_actor_alias
  FROM user_preferences WHERE user_id = NEW.user_id;

  INSERT INTO notifications (user_id, type, post_id, actor_alias)
  VALUES (v_post_author, 'reaction', NEW.post_id, v_actor_alias);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_reaction ON user_reactions;
CREATE TRIGGER trg_notify_reaction
  AFTER INSERT ON user_reactions
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_reaction();

------------------------------------------------------------
-- 3. 댓글 시 알림 생성 트리거
------------------------------------------------------------
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
  -- 댓글 작성자 별칭
  SELECT display_alias INTO v_actor_alias
  FROM user_preferences WHERE user_id = NEW.author_id;

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

DROP TRIGGER IF EXISTS trg_notify_comment ON comments;
CREATE TRIGGER trg_notify_comment
  AFTER INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_comment();

------------------------------------------------------------
-- 4. 알림 조회 RPC
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
  ORDER BY n.created_at DESC
  LIMIT p_limit OFFSET p_offset;
$$;

------------------------------------------------------------
-- 5. 미읽음 알림 수 RPC
------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_unread_notification_count()
RETURNS INT
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public
AS $$
  SELECT COUNT(*)::INT
  FROM notifications
  WHERE user_id = (SELECT auth.uid()) AND read = false;
$$;

------------------------------------------------------------
-- 6. 알림 읽음 처리 RPC
------------------------------------------------------------
CREATE OR REPLACE FUNCTION mark_notifications_read(p_ids BIGINT[])
RETURNS void
LANGUAGE sql SECURITY INVOKER
SET search_path = public
AS $$
  UPDATE notifications
  SET read = true
  WHERE id = ANY(p_ids) AND user_id = (SELECT auth.uid());
$$;

------------------------------------------------------------
-- 7. 전체 읽음 처리 RPC
------------------------------------------------------------
CREATE OR REPLACE FUNCTION mark_all_notifications_read()
RETURNS void
LANGUAGE sql SECURITY INVOKER
SET search_path = public
AS $$
  UPDATE notifications
  SET read = true
  WHERE user_id = (SELECT auth.uid()) AND read = false;
$$;
