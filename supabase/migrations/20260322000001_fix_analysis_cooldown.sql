-- =============================================================================
-- 20260322000001_fix_analysis_cooldown.sql
-- 감정분석 쿨다운 버그 수정
--
-- 문제:
--   post_analysis.analyzed_at이 NOT NULL DEFAULT now()로 설정되어 있어
--   트리거(trg_create_pending_analysis)가 pending 행 생성 시 analyzed_at=now() 기록.
--   Edge Function의 쿨다운 체크(60초)에서 신규 글 분석이 skip됨.
--
-- 수정:
--   1. analyzed_at을 NULL 허용 + DEFAULT NULL로 변경
--   2. pending/analyzing 상태의 기존 행 analyzed_at을 NULL로 정리
--   3. trg_create_pending_analysis는 analyzed_at 미지정이므로 DEFAULT NULL 적용됨
--
-- Edge Function 수정 (별도 배포):
--   - analyze.ts 쿨다운 체크: existing.status === 'done' 가드 추가
--   - content_too_short 분기: retry_count: 0 추가
--   - analyze-post-on-demand: JWT 검증 추가
-- =============================================================================

-- Phase 1: analyzed_at NULL 허용 + DEFAULT 변경
ALTER TABLE public.post_analysis
  ALTER COLUMN analyzed_at DROP NOT NULL,
  ALTER COLUMN analyzed_at SET DEFAULT NULL;

-- Phase 2: 미완료 상태의 analyzed_at 정리
UPDATE public.post_analysis
SET analyzed_at = NULL
WHERE status IN ('pending', 'analyzing');
