-- =============================================================================
-- 20260303000003_post_update_reanalysis.sql
--
-- 게시글 수정 시 감정분석 자동 재실행.
--
-- 설계:
--   1. content 또는 title이 실제로 변경된 경우에만 트리거 (WHEN 절)
--   2. 기존 analyze-post Edge Function 재사용 (UPDATE 이벤트 전송)
--   3. 비용 보호: Edge Function 레벨에서 60초 쿨다운 적용
--
-- 연관 변경:
--   - analyze-post: INSERT + UPDATE 이벤트 수락
--   - _shared/analyze.ts: 60초 쿨다운 + analyzed_at 명시 갱신
--   - 클라이언트 Realtime: INSERT → * (UPDATE 이벤트도 감지)
-- =============================================================================

-- posts UPDATE 시 content/title 변경되면 analyze-post Edge Function 자동 호출
CREATE TRIGGER analyze_post_on_update
  AFTER UPDATE OF content, title ON public.posts
  FOR EACH ROW
  WHEN (OLD.content IS DISTINCT FROM NEW.content OR OLD.title IS DISTINCT FROM NEW.title)
  EXECUTE FUNCTION supabase_functions.http_request(
    'https://qwrjebpsjjdxhhhllqcw.supabase.co/functions/v1/analyze-post',
    'POST',
    '{"Content-Type":"application/json"}',
    '{}',
    '5000'
  );
