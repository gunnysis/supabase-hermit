-- =============================================================================
-- 20260314000001_drop_search_posts_v1.sql
-- search_posts v1 제거 (deprecated, 앱/웹 모두 v2 전환 완료)
-- =============================================================================

DROP FUNCTION IF EXISTS public.search_posts(TEXT, INTEGER, INTEGER);
