# 중앙 레포 (supabase-hermit) 분석 스냅샷

> **최종 갱신**: 2026-03-16 | **마이그레이션**: 37개 | **RPC**: 30개(public) + 13개(internal)

## 통계 요약

| 항목 | 수량 |
|------|------|
| 마이그레이션 | 37 |
| 테이블 | 10 (groups/group_members 레거시 잔존하나 실사용 안 함) |
| 뷰 | 1 (posts_with_like_count) |
| Public RPC | 30 |
| Internal 함수 | 13 |
| 트리거 | 17 |
| shared 타입 exports | 42 |
| shared 상수 exports | 21 |
| shared 유틸 함수 | 3 |
| 스크립트 총 라인 | 741 |
| database.gen.ts 라인 | 1,198 |

---

## 마이그레이션 목록 (37개)

| # | 파일 | 핵심 내용 |
|---|------|----------|
| 1 | 20260301000001_schema.sql | 베이스라인: 테이블/함수/뷰/트리거/인덱스 |
| 2 | 20260301000002_rls.sql | RLS 정책 |
| 3 | 20260301000003_infra.sql | 권한 + Storage |
| 4 | 20260302000000_fix_rls_update_policies.sql | UPDATE 정책 수정 |
| 5 | 20260303000001_core_redesign.sql | 리액션 RPC, 소프트삭제, FK CASCADE |
| 6 | 20260303000002_fix_group_members_recursion.sql | RLS 재귀 수정 (레거시) |
| 7 | 20260303000003_post_update_reanalysis.sql | 글 수정 시 감정분석 재실행 |
| 8 | 20260304000001_fix_reactions_data.sql | 리액션 데이터 정합성 |
| 9 | 20260306000001_remove_author_column.sql | author 컬럼 제거 |
| 10 | 20260307000001_recommendation_improvements.sql | 추천 개선 |
| 11 | 20260308000001_ux_redesign.sql | initial_emotions, user_preferences, 감정 RPC |
| 12 | 20260309000001_security_performance_fixes.sql | 보안/성능 |
| 13 | 20260310000001_comprehensive_improvements.sql | 공개 게시판, 뷰 최적화, 검색 RPC |
| 14 | 20260311000001_fix_rpc_missing_columns.sql | get_posts_by_emotion 컬럼 보강 |
| 15 | 20260311000002_fix_search_posts_columns.sql | search_posts 컬럼 보강 |
| 16 | 20260311000003_analysis_status_retry.sql | 감정분석 상태 + 재시도 |
| 17 | 20260312000001_search_v2.sql | 검색 v2 |
| 18 | 20260313000001_admin_groups_rls_fix.sql | groups RLS (레거시) |
| 19 | 20260314000001_drop_search_posts_v1.sql | search_posts v1 제거 |
| 20 | 20260315000001_search_v2_ilike_escape.sql | ILIKE 이스케이프 |
| 21 | 20260315000002_fix_search_v2_column_order.sql | CTE 컬럼 순서 |
| 22 | 20260316000001_cleanup_stuck_analyses.sql | stuck 분석 자동 정리 |
| 23 | 20260317000001_post_analysis_rls.sql | post_analysis SELECT RLS |
| 24 | 20260317000002_reactions_rls_cleanup.sql | 직접 쓰기 정책 제거 |
| 25 | 20260318000001_boards_constraints.sql | boards CHECK 제약조건 |
| 26 | 20260319000001_remove_group_board_system.sql | 그룹/게시판 시스템 제거 |
| 27 | 20260320000001_advisor_performance_security.sql | RLS initplan + search_path |
| 28 | 20260321000001_admin_cleanup_test_data.sql | 테스트 데이터 정리 RPC |
| 29 | 20260322000001_fix_analysis_cooldown.sql | 쿨다운 버그 수정 |
| 30 | 20260323000001_daily_post.sql | 오늘의 하루 |
| 31 | 20260324000001_daily_insights.sql | 나의 패턴 인사이트 |
| 32 | 20260325000001_anonymous_alias.sql | v2: 고정 익명 별칭 |
| 33 | 20260325000002_comment_replies.sql | v2: 댓글 답글 |
| 34 | 20260325000003_notifications.sql | v2: In-App 알림 |
| 35 | 20260325000004_user_blocks.sql | v2: 사용자 차단 |
| 36 | 20260326000001_v2_improvements.sql | v2 점검 (타임존, 별칭, 알림, 차단) |
| 37 | 20260327000001_v3_refinement.sql | v3: post_type CHECK, 알림 인덱스, 별칭 유니크, analyzed_at, 답글 검증 |

---

## 테이블 (10개 실사용)

| 테이블 | 핵심 필드 | 비고 |
|--------|----------|------|
| boards | id, name, anon_mode, visibility | 공개 게시판 id=12 |
| posts | title, content, post_type, activities, initial_emotions, deleted_at | 소프트삭제 |
| comments | content, parent_id, deleted_at | 1단계 답글, 소프트삭제 |
| reactions | post_id, reaction_type, count | 집계 테이블 |
| user_reactions | user_id, post_id, reaction_type | UNIQUE |
| post_analysis | emotions[], status, retry_count, error_reason | 감정분석 |
| user_preferences | display_alias, theme_preference, notification_enabled | 별칭 |
| app_admin | user_id | 관리자 |
| notifications | type, post_id, actor_alias, read | 알림 |
| user_blocks | blocker_id, blocked_alias | 차단 |

---

## Public RPC 함수 (30개)

### CORE (2)
- `toggle_reaction(post_id, type)` — SECURITY DEFINER + advisory lock
- `get_post_reactions(post_id)`

### CONTENT (2)
- `soft_delete_post(post_id)` — 본인 + 관리자
- `soft_delete_comment(comment_id)`

### DISCOVERY (5)
- `get_recommended_posts_by_emotion(post_id, limit)`
- `get_trending_posts(hours, limit)`
- `get_posts_by_emotion(emotion, limit, offset)`
- `get_emotion_trend(days)`
- `get_similar_feeling_count(post_id, days)`

### ANALYTICS (3)
- `get_user_emotion_calendar(user_id, start, end)`
- `get_emotion_timeline(days)`
- `get_my_activity_summary()`

### SEARCH (1)
- `search_posts_v2(query, emotion, sort, limit, offset)`

### ADMIN (3)
- `admin_cleanup_posts(user_id?, before?, after?)`
- `admin_cleanup_comments(user_id?, before?, after?)`
- `cleanup_stuck_analyses()`

### DAILY POST (3)
- `create_daily_post(emotions, activities?, content?)`
- `update_daily_post(post_id, emotions, activities?, content?)`
- `get_today_daily()`

### INSIGHTS (1)
- `get_daily_activity_insights(days?)`

### ALIAS (2)
- `generate_display_alias()`
- `get_my_alias()`

### NOTIFICATIONS (4)
- `get_notifications(limit, offset)`
- `get_unread_notification_count()`
- `mark_notifications_read(ids[])`
- `mark_all_notifications_read()`

### USER BLOCKS (3)
- `block_user(alias)`
- `unblock_user(alias)`
- `get_blocked_aliases()`

---

## Internal 함수 (13개)

| 함수 | 용도 |
|------|------|
| update_updated_at() | 시간 트리거 |
| check_daily_post_limit() | 하루 1회 제한 |
| check_daily_comment_limit() | 댓글 제한 |
| create_pending_analysis() | 분석 워크플로 |
| mark_analysis_analyzing() | 분석 워크플로 |
| check_reply_depth() | 답글 깊이 제한 |
| check_comment_parent() | v3: 답글 유효성 검증 |
| notify_on_reaction() | 리액션 알림 트리거 |
| notify_on_comment() | 댓글 알림 트리거 |
| set_post_display_alias() | 게시글 별칭 자동 설정 |
| set_comment_display_alias() | 댓글 별칭 자동 설정 |
| assign_alias_on_insert() | 별칭 자동 부여 |
| cleanup_orphan_group_members() | 레거시 정리 |

---

## 트리거 (17개)

| 트리거 | 대상 | 용도 |
|--------|------|------|
| trg_posts_updated_at | posts | 수정 시간 |
| trg_comments_updated_at | comments | 수정 시간 |
| trg_boards_updated_at | boards | 수정 시간 |
| trg_groups_updated_at | groups | 수정 시간 (레거시) |
| trg_check_daily_post_limit | posts | 하루 1회 |
| trg_check_daily_comment_limit | comments | 댓글 제한 |
| analyze_post_on_insert | posts | Edge Function 호출 |
| analyze_post_on_update | posts | Edge Function 호출 |
| trg_create_pending_analysis | posts | 분석 레코드 생성 |
| trg_mark_analysis_analyzing | post_analysis | 상태 전환 |
| trg_assign_alias | user_preferences | 별칭 자동 부여 |
| trg_set_post_alias | posts | 게시글 별칭 |
| trg_set_comment_alias | comments | 댓글 별칭 |
| trg_check_reply_depth | comments | 답글 깊이 |
| trg_check_comment_parent | comments | v3: 답글 유효성 |
| trg_notify_reaction | user_reactions | 리액션 알림 |
| trg_notify_comment | comments | 댓글 알림 |

---

## shared/ 파일 요약

### types.ts (42 exports)
- **인터페이스 25개**: Board, Post, PostWithCounts, PostAnalysis, Comment, Reaction, UserReaction, ToggleReactionResponse, AppAdmin, EmotionTrend, RecommendedPost, TrendingPost, CreatePostRequest, CreateCommentRequest, CreateReactionRequest, UpdatePostRequest, UpdateCommentRequest, UserPreferences, EmotionCalendarDay, EmotionTimelineEntry, SearchResult, Notification, UserBlock, ActivityInsight, ActivitySummary
- **타입 6개**: AnonMode, AnalysisStatus, ReactionType, SearchSort, NotificationType
- **응답 타입 9개**: Get/Create/Update Post/Comment/Reaction Response
- **가드 2개**: isPost(), isComment()

### constants.ts (21 exports)
- ALLOWED_EMOTIONS(13), EMOTION_EMOJI, EMOTION_COLOR_MAP, REACTION_COLOR_MAP
- MOTION, SHARED_PALETTE(5계열), EMPTY_STATE_MESSAGES, GREETING_MESSAGES
- SEARCH_HIGHLIGHT, SEARCH_SORT_OPTIONS, SEARCH_CONFIG, ADMIN_CONSTANTS
- ANALYSIS_STATUS, ANALYSIS_CONFIG, VALIDATION
- ACTIVITY_PRESETS(10), DAILY_CONFIG, DAILY_INSIGHTS_CONFIG

### utils.ts (3 함수)
- validatePostInput(), validateDailyPostInput(), validateCommentInput()

---

## 스크립트

| 스크립트 | 라인 | 핵심 |
|---------|------|------|
| db.sh | 98 | push/pull/diff/lint/status + 후처리 자동화 |
| gen-types.sh | 70 | Supabase CLI → TS 타입 생성 (변경 감지) |
| sync-to-projects.sh | 373 | 6가지 파일 앱/웹 동기화 |
| verify.sh | 200 | 3개 레포 정합성 검증 |
