# 에러 처리 전략 통일 설계

> **작성일**: 2026-03-18
> **상태**: 완료 (2026-03-18)
> **범위**: 웹 + 앱 양쪽

## 문제

에러 처리 전략 부재로 반복적인 사이드이펙트 발생:
1. API 함수가 throw/null을 혼재 사용 → 호출부가 예측 불가
2. useQuery의 isError를 컴포넌트가 무시 → 에러 시 빈 화면 또는 크래시
3. QueryClient에 전역 에러 핸들러 없음 → 사용자에게 피드백 없음
4. Mutation onError 누락 → 실패해도 알림 없음

## 전략: 3계층 방어

```
[1층] API 함수 — 모두 throw (일관성)
       ↓ TanStack Query가 잡음
[2층] QueryClient onError — 전역 토스트 (사용자 피드백)
       ↓ 컴포넌트는 isError로 분기
[3층] ErrorBoundary — 예외 누수 최종 방어
```

## 변경 사항

### 1. API 함수 표준화 — "모두 throw"

**원칙**: API 함수는 성공 시 데이터 반환, 실패 시 무조건 throw.
null/[] 반환하던 함수를 throw로 전환.

**웹 수정 대상** (8개):
- `postsApi.ts`: getPostAnalysis, getYesterdayDailyReactions, getSameMoodDailies, getWeeklyEmotionSummary
- `myApi.ts`: getMyAlias
- `blocksApi.ts`: getBlockedAliases
- `notificationsApi.ts`: getUnreadCount
- `postsApi.server.ts`: getBoardPostsServer, getPostServer

**앱 수정 대상** (8개):
- `my.ts`: getYesterdayDailyReactions, getSameMoodDailies, getWeeklyEmotionSummary, getMyAlias
- `analysis.ts`: getEmotionTrend, getPostAnalysis
- `blocks.ts`: getBlockedAliases
- `notifications.ts`: getUnreadCount

**예외**: 일부 함수는 "데이터 없음"이 정상인 경우 (예: getTodayDaily → null은 정상). 이 경우 throw하지 않고 null 반환 유지. 단, Supabase error가 있으면 throw.

### 2. QueryClient 전역 onError

**웹** (`src/lib/query-client.ts`):
```ts
queries: {
  ...기존,
  meta: { showErrorToast: true },  // 기본값
},
mutations: {
  onError: (error) => {
    // toast.error 호출
  },
},
```

**QueryClient에 전역 에러 콜백 추가**:
- 웹: `onError` 핸들러에서 `sonner` toast 호출
- 앱: `onError` 핸들러에서 `react-native-toast-message` 호출
- 특정 쿼리에서 에러 토스트를 원치 않으면 `meta: { silent: true }` 옵션

### 3. Mutation onError 보강

누락된 mutation에 onError 추가:
- 웹: useCreateDaily, useUpdateDaily
- 앱: useCreateDaily, useUpdateDaily

### 4. 정리

- 앱 `useErrorHandler` → 삭제 (사용 0회, 죽은 코드)

## 사이드이펙트 체크

- [ ] null → throw 전환 시, 호출부에서 null 체크에 의존하는 곳 확인
  - getMyAlias: ProfileSection에서 `alias ?? '익명'` → useQuery가 error 잡으므로 data는 undefined → `?? '익명'` 유지하면 호환
  - getBlockedAliases: `data: blockedAliases = []` → useQuery 기본값으로 유지
  - getWeeklyEmotionSummary: `if (!data) return null` → 기존 패턴 유지
  - getUnreadCount: 0 반환 → useQuery error 시 data undefined → `?? 0` 필요
- [ ] 에러 토스트 중복: mutation에서 이미 onError 토스트 + 전역 onError 토스트 → mutation은 전역 핸들러 사용
- [ ] retry: getMyAlias 등 4xx 에러는 retry 불필요 → QueryClient에서 이미 4xx retry=0
