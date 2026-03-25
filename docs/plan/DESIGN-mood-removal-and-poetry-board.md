# 설계: MoodSelector 제거 + 시 게시판 구현

> 작성일: 2026-03-25

## 1. 게시글 작성 시 "지금 어떤 마음인가요?" 제거

### 배경
- 일반 게시글(`post_type='post'`) 작성/수정 시 `MoodSelector`로 `initial_emotions`를 선택하는 UI가 있음
- AI 감정분석이 자동으로 실행되므로 사용자가 직접 감정을 선택할 필요성이 낮음
- daily 게시글의 감정 선택은 별도 UI(DailyPostForm 내장)이며, 이번 작업과 무관

### 변경 범위

| 구분 | 파일 | 변경 |
|------|------|------|
| 웹 | `CreatePostForm.tsx` | MoodSelector 제거, initialEmotions 상태 제거, API 호출에서 제외 |
| 웹 | `EditPostForm.tsx` | MoodSelector 제거, initialEmotions 상태 제거, API 호출에서 제외 |
| 웹 | `MoodSelector.tsx` | 삭제 (사용처 없음) |
| 앱 | `create.tsx` (RegularCreateForm) | MoodSelector 제거, initialEmotions 상태 제거 |
| 앱 | `post/edit/[id].tsx` | MoodSelector 제거, initialEmotions 상태 제거 |
| 앱 | `MoodSelector.tsx` | 삭제 (사용처 없음) |

### 변경하지 않는 것
- DB `posts.initial_emotions` 컬럼 — daily 게시글이 사용 중
- `shared/types.ts`의 `initial_emotions` 필드 — daily 게시글이 사용 중
- `DailyPostForm` — 별도 인라인 감정 선택 UI, 변경 없음
- `postsApi.ts`의 `updatePost` 시그니처 — 하위 호환 유지

---

## 2. 시 게시판 구현

### 배경
- 현재 게시판은 `자유게시판(id=12)` 1개만 존재
- 시를 작성하는 전용 게시판을 추가하여 감정 표현의 다양성 확장
- 기존 아키텍처(board_id 기반 필터링) 위에 구현, 구조 변경 최소화

### DB 마이그레이션

```sql
INSERT INTO public.boards (id, name, description, visibility, anon_mode)
VALUES (13, '시 게시판', '마음을 시로 표현해보세요.', 'public', 'always_anon');
```

- 시 게시글은 기존 `posts` 테이블에 `board_id=13`으로 저장
- `post_type='post'` 유지 (별도 타입 불필요)
- AI 감정분석 자동 발동 (일반 게시글과 동일)
- 리액션/댓글/Realtime/RLS 모두 기존 로직 그대로

### 상수 추가

```typescript
export const POETRY_BOARD_ID = 13

export const PUBLIC_BOARDS = [
  { id: 12, name: '자유게시판', icon: '📝' },
  { id: 13, name: '시 게시판', icon: '🪶' },
] as const
```

### 피드 UI (웹/앱)

- 홈 피드 상단에 게시판 전환 탭 추가: `자유게시판 | 시 게시판`
- 탭 전환 시 `useBoardPosts(selectedBoardId, sortOrder)` 호출
- 기존 감정 필터, 정렬, 무한스크롤 모두 게시판별로 독립 동작
- 서버 프리페치(웹)는 기본 게시판(12)만 — 나머지는 클라이언트 페칭

### 글쓰기 UI (웹/앱)

- 글쓰기 페이지에 탭 3개: `📝 글쓰기 | 🪶 시 쓰기 | 🌤️ 오늘의 하루`
- 시 쓰기 선택 시 `CreatePostForm`에 `boardId={POETRY_BOARD_ID}` 전달
- 시 작성 폼: 제목 필수, 본문 필수, 이미지 첨부 가능
- placeholder 차별화: 제목 "시의 제목을 입력하세요", 본문 "시를 작성해보세요"
- `resolveDisplayName(userId, boardId)` → 게시판별 고유 별칭 자동 부여

### 익명 별칭
- `resolveDisplayName` seed가 `${userId}:board:${boardId}`이므로 게시판별 다른 별칭
- 시 게시판에서는 자유게시판과 다른 별칭으로 표시 → 프라이버시 보호

### 사이드이펙트 체크
- [x] 삭제 연쇄: 없음 (새 데이터 추가만)
- [x] 동기화: constants.ts sync 필요
- [x] 타임존: 해당 없음
- [x] 에러 처리: getBoardPosts는 이미 boardId 파라미터 지원
- [x] 캐시: `['boardPosts', boardId]`로 게시판별 분리 — 기존 캐시 무효화 영향 없음
- [x] 호환성: DEFAULT_PUBLIC_BOARD_ID 유지, 기존 코드 변경 없음
