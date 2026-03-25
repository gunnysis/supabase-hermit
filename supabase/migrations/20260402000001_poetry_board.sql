-- 시 게시판 추가
-- 기존 자유게시판(id=12)과 동일 구조, 시 전용 공간

INSERT INTO public.boards (id, name, description, visibility, anon_mode)
VALUES (13, '시 게시판', '마음을 시로 표현해보세요.', 'public', 'always_anon')
ON CONFLICT (id) DO NOTHING;

-- 시퀀스가 수동 ID 이상이 되도록 보정
SELECT setval('boards_id_seq', GREATEST((SELECT MAX(id) FROM public.boards), 13));
