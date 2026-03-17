# v2 타입 리팩토링 설계

> **문제**: ESLint/TypeScript 에러 반복 → 근본 원인은 타입 설계 불완전
> **목표**: 한 번에 모든 타입 문제 해결, 앱 pre-commit hook 통과

---

## 근본 원인 분석

### 1. RPC 반환 타입이 정의되지 않음

`get_today_daily()`, `get_daily_activity_insights()` 등 RPC가 `JSON`을 반환하는데, 클라이언트에서 `as unknown as Type`으로 캐스팅. Supabase 자동 생성 타입(`database.gen.ts`)과 비즈니스 타입(`types.ts`) 사이에 간극.

### 2. early return 전 hooks 문제

PostCard, CreateScreen에서 `post_type === 'daily'` 분기가 hooks 호출 전에 있어서 React hooks 규칙 위반.

**패턴**: 조건 분기로 다른 컴포넌트를 렌더하면 → **별도 컴포넌트로 분리**해야 함.

### 3. error 타입이 `any`

`onError: (err: any)` 패턴이 여러 곳. Supabase/API 에러는 `{ code?: string; message?: string }` 구조인데 any로 캐스팅.

---

## 수정 설계

### A. API 에러 타입 통일

```typescript
// src/shared/lib/api/error.ts에 추가
export interface ApiErrorLike {
  code?: string;
  message?: string;
  details?: string;
  hint?: string;
}
```

모든 `onError: (err: any)` → `onError: (err: unknown)` + `(err as ApiErrorLike)?.code`

### B. RPC 반환 타입 캐스팅 통일

모든 `data as Type` → `data as unknown as Type` (이미 일부 적용됨)

### C. PostCard hooks 규칙 수정

```
변경 전:
  PostCardComponent에서 early return + hooks

변경 후:
  PostCardComponent = 분기만 (hooks 없음)
  → DailyPostCard (daily용, 자체 hooks)
  → RegularPostCard (일반용, 기존 hooks)
```

### D. CreateScreen hooks 규칙 수정

```
변경 전:
  CreateScreen에서 early return + hooks

변경 후:
  CreateScreen = 분기만
  → DailyPostForm / DailyEditWrapper (daily용)
  → RegularCreateForm (일반용, 기존 hooks 이동)
```

### E. Notification 타입 import

`getLabel(n: any)` → `getLabel(n: Notification)` + import

### F. queryClient.getQueryData 타입

`getQueryData<any>` → `getQueryData<{ post_count?: number }>` 또는 적절한 타입

---

## 파일 목록

| # | 파일 | 에러 | 수정 |
|---|------|------|------|
| 1 | PostCard.tsx | hooks 조건부 호출 | hooks를 모두 early return 위로 이동 |
| 2 | create.tsx | hooks 조건부 호출 | RegularCreateForm 분리 |
| 3 | notifications.tsx | any + 미사용 변수 | Notification 타입 + isLoading 제거 |
| 4 | DailyPostForm.tsx | any 2개 | unknown + typed cast |
| 5 | api/my.ts | as 캐스팅 | as unknown as Type |

---

## 작업 순서

1. `shared/lib/api/error.ts` — ApiErrorLike 타입 추가 (있으면 확장)
2. PostCard.tsx — 모든 hooks를 early return 위로 (이미 부분 완료)
3. create.tsx — RegularCreateForm 분리 (이미 부분 완료)
4. DailyPostForm.tsx — err: unknown + typed cast
5. notifications.tsx — Notification 타입 + isLoading 제거
6. api/my.ts — 캐스팅 수정
7. 전체 tsc --noEmit + eslint 확인
