# 앱 레포 (gns-hermit-comm) 분석 스냅샷

> **최종 갱신**: 2026-03-16 | **Expo SDK 55** | **React Native 0.83.2** | **파일**: 137개

## 통계 요약

| 항목 | 수량 |
|------|------|
| .ts/.tsx 파일 | 137 |
| API 함수 | 49 |
| 커스텀 훅 | 27 |
| Feature 모듈 | 9 |
| 공유 컴포넌트 | 21 |
| 테스트 파일 | 6 (14 suites, 121 tests) |
| Edge Functions | 2 |
| 네비게이션 라우트 | 13 |
| `as any` | 0 |
| TODO/FIXME | 0 |
| @ts-ignore | 0 |

---

## 디렉토리 구조

```
src/
├── app/                  # Expo Router (13 routes)
│   ├── (tabs)/           # 탭 네비게이션 (home, create, my, search)
│   ├── admin/            # 관리자 (dashboard, login)
│   └── post/             # 게시글 (detail, edit)
├── features/             # 도메인별 모듈 (9개)
├── shared/
│   ├── lib/api/          # API 모듈 (13개)
│   ├── hooks/            # 공유 훅 (4개)
│   ├── components/       # 공유 컴포넌트 (21개)
│   ├── utils/            # 유틸리티
│   └── styles/           # 스타일
├── types/                # 타입 정의 (4 파일)
├── app.tsx               # 앱 진입점
├── Root.tsx              # 루트 프로바이더
└── GlobalStyles.tsx      # 글로벌 스타일
```

---

## 네비게이션

```
_layout.tsx (Root)
├── (tabs)/
│   ├── index.tsx         # 홈
│   ├── create.tsx        # 글쓰기
│   ├── my.tsx            # 내 프로필
│   └── search.tsx        # 검색
├── admin/
│   ├── index.tsx         # 관리자 대시보드
│   └── login.tsx         # 관리자 로그인
├── post/
│   ├── [id].tsx          # 게시글 상세
│   └── edit/[id].tsx     # 게시글 수정
├── notifications.tsx     # 알림
└── search.tsx            # 검색
```

---

## Feature 모듈 (9개)

| Feature | 파일 | 컴포넌트 | 훅 | API |
|---------|------|---------|-----|-----|
| admin | 2 | - | 1 | 1 |
| auth | 2 | - | 1 | - |
| blocks | 1 | - | 1 | - |
| boards | 3 | - | 2 | 1 |
| comments | 3 | 2 | 1 | - |
| my | 8 | 3 | 5 | - |
| notifications | 1 | - | 1 | - |
| **posts** | **34** | **23** | **11** | - |
| search | 3 | 3 | - | - |

---

## API 모듈 (49 함수)

### posts.ts (10)
getPosts, searchPosts, getPost, createPost, deletePost, getPostsByEmotion, updatePost, createDailyPost, updateDailyPost, getTodayDaily

### comments.ts (4)
getComments, createComment, updateComment, deleteComment

### reactions.ts (2)
getPostReactions, toggleReaction

### analysis.ts (3)
getEmotionTrend, getPostAnalysis, invokeSmartService

### recommendations.ts (1)
getRecommendedPosts

### trending.ts (1)
getTrendingPosts

### my.ts (6)
getActivitySummary, getEmotionTimeline, getDailyInsights, getYesterdayDailyReactions, getSameMoodDailies, getMyAlias

### notifications.ts (4)
getNotifications, getUnreadCount, markRead, markAllRead

### blocks.ts (3)
blockUser, unblockUser, getBlockedAliases

### health.ts (1)
healthCheck

### error.ts
APIError 클래스 — status, message, code, details + userMessage getter

### helpers.ts
extractErrorMessage — Supabase 에러 → 사용자 메시지 변환

---

## 커스텀 훅 (27개)

### Feature 훅 (23)
- **admin**: useIsAdmin
- **auth**: useAuth
- **blocks**: useBlocks
- **boards**: useBoardPosts, useBoards
- **comments**: useRealtimeComments
- **my**: useActivitySummary, useCreateDaily, useDailyInsights, useEmotionTimeline, useTodayDaily
- **notifications**: useNotifications
- **posts**: useCreatePost, useDraft, useEmotionTrend, usePostDetail, usePostDetailAnalysis, usePostDetailComments, usePostDetailReactions, useRealtimePosts, useRealtimeReactions, useRecommendedPosts, useTrendingPosts

### 공유 훅 (4)
- useErrorHandler, useNetworkStatus, useResponsiveLayout, useThemeColors

---

## 공유 컴포넌트 (21개)

ActivityTagSelector, AppErrorBoundary, Button, Container, ContentEditor, EmptyState, ErrorView, FloatingActionButton, HighlightText, HomeCheckinBanner, Input, Loading, NetworkBanner, NotificationBell, ScreenHeader, Skeleton, SortTabs, YesterdayReactionBanner

---

## 핵심 의존성

| 패키지 | 버전 | 용도 |
|--------|------|------|
| react | 19.2.0 | UI |
| react-native | 0.83.2 | 네이티브 |
| expo | ~55.0.5 | SDK |
| expo-router | ~55.0.5 | 라우팅 |
| @supabase/supabase-js | ^2.95.3 | DB |
| @tanstack/react-query | ^5.62.0 | 상태관리 |
| nativewind | ^4.0.1 | Tailwind RN |
| @sentry/react-native | ~7.11.0 | 모니터링 |
| react-hook-form | ^7.54.0 | 폼 |
| zod | ^3.23.8 | 검증 |
| date-fns | ^4.1.0 | 날짜 |
| typescript | ~5.9.2 | 타입 |

---

## Edge Functions (앱 레포 관리)

| 함수 | JWT | 트리거 | 설명 |
|------|-----|--------|------|
| analyze-post | X | DB webhook (INSERT/UPDATE) | 자동 감정분석 (post_type='post'만, 60초 쿨다운) |
| analyze-post-on-demand | O | 수동 요청 | 재시도 + 폴백 (쿨다운 우회) |

공유 모듈: `_shared/analyze.ts` (Gemini API + 한국어 프롬프트), `_shared/cors.ts`

---

## 앱 설정

| 설정 | 값 |
|------|-----|
| NATIVE_VERSION | 2.0.0 |
| BUILD_NUMBER | 1 (autoIncrement on prod) |
| runtimeVersion | fingerprint (자동 OTA) |
| PROJECT_ID | bc4199dd-30ad-42bb-ba1c-4e6fce0eecdd |

---

## Realtime 구독

| 훅 | 대상 |
|----|------|
| useRealtimePosts | posts 변경 |
| useRealtimeComments | comments 변경 |
| useRealtimeReactions | reactions 변경 |

---

## 테스트

| 파일 | 유형 |
|------|------|
| tests/features/auth/auth.test.ts | 인증 |
| tests/features/posts/usePostDetailAnalysis.test.ts | 분석 폴링 |
| tests/integration/tabs.integration.test.tsx | 통합 |
| src/shared/components/Button.test.tsx | 컴포넌트 |
| src/shared/components/ErrorView.test.tsx | 컴포넌트 |
| src/shared/lib/schemas.test.ts | 스키마 |

러너: Jest 29.7.0 | 결과: 14 suites, 121 tests 통과

---

## EAS Build 프로필

| 프로필 | 채널 | 배포 |
|--------|------|------|
| development | - | 개발 클라이언트 |
| preview | preview | 내부 테스트 |
| production | production | Play Store (autoIncrement) |
