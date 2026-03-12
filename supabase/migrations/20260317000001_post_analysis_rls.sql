-- post_analysis SELECT: 인증된 사용자만 조회 가능하도록 RLS 강화
-- 모든 RPC (get_emotion_trend, get_emotion_timeline 등)는 SECURITY DEFINER이므로 영향 없음
-- 웹 getPostAnalysis()는 클라이언트 사이드에서만 호출 (인증 필수)

DROP POLICY IF EXISTS "post_analysis_select" ON public.post_analysis;
CREATE POLICY "post_analysis_select" ON public.post_analysis
  FOR SELECT USING (auth.role() = 'authenticated');
