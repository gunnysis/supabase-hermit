-- boards 테이블 길이 제약조건 추가
-- name: 최대 100자, description: 최대 500자

DO $$ BEGIN
  ALTER TABLE public.boards
    ADD CONSTRAINT boards_name_length
    CHECK (char_length(name) <= 100);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.boards
    ADD CONSTRAINT boards_description_length
    CHECK (description IS NULL OR char_length(description) <= 500);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
