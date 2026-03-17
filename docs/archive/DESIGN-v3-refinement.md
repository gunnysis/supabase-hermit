# v3 종합 개선 설계

> **범위**: DB 스키마 정비 + 공유 타입/유틸 보강 + 웹 타입 안전성 + 문서 갱신
> **목표**: 기술 부채 해소, 타입 안전성 100%, DB 무결성 강화

---

## 1. DB 스키마 정비 (Migration 37)

### 1.1 post_type CHECK 제약조건
```sql
ALTER TABLE posts ADD CONSTRAINT posts_post_type_check
  CHECK (post_type IN ('post', 'daily'));
```
**이유**: `post_type`이 ('post' | 'daily') 외 값 삽입 가능 — DB 레벨 무결성 부재

### 1.2 알림 페이지네이션 인덱스
```sql
CREATE INDEX IF NOT EXISTS idx_notifications_user_created_id
  ON notifications (user_id, created_at DESC, id DESC);
```
**이유**: `get_notifications()` ORDER BY `created_at DESC, id DESC` (v2 tie-breaker) 매칭 인덱스 없음

### 1.3 user_preferences.display_alias 유니크 인덱스 보강
기존 UNIQUE 제약조건은 있지만, partial index로 NULL 제외 필요:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_preferences_alias_unique
  ON user_preferences (display_alias) WHERE display_alias IS NOT NULL;
```

### 1.4 post_analysis.analyzed_at 기본값 수정
```sql
ALTER TABLE post_analysis ALTER COLUMN analyzed_at SET DEFAULT NULL;
```
**이유**: `INSERT INTO post_analysis (status='pending')` 시 `analyzed_at=now()` → 쿨다운 계산 오류

---

## 2. 공유 타입 보강 (shared/types.ts)

### 추가 타입
```typescript
/** In-App 알림 */
export interface Notification {
  id: number
  type: 'reaction' | 'comment' | 'reply'
  post_id: number | null
  comment_id: number | null
  actor_alias: string | null
  read: boolean
  created_at: string
}

/** 알림 타입 */
export type NotificationType = 'reaction' | 'comment' | 'reply'

/** 사용자 차단 */
export interface UserBlock {
  id: number
  blocker_id: string
  blocked_alias: string
  created_at: string
}

/** 나의 패턴 인사이트 (get_daily_activity_insights RPC) */
export interface ActivityInsight {
  activity: string
  total_count: number
  emotions: { emotion: string; count: number }[]
  top_emotion: string
}

/** 나의 활동 요약 (get_my_activity_summary RPC) */
export interface ActivitySummary {
  post_count: number
  comment_count: number
  reaction_count: number
  streak_days: number
  first_post_at: string | null
}
```

---

## 3. 공유 유틸 보강 (shared/utils.ts)

```typescript
/** 오늘의 하루 입력 검증 */
export function validateDailyPostInput(input: {
  emotions: string[]
  activities?: string[]
  content?: string
}): string | null {
  if (!input.emotions.length) return '감정을 하나 이상 선택해주세요.'
  if (input.emotions.length > 3) return '감정은 최대 3개까지 선택할 수 있어요.'
  if (input.activities && input.activities.length > 5) return '활동은 최대 5개까지 선택할 수 있어요.'
  if (input.content && input.content.length > 200) return '한마디는 200자 이내로 입력해주세요.'
  return null
}
```

---

## 4. 웹 타입 안전성 수정

### 4.1 불필요한 `as any` 제거 (4곳)

| 파일 | 현재 | 수정 |
|------|------|------|
| PostCard.tsx:26 | `(post as any).post_type === 'daily'` | `post.post_type === 'daily'` |
| DailyPostCard.tsx:16 | `(post as any).activities ?? []` | `post.activities ?? []` |
| create/page.tsx:34 | `(post as any).initial_emotions ?? []` | `post.initial_emotions ?? []` |
| create/page.tsx:35 | `(post as any).activities ?? []` | `post.activities ?? []` |

**근거**: `PostWithCounts`에 `post_type`, `activities` 이미 정의됨. `Post`에 `initial_emotions`, `activities` 이미 정의됨.

### 4.2 DailyPostForm 타입 수정 (2곳)

| 현재 | 수정 |
|------|------|
| `getQueryData<any>(['myActivity'])` | `getQueryData<ActivitySummary>(['myActivity'])` |
| `onError: (err: any)` | `onError: (err: Error)` |

### 4.3 Notification 타입 통합
웹 `notificationsApi.ts`의 로컬 `Notification` 인터페이스 → 중앙 `shared/types.ts`에서 import

---

## 5. 문서 갱신

- CLAUDE.md: 마이그레이션 37개, RPC 28개 확인 (실제 28개 맞음, 중복 정의 존재하지만 동일 함수)
- SCHEMA.md: v2 테이블/RPC/제약조건 반영

---

## 작업 순서

1. Migration 37 SQL 작성
2. shared/types.ts 타입 추가
3. shared/utils.ts 유틸 추가
4. DB push + gen-types
5. 웹 타입 수정
6. sync + verify
7. 웹 배포
8. 문서 갱신
