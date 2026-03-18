# 마이페이지 종합 개선 설계

> **작성일**: 2026-03-18
> **상태**: 완료 (2026-03-18)

---

## 1. 서비스 맥락

### 은둔마을에서 마이페이지의 역할

은둔마을은 **익명 감정 커뮤니티**. 사용자는 UUID 기반 익명 계정으로 감정을 기록하고 공유한다.
이 맥락에서 마이페이지는 일반 SNS의 "프로필"이 아니라 **"나만의 감정 기록장"**이다.

- **정체성 없는 프로필**: 이름, 사진, 소개 대신 별칭(조용한 고양이)과 스트릭
- **외부에 보여주는 게 아닌 나를 위한 공간**: 감정 캘린더, 패턴 인사이트, 주간 회고
- **성장 추적**: 스트릭, 마일스톤, 진행률 바 — 게이미피케이션으로 지속 동기부여

### 현재 수치
- 9개 섹션, 11개 고유 RPC 호출 (병렬), 웹+앱 총 ~1,200줄
- 앱/웹 기능 대칭 85%, 문구 일치 95%

---

## 2. 발견된 문제 (심각도순)

### CRITICAL — 서비스 불가
| # | 문제 | 영향 |
|---|------|------|
| C1 | **웹 로그아웃 후 새 익명 세션 미생성** — user 영구 null → 모든 RPC 실패 | 마이페이지 "문제가 발생했습니다" 에러의 유력 원인 |
| C2 | **로그아웃 시 QueryClient 캐시 미정리** — 이전 사용자 데이터 30분(웹)/12시간(앱) 잔존 | 개인 데이터 노출 위험 |

### HIGH — 코드 건강성
| # | 문제 | 영향 |
|---|------|------|
| H1 | signOut 에러 처리 누락 4곳 (웹 2, 앱 2) | 실패 시 사용자에게 피드백 없음 |
| H2 | SectionErrorBoundary에 componentDidCatch 없음 | 에러 발생해도 Sentry에 안 잡힘 |
| H3 | getActivityLabel 동일 함수 2벌 중복 (DailyInsights, WeeklySummary) | 유지보수 부채 |
| H4 | EmotionTrendChart 4개 개별 useQuery — 코드 60줄 반복 | 가독성, useMemo 누락 |
| H5 | 앱 BlockedUsersSection 에러 토스트 중복 (개별 + 전역 MutationCache) | 같은 에러 토스트 2번 표시 |

### MEDIUM — UX/디자인
| # | 문제 | 영향 |
|---|------|------|
| M1 | WeeklySummary 빈 상태 "이번 주" 고정 — weekOffset > 0에서 잘못된 정보 | 사용자 혼란 |
| M2 | 감정 칩 CLAUDE.md 표준 위반 (ProfileSection, WeeklySummary) | 시각적 불일치 |
| M3 | 진행률 바 색상 불일치 — 앱 `bg-happy-400` vs 웹 `bg-yellow-400` | 디자인 토큰 불통일 |
| M4 | 색상 폴백 3가지 혼재 (`#f5f5f4`, `#E7D7FF`, `var(--muted)`) | 일관성 없음 |
| M5 | DailyInsights 인사이트 이모지 💡 — 웹만 있고 앱에 없음 | 앱/웹 문구 불일치 |
| M6 | EmotionTrendChart 범례 중복 제거 O(n²) | 미미한 성능 이슈 |

### LOW — 신규 사용자 경험
| # | 문제 | 영향 |
|---|------|------|
| L1 | EmotionCalendar 데이터 없으면 완전 숨김 (null 반환) — 다른 섹션은 빈 상태 메시지 있음 | 기능 존재를 모름 |
| L2 | 빈 상태에서 CTA(행동 유도) 없음 — "오늘의 하루 기록하기" 버튼 같은 직접 유도 부재 | 전환율 저하 가능 |

---

## 3. 신규 사용자 경험 분석

데이터 0인 사용자가 마이페이지 진입 시:

```
✅ 프로필:    "조용한 고양이, 함께한 지 1일째"
✅ 스트릭:    "✨ 오늘 하루를 나눠보세요" + "총 0일"
✅ 활동:      📝 0  💬 0  💛 0
✅ 주간회고:  "이번 주는 아직 기록이 없어요" + 주 이동 가능
✅ 감정흐름:  회색 바 4개 (최소 높이)
✅ 패턴:      "💡 아직 패턴을 찾고 있어요" + 0/7 진행률 바
❌ 캘린더:    완전 숨김 (사용자는 이 기능의 존재를 모름)
✅ 마을감정:  유령 바 + "아직 이 주의 이야기가 모이고 있어요"
✅ 차단관리:  "차단한 사용자가 없어요"
```

**평가**: 대체로 좋음. NN/G 빈 상태 가이드라인의 3가지 원칙 적용 현황:
1. ✅ 상태 커뮤니케이션 — 대부분 빈 상태 메시지 있음
2. ⚠️ 학습 신호 — DailyInsights 진행률만 (다른 섹션은 부족)
3. ❌ 직접 행동 경로 — CTA 버튼 없음

---

## 4. 네트워크 요청 분석

페이지 로드 시 **11개 고유 RPC** 동시 호출 (모두 병렬, 의존성 없음):

```
┌─ get_my_activity_summary()      ← page.tsx + ProfileSection (캐시 공유)
├─ get_my_alias()                 ← ProfileSection
├─ get_today_daily()              ← ProfileSection
├─ get_my_streak()                ← StreakBadge
├─ get_weekly_emotion_summary(0)  ← WeeklySummary + EmotionTrendChart (캐시 공유)
├─ get_weekly_emotion_summary(1)  ← EmotionTrendChart
├─ get_weekly_emotion_summary(2)  ← EmotionTrendChart
├─ get_weekly_emotion_summary(3)  ← EmotionTrendChart
├─ get_daily_activity_insights()  ← DailyInsights
├─ get_emotion_timeline()         ← EmotionWave
├─ get_user_emotion_calendar()    ← EmotionCalendar
└─ get_blocked_aliases()          ← BlockedUsersSection
```

**판단**: 11개 병렬 요청은 개별적으로는 가벼운 RPC이고, 현대 브라우저의 HTTP/2 멀티플렉싱으로 문제 없음. 다만 EmotionTrendChart의 4개 동일 RPC는 단일 요청으로 통합 가능 (tech-debt).

---

## 5. 설계 원칙

### 원칙 1: 로그아웃 = 완전 초기화
signOut → 캐시 클리어 → 새 익명 세션 → 홈 이동. onAuthStateChange가 중앙에서 처리.

### 원칙 2: 빈 상태 = 성장의 시작
빈 화면이 아닌 "앞으로 채워질 공간"을 보여준다. 격려 메시지 + 진행률.

### 원칙 3: 최소 변경, 최대 효과
Phase 1(인증)이 서비스 안정성에 가장 큰 영향. Phase 2-3은 코드 품질과 일관성.

---

## 6. 변경 사항

### Phase 1: 인증 안정화 (CRITICAL)

**1-1. 웹 useAuth — SIGNED_OUT 처리**
파일: `웹 src/features/auth/hooks/useAuth.ts`
```ts
onAuthStateChange(async (event, session) => {
  if (cancelled) return
  if (event === 'SIGNED_OUT') {
    const { getQueryClient } = await import('@/lib/query-client')
    getQueryClient().clear()
    const newUser = await ensureAnonymousSession()
    if (!cancelled && newUser) setUser(newUser)
    return
  }
  setUser(session?.user ?? null)
})
```

**1-2. 앱 useAuth — SIGNED_OUT 캐시 정리**
파일: `앱 src/features/auth/hooks/useAuth.ts`
```ts
} else if (event === 'SIGNED_OUT') {
  queryClient.clear()
  setUser(null)
}
```

**1-3. 웹 ProfileSection — 에러 처리 + 로딩**
파일: `웹 src/features/my/components/ProfileSection.tsx`
- `signingOut` state 추가, try-catch + `toast.error()`, 버튼 disabled

**1-4. 웹 AdminPage — 에러 처리**
파일: `웹 src/app/admin/page.tsx`
- try-catch + `toast.error()`

**1-5. 앱 my.tsx — 에러 처리**
파일: `앱 src/app/(tabs)/my.tsx`
- async 래핑 + try-catch + Toast

**1-6. 앱 admin/_layout.tsx — 에러 처리**
파일: `앱 src/app/admin/_layout.tsx`
- try-catch + logger.error + 폴백 네비게이션

---

### Phase 2: 코드 품질 (HIGH)

**2-1. SectionErrorBoundary 로깅**
파일: `웹 src/features/my/components/SectionErrorBoundary.tsx`
- `componentDidCatch(error, errorInfo)` 추가 → `logger.error()` (Sentry 연동)

**2-2. getActivityLabel 중앙 추출**
파일: `중앙 shared/utils.ts` → sync → 웹/앱
```ts
export function getActivityLabel(
  id: string,
  presets: readonly { id: string; icon: string; name: string }[]
): string {
  const preset = presets.find((p) => p.id === id)
  return preset ? `${preset.icon} ${preset.name}` : id
}
```
웹/앱 DailyInsights, WeeklySummary에서 로컬 함수 제거 → import 변경

**2-3. EmotionTrendChart useQueries 전환**
파일: 웹/앱 `EmotionTrendChart.tsx`
```ts
const weekQueries = useQueries({
  queries: [3, 2, 1, 0].map(offset => ({
    queryKey: ['weeklySummary', offset],
    queryFn: () => getWeeklyEmotionSummary(offset),
    enabled, staleTime: 30 * 60 * 1000,
    meta: { silent: true },
  })),
})
const weeks = useMemo(() => weekQueries.map(q => q.data).filter(Boolean), [weekQueries])
```

**2-4. EmotionTrendChart useMemo + Set**
같은 파일에서:
- weekData, maxDays를 useMemo로 감싸기
- 범례 reduce O(n²) → `[...new Set(...)]` O(n)

**2-5. 앱 BlockedUsersSection 토스트 중복 제거**
파일: `앱 src/features/my/components/BlockedUsersSection.tsx`
- handleUnblock의 onError에서 `Toast.show` 제거 (전역 MutationCache가 담당)
- 미사용 `Toast` import 제거

---

### Phase 3: 디자인 통일 (MEDIUM)

**3-1. WeeklySummary 빈 상태 문구 수정**
파일: 웹/앱 `WeeklySummary.tsx`
```tsx
// 변경 전: "이번 주는 아직 기록이 없어요"
// 변경 후:
<p>{weekLabel}에는 기록이 없어요</p>
```

**3-2. EMOTION_FALLBACK_COLOR 통일**
파일: `중앙 shared/constants.ts` → sync
```ts
export const EMOTION_FALLBACK_COLOR = '#E7D7FF'
```
웹/앱 컴포넌트에서 `#f5f5f4`, `var(--muted)` 등을 `EMOTION_FALLBACK_COLOR`로 교체

**3-3. 진행률 바 색상 통일**
파일: `웹 DailyInsights.tsx`
- `bg-yellow-400` → `bg-happy-400`

**3-4. DailyInsights 이모지 통일**
파일: `앱 DailyInsights.tsx`
- 인사이트 문구 앞에 💡 추가 (웹과 동일)

**3-5. 감정 칩 CLAUDE.md 표준 적용**
파일: `웹 ProfileSection.tsx`
- 오늘 감정 칩: `px-2 py-0.5 text-[10px]` → `px-3 py-1.5 text-xs`

---

## 7. tech-debt 이관 (이번 범위 외)

| 항목 | 이유 |
|------|------|
| EmotionTrendChart 4주 단일 RPC | DB 마이그레이션 필요, 현재 캐시 공유로 충분 |
| ProfileSection → Dumb 컴포넌트 | 현재 잘 동작하고, activitySummary 캐시 공유로 중복 호출 비용 없음 |
| EmotionCalendar 빈 상태 메시지 | 현재 9개 중 8개가 표시되어 심각하지 않음 |
| StreakBadge/EmotionTrendChart 스켈레톤 | 데이터 로드가 빠르고 SectionErrorBoundary가 방어 |
| 빈 상태 CTA 버튼 | 기획 결정 필요 (서비스 방향에 따라) |

---

## 8. 사이드이펙트 체크

- [x] **삭제 연쇄**: queryClient.clear()는 진행 중 mutation 미취소 (안전)
- [x] **동기화**: shared/ 변경 2건 (utils.ts + constants.ts) → `bash scripts/db.sh push` 또는 `bash scripts/sync-to-projects.sh`
- [x] **에러**: ensureAnonymousSession 3회 재시도 → 최종 실패 시 user null (현재와 동일)
- [x] **캐시**: clear() 후 컴포넌트 마운트 시 자동 refetch
- [x] **호환성**: useQueries queryKey 유지 → WeeklySummary 캐시 공유 유지
- [ ] **AsyncStorage**: queryClient.clear()가 앱 persister도 초기화하는지 런타임 확인 필요

---

## 9. 변경 파일 요약

| Phase | 중앙 | 웹 | 앱 |
|-------|------|----|----|
| 1 (인증) | — | useAuth, ProfileSection, admin/page | useAuth, my.tsx, admin/_layout |
| 2 (품질) | shared/utils.ts | SectionErrorBoundary, DailyInsights, WeeklySummary, EmotionTrendChart | DailyInsights, WeeklySummary, EmotionTrendChart, BlockedUsersSection |
| 3 (디자인) | shared/constants.ts | DailyInsights, ProfileSection, WeeklySummary | DailyInsights, WeeklySummary |
| **합계** | **2파일** | **8파일** | **7파일** |
