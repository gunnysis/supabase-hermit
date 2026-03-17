-- =============================================================
-- 스트릭 보상 시스템
-- user_preferences에 streak 관련 컬럼 추가
-- get_my_streak() RPC 신규
-- =============================================================

------------------------------------------------------------
-- 1. user_preferences 확장
------------------------------------------------------------
ALTER TABLE user_preferences
  ADD COLUMN IF NOT EXISTS longest_streak INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_milestone INT DEFAULT 0;

------------------------------------------------------------
-- 2. get_my_streak() — daily 전용 스트릭 + 마일스톤 체크
------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_my_streak()
RETURNS JSON
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := (SELECT auth.uid());
  v_today DATE := kst_date(now());
  v_streak INT := 0;
  v_total_days INT := 0;
  v_longest INT := 0;
  v_last_milestone INT := 0;
  v_new_milestone INT := 0;
  v_completed_today BOOLEAN := FALSE;
BEGIN
  -- 오늘 daily 작성 여부
  SELECT EXISTS(
    SELECT 1 FROM posts
    WHERE author_id = v_uid AND post_type = 'daily'
      AND deleted_at IS NULL AND created_date_kst = v_today
  ) INTO v_completed_today;

  -- 연속 스트릭 계산 (daily만)
  WITH daily_days AS (
    SELECT DISTINCT created_date_kst AS d
    FROM posts
    WHERE author_id = v_uid AND post_type = 'daily' AND deleted_at IS NULL
  ),
  numbered AS (
    SELECT d, d - (ROW_NUMBER() OVER (ORDER BY d DESC))::INT * INTERVAL '1 day' AS grp
    FROM daily_days
    WHERE d <= v_today
  )
  SELECT COUNT(*)::INT INTO v_streak
  FROM numbered
  WHERE grp = (SELECT grp FROM numbered ORDER BY d DESC LIMIT 1);

  -- 오늘 미작성이면 어제까지의 스트릭 (streak freeze 1일 허용)
  IF NOT v_completed_today AND v_streak > 0 THEN
    -- 어제 작성했는지 확인
    IF NOT EXISTS(
      SELECT 1 FROM posts
      WHERE author_id = v_uid AND post_type = 'daily'
        AND deleted_at IS NULL AND created_date_kst = v_today - 1
    ) THEN
      v_streak := 0; -- 어제도 미작성이면 스트릭 리셋
    END IF;
  END IF;

  -- 총 기록일 수
  SELECT COUNT(DISTINCT created_date_kst)::INT INTO v_total_days
  FROM posts
  WHERE author_id = v_uid AND post_type = 'daily' AND deleted_at IS NULL;

  -- 최장 스트릭 조회/갱신
  SELECT COALESCE(longest_streak, 0), COALESCE(last_milestone, 0)
  INTO v_longest, v_last_milestone
  FROM user_preferences WHERE user_id = v_uid;

  IF v_streak > v_longest THEN
    v_longest := v_streak;
    UPDATE user_preferences SET longest_streak = v_longest WHERE user_id = v_uid;
  END IF;

  -- 마일스톤 체크 (7, 14, 30, 50, 100)
  v_new_milestone := 0;
  IF v_streak >= 100 AND v_last_milestone < 100 THEN v_new_milestone := 100;
  ELSIF v_streak >= 50 AND v_last_milestone < 50 THEN v_new_milestone := 50;
  ELSIF v_streak >= 30 AND v_last_milestone < 30 THEN v_new_milestone := 30;
  ELSIF v_streak >= 14 AND v_last_milestone < 14 THEN v_new_milestone := 14;
  ELSIF v_streak >= 7 AND v_last_milestone < 7 THEN v_new_milestone := 7;
  END IF;

  IF v_new_milestone > 0 THEN
    UPDATE user_preferences SET last_milestone = v_new_milestone WHERE user_id = v_uid;
  END IF;

  RETURN json_build_object(
    'current_streak', v_streak,
    'total_days', v_total_days,
    'longest_streak', v_longest,
    'completed_today', v_completed_today,
    'new_milestone', v_new_milestone
  );
END;
$$;
