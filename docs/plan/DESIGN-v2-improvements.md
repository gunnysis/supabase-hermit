# v2 기능 점검 및 개선 설계

## 배경
v2 기능(별칭/답글/알림/차단 + 오늘의 하루) 전체 감사 후 발견된 이슈를 수정하는 마이그레이션.

## 수정 대상

### DB 마이그레이션 (20260326000001_v2_improvements.sql)

| # | 심각도 | 내용 | 파일 |
|---|--------|------|------|
| 1 | P0 | `create_daily_post()` 타임존 로직 — `CURRENT_DATE AT TIME ZONE` → `(now() AT TIME ZONE 'Asia/Seoul')::date` | daily_post.sql |
| 2 | P0 | `get_today_daily()` 동일 타임존 로직 수정 | daily_post.sql |
| 3 | P0 | `generate_display_alias()` TOCTOU 레이스 컨디션 — UNIQUE 위반 시 EXCEPTION 재시도 | anonymous_alias.sql |
| 4 | P1 | `notify_on_reaction()` / `notify_on_comment()` actor_alias COALESCE 추가 | notifications.sql |
| 5 | P1 | `get_notifications()` ORDER BY tie-breaker (id DESC) 추가 | notifications.sql |
| 6 | P1 | `block_user()` 별칭 존재 검증 추가 | user_blocks.sql |

### 웹 수정

| # | 심각도 | 내용 | 파일 |
|---|--------|------|------|
| 1 | P1 | PostDetailView `(post as any).post_type` → `post.post_type` 제거 (7곳) | PostDetailView.tsx |
| 2 | P1 | HomeCheckinBanner `(todayDaily as any)` 제거 | HomeCheckinBanner.tsx |
| 3 | P1 | blocksApi.ts 에러 핸들링 추가 | blocksApi.ts |
| 4 | P1 | notificationsApi.ts markAllRead/markNotificationsRead 에러 핸들링 | notificationsApi.ts |
| 5 | P1 | useBlocks.ts onError 핸들러 추가 | useBlocks.ts |
| 6 | P1 | notifications page → 클릭 시 개별 읽음 처리 | notifications/page.tsx |

### 앱 수정

| # | 심각도 | 내용 | 파일 |
|---|--------|------|------|
| 1 | P1 | blocks.ts 에러 핸들링 추가 | api/blocks.ts |
| 2 | P1 | notifications.ts markRead/markAllRead 에러 핸들링 | api/notifications.ts |
| 3 | P1 | useBlocks.ts onError 핸들러 추가 | hooks/useBlocks.ts |

## 타임존 버그 상세

### 문제
```sql
-- CURRENT_DATE는 Supabase 서버의 UTC 날짜를 반환
-- 예: KST 2026-03-16 02:00 → UTC 2026-03-15
-- CURRENT_DATE = '2026-03-15'
-- '2026-03-15' AT TIME ZONE 'Asia/Seoul' = 2026-03-14T15:00:00Z (KST 자정)
-- 의도: 2026-03-15T15:00:00Z (KST 3/16 자정)
```

### 해결
```sql
-- KST 기준 오늘 날짜를 먼저 구한 뒤 TIMESTAMPTZ로 변환
v_kst_today DATE := (now() AT TIME ZONE 'Asia/Seoul')::DATE;
v_today_start TIMESTAMPTZ := v_kst_today::TIMESTAMP AT TIME ZONE 'Asia/Seoul';
v_today_end TIMESTAMPTZ := (v_kst_today + 1)::TIMESTAMP AT TIME ZONE 'Asia/Seoul';
```
