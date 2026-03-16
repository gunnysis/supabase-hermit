-- v3 종합 개선: 스키마 제약조건 + 인덱스 + 기본값 수정
-- 설계: docs/plan/DESIGN-v3-refinement.md

BEGIN;

-- ============================================================
-- 1. post_type CHECK 제약조건
-- posts.post_type이 'post' 또는 'daily'만 허용
-- ============================================================
DO $$ BEGIN
  ALTER TABLE posts ADD CONSTRAINT posts_post_type_check
    CHECK (post_type IN ('post', 'daily'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- 2. 알림 페이지네이션 최적화 인덱스
-- get_notifications() ORDER BY created_at DESC, id DESC 매칭
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_notifications_user_created_id
  ON notifications (user_id, created_at DESC, id DESC);

-- ============================================================
-- 3. user_preferences.display_alias partial unique index
-- NULL이 아닌 별칭만 유니크 보장 (기존 UNIQUE 보완)
-- ============================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_preferences_alias_nonnull
  ON user_preferences (display_alias) WHERE display_alias IS NOT NULL;

-- ============================================================
-- 4. post_analysis.analyzed_at 기본값 NULL로 수정
-- pending 상태에서 analyzed_at=now() → 쿨다운 오계산 방지
-- ============================================================
ALTER TABLE post_analysis ALTER COLUMN analyzed_at SET DEFAULT NULL;

-- ============================================================
-- 5. comments.parent_id 자기참조 방지
-- parent_id는 같은 post_id 내의 댓글만 참조 가능
-- (1단계 답글만 허용 — parent의 parent_id는 NULL이어야 함)
-- ============================================================
CREATE OR REPLACE FUNCTION check_comment_parent()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.parent_id IS NOT NULL THEN
    -- 부모 댓글이 같은 게시글에 속하는지 확인
    IF NOT EXISTS (
      SELECT 1 FROM comments
      WHERE id = NEW.parent_id
        AND post_id = NEW.post_id
        AND parent_id IS NULL  -- 1단계만 허용
        AND deleted_at IS NULL
    ) THEN
      RAISE EXCEPTION 'Invalid parent comment: must be a top-level comment in the same post';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_comment_parent ON comments;
CREATE TRIGGER trg_check_comment_parent
  BEFORE INSERT OR UPDATE OF parent_id ON comments
  FOR EACH ROW
  EXECUTE FUNCTION check_comment_parent();

COMMIT;
