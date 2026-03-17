# 마이페이지 종합 점검 및 개선 설계

> 작성일: 2026-03-17
> 검증일: 2026-03-17 (코드 대조 완료)
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

웹 (features/posts/)
├── components/       → EmotionCalendar, EmotionWave (마이페이지에서 사용하나 posts 모듈에 위치)

앱 (features/my/)
├── hooks/            → useActivitySummary, useMyAlias, useEmotionTimeline, useDailyInsights, useCreateDaily, useTodayDaily
├── components/       → ProfileSection, ActivitySummary, DailyInsights, EmotionWaveNative
└── shared/lib/api/   → my.ts (getActivitySummary, getEmotionTimeline, getDailyInsights 등)
```

---

## 2. 발견된 문제 (우선순위별)

> 각 이슈 끝의 `[검증: ✅]`은 실제 코드 대조 완료를 의미

### P0 — 즉시 수정

#### 2.1 [타입] ActivitySummary.streak_days 불일치 [검증: ✅]
- **위치**: `shared/types.ts` line 246
- **문제**: RPC `get_my_activity_summary()`는 `streak`을 반환하지만, 공유 타입은 `streak_days`로 정의. 또한 `first_post_at` 필드는 RPC에 없음
- **영향**: 공유 타입을 import하는 곳에서 타입 에러 또는 런타임 undefined
- **현상**: 웹 `myApi.ts` line 5-10에서 `streak` 필드로 로컬 타입 재정의하여 우회. 앱 `my.ts`도 동일 우회
- **수정**: `shared/types.ts`의 `streak_days` → `streak`으로 변경, `first_post_at` 필드 제거 → sync 후 웹/앱 로컬 타입 제거

#### 2.2 [API 중복] getMyAlias() 이중 정의 [검증: ✅]
- **위치**: 웹 `postsApi.ts` line 321 + `myApi.ts` line 32
- **문제**: 동일 함수가 2곳에 정의. `myApi.ts` 버전이 에러 로깅 포함하여 더 우수
- **수정**: `postsApi.ts`에서 제거, `myApi.ts`만 유지. `postsApi.ts`의 `getMyAlias` import 하는 곳 확인 후 변경

### P1 — 코드 품질 + 안정성

#### 2.3 [에러 처리] BlockedUsersSection unblock 에러 피드백 없음 [검증: ✅]
- **위치**: 웹 `BlockedUsersSection.tsx` line 38-44
- **문제**: `useUnblockUser()` 훅에 `onError`는 있으나 `logger.error`만 수행. 컴포넌트에서 사용자에게 실패를 알리는 toast 등 피드백 없음
- **수정**: 컴포넌트 레벨에서 `toast.error('차단 해제에 실패했어요')` 추가, 또는 훅의 onError에 toast 추가

#### 2.4 [에러 처리] notificationsApi 불일치 [검증: ✅]
- **위치**: 웹 `notificationsApi.ts`
- **문제**: `getNotifications()`은 에러 로깅 + throw, `getUnreadCount()`는 에러 무시하고 silent return 0 (로깅도 없음)
- **수정**: `getUnreadCount()`에 에러 로깅 추가. throw 여부는 호출자(useQuery)가 처리하므로 선택적

#### 2.5 [타입 안전성] ProfileSection todayDaily 캐스팅 [검증: ✅]
- **위치**: 웹 `ProfileSection.tsx` line 28-32
- **문제**: `todayDaily as { emotions?: string[] }` — Post 타입을 import하지 않고 인라인 캐스팅. `useTodayDaily()`가 반환하는 실제 타입과 불일치 가능
- **수정**: `useTodayDaily` 반환 타입을 Post로 명시하거나, `todayDaily?.emotions` 직접 접근 (Post 타입에 emotions 필드가 있는지 확인 필요)

#### 2.6 [스타일] 앱 DailyInsights/EmotionWaveNative — `text-gray-800` [검증: ✅]
- **위치**: 앱 `DailyInsights.tsx` lines 29, 63 / `EmotionWaveNative.tsx` lines 26, 69 (총 4곳)
- **문제**: `text-gray-800`은 프로젝트 색상 팔레트(stone) 기준 벗어남
- **수정**: `text-stone-900`으로 변경

#### 2.7 [성능] todayDaily staleTime: 0 — 웹/앱 모두 [검증: ✅]
- **위치**: 웹 `useTodayDaily.ts` line 9 + **앱 `useTodayDaily.ts` line 9**
- **문제**: 양쪽 모두 `staleTime: 0` → 컴포넌트 마운트 시마다 refetch. ProfileSection + HomeCheckinBanner에서 중복 호출
- **수정**: `staleTime: 60 * 1000` (1분)으로 변경 — **웹과 앱 모두**

#### 2.8 [로딩] 앱 EmotionWaveNative — isLoading 미처리 [검증: ✅]
- **위치**: 앱 `EmotionWaveNative.tsx` line 13
- **문제**: `useEmotionTimeline()`에서 `isLoading` destructure 안 함 → 데이터 로딩 중 빈 상태 placeholder만 표시, 로딩 스켈레톤 없음
- **수정**: `isLoading` 체크 + Skeleton 표시

### P2 — 접근성 + UX

#### 2.9 [접근성] DailyInsights 프로그레스 바 ARIA 누락 — 웹/앱 모두 [검증: ✅]
- **위치**: 웹 `DailyInsights.tsx` line 39 + 앱 `DailyInsights.tsx` line 40
- **문제**: `role="progressbar"`, `aria-valuenow`, `aria-valuemax`, `aria-label` 없음. 웹과 앱 모두 해당
- **수정**: ARIA 속성 추가

#### 2.10 [접근성] EmotionWave 툴팁 ARIA 누락 [검증: ✅]
- **위치**: 웹 `EmotionWave.tsx` line 122-140
- **문제**: 툴팁에 `role="tooltip"` 없음, 키보드 접근 불가
- **수정**: `role="tooltip"` + `aria-describedby` 추가

#### 2.11 [UX] DailyInsights — activity_emotion_map 빈 배열 시 null 반환 [검증: ✅]
- **위치**: 웹 `DailyInsights.tsx` line 50 / 앱 `DailyInsights.tsx` line 55
- **문제**: 7일 이상인데 활동 데이터 없으면 `return null`로 섹션 사라짐
- **수정**: "활동 데이터를 모으는 중이에요" 메시지 표시

#### 2.12 [UX] useEmotionTimeline — enabled 파라미터 없음 — 웹/앱 모두 [검증: ✅]
- **위치**: 웹 `useEmotionTimeline.ts` + 앱 `useEmotionTimeline.ts`
- **문제**: 다른 훅(`useDailyInsights`, `useTodayDaily`)과 달리 `enabled` 파라미터 지원 안 함
- **수정**: `enabled = true` 파라미터 추가 — **웹과 앱 모두**

### P3 — DB/RPC 개선

#### 2.13 [타임존] get_emotion_timeline() UTC 사용 [검증: ✅]
- **위치**: `20260308000001_ux_redesign.sql` line 118
- **문제**: `now() - interval`과 `analyzed_at::DATE`는 UTC 기준. daily post 함수들(`create_daily_post`, `get_today_daily`)은 KST 기준
- **영향**: 자정 전후 1시간 동안 데이터 불일치 가능 (감정 타임라인이 KST 날짜와 어긋남)
- **수정**: `(now() AT TIME ZONE 'Asia/Seoul')` 적용, DATE 캐스팅도 KST 기준으로 변경

#### 2.14 [보안] get_my_activity_summary, get_emotion_timeline — SECURITY DEFINER [검증: ✅]
- **위치**: `20260308000001_ux_redesign.sql` line 115 (get_emotion_timeline), line 129 (get_my_activity_summary)
- **문제**: 사용자 본인 데이터 조회에 불필요한 DEFINER 권한. `auth.uid()` 필터링하므로 INVOKER로 충분
- **참고**: `get_daily_activity_insights()`는 이미 SECURITY INVOKER로 올바르게 설정됨
- **수정**: SECURITY INVOKER로 변경 (RLS가 이미 필터링)

#### 2.15 [API 구조] get_user_emotion_calendar() — 인라인 API 호출 [검증: ✅]
- **위치**: 웹 `EmotionCalendar.tsx` line 10-21 / 앱 `EmotionCalendar.tsx`
- **문제**: RPC 호출이 컴포넌트 파일 내 인라인 함수로 정의. 다른 API 함수들은 `myApi.ts`에 모듈화되어 있어 일관성 없음
- **현상**: 데드 코드 아님 — EmotionCalendar가 실제 호출 중
- **수정**: `myApi.ts`(웹) / `my.ts`(앱)로 추출

#### 2.16 [성능] get_user_emotion_calendar() — created_at::DATE 캐스팅 [검증: ✅]
- **위치**: `20260308000001_ux_redesign.sql` line 104
- **문제**: `p.created_at::DATE = d.day::DATE` — DATE 캐스팅은 인덱스 활용 불가 (함수 적용)
- **영향**: 데이터 증가 시 full scan 발생
- **수정**: 범위 비교로 변경 (`p.created_at >= d.day::TIMESTAMPTZ AND p.created_at < (d.day + 1)::TIMESTAMPTZ`)

---

## 3. 동기화 현황

### 공유 파일 동기화 상태

| 파일 | 중앙 | 웹 | 앱 | 동기화 |
|---|---|---|---|---|
| constants.ts | ✅ | ✅ | ✅ | 정상 |
| types.ts | ❌ streak_days 버그 | ✅ 로컬 우회 | ✅ 로컬 우회 | ⚠️ 중앙 수정 필요 (2.1) |
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
- [ ] `shared/types.ts`: ActivitySummary `streak_days` → `streak`, `first_post_at` 제거 (2.1)
- [ ] sync 실행 → 웹/앱 로컬 타입 우회 코드 제거

#### 웹
- [ ] `postsApi.ts`에서 `getMyAlias()` 제거, import 변경 확인 (2.2)
- [ ] `myApi.ts`: 로컬 ActivitySummary 타입 제거 (중앙 sync 후) (2.1)
- [ ] `ProfileSection.tsx`: todayDaily 타입 안전성 개선 (2.5)
- [ ] `useTodayDaily.ts`: staleTime `0` → `60_000` (2.7)
- [ ] `BlockedUsersSection.tsx`: unblock 에러 toast 추가 (2.3)
- [ ] `notificationsApi.ts`: `getUnreadCount()` 에러 로깅 추가 (2.4)
- [ ] `useEmotionTimeline.ts`: enabled 파라미터 추가 (2.12)

#### 앱
- [ ] `my.ts`: 로컬 ActivitySummary 타입 제거 (중앙 sync 후) (2.1)
- [ ] `DailyInsights.tsx`, `EmotionWaveNative.tsx`: `text-gray-800` → `text-stone-900` (4곳) (2.6)
- [ ] `EmotionWaveNative.tsx`: isLoading 스켈레톤 추가 (2.8)
- [ ] `useTodayDaily.ts`: staleTime `0` → `60_000` (2.7)
- [ ] `useEmotionTimeline.ts`: enabled 파라미터 추가 (2.12)

### Phase 2 — 접근성 + UX (P2)

#### 웹
- [ ] `DailyInsights.tsx`: 프로그레스 바 ARIA 추가 (2.9)
- [ ] `EmotionWave.tsx`: 툴팁 ARIA + 키보드 접근 (2.10)
- [ ] `DailyInsights.tsx`: 빈 activity_emotion_map 시 안내 메시지 표시 (2.11)

#### 앱
- [ ] `DailyInsights.tsx`: 프로그레스 바 ARIA 추가 (2.9)
- [ ] `DailyInsights.tsx`: 빈 배열 시 안내 메시지 추가 (2.11)

### Phase 3 — DB/RPC 개선 (P3)

#### 중앙 (마이그레이션)
- [ ] `get_emotion_timeline()`: KST 타임존 적용 (2.13)
- [ ] `get_my_activity_summary()`, `get_emotion_timeline()`: INVOKER 전환 (2.14)
- [ ] `get_user_emotion_calendar()`: created_at 범위 비교 최적화 (2.16)

#### 웹/앱
- [ ] EmotionCalendar API 함수 → myApi.ts / my.ts 추출 (2.15)

---

## 5. 비변경 사항

- DB 스키마 (테이블/뷰) 변경 없음
- RPC 반환값 변경 없음 (타입 문서만 수정)
- shared/constants.ts 변경 없음
- 네비게이션 구조 변경 없음

---

## 6. 테스트 체크리스트

- [ ] 웹: 마이페이지 전체 렌더링 (프로필 + 활동 + 패턴 + 캘린더 + 타임라인 + 차단)
- [ ] 웹: 차단 해제 동작 확인 + 에러 시 토스트 표시
- [ ] 웹: EmotionWave 호버 툴팁
- [ ] 웹: todayDaily 중복 refetch 감소 확인 (Network 탭)
- [ ] 앱: 마이페이지 전체 렌더링
- [ ] 앱: EmotionWaveNative 로딩 스켈레톤 표시 확인
- [ ] 앱: EmotionWaveNative 탭 인터랙션
- [ ] 앱: TypeScript 빌드 통과
- [ ] 앱: 테스트 14 suites 통과
- [ ] 중앙: sync + verify 통과

---

## 7. 검증 이력

| 날짜 | 검증자 | 결과 |
|---|---|---|
| 2026-03-17 | Claude (코드 대조) | 전체 16개 이슈 ✅ 확인. 기존 2.2 로그아웃 제거 (설계 결정이므로), 2.7/2.9/2.12 범위 확대 (앱 포함), 2.3 설명 정확화 (훅 onError 존재하나 toast 없음), 번호 체계 정리 (결번 제거), 파일 매핑에 EmotionCalendar/EmotionWave 위치 추가 |
