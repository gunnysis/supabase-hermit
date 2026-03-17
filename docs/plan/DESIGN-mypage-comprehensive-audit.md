# 마이페이지 종합 점검 및 개선 설계

> 작성일: 2026-03-17
> 범위: 중앙/웹/앱 3개 레포의 마이페이지 관련 전체 기술 스택

---

## 1. 현재 아키텍처 요약

### 마이페이지 구성 요소

| 섹션 | 웹 | 앱 | RPC | 상태 |
|---|---|---|---|---|
| 프로필 히어로 | ProfileSection | ProfileSection | get_my_alias, get_my_activity_summary, get_today_daily | ✅ 양쪽 구현 |
| 활동 요약 | page.tsx 인라인 | ActivitySummary | get_my_activity_summary | ✅ 양쪽 구현 |
| 나의 패턴 | DailyInsights | DailyInsights | get_daily_activity_insights | ✅ 양쪽 구현 |
| 감정 캘린더 | EmotionCalendar | EmotionCalendar | get_user_emotion_calendar | ✅ 양쪽 구현 |
| 감정 타임라인 | EmotionWave | EmotionWaveNative | get_emotion_timeline | ✅ 양쪽 구현 |
| 차단 관리 | BlockedUsersSection | **없음** | block_user, unblock_user, get_blocked_aliases | ❌ 앱 미구현 |
| 로그아웃 | ProfileSection 내 | **없음** | — | ❌ 앱 미구현 |
| 설정 섹션 | 있음 (헤더 + 차단) | **없음** | — | ❌ 앱 미구현 |

### 파일 매핑

```
중앙 (shared/)
├── utils.ts          → processEmotionTimeline() [웹/앱 공유]
├── types.ts          → ActivitySummary, EmotionTimelineEntry, EmotionCalendarDay 등
└── constants.ts      → ACTIVITY_PRESETS, DAILY_INSIGHTS_CONFIG, EMOTION_COLOR_MAP

웹 (features/my/)
├── api/myApi.ts      → getActivitySummary, getEmotionTimeline, getMyAlias
├── hooks/            → useActivitySummary, useMyAlias, useEmotionTimeline, useDailyInsights, useCreateDaily, useTodayDaily
└── components/       → ProfileSection, DailyInsights, BlockedUsersSection

앱 (features/my/)
├── hooks/            → useActivitySummary, useMyAlias, useEmotionTimeline, useDailyInsights, useCreateDaily, useTodayDaily
├── components/       → ProfileSection, ActivitySummary, DailyInsights, EmotionWaveNative
└── shared/lib/api/   → my.ts (getActivitySummary, getEmotionTimeline, getDailyInsights 등)
```

---

## 2. 발견된 문제 (우선순위별)

### P0 — 즉시 수정

#### 2.1 [타입] ActivitySummary.streak_days 불일치
- **위치**: `shared/types.ts` line 246
- **문제**: RPC는 `streak`을 반환하지만, 공유 타입은 `streak_days`로 정의
- **영향**: 공유 타입을 import하는 곳에서 타입 에러 또는 런타임 undefined
- **현상**: 웹/앱 모두 로컬 타입을 별도 정의하여 우회 중 (myApi.ts, my.ts)
- **수정**: `shared/types.ts`의 `streak_days` → `streak`으로 변경, `first_post_at` 필드 제거 (RPC에 없음)

#### 2.2 [기능 누락] 앱 — 로그아웃 버튼 없음
- **위치**: 앱 `ProfileSection.tsx`
- **문제**: 웹에는 로그아웃 있으나 앱 마이페이지에 없음
- **영향**: 사용자가 로그아웃 불가 (관리자 메뉴에만 존재)
- **수정**: 앱 ProfileSection에 로그아웃 버튼 추가

#### 2.3 [기능 누락] 앱 — 차단 관리 UI 없음
- **위치**: 앱 `my.tsx`
- **문제**: 차단 API/훅은 존재하나 UI 컴포넌트 없음
- **영향**: 차단한 사용자 확인/해제 불가
- **수정**: `BlockedUsersSection` 컴포넌트 + `useUnblockUser` 훅 생성

#### 2.4 [API 중복] getMyAlias() 이중 정의
- **위치**: 웹 `postsApi.ts` line 321 + `myApi.ts` line 32
- **문제**: 동일 함수가 2곳에 정의
- **수정**: `postsApi.ts`에서 제거, `myApi.ts`만 유지

### P1 — 코드 품질 + 안정성

#### 2.5 [에러 처리] BlockedUsersSection unblock 에러 무시
- **위치**: 웹 `BlockedUsersSection.tsx` line 41
- **문제**: `unblock(alias)` 호출 시 onError 콜백 없음
- **수정**: toast.error 추가

#### 2.6 [에러 처리] notificationsApi 불일치
- **위치**: 웹 `notificationsApi.ts`
- **문제**: `getNotifications()`은 throw, `getUnreadCount()`는 silent return 0
- **수정**: 에러 로깅 패턴 통일 (message + code)

#### 2.7 [타입 안전성] ProfileSection todayDaily 캐스팅
- **위치**: 웹 `ProfileSection.tsx` line 28
- **문제**: `todayDaily as { emotions?: string[] }` 불안전한 캐스팅
- **수정**: Post 타입 사용 또는 null 체크 강화

#### 2.8 [스타일] 앱 DailyInsights/EmotionWaveNative — `text-gray-800`
- **위치**: 앱 `DailyInsights.tsx` lines 29, 63 / `EmotionWaveNative.tsx` lines 26, 69
- **문제**: `text-gray-800`은 프로젝트 색상 팔레트(stone) 기준 벗어남
- **수정**: `text-stone-900`으로 변경

#### 2.9 [성능] todayDaily staleTime: 0
- **위치**: 웹 `useTodayDaily.ts` line 9
- **문제**: 항상 refetch → ProfileSection + HomeCheckinBanner에서 중복 호출
- **수정**: `staleTime: 60 * 1000` (1분)으로 변경

#### 2.10 [로딩] 앱 EmotionWaveNative — isLoading 미처리
- **위치**: 앱 `EmotionWaveNative.tsx` line 13
- **문제**: `isLoading` destructure 안 함 → 빈 상태만 표시, 로딩 스켈레톤 없음
- **수정**: isLoading 체크 + Skeleton 표시

### P2 — 접근성 + UX

#### 2.11 [접근성] DailyInsights 프로그레스 바 ARIA 누락
- **위치**: 웹 `DailyInsights.tsx` line 39
- **문제**: `role="progressbar"`, `aria-valuenow`, `aria-valuemax` 없음
- **수정**: ARIA 속성 추가

#### 2.12 [접근성] EmotionWave 툴팁 ARIA 누락
- **위치**: 웹 `EmotionWave.tsx` line 123
- **문제**: 툴팁에 `role="tooltip"` 없음, 키보드 접근 불가
- **수정**: `role="tooltip"` + `aria-describedby` 추가

#### 2.13 [UX] DailyInsights — activity_emotion_map 빈 배열 시 null 반환
- **위치**: 웹/앱 `DailyInsights.tsx`
- **문제**: 7일 이상인데 활동 데이터 없으면 섹션 사라짐
- **수정**: "활동 데이터를 모으는 중이에요" 메시지 표시

#### 2.14 [UX] useEmotionTimeline — enabled 파라미터 없음
- **위치**: 웹 `useEmotionTimeline.ts`
- **문제**: 다른 훅과 달리 enabled 지원 안 함
- **수정**: `enabled = true` 파라미터 추가

### P3 — DB/RPC 개선

#### 2.15 [타임존] get_emotion_timeline() UTC 사용
- **위치**: `20260308000001_ux_redesign.sql` line 120
- **문제**: `now() - interval`은 UTC 기준, daily post 함수들은 KST 기준
- **영향**: 자정 전후 1시간 동안 데이터 불일치 가능
- **수정**: `(now() AT TIME ZONE 'Asia/Seoul')` 적용

#### 2.16 [보안] get_my_activity_summary, get_emotion_timeline — SECURITY DEFINER
- **위치**: `20260308000001_ux_redesign.sql`
- **문제**: 사용자 데이터 조회에 불필요한 DEFINER 권한
- **수정**: SECURITY INVOKER로 변경 (RLS가 이미 필터링)

#### 2.17 [미사용] get_user_emotion_calendar() — 웹/앱 모두 인라인 API 사용
- **위치**: EmotionCalendar.tsx (웹/앱 모두)
- **문제**: RPC는 존재하나 컴포넌트에서 직접 supabase 호출
- **현상**: 데드 코드는 아님 (EmotionCalendar가 호출함), 다만 API 모듈 미추출
- **수정**: myApi.ts로 추출

#### 2.18 [성능] get_user_emotion_calendar() — created_at::DATE 캐스팅
- **위치**: `20260308000001_ux_redesign.sql` line 103
- **문제**: `p.created_at::DATE = d.day::DATE` — 인덱스 활용 불가
- **영향**: 데이터 많아지면 성능 저하
- **수정**: 범위 비교로 변경 (`p.created_at >= d.day AND p.created_at < d.day + 1`)

---

## 3. 동기화 현황

### 공유 파일 동기화 상태

| 파일 | 중앙 | 웹 | 앱 | 동기화 |
|---|---|---|---|---|
| constants.ts | ✅ | ✅ | ✅ | 정상 |
| types.ts | ❌ streak_days 버그 | ✅ 로컬 우회 | ✅ 로컬 우회 | ⚠️ 중앙 수정 필요 |
| utils.ts (processEmotionTimeline) | ✅ | ✅ | ✅ | 정상 |

### 캐시 키 일치 확인

| 기능 | 웹 캐시 키 | 앱 캐시 키 | 일치 |
|---|---|---|---|
| 활동 요약 | `['activitySummary']` | `['activitySummary']` | ✅ |
| 나의 별칭 | `['myAlias']` | `['myAlias']` | ✅ |
| 오늘의 하루 | `['todayDaily']` | `['todayDaily']` | ✅ |
| 감정 타임라인 | `['emotionTimeline', days]` | `['emotionTimeline', days]` | ✅ |
| 나의 패턴 | `['dailyInsights', days]` | `['dailyInsights', days]` | ✅ |
| 감정 캘린더 | `['emotionCalendar', userId, days]` | `['emotionCalendar', userId, days]` | ✅ |
| 차단 목록 | `['blockedAliases']` | `['blockedAliases']` | ✅ |
| 미읽음 알림 | `['unreadNotificationCount']` | `['unreadNotificationCount']` | ✅ |

### 캐시 무효화 매트릭스

| 이벤트 | 무효화 대상 | 웹 | 앱 |
|---|---|---|---|
| daily post 생성 | todayDaily, boardPosts, activitySummary, dailyInsights | ✅ | ✅ |
| daily post 수정 | todayDaily, boardPosts, activitySummary, dailyInsights | ✅ | ✅ |
| 차단 | blockedAliases, boardPosts | ✅ | ✅ |
| 차단 해제 | blockedAliases, boardPosts | ✅ | ❌ 훅 미존재 |
| 알림 읽음 | notifications, unreadNotificationCount | ✅ | ✅ |

---

## 4. 구현 계획

### Phase 1 — 즉시 수정 (P0 + P1)

#### 중앙
- [ ] `shared/types.ts`: ActivitySummary `streak_days` → `streak`, `first_post_at` 제거
- [ ] sync 실행

#### 웹
- [ ] `postsApi.ts`에서 `getMyAlias()` 제거 (myApi.ts에만 유지)
- [ ] `ProfileSection.tsx`: todayDaily 타입 안전성 개선
- [ ] `useTodayDaily.ts`: staleTime `0` → `60_000`
- [ ] `BlockedUsersSection.tsx`: unblock 에러 토스트 추가
- [ ] `notificationsApi.ts`: 에러 로깅 통일
- [ ] `useEmotionTimeline.ts`: enabled 파라미터 추가

#### 앱
- [ ] `ProfileSection.tsx`: 로그아웃 버튼 추가
- [ ] `BlockedUsersSection.tsx`: 신규 컴포넌트 생성
- [ ] `useBlocks.ts`: `useUnblockUser()` 훅 추가
- [ ] `my.tsx`: 설정 섹션 + BlockedUsersSection 추가
- [ ] `DailyInsights.tsx`, `EmotionWaveNative.tsx`: `text-gray-800` → `text-stone-900`
- [ ] `EmotionWaveNative.tsx`: isLoading 스켈레톤 추가

### Phase 2 — 접근성 + UX (P2)

#### 웹
- [ ] `DailyInsights.tsx`: 프로그레스 바 ARIA 추가
- [ ] `EmotionWave.tsx`: 툴팁 ARIA + 키보드 접근
- [ ] `DailyInsights.tsx`: 빈 activity_emotion_map 메시지 표시

#### 앱
- [ ] `DailyInsights.tsx`: 빈 배열 메시지 추가

### Phase 3 — DB/RPC 개선 (P3)

#### 중앙 (마이그레이션)
- [ ] `get_emotion_timeline()`: KST 타임존 적용
- [ ] `get_my_activity_summary()`, `get_emotion_timeline()`: INVOKER 전환
- [ ] `get_user_emotion_calendar()`: created_at 범위 비교 최적화

#### 웹/앱
- [ ] EmotionCalendar API 함수 → myApi.ts 추출

---

## 5. 비변경 사항

- DB 스키마 (테이블/뷰) 변경 없음
- RPC 반환값 변경 없음 (타입 문서만 수정)
- shared/constants.ts 변경 없음
- 네비게이션 구조 변경 없음

---

## 6. 테스트 체크리스트

- [ ] 웹: 마이페이지 전체 렌더링 (프로필 + 활동 + 패턴 + 캘린더 + 타임라인 + 차단)
- [ ] 웹: 로그아웃 후 리다이렉트
- [ ] 웹: 차단 해제 동작 확인
- [ ] 웹: EmotionWave 호버 툴팁
- [ ] 앱: 마이페이지 전체 렌더링
- [ ] 앱: 로그아웃 동작
- [ ] 앱: 차단 관리 (목록 + 해제)
- [ ] 앱: EmotionWaveNative 탭 인터랙션
- [ ] 앱: TypeScript 빌드 통과
- [ ] 앱: 테스트 14 suites 통과
- [ ] 중앙: sync + verify 통과
