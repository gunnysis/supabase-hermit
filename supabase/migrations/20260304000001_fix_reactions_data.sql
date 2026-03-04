-- reactions 테이블 정합성 복구
-- 문제: 이모지 타입('👍','❤️','😂')과 named 타입('like','heart','laugh') 혼재
--       이모지 타입 행은 user_reactions 없는 고아 데이터
--       일부 named 타입의 count가 실제 user_reactions 수와 불일치
-- 해결: user_reactions(정본)로부터 reactions 테이블 재구축

BEGIN;

-- 1. 기존 reactions 전체 삭제
DELETE FROM public.reactions;

-- 2. user_reactions 기반으로 재구축
INSERT INTO public.reactions (post_id, reaction_type, count)
SELECT post_id, reaction_type, COUNT(*)::int
FROM public.user_reactions
GROUP BY post_id, reaction_type;

COMMIT;
