-- =============================================================================
-- 20260330000001_legacy_cleanup.sql
-- 레거시 정리 + 인덱스 추가 + RPC 문서화
--
-- 1. user_blocks 성능 인덱스 (get_blocked_aliases 최적화)
-- 2. 전체 public RPC COMMENT 문서화 (33개)
-- =============================================================================

-- ============================================================
-- 1. user_blocks 인덱스
-- ============================================================
-- get_blocked_aliases()는 blocker_id로 조회 — UNIQUE(blocker_id, blocked_alias)만으로는
-- blocker_id 단독 조회 시 인덱스 활용이 비효율적
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker
  ON public.user_blocks(blocker_id);

-- ============================================================
-- 2. RPC 함수 COMMENT 문서화 (33개)
-- ============================================================

-- CORE (2)
COMMENT ON FUNCTION public.toggle_reaction(BIGINT, TEXT) IS
  '리액션 토글 (SECURITY DEFINER + advisory lock). reactions/user_reactions 직접 쓰기 정책 제거됨 — 반드시 이 RPC 사용';
COMMENT ON FUNCTION public.get_post_reactions(BIGINT) IS
  '게시글 리액션 목록 + 현재 사용자 반응 상태 조회';

-- CONTENT (2)
COMMENT ON FUNCTION public.soft_delete_post(BIGINT) IS
  '게시글 소프트삭제 (본인 또는 관리자). 연관 알림도 정리';
COMMENT ON FUNCTION public.soft_delete_comment(BIGINT) IS
  '댓글 소프트삭제 (본인 또는 관리자). 연관 알림도 정리';

-- DISCOVERY (5)
COMMENT ON FUNCTION public.get_emotion_trend(INTEGER) IS
  '최근 N일간 감정 트렌드 집계 (상위 5개, 비율 포함)';
COMMENT ON FUNCTION public.get_recommended_posts_by_emotion(BIGINT, INTEGER) IS
  '감정 기반 추천 게시글 (유사 감정 매칭 + 폴백 + 시간 감쇠)';
COMMENT ON FUNCTION public.get_trending_posts(INTEGER, INTEGER) IS
  '트렌딩 게시글 (참여도/시간 가중 점수)';
COMMENT ON FUNCTION public.get_posts_by_emotion(TEXT, INT, INT) IS
  '특정 감정으로 게시글 필터링 (페이지네이션)';
COMMENT ON FUNCTION public.get_similar_feeling_count(BIGINT, INTEGER) IS
  '비슷한 마음을 가진 사용자 수 (N일 이내)';

-- ANALYTICS (3)
COMMENT ON FUNCTION public.get_user_emotion_calendar(UUID, DATE, DATE) IS
  '사용자 감정 캘린더 히트맵 (날짜별 감정 목록)';
COMMENT ON FUNCTION public.get_emotion_timeline(INTEGER) IS
  '전체 감정 분포 타임라인 (일별 감정 비율)';
COMMENT ON FUNCTION public.get_my_activity_summary() IS
  '내 활동 요약 (총 글/댓글/반응 수, 연속 기록일)';

-- SEARCH (1)
COMMENT ON FUNCTION public.search_posts_v2(TEXT, TEXT, TEXT, INTEGER, INTEGER) IS
  '게시글 검색 v2 — 풀텍스트 + ILIKE 병행, 관련도/인기도/최신 정렬, 하이라이트, 감정 필터';

-- ADMIN (3)
COMMENT ON FUNCTION public.cleanup_stuck_analyses() IS
  '5분 이상 pending/analyzing 상태 감정분석을 failed로 전환 (pg_cron 자동 실행)';
COMMENT ON FUNCTION public.admin_cleanup_posts(UUID, TIMESTAMPTZ, TIMESTAMPTZ) IS
  '관리자 전용: 테스트 게시글 hard delete (CASCADE). user_id/before/after 필터';
COMMENT ON FUNCTION public.admin_cleanup_comments(UUID, TIMESTAMPTZ, TIMESTAMPTZ) IS
  '관리자 전용: 테스트 댓글 hard delete. user_id/before/after 필터';

-- DAILY POST (3)
COMMENT ON FUNCTION public.create_daily_post(TEXT[], TEXT[], TEXT) IS
  '오늘의 하루 생성 — posts + post_analysis 원자적 생성, 하루 1회 KST 제한';
COMMENT ON FUNCTION public.update_daily_post(BIGINT, TEXT[], TEXT[], TEXT) IS
  '오늘의 하루 수정 — posts + post_analysis 동기화 업데이트';
COMMENT ON FUNCTION public.get_today_daily() IS
  '오늘(KST) 내 daily 게시글 조회 (홈 진입점용). 좋아요/댓글 수 포함';

-- INSIGHTS (1)
COMMENT ON FUNCTION public.get_daily_activity_insights(INTEGER) IS
  '나의 패턴: 활동-감정 상관관계 분석 (7일+ daily 데이터 필요)';

-- ALIAS (2)
COMMENT ON FUNCTION public.generate_display_alias() IS
  '고정 익명 별칭 생성 (형용사 30 × 명사 30 풀 + 충돌 시 숫자 접미사)';
COMMENT ON FUNCTION public.get_my_alias() IS
  '내 고정 별칭 조회. 없으면 자동 생성 후 반환';

-- NOTIFICATIONS (4)
COMMENT ON FUNCTION public.get_notifications(INTEGER, INTEGER) IS
  '알림 목록 조회 (최신순, 페이지네이션)';
COMMENT ON FUNCTION public.get_unread_notification_count() IS
  '미읽음 알림 수 조회';
COMMENT ON FUNCTION public.mark_notifications_read(BIGINT[]) IS
  '선택한 알림 읽음 처리 (ID 배열)';
COMMENT ON FUNCTION public.mark_all_notifications_read() IS
  '전체 알림 일괄 읽음 처리';

-- USER BLOCKS (3)
COMMENT ON FUNCTION public.block_user(TEXT) IS
  '특정 별칭 차단. 차단된 사용자의 글/댓글이 필터링됨';
COMMENT ON FUNCTION public.unblock_user(TEXT) IS
  '차단 해제';
COMMENT ON FUNCTION public.get_blocked_aliases() IS
  '차단한 별칭 목록 조회';

-- DAILY EVOLUTION (4)
COMMENT ON FUNCTION public.get_yesterday_daily_reactions() IS
  '어제 daily 게시글의 반응 조회 (좋아요 수 + 댓글 수, KST 서버 계산)';
COMMENT ON FUNCTION public.get_same_mood_dailies(BIGINT, TEXT[]) IS
  '같은 감정을 가진 오늘의 daily 게시글 3개 (본인 제외, KST 기준)';
COMMENT ON FUNCTION public.get_weekly_emotion_summary(INTEGER) IS
  '주간 감정 요약 — Top 5 감정, Top 활동, 기록일 수 (week_offset으로 과거 조회)';
COMMENT ON FUNCTION public.get_my_streak() IS
  'daily 스트릭 조회 — 연속일/총일/최장기록 + 마일스톤 달성 + streak freeze';

-- Done.
