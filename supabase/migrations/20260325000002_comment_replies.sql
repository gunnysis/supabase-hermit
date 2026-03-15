-- =============================================================
-- v2-1: 댓글 답글 (Comment Replies)
-- 1단계 답글만 허용 (중첩 불가)
-- =============================================================

------------------------------------------------------------
-- 1. comments에 parent_id 추가
------------------------------------------------------------
ALTER TABLE comments ADD COLUMN IF NOT EXISTS
  parent_id BIGINT REFERENCES comments(id) ON DELETE CASCADE;

------------------------------------------------------------
-- 2. 답글 1단계 제한 (parent의 parent가 NULL이어야 함)
------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_reply_depth()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.parent_id IS NOT NULL THEN
    -- parent의 parent_id가 NULL이 아니면 → 2단계 이상 중첩 → 거부
    IF EXISTS (SELECT 1 FROM comments WHERE id = NEW.parent_id AND parent_id IS NOT NULL) THEN
      RAISE EXCEPTION 'Nested replies are not allowed (max 1 level)';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_reply_depth ON comments;
CREATE TRIGGER trg_check_reply_depth
  BEFORE INSERT ON comments
  FOR EACH ROW
  WHEN (NEW.parent_id IS NOT NULL)
  EXECUTE FUNCTION check_reply_depth();

------------------------------------------------------------
-- 3. 인덱스 (부모 댓글별 답글 조회)
------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_comments_parent
  ON comments (parent_id)
  WHERE parent_id IS NOT NULL;
