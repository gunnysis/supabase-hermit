-- =============================================================
-- pg_cron 자동화 설정
-- 1. stuck 감정분석 자동 정리 (5분마다)
-- 2. 확장 활성화 확인
-- =============================================================

-- pg_cron이 이미 활성화되어 있다면 스케줄 등록
-- (Dashboard에서 pg_cron 확장을 먼저 활성화해야 함)
DO $$
BEGIN
  -- pg_cron 확장이 존재하는지 확인
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- 기존 스케줄 제거 (중복 방지)
    PERFORM cron.unschedule('cleanup-stuck-analyses');

    -- 5분마다 stuck 감정분석 정리
    PERFORM cron.schedule(
      'cleanup-stuck-analyses',
      '*/5 * * * *',
      $cron$ SELECT cleanup_stuck_analyses(); $cron$
    );

    RAISE NOTICE 'pg_cron: cleanup-stuck-analyses 스케줄 등록 완료';
  ELSE
    RAISE NOTICE 'pg_cron 확장이 비활성화 상태입니다. Dashboard > Extensions에서 활성화해주세요.';
  END IF;
END $$;
