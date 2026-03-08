-- 5분 이상 pending/analyzing 상태인 분석을 failed로 전환하는 정리 함수
-- 수동 실행: SELECT public.cleanup_stuck_analyses();
-- pg_cron 사용 시: SELECT cron.schedule('cleanup-stuck-analyses', '*/10 * * * *', 'SELECT public.cleanup_stuck_analyses()');

CREATE OR REPLACE FUNCTION public.cleanup_stuck_analyses()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  affected INTEGER;
BEGIN
  UPDATE post_analysis
  SET
    status = 'failed',
    error_reason = CASE
      WHEN status = 'pending' THEN 'webhook_never_processed'
      ELSE 'analyzing_timeout'
    END,
    last_attempted_at = now()
  WHERE status IN ('pending', 'analyzing')
    AND (
      -- pending: last_attempted_at 없으면 analyzed_at 기준 5분
      (status = 'pending' AND last_attempted_at IS NULL
       AND analyzed_at < now() - INTERVAL '5 minutes')
      OR
      -- pending: last_attempted_at 기준 5분
      (status = 'pending' AND last_attempted_at IS NOT NULL
       AND last_attempted_at < now() - INTERVAL '5 minutes')
      OR
      -- analyzing: last_attempted_at 기준 5분
      (status = 'analyzing'
       AND last_attempted_at < now() - INTERVAL '5 minutes')
    );

  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;
