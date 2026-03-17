# DB 스키마 문서 — 은둔마을

> 최종 업데이트: 2026-03-17
> 마이그레이션 38개 적용 완료

---

## 테이블

### `boards`
게시판.

| 컬럼 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `id` | BIGSERIAL | PK | |
| `name` | TEXT | NOT NULL | 게시판명 |
| `description` | TEXT | nullable | |
| `visibility` | TEXT | `'public'` | 공개 여부 |
| `anon_mode` | TEXT | `'allow_choice'` | 익명 정책 |
| `created_at` | TIMESTAMPTZ | `now()` | |
| `updated_at` | TIMESTAMPTZ | `now()` | 자동 갱신 (트리거) |

**visibility 값**: `public`, `private`
**anon_mode 값**: `always_anon`, `allow_choice`, `require_name`

---

### `posts`
게시글. 소프트삭제 지원 (`deleted_at`).

| 컬럼 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `id` | BIGSERIAL | PK | |
| `title` | TEXT | NOT NULL | 제목 (최대 200자) |
| `content` | TEXT | NOT NULL | 본문 (최대 100,000자) |
| `author_id` | UUID | NOT NULL, FK -> auth.users | |
| `board_id` | BIGINT | FK -> boards, ON DELETE SET NULL | 게시판 |
| `is_anonymous` | BOOLEAN | `true` | 익명 여부 |
| `display_name` | TEXT | `'익명'` | 표시 이름 |
| `image_url` | TEXT | nullable | 첨부 이미지 URL |
| `initial_emotions` | TEXT[] | `NULL` | 글쓰기 시 사용자가 선택한 감정 (AI 분석 힌트) |
| `post_type` | TEXT | `'post'` | 게시글 유형: `post` (일반), `daily` (오늘의 하루) |
| `activities` | TEXT[] | `NULL` | 활동 태그 (daily 전용, ACTIVITY_PRESETS 기반) |
| `created_at` | TIMESTAMPTZ | `now()` | |
| `updated_at` | TIMESTAMPTZ | `now()` | 자동 갱신 (트리거) |
| `deleted_at` | TIMESTAMPTZ | nullable | 소프트삭제 시각 |

**CHECK 제약조건**: `post_type IN ('post', 'daily')`

---

### `comments`
댓글. 소프트삭제 지원 (`deleted_at`).

| 컬럼 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `id` | BIGSERIAL | PK | |
| `post_id` | BIGINT | NOT NULL, FK -> posts, ON DELETE CASCADE | 소속 게시글 |
| `content` | TEXT | NOT NULL | 댓글 내용 (최대 5,000자) |
| `author_id` | UUID | NOT NULL, FK -> auth.users | |
| `is_anonymous` | BOOLEAN | `true` | |
| `display_name` | TEXT | `'익명'` | |
| `parent_id` | BIGINT | nullable, FK -> comments | 답글 대상 (1단계만) |
| `created_at` | TIMESTAMPTZ | `now()` | |
| `updated_at` | TIMESTAMPTZ | `now()` | 자동 갱신 (트리거) |
| `deleted_at` | TIMESTAMPTZ | nullable | 소프트삭제 시각 |

---

### `reactions`
리액션 집계 테이블. **직접 쓰기 금지** — `toggle_reaction()` RPC 사용.

| 컬럼 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `id` | BIGSERIAL | PK | |
| `post_id` | BIGINT | NOT NULL, FK -> posts, ON DELETE CASCADE | |
| `reaction_type` | TEXT | NOT NULL | 리액션 종류 |
| `count` | INT | `0` | 집계 수 |

**UNIQUE**: (post_id, reaction_type)

---

### `user_reactions`
사용자별 리액션 기록. **직접 쓰기 금지** — `toggle_reaction()` RPC 사용.

| 컬럼 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `id` | BIGSERIAL | PK | |
| `user_id` | UUID | NOT NULL, FK -> auth.users, ON DELETE CASCADE | |
| `post_id` | BIGINT | NOT NULL, FK -> posts, ON DELETE CASCADE | |
| `reaction_type` | TEXT | NOT NULL | |
| `created_at` | TIMESTAMPTZ | `now()` | |

**UNIQUE**: (user_id, post_id, reaction_type)

---

### `post_analysis`
AI 감정 분석 결과. 게시글 INSERT시 pending 행 자동 생성 (트리거), Edge Function이 분석 완료 후 상태 갱신.

| 컬럼 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `id` | BIGSERIAL | PK | |
| `post_id` | BIGINT | NOT NULL, FK -> posts, ON DELETE CASCADE, UNIQUE | |
| `emotions` | TEXT[] | `'{}'` | 감정 태그 배열 |
| `analyzed_at` | TIMESTAMPTZ | `NULL` | 분석 완료 시각 (완료 전 NULL) |
| `status` | TEXT | `'pending'` | 분석 상태 |
| `retry_count` | INT | `0` | 재시도 횟수 |
| `error_reason` | TEXT | nullable | 실패 사유 |
| `last_attempted_at` | TIMESTAMPTZ | nullable | 마지막 시도 시각 |

**status 값**: `pending` (대기), `analyzing` (분석 중), `done` (완료), `failed` (실패)
**CHECK 제약조건**: `status IN ('pending', 'analyzing', 'done', 'failed')`

---

### `user_preferences`
사용자 설정. 감정 선호, 테마, 온보딩 상태 관리.

| 컬럼 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `user_id` | UUID | PK, FK -> auth.users, ON DELETE CASCADE | |
| `preferred_emotions` | TEXT[] | `'{}'` | 선호 감정 목록 |
| `onboarding_completed` | BOOLEAN | `false` | 온보딩 완료 여부 |
| `theme_preference` | TEXT | `'system'` | 테마 설정 |
| `notification_enabled` | BOOLEAN | `true` | 알림 활성화 |
| `display_alias` | TEXT | nullable | 고정 익명 별칭 (자동 부여, UNIQUE) |
| `created_at` | TIMESTAMPTZ | `now()` | |
| `updated_at` | TIMESTAMPTZ | `now()` | |

**theme_preference 값**: `light`, `dark`, `system`

**RLS 정책**: 자기 행만 SELECT/INSERT/UPDATE 가능

---

### `app_admin`
앱 관리자 목록. 운영 도구 접근 권한 제어.

| 컬럼 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `user_id` | UUID | PK, FK -> auth.users, ON DELETE CASCADE | |
| `created_at` | TIMESTAMPTZ | `now()` | |

---

### `notifications`
In-App 알림. 리액션/댓글/답글 시 자동 생성 (트리거).

| 컬럼 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `id` | BIGSERIAL | PK | |
| `user_id` | UUID | NOT NULL, FK -> auth.users | 알림 수신자 |
| `type` | TEXT | NOT NULL | 알림 유형: `reaction`, `comment`, `reply` |
| `post_id` | BIGINT | nullable, FK -> posts | 관련 게시글 |
| `comment_id` | BIGINT | nullable, FK -> comments | 관련 댓글 |
| `actor_alias` | TEXT | nullable | 행위자 별칭 |
| `read` | BOOLEAN | `false` | 읽음 여부 |
| `created_at` | TIMESTAMPTZ | `now()` | |

**인덱스**: `(user_id, read, created_at DESC)` — 미읽음 알림 빠른 조회

---

### `user_blocks`
사용자 차단.

| 컬럼 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `id` | BIGSERIAL | PK | |
| `blocker_id` | UUID | NOT NULL, FK -> auth.users | 차단한 사용자 |
| `blocked_alias` | TEXT | NOT NULL | 차단된 별칭 |
| `created_at` | TIMESTAMPTZ | `now()` | |

**UNIQUE**: `(blocker_id, blocked_alias)`

---

## 뷰

### `posts_with_like_count`
게시글에 좋아요수, 댓글수, 감정 정보, 분석 상태를 결합한 뷰. `security_invoker = true`.

```sql
SELECT
  p.id, p.title, p.content, p.author_id, p.created_at,
  p.board_id, p.is_anonymous, p.display_name, p.image_url,
  p.initial_emotions, p.post_type, p.activities,
  COALESCE(r_agg.total_reactions, 0)::integer AS like_count,
  COALESCE(c_agg.total_comments, 0)::integer AS comment_count,
  pa.emotions,
  COALESCE(pa.status, 'pending') AS analysis_status
FROM posts p
LEFT JOIN post_analysis pa ON pa.post_id = p.id
LEFT JOIN (
  SELECT r.post_id, SUM(r.count)::integer AS total_reactions
  FROM reactions r GROUP BY r.post_id
) r_agg ON r_agg.post_id = p.id
LEFT JOIN (
  SELECT c.post_id, COUNT(*)::integer AS total_comments
  FROM comments c WHERE c.deleted_at IS NULL GROUP BY c.post_id
) c_agg ON c_agg.post_id = p.id
WHERE p.deleted_at IS NULL;
```

> 리액션/댓글 수는 LEFT JOIN + GROUP BY로 집계 (스칼라 서브쿼리 → JOIN 최적화 적용).
> `initial_emotions`, `analysis_status` 포함.

---

## RPC 함수

### `toggle_reaction(p_post_id BIGINT, p_type TEXT) -> JSONB`
리액션 토글. 이미 있으면 제거, 없으면 추가. `reactions` + `user_reactions` 동시 관리.

- **SECURITY DEFINER** — RLS 우회
- **Advisory Lock** — `pg_advisory_xact_lock`으로 동시성 안전 보장
- 반환: `{"action": "added"}` 또는 `{"action": "removed"}`
- 인증 필수

### `get_post_reactions(p_post_id BIGINT) -> TABLE`
게시글의 리액션 목록 + 현재 사용자 반응 여부.

- 반환 컬럼: `reaction_type`, `count`, `user_reacted`

### `soft_delete_post(p_post_id BIGINT) -> void`
게시글 소프트삭제. `deleted_at = now()` 설정.

- 본인 게시글 또는 **관리자** (`app_admin`) 삭제 가능
- 이미 삭제된 게시글은 예외 발생

### `soft_delete_comment(p_comment_id BIGINT) -> void`
댓글 소프트삭제. 동작 방식은 `soft_delete_post`와 동일 (관리자 삭제 포함).

### `get_emotion_trend(days INT DEFAULT 7) -> TABLE`
최근 N일간 감정 트렌드 상위 5개 반환.

- 반환 컬럼: `emotion`, `cnt`, `pct` (비율 %)
- 삭제된 게시글(`deleted_at IS NOT NULL`) 제외

### `get_recommended_posts_by_emotion(p_post_id BIGINT, p_limit INT DEFAULT 10) -> TABLE`
지정 게시글과 감정이 겹치는 공개 글 추천. 감정 없으면 참여도 기반 폴백.

- 반환 컬럼: `id`, `title`, `board_id`, `like_count`, `comment_count`, `emotions`, `created_at`, `score`
- 정렬: 감정 겹침 × 10 + 참여도 (좋아요 + 댓글×2), 시간 감쇠 적용 (1주 → 점수 절반)
- CTE 기반 최적화 (match_score 1회 계산, N+1 서브쿼리 제거)
- 폴백: 감정 분석 없는 글에서도 참여도+최신순 추천 반환

### `get_trending_posts(p_hours INT DEFAULT 72, p_limit INT DEFAULT 10) -> TABLE`
홈 피드 "지금 뜨는 글" 섹션용. 참여도/시간 가중 점수 기반.

- 반환 컬럼: `id`, `title`, `board_id`, `like_count`, `comment_count`, `emotions`, `created_at`, `display_name`, `score`
- 점수: `(like_count + comment_count × 2 + 1) / max(age_hours, 1)`
- 클라이언트: 72시간 조회 후 3개 미만이면 720시간으로 확장

### `get_posts_by_emotion(p_emotion TEXT, p_limit INT, p_offset INT) -> TABLE`
특정 감정의 게시글 필터링. 감정 필터 바에서 사용.

- 반환 컬럼: `id`, `title`, `content`, `board_id`, `like_count`, `comment_count`, `emotions`, `created_at`, `display_name`, `author_id`, `is_anonymous`, `image_url`, `initial_emotions`
- `posts_with_like_count` 뷰에서 `p_emotion = ANY(emotions)` 필터

### `get_similar_feeling_count(p_post_id BIGINT, p_days INT DEFAULT 30) -> INT`
게시글의 감정과 유사한 감정을 가진 다른 사용자 수 반환. 게시글 상세 "비슷한 마음" 표시용.

- 해당 게시글의 감정 태그와 겹치는(`&&`) 다른 사용자의 글 작성자 수
- 본인 제외, 삭제된 글 제외, p_days일 이내

### `get_user_emotion_calendar(p_user_id UUID, p_start DATE, p_end DATE) -> TABLE`
사용자의 감정 캘린더 히트맵 데이터.

- 반환 컬럼: `day`, `emotions`, `post_count`
- 기간 내 각 날짜별 작성한 글의 감정 + 글 수
- `generate_series`로 빈 날짜도 포함

### `get_emotion_timeline(p_days INT DEFAULT 7) -> TABLE`
커뮤니티 감정 분포 타임라인 (영역 차트용).

- 반환 컬럼: `day`, `emotion`, `cnt`
- 최근 N일간 날짜별 감정별 집계

### `get_my_activity_summary() -> TABLE`
내 활동 요약 (나의 공간 프로필용).

- 반환 컬럼: `total_posts`, `total_comments`, `total_reactions`, `current_streak`
- 현재 사용자의 글/댓글/받은 리액션 수 + 연속 활동 일수

### `cleanup_stuck_analyses() -> INT`
5분 이상 `analyzing` 상태에 머무른 감정분석을 `failed`로 전환.

- 반환: 전환된 행 수
- `error_reason`에 `'stuck_timeout'` 기록
- SECURITY DEFINER

### `admin_cleanup_posts(p_user_id UUID, p_before TIMESTAMPTZ, p_after TIMESTAMPTZ) -> JSONB`
관리자 전용: 조건에 맞는 글을 hard DELETE (CASCADE). 최소 1개 필터 필수.

### `admin_cleanup_comments(p_user_id UUID, p_before TIMESTAMPTZ, p_after TIMESTAMPTZ) -> JSONB`
관리자 전용: 조건에 맞는 댓글을 hard DELETE. 동일 구조.

### `create_daily_post(p_emotions TEXT[], p_activities TEXT[], p_content TEXT) -> JSON`
오늘의 하루 생성. posts + post_analysis 원자적 생성. KST 기준 하루 1회.

### `update_daily_post(p_post_id BIGINT, p_emotions TEXT[], p_activities TEXT[], p_content TEXT) -> JSON`
오늘의 하루 수정. posts + post_analysis 동기 갱신.

### `get_today_daily() -> JSON`
오늘(KST) 내 daily 게시글 조회.

### `get_daily_activity_insights(p_days INT DEFAULT 30) -> JSON`
나의 패턴: 활동-감정 상관관계. 7일 이상 daily 필요. SECURITY INVOKER.

### `generate_display_alias() -> TEXT`
고정 익명 별칭 생성. 30×30 풀 + 충돌 시 숫자 접미사. EXCEPTION 재시도.

### `get_my_alias() -> TEXT`
내 별칭 조회.

### `get_notifications(p_limit INT, p_offset INT) -> TABLE`
알림 목록 조회 (최신순).

### `get_unread_notification_count() -> INT`
미읽음 알림 수.

### `mark_notifications_read(p_ids BIGINT[]) -> void`
선택 알림 읽음 처리.

### `mark_all_notifications_read() -> void`
전체 알림 읽음 처리.

### `block_user(p_alias TEXT) -> void`
특정 별칭 차단. 별칭 존재 검증 포함.

### `unblock_user(p_alias TEXT) -> void`
차단 해제.

### `get_blocked_aliases() -> TABLE`
차단 별칭 목록.

### `search_posts_v2(p_query TEXT, p_emotion TEXT, p_sort TEXT, p_limit INT, p_offset INT) -> TABLE`
게시글 검색 (v2). 풀텍스트 검색 + 관련도 정렬 + 하이라이트 + 서버 사이드 감정 필터.

- 반환 컬럼: `id`, `title`, `content`, `board_id`, `like_count`, `comment_count`, `emotions`, `created_at`, `display_name`, `author_id`, `is_anonymous`, `image_url`, `initial_emotions`, **`title_highlight`**, **`content_highlight`**, **`relevance_score`**
- `p_emotion`: 감정 필터 (NULL이면 전체)
- `p_sort`: `'relevance'` (관련도) | `'recent'` (최신) | `'popular'` (인기)
- 풀텍스트: `to_tsvector('simple')` + ILIKE 하이브리드
- 하이라이트: `ts_headline` — `<<` `>>` 구분자
- 관련도: `ts_rank` + 제목 매칭 가중치
- 최소 2자 이상 검색어 필요

---

## RLS 정책

### posts
| 정책 | 동작 | 조건 |
|---|---|---|
| Everyone can read posts | SELECT | `deleted_at IS NULL` |
| Authenticated users can create posts | INSERT | `auth.uid() = author_id` |
| Users can update own posts | UPDATE | `auth.uid() = author_id` |

> hard DELETE 정책 제거됨 — `soft_delete_post()` 사용

### comments
| 정책 | 동작 | 조건 |
|---|---|---|
| Everyone can read comments | SELECT | `deleted_at IS NULL` |
| Authenticated users can create comments | INSERT | `auth.uid() = author_id` |
| Users can update own comments | UPDATE | `auth.uid() = author_id` |

> hard DELETE 정책 제거됨 — `soft_delete_comment()` 사용

### reactions
| 정책 | 동작 | 조건 |
|---|---|---|
| Everyone can read reactions | SELECT | 무조건 허용 |

> INSERT/UPDATE/DELETE 정책 제거됨 — `toggle_reaction()` 사용

### boards
| 정책 | 동작 | 조건 |
|---|---|---|
| boards_select | SELECT | 무조건 허용 |
| Only app_admin can create boards | INSERT | `auth.uid() IN app_admin` |

### app_admin
| 정책 | 동작 | 조건 |
|---|---|---|
| Users can read own app_admin row | SELECT | `auth.uid() = user_id` |

### post_analysis
| 정책 | 동작 | 조건 |
|---|---|---|
| post_analysis_select | SELECT | `auth.role() = 'authenticated'` |

### user_reactions
| 정책 | 동작 | 조건 |
|---|---|---|
| user_reactions_select | SELECT | 무조건 허용 |

> INSERT/DELETE 정책 제거됨 — `toggle_reaction()` 사용

### user_preferences
| 정책 | 동작 | 조건 |
|---|---|---|
| user_prefs_select | SELECT | `auth.uid() = user_id` |
| user_prefs_insert | INSERT | `auth.uid() = user_id` |
| user_prefs_update | UPDATE | `auth.uid() = user_id` |

---

## 트리거

| 트리거 | 테이블 | 이벤트 | 설명 |
|---|---|---|---|
| `trg_posts_updated_at` | posts | BEFORE UPDATE | `updated_at` 자동 갱신 |
| `trg_comments_updated_at` | comments | BEFORE UPDATE | `updated_at` 자동 갱신 |
| `trg_boards_updated_at` | boards | BEFORE UPDATE | `updated_at` 자동 갱신 |
| `trg_check_daily_post_limit` | posts | BEFORE INSERT | 일일 게시글 50건 제한 |
| `trg_check_daily_comment_limit` | comments | BEFORE INSERT | 일일 댓글 100건 제한 |
| `analyze_post_on_insert` | posts | AFTER INSERT | Edge Function `analyze-post` 자동 호출 |
| `analyze_post_on_update` | posts | AFTER UPDATE (content, title) | content/title 변경 시 `analyze-post` 재호출 (WHEN 절로 실제 변경만) |
| `trg_create_pending_analysis` | posts | AFTER INSERT | `post_analysis`에 pending 행 자동 생성 |
| `trg_mark_analysis_analyzing` | posts | AFTER UPDATE (content, title) | `post_analysis.status`를 analyzing으로 전환 (WHEN 절로 실제 변경만) |

---

## 인덱스

### posts
| 인덱스 | 컬럼 | 비고 |
|---|---|---|
| `idx_posts_created_at` | `created_at DESC` | |
| `idx_posts_board_id` | `board_id` | |
| `idx_posts_author_id` | `author_id` | |
| `idx_posts_deleted_at` | `deleted_at` | partial: WHERE deleted_at IS NOT NULL |
| `idx_posts_board_created_at` | `board_id, created_at DESC` | |
| `idx_posts_author_id_created_at` | `author_id, created_at DESC` | |
| `idx_posts_trending` | `created_at DESC` | partial: WHERE deleted_at IS NULL |
| `idx_posts_author_deleted_created` | `author_id, created_at DESC` | partial: WHERE deleted_at IS NULL |
| `idx_posts_fts` | `to_tsvector('simple', title) \|\| to_tsvector('simple', content)` | GIN, partial: WHERE deleted_at IS NULL |

### comments
| 인덱스 | 컬럼 | 비고 |
|---|---|---|
| `idx_comments_post_id` | `post_id` | |
| `idx_comments_author_id` | `author_id` | |
| `idx_comments_deleted_at` | `deleted_at` | partial: WHERE deleted_at IS NOT NULL |
| `idx_comments_author_id_created_at` | `author_id, created_at DESC` | |

### 기타
| 인덱스 | 테이블 | 컬럼 |
|---|---|---|
| `idx_reactions_post_id` | reactions | `post_id` |
| `idx_user_reactions_post_type` | user_reactions | `post_id, reaction_type` |
| `idx_app_admin_user_id` | app_admin | `user_id` |
| `idx_boards_visibility` | boards | `visibility` |
| `idx_boards_name` | boards | `name` (UNIQUE) |
| `idx_post_analysis_emotions` | post_analysis | `emotions` (GIN) |
| `idx_post_analysis_analyzed_at` | post_analysis | `analyzed_at DESC` |
| `idx_post_analysis_status` | post_analysis | `status` (partial: WHERE status IN ('pending', 'failed')) |

---

## 제약조건

| 테이블 | 제약조건 | 설명 |
|---|---|---|
| boards | `boards_visibility_check` | visibility IN ('public', 'private') |
| boards | `boards_anon_mode_check` | anon_mode IN ('always_anon', 'allow_choice', 'require_name') |
| boards | `boards_name_length` | char_length(name) <= 100 |
| boards | `boards_description_length` | description IS NULL OR char_length(description) <= 500 |
| posts | `posts_title_length` | length(title) <= 200 |
| posts | `posts_content_length` | length(content) <= 100000 |
| comments | `comments_content_length` | length(content) <= 5000 |
| reactions | `reactions_type_check` | reaction_type IN ('like','heart','laugh','sad','surprise') |
| user_reactions | `user_reactions_type_check` | reaction_type IN ('like','heart','laugh','sad','surprise') |
| boards | `idx_boards_name` (UNIQUE) | 게시판명 유니크 |

---

## Realtime

`supabase_realtime` publication에 포함된 테이블:
- `post_analysis`
- `reactions`
- `user_reactions`

### 클라이언트 구독 패턴

앱/웹 모두 `post_analysis`의 INSERT/UPDATE를 Realtime으로 감지하여 감정 분석 결과를 실시간 수신:

```typescript
// postgres_changes 구독 (앱/웹 공통 패턴)
// event: '*' — INSERT(신규 분석) + UPDATE(재분석) 모두 감지
supabase
  .channel(`post-analysis-${postId}`)
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'post_analysis',
    filter: `post_id=eq.${postId}`,
  }, () => {
    queryClient.invalidateQueries({ queryKey: ['postAnalysis', postId] })
  })
  .subscribe((status, err) => {
    if (err) logger.error(`Realtime channel error:`, err)
  })
```

**에러 핸들링**: 모든 `.subscribe()` 호출에 `(status, err)` 콜백 추가 — 에러 시 `logger.error`로 Sentry 전송.

**Fallback 전략**: Realtime 구독 후 15초 경과해도 분석 결과 없으면 `analyze-post-on-demand` Edge Function 수동 호출.

---

## Edge Functions (앱 레포에서 관리)

| 함수 | JWT 검증 | 트리거 | 설명 |
|---|---|---|---|
| `analyze-post` | X | DB Trigger (posts INSERT + UPDATE) | 게시글 작성/수정 시 자동 감정 분석 (60초 쿨다운) |
| `analyze-post-on-demand` | O | 클라이언트 수동 호출 | Webhook 실패/지연 시 fallback + 수동 재시도 (쿨다운 우회) |

### 감정 분석 흐름

```
게시글 INSERT / UPDATE (content/title 변경)
  ├─ [자동] DB Trigger → analyze-post → 쿨다운 확인 → Claude API → post_analysis UPSERT
  │    └─ Realtime (INSERT 또는 UPDATE) → 클라이언트 즉시 수신
  └─ [fallback] 15초 후 → analyze-post-on-demand (force) → 동일 분석 → post_analysis UPSERT
       └─ Realtime → 클라이언트 즉시 수신
```

> `smart-service`, `recommend-posts-by-emotion` Edge Function은 삭제됨.
> 추천은 `get_recommended_posts_by_emotion` RPC로 직접 호출.

---

## Storage

### `post-images` 버킷
- **공개 버킷** (public: true)
- 파일 크기 제한: 50MB
- 허용 MIME: `image/jpeg`, `image/png`, `image/webp`, `image/gif`
- 폴더 구조: `{user_id}/filename`

**Storage 정책**:
| 정책 | 동작 | 조건 |
|---|---|---|
| authenticated users can upload | INSERT | `auth.uid() = folder[0]` |
| anyone can read | SELECT | `bucket_id = 'post-images'` |
| users can delete own | DELETE | `auth.uid() = folder[0]` |

> Storage는 Dashboard에서 수동 구성 필요 (마이그레이션에서는 storage 스키마 존재 시에만 실행)

---

## 마이그레이션 히스토리

| 순서 | 파일 | 설명 |
|---|---|---|
| 1 | `20260301000001_schema.sql` | 베이스라인: 확장, 함수, 테이블, 인덱스, 뷰, 트리거 |
| 2 | `20260301000002_rls.sql` | 베이스라인: 전체 RLS 정책 |
| 3 | `20260301000003_infra.sql` | 베이스라인: 스키마 권한(grants) + Storage 버킷/정책 |
| 4 | `20260302000000_fix_rls_update_policies.sql` | UPDATE 정책에서 `deleted_at IS NULL` 제거 (소프트삭제 호환) |
| 5 | `20260303000001_core_redesign.sql` | 리액션 RPC, 소프트삭제 RPC, FK CASCADE, 길이 제약조건, 인덱스 추가, Realtime |
| 6 | `20260303000002_fix_group_members_recursion.sql` | (레거시) `is_group_member()` 함수로 RLS 자기참조 재귀 수정 |
| 7 | `20260303000003_post_update_reanalysis.sql` | 게시글 수정 시 감정분석 자동 재실행 트리거 |
| 8 | `20260304000001_fix_reactions_data.sql` | 리액션 데이터 정합성 수정 |
| 9 | `20260306000001_remove_author_column.sql` | author 컬럼 제거 |
| 10 | `20260307000001_recommendation_improvements.sql` | 추천 개선 (트렌딩, 감정 폴백, pct, 시간 감쇠) |
| 11 | `20260308000001_ux_redesign.sql` | UX 리디자인: initial_emotions, user_preferences, 감정 RPC 5개, 인덱스 2개 |
| 12 | `20260309000001_security_performance_fixes.sql` | 보안/성능: boards RLS 가시성, 인덱스 3개, RPC 최적화 2개, CHECK 제약조건 2개, 유니크 인덱스 1개 |
| 13 | `20260310000001_comprehensive_improvements.sql` | 공개 게시판(id=12), 뷰 LEFT JOIN 최적화, 검색 RPC, advisory lock, 관리자 삭제 |
| 14 | `20260311000001_fix_rpc_missing_columns.sql` | get_posts_by_emotion RPC에 content/author_id/image_url 등 누락 컬럼 추가 |
| 15 | `20260311000002_fix_search_posts_columns.sql` | search_posts RPC에 동일 누락 컬럼 추가 (content_preview 제거) |
| 16 | `20260311000003_analysis_status_retry.sql` | 감정분석 상태 추적: status/retry_count/error_reason 컬럼, pending 자동 생성/analyzing 전환 트리거, 뷰에 analysis_status |
| 17 | `20260312000001_search_v2.sql` | 검색 v2: 풀텍스트(tsvector) + 관련도 정렬 + 하이라이트 + 서버 사이드 감정 필터, tsvector GIN 인덱스 |
| 18 | `20260313000001_admin_groups_rls_fix.sql` | (레거시) groups UPDATE/DELETE RLS + invite_code CHECK(4-50자) |
| 19 | `20260314000001_drop_search_posts_v1.sql` | search_posts v1 함수 제거 (deprecated) |
| 20 | `20260315000001_search_v2_ilike_escape.sql` | search_posts_v2 ILIKE 와일드카드 이스케이프 |
| 21 | `20260315000002_fix_search_v2_column_order.sql` | search_posts_v2 CTE 컬럼 순서 수정 |
| 22 | `20260316000001_cleanup_stuck_analyses.sql` | 감정분석 stuck 상태 자동 정리 함수 (cleanup_stuck_analyses) |
| 23 | `20260317000001_post_analysis_rls.sql` | post_analysis SELECT: `auth.role() = 'authenticated'`로 강화 (anon 접근 차단) |
| 24 | `20260317000002_reactions_rls_cleanup.sql` | reactions/user_reactions 직접 쓰기 RLS 5개 정책 제거 (toggle_reaction RPC 전용) |
| 25 | `20260318000001_boards_constraints.sql` | boards 이름/설명 길이 CHECK 제약조건 (name ≤ 100, description ≤ 500) |
| 26 | `20260319000001_remove_group_board_system.sql` | 그룹/게시판 시스템 완전 제거: groups/group_members 테이블 DROP, posts/comments/boards에서 group_id/member_id/board_id 컬럼 제거, is_group_member/cleanup_orphan_group_members RPC 제거 |
| 27 | `20260320000001_advisor_performance_security.sql` | RLS initplan 최적화 (auth.uid()→(select auth.uid())) 6개 정책, get_post_reactions search_path 설정, pg_trgm extensions 스키마 이동 |
| 28 | `20260321000001_admin_cleanup_test_data.sql` | 관리자 전용 테스트 데이터 정리 RPC 2개 |
| 29 | `20260322000001_fix_analysis_cooldown.sql` | 감정분석 쿨다운 버그 수정 (analyzed_at NULL 허용) |
| 30 | `20260323000001_daily_post.sql` | 오늘의 하루: posts 확장(post_type, activities), RPC 3개, 트리거 조건 |
| 31 | `20260324000001_daily_insights.sql` | 나의 패턴: get_daily_activity_insights RPC |
| 32 | `20260325000001_anonymous_alias.sql` | 고정 익명 별칭 + 자동 부여 트리거 |
| 33 | `20260325000002_comment_replies.sql` | 댓글 답글 (parent_id, 1단계) |
| 34 | `20260325000003_notifications.sql` | In-App 알림 + 자동 생성 트리거 |
| 35 | `20260325000004_user_blocks.sql` | 사용자 차단 |
| 36 | `20260326000001_v2_improvements.sql` | v2 점검: 타임존 수정, 별칭 레이스컨디션, 알림/차단 개선 |
| 37 | `20260327000001_v3_refinement.sql` | v3 정비: post_type CHECK, 알림 인덱스, 별칭 unique, analyzed_at 기본값, 답글 검증 |
| 38 | `20260328000001_mypage_rpc_optimization.sql` | v4: RPC KST 타임존 + INVOKER + 범위 비교 최적화 |

---

## ER 다이어그램 (텍스트)

```
auth.users
  |
  +--< posts (author_id)
  |     |
  |     +--< comments (post_id) CASCADE
  |     +--< reactions (post_id) CASCADE
  |     +--< user_reactions (post_id) CASCADE
  |     +--< post_analysis (post_id) CASCADE  [1:1]
  |
  +--< comments (author_id)
  +--< user_reactions (user_id) CASCADE
  +--< app_admin (user_id) CASCADE
  +--< user_preferences (user_id) CASCADE  [1:1]
  +--< notifications (user_id)
  +--< user_blocks (blocker_id)

posts --< boards (board_id) SET NULL
comments --< comments (parent_id)  [1단계 답글]
```
