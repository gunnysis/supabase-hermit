# 웹 레포 (web-hermit-comm) 분석 스냅샷

> **최종 갱신**: 2026-03-18 | **Next.js 16.1.6** | **React 19.2.3** | **파일**: 119개

## 통계 요약

| 항목 | 수량 |
|------|------|
| .ts/.tsx 파일 | 119 |
| 총 코드 라인 | ~8,700 |
| API 함수 | 50+ |
| 커스텀 훅 | 18 |
| 컴포넌트 | 68 (.tsx) |
| 페이지 라우트 | 12 |
| 테스트 파일 | 3 |
| `as any` | 0 |
| TODO/FIXME | 0 |
| @ts-ignore | 0 |

---

## 디렉토리 구조

```
src/
├── app/                  # Next.js App Router (12 routes)
├── components/           # 공유 UI (layout 5, providers 2, ui 20)
├── features/             # 도메인별 모듈 (8개)
├── lib/                  # 유틸리티 (13 파일)
├── types/                # 타입 정의 (4 파일)
└── utils/                # Supabase 클라이언트 (2 파일)
```

---

## 페이지 라우트

| 라우트 | 파일 | 타입 |
|--------|------|------|
| `/` | page.tsx | 홈/피드 |
| `/admin` | admin/page.tsx | 관리자 대시보드 |
| `/admin/login` | admin/login/page.tsx | 관리자 로그인 |
| `/create` | create/page.tsx | 글쓰기/오늘의하루 |
| `/my` | my/page.tsx | 내 프로필 |
| `/notifications` | notifications/page.tsx | 알림 |
| `/post/[id]` | post/[id]/page.tsx | 게시글 상세 |
| `/post/[id]/edit` | post/[id]/edit/page.tsx | 게시글 수정 |
| `/search` | search/page.tsx | 검색 |
| `/feed.xml` | feed.xml/route.ts | RSS |
| `/robots.txt` | robots.txt/route.ts | SEO |
| `/sitemap.xml` | sitemap.xml/route.ts | SEO |

---

## Feature 모듈 (8개)

### admin/
- **API**: checkAppAdmin(userId)
- **훅**: useIsAdmin(userId)

### auth/
- **AuthProvider.tsx**: 컨텍스트 + 세션 관리
- **auth.ts**: signInAnonymously, signOut
- **훅**: useAuth() — 자동 익명 로그인, onAuthStateChange

### blocks/
- **API**: blockUser(alias), unblockUser(alias), getBlockedAliases()
- **훅**: useBlockedAliases(), useBlockUser()

### comments/
- **API**: getComments, createComment, updateComment, deleteComment
- **컴포넌트**: CommentForm, CommentItem, CommentSection
- **훅**: useComments(postId) — Realtime + 낙관적 업데이트

### my/
- **API**: getActivitySummary, getEmotionTimeline, getUserEmotionCalendar, getMyAlias
- **컴포넌트**: ProfileSection, StreakBadge, WeeklySummary, EmotionTrendChart, DailyInsights, BlockedUsersSection, SectionErrorBoundary
- **훅**: useActivitySummary, useMyAlias, useCreateDaily(), useUpdateDaily(), useDailyInsights(), useTodayDaily(), useEmotionTimeline

### notifications/
- **API**: getNotifications, getUnreadCount, markNotificationsRead, markAllRead
- **훅**: useUnreadCount(), useNotifications(), useMarkRead(), useMarkAllRead()

### posts/ (가장 큰 모듈 — 23 컴포넌트, 6 훅, 3 API)
- **API**: postsApi.ts (20함수), postsApi.server.ts (6함수), uploadImage.ts
- **컴포넌트**: PostCard, DailyPostCard, PostDetailView, CreatePostForm, DailyPostForm, EditPostForm, SearchView, PublicFeed, EmotionCalendar, EmotionTrend, EmotionWave, CommunityPulse, EmotionFilterBar, EmotionTags, GreetingBanner, HomeCheckinBanner, MoodSelector, PostCardSkeleton, PostContent, RecommendedPosts, SameMoodDailies, TrendingPosts, YesterdayReactionBanner, ActivityTagSelector, RichEditor
- **훅**: useBoardPosts, usePostDetail, usePostAnalysis, useEmotionTrend, useRecommendedPosts, useTrendingPosts

### reactions/
- **API**: getPostReactions, toggleReaction
- **컴포넌트**: ReactionBar
- **훅**: useReactions(postId, userId) — Realtime + 낙관적 업데이트

---

## 핵심 의존성

| 패키지 | 버전 | 용도 |
|--------|------|------|
| next | 16.1.6 | 프레임워크 |
| react | 19.2.3 | UI |
| @supabase/supabase-js | ^2.98.0 | DB |
| @supabase/ssr | ^0.9.0 | SSR 클라이언트 |
| @tanstack/react-query | ^5.90.21 | 상태관리 |
| tailwindcss | ^4 | 스타일 |
| @sentry/nextjs | ^10.42.0 | 모니터링 |
| react-hook-form | ^7.71.2 | 폼 |
| zod | ^4.3.6 | 검증 |
| @tiptap/react | ^3.20.0 | 리치 에디터 |
| date-fns | ^4.1.0 | 날짜 |
| vitest | ^4.0.18 | 테스트 |
| typescript | ~5.9.0 | 타입 |

---

## Supabase 클라이언트 패턴

```typescript
// src/utils/supabase/client.ts
import { createBrowserClient } from '@supabase/ssr'
import type { Database } from '@/types/database.gen'

export function createClient() {
  return createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!.trim(),
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!.trim(),
  )
}
```
- 호출 시마다 새 인스턴스 생성 (Supabase SSR 권장 패턴)
- `Database` 제네릭으로 타입 안전

---

## Realtime 구독 (3개 훅)

| 훅 | 채널 | 대상 |
|----|------|------|
| useComments | comments | INSERT/UPDATE/DELETE |
| useReactions | reactions + user_reactions | INSERT/UPDATE |
| usePostAnalysis | post_analysis | UPDATE |

모두 useEffect cleanup으로 `supabase.removeChannel()` 호출.

---

## 자동 동기화 파일 (중앙에서 생성)

| 파일 | 소스 |
|------|------|
| src/lib/constants.generated.ts | shared/constants.ts |
| src/lib/utils.generated.ts | shared/utils.ts |
| src/types/database.types.ts | shared/types.ts |
| src/types/database.gen.ts | types/database.gen.ts |
| supabase/migrations/*.sql | supabase/migrations/ |
| supabase/config.toml | supabase/config.toml |

---

## 테스트

| 파일 | 유형 |
|------|------|
| src/lib/__tests__/constants.test.ts | 단위 |
| src/lib/__tests__/schemas.test.ts | 단위 |
| src/types/__tests__/database.test.ts | 타입 |

테스트 러너: Vitest 4.0.18
