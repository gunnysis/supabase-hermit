# 감정분석 실패 수정 설계

## 날짜: 2026-03-15

## 배경

글 작성 후 감정분석이 실패하는 구조적 결함 분석 결과, 5개 실패 경로를 식별.

## 발견된 문제

### P0-1: 쿨다운 버그 — 신규 글 분석 skip

**경로**: INSERT → `trg_create_pending_analysis` → `post_analysis(status=pending, analyzed_at=now())` → Edge Function `analyzeAndSave()` → 쿨다운 체크 `diffMs < 60000` → **skip**

**원인**: `post_analysis.analyzed_at`의 `NOT NULL DEFAULT now()`. 트리거가 pending 행을 생성할 때 analyzed_at이 자동으로 현재 시각으로 설정됨. Edge Function이 즉시 실행되면 `diffMs ≈ 0` → 쿨다운 발동.

**수정**: `analyze.ts:274`의 쿨다운 조건에 `status === 'done'` 가드 추가.

```typescript
// Before
if (existing?.analyzed_at) {
// After
if (existing?.analyzed_at && existing.status === 'done') {
```

### P0-2: createPost 42501 재시도 시 id=0 반환

**경로**: `createPost()` → 첫 INSERT 42501(RLS) → `.select()` 없이 재시도 → data=null → `id: 0` 반환 → `usePostDetailAnalysis(0)` disabled.

**수정**: 재시도 INSERT에 `.select().single()` 추가.

### P1-1: analyze-post-on-demand JWT 미검증

**위험**: postId를 아는 누구나 무인증으로 분석 트리거 가능 → Gemini API 사용량 고갈.

**수정**: Authorization 헤더에서 JWT를 추출하고 `supabase.auth.getUser()`로 검증.

### P1-2: content_too_short 분기 retry_count 미초기화

`retry_count`가 이전 실패 시도의 값을 유지. 모니터링 혼란 가능.

**수정**: `retry_count: 0` 추가.

### P2: DB analyzed_at NULL 허용 (DB 마이그레이션)

pending/analyzing 행은 `analyzed_at`이 의미 없음. NULL로 변경하여 의미적 정확성 확보.
트리거에서도 `analyzed_at`을 명시적으로 생략 (이미 미지정이지만 DEFAULT가 변경됨).

## 수정 범위

| 파일 | 변경 |
|---|---|
| `_shared/analyze.ts` | 쿨다운 조건 + retry_count |
| `analyze-post-on-demand/index.ts` | JWT 검증 추가 |
| `src/shared/lib/api/posts.ts` (앱) | createPost 재시도 `.select().single()` |
| DB 마이그레이션 | analyzed_at NULL 허용 + DEFAULT 제거 |

## 미수정 (수용)

- **retry_count race condition**: 동시 실행 확률 극히 낮음, 현재 수준 수용
- **failed 시 기존 emotions 유지**: 의도적 설계 — 일시적 실패 시 이전 감정 표시 유지
- **화면 이탈 시 refetch 취소**: React 생명주기 정상 동작, 재진입 시 자동 복구
