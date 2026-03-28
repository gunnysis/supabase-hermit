-- 시 게시판 제거
-- board_id=13 게시글을 자유게시판(12)으로 이관 후 board 삭제

-- 1) 시 게시판 게시글 → 자유게시판 이관
UPDATE public.posts
SET board_id = 12
WHERE board_id = 13;

-- 2) 시 게시판 삭제
DELETE FROM public.boards WHERE id = 13;
