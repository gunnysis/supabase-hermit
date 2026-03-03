-- posts: UPDATE USING에서 deleted_at IS NULL 제거
-- (소프트 삭제 시 deleted_at을 세팅하는 쪽이 업데이트이므로
--  업데이트 대상 행 자체는 deleted_at이 아직 NULL이 맞지만,
--  PostgREST가 업데이트 결과를 반환할 때 SELECT 정책과 충돌하여 PGRST116 발생)
-- 해결: WITH CHECK에 deleted_at IS NULL 이동 (신규 값이 삭제 상태가 아닌 경우만 허용)
-- 단, 소프트 삭제(deleted_at 세팅)는 허용해야 하므로 WITH CHECK는 author_id만 검사

DROP POLICY IF EXISTS "Users can update own posts" ON posts;
CREATE POLICY "Users can update own posts"
  ON posts FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

-- comments: 동일한 패턴으로 수정
DROP POLICY IF EXISTS "Users can update own comments" ON comments;
CREATE POLICY "Users can update own comments"
  ON comments FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);
