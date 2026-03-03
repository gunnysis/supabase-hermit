-- =============================================================================
-- 20260301000003_infra.sql — 은둔마을 권한 및 Storage 베이스라인
--
-- public 스키마 권한(grants) + Storage 버킷·정책 정의.
-- =============================================================================

-- ----------------------------------------------------------------------------
-- 1. 권한 (grants)
-- ----------------------------------------------------------------------------

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;
GRANT USAGE ON SCHEMA public TO anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES    IN SCHEMA public TO anon, authenticated, service_role;
GRANT USAGE, SELECT                  ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES    TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT USAGE, SELECT                  ON SEQUENCES TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Storage — post-images 버킷 (이미지 업로드)
-- ----------------------------------------------------------------------------
-- ⚠️  storage 스키마는 Supabase 플랫폼이 관리하며, `supabase db push` 시
--     아직 초기화되지 않아 "relation storage.buckets does not exist" 오류 발생.
--     아래 Storage 설정은 Supabase Dashboard > Storage 에서 직접 구성하거나,
--     로컬 supabase start 환경에서만 실행됨.
-- ----------------------------------------------------------------------------

DO $$
BEGIN
  -- storage 스키마가 존재할 때만 실행 (로컬 Supabase / 이미 초기화된 원격)
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'storage') THEN

    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES ('post-images', 'post-images', true, 52428800, ARRAY['image/jpeg','image/png','image/webp','image/gif'])
    ON CONFLICT (id) DO NOTHING;

    -- 기존 정책 삭제 후 재생성 (DDL은 EXECUTE로 실행)
    EXECUTE 'DROP POLICY IF EXISTS "authenticated users can upload post images" ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "anyone can read post images"               ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "users can delete own post images"          ON storage.objects';

    EXECUTE '
      CREATE POLICY "authenticated users can upload post images"
        ON storage.objects FOR INSERT TO authenticated
        WITH CHECK (bucket_id = ''post-images'' AND auth.uid()::text = (storage.foldername(name))[1])';

    EXECUTE '
      CREATE POLICY "anyone can read post images"
        ON storage.objects FOR SELECT
        USING (bucket_id = ''post-images'')';

    EXECUTE '
      CREATE POLICY "users can delete own post images"
        ON storage.objects FOR DELETE TO authenticated
        USING (bucket_id = ''post-images'' AND auth.uid()::text = (storage.foldername(name))[1])';

  ELSE
    RAISE NOTICE 'storage 스키마 없음 — Storage 설정은 Dashboard에서 수동 구성 필요';
  END IF;
END $$;
