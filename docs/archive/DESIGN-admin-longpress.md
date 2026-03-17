# 관리자 접근 UX 재설계 — 설정 탭 제거 + 롱프레스 히든 도어

> 작성일: 2026-03-07
> 대상: 앱(React Native/Expo SDK 54) + 웹(Next.js)
> 상태: 설계 완료 — 구현 대기

---

## 1. Context

### 1.1 현재 상태

**앱 (5탭 구조)**:
```
[홈] [그룹] [검색] [글쓰기(숨김)] [설정]
```

설정 탭(`settings.tsx`)의 전체 기능:
- 앱 버전 표시
- 관리자 페이지 버튼 (관리자만 노출, `useIsAdmin()`)

**문제**:
- 설정 탭이 사실상 관리자 전용 진입점. 일반 사용자에게는 앱 버전만 보이는 빈 화면
- 5번째 탭을 설정에 할당하는 것은 공간 낭비
- 관리자가 극소수(1~2명)인 커뮤니티에서 전용 탭이 불필요
- 탭 하나를 비우면 향후 마이페이지, 영상 등 신규 기능에 할당 가능

**웹**:
- `/admin`, `/admin/login` 라우트가 URL로 직접 접근 가능
- 하단 네비게이션에 관리자 링크 없음 (이미 히든 상태)
- 별도 수정 최소화 가능

### 1.2 목표

- 설정 탭 **제거** → 4탭 구조 (홈/그룹/검색/글쓰기(숨김))로 전환
- 관리자 접근을 **롱프레스 히든 도어** 패턴으로 전환
- 앱 버전 정보는 마이페이지(향후) 또는 적절한 위치로 이전
- 보안 수준 유지 — 롱프레스는 UI 진입점일 뿐, 실제 인증은 기존 로직 유지

---

## 2. 핵심 설계 결정

| 항목 | 결정 | 이유 |
|------|------|------|
| 롱프레스 트리거 위치 | 홈 ScreenHeader의 앱 로고/타이틀 ("은둔마을") | 모든 화면에서 접근 가능, 자연스러운 위치, 기존 레이아웃 변경 없음 |
| 롱프레스 시간 | 800ms | Android 기본 롱프레스(500ms)보다 길어 오탐 방지, 3초 이상은 불편 |
| 피드백 | 햅틱(medium impact) + 미세 스케일 애니메이션 | 트리거 인지 + 비관리자에게 힌트 미노출 |
| 인증 흐름 | 롱프레스 → 관리자 체크 → 관리자면 `/admin`으로 이동 / 아니면 무반응 | 비관리자에게는 아무 일도 일어나지 않음 |
| 웹 트리거 | Header 로고 더블클릭 (5회 연속 탭) | 웹에서 롱프레스 UX가 자연스럽지 않음, Android 개발자 옵션 패턴 차용 |
| 앱 버전 정보 | 관리자 페이지 하단에 표시 | 일반 사용자에게 앱 버전은 불필요한 정보 |
| 설정 탭 슬롯 활용 | 마이페이지 또는 빈 상태 유지 | 향후 마이페이지/영상 탭으로 전환 가능 |


본 설계는 **Instagram 롱프레스 + Android 반복 탭**의 하이브리드:
- 앱: 로고 롱프레스 (간단, 1회 동작)
- 웹: 로고 영역 5회 연속 탭 (웹에서 롱프레스 대체)

---

## 4. 앱 구현 설계

### 4.1 탭 구조 변경

**변경 전 (5탭)**:
```
[홈] [그룹] [검색] [글쓰기(숨김)] [설정]
```

**변경 후 (4탭 + 글쓰기 숨김)**:
```
[홈] [그룹] [검색] [글쓰기(숨김)]
```

**파일 변경**:
- `src/app/(tabs)/_layout.tsx` — 설정 탭 제거
- `src/app/(tabs)/settings.tsx` — 삭제
- `src/app/settings/index.tsx` — 삭제

### 4.2 롱프레스 트리거 구현

**트리거 위치**: `ScreenHeader` 컴포넌트의 앱 타이틀 ("은둔마을")

```
+--------------------------------------------------+
| [은둔마을]           [검색 아이콘] [정렬 아이콘]      |
|  ^^^^^^^^^                                        |
|  롱프레스 800ms → 관리자 진입                        |
+--------------------------------------------------+
```

**기술 스택**:
- `react-native-gesture-handler`의 `LongPressGestureHandler` — Expo SDK 54에 기본 포함
- `expo-haptics` — 햅틱 피드백 (Expo SDK 54 기본 포함)
- `react-native-reanimated` — 미세 애니메이션 (기존 사용 중)

**컴포넌트 설계**:

```tsx
// src/components/AdminLongPress.tsx
import { Gesture, GestureDetector } from 'react-native-gesture-handler'
import * as Haptics from 'expo-haptics'
import Animated, { useSharedValue, useAnimatedStyle, withSequence, withTiming } from 'react-native-reanimated'
import { useIsAdmin } from '@/features/admin/hooks/useIsAdmin'
import { router } from 'expo-router'

interface Props {
  children: React.ReactNode
}

export function AdminLongPress({ children }: Props) {
  const { data: isAdmin } = useIsAdmin()
  const scale = useSharedValue(1)

  const longPress = Gesture.LongPress()
    .minDuration(800)
    .onStart(() => {
      // 햅틱 피드백 (관리자 여부 무관 — 관리자인지 힌트를 주지 않기 위해)
      // 아래 runOnJS 호출 필요
    })
    .onFinalize((_event, success) => {
      if (success) {
        handleLongPress()
      }
    })

  const handleLongPress = () => {
    // 미세 스케일 애니메이션 (누른 느낌)
    scale.value = withSequence(
      withTiming(0.95, { duration: 80 }),
      withTiming(1, { duration: 120 })
    )

    if (isAdmin) {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium)
      router.push('/admin')
    }
    // 비관리자: 아무 일도 안 일어남 (햅틱도 없음 — 힌트 차단)
  }

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }))

  return (
    <GestureDetector gesture={longPress}>
      <Animated.View style={animatedStyle}>
        {children}
      </Animated.View>
    </GestureDetector>
  )
}
```

**ScreenHeader 적용**:

```tsx
// src/components/ScreenHeader.tsx (수정)
import { AdminLongPress } from './AdminLongPress'

export function ScreenHeader({ title, ... }) {
  return (
    <View style={styles.header}>
      <AdminLongPress>
        <Text style={styles.title}>{title}</Text>
      </AdminLongPress>
      {/* 검색, 정렬 아이콘 등 기존 코드 유지 */}
    </View>
  )
}
```

### 4.3 롱프레스 인터랙션 흐름

```
사용자가 "은둔마을" 타이틀을 800ms 이상 누름
    |
    +-- useIsAdmin() 캐시 확인 (React Query, 60초 staleTime)
    |
    +-- [관리자인 경우]
    |     +-- 햅틱 피드백 (Medium Impact)
    |     +-- 스케일 바운스 애니메이션 (0.95 → 1.0)
    |     +-- router.push('/admin')
    |     +-- 기존 관리자 인증 흐름 유지 (admin/_layout.tsx 보호)
    |
    +-- [비관리자인 경우]
          +-- 아무 반응 없음 (햅틱 없음, 애니메이션 없음)
          +-- 히든 도어의 존재를 알 수 없음
```

### 4.4 보안 레이어 (기존 유지)

롱프레스는 **UI 진입점**일 뿐, 보안은 기존 3중 레이어 유지:

```
Layer 1: useIsAdmin() — 클라이언트 권한 체크 (UI 게이팅)
Layer 2: admin/_layout.tsx — 라우트 보호 (미인증→로그인, 비관리자→리다이렉트)
Layer 3: RLS 정책 — DB 레벨 (app_admin 테이블 기반, 서버 사이드 강제)
```

비관리자가 URL로 `/admin` 직접 접근해도 Layer 2에서 차단됨 (기존 로직 변경 없음).

### 4.5 접근성 고려

| 요소 | 처리 |
|------|------|
| 스크린 리더 | `accessibilityHint` 미설정 (히든 도어 의도적 은닉) |
| 일반 탭 | 기존 타이틀 탭 동작 유지 (있다면). 롱프레스만 히든 트리거 |
| 모터 장애 | 800ms 롱프레스가 어려울 수 있음 → 관리자는 극소수이므로 허용 범위 |

---

## 5. 웹 구현 설계

### 5.1 시크릿 탭 패턴 (5회 연속 클릭)

웹에서 롱프레스는 우클릭 메뉴와 충돌하고 UX가 부자연스러움. 대신 **로고 영역 5회 연속 클릭** 패턴 채택 (Android 개발자 옵션과 동일 UX).

**트리거 위치**: `Header` 컴포넌트의 "은둔마을" 로고 텍스트

```
+--------------------------------------------------+
| [은둔마을]                    [검색] [그룹] [글쓰기] |
|  ^^^^^^^^^                                        |
|  3초 내 5회 클릭 → 관리자 진입                       |
+--------------------------------------------------+
```

### 5.2 컴포넌트 설계

```tsx
// src/components/layout/AdminSecretTap.tsx
'use client'

import { useRef, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { useIsAdmin } from '@/features/admin/hooks/useIsAdmin'

const TAP_COUNT = 5
const TAP_WINDOW_MS = 3000

interface Props {
  children: React.ReactNode
}

export function AdminSecretTap({ children }: Props) {
  const router = useRouter()
  const { data: isAdmin } = useIsAdmin()
  const tapsRef = useRef<number[]>([])

  const handleClick = useCallback(() => {
    const now = Date.now()

    // 윈도우 밖의 오래된 탭 제거
    tapsRef.current = tapsRef.current.filter(t => now - t < TAP_WINDOW_MS)
    tapsRef.current.push(now)

    if (tapsRef.current.length >= TAP_COUNT) {
      tapsRef.current = []
      if (isAdmin) {
        router.push('/admin')
      }
      // 비관리자: 아무 반응 없음
    }
  }, [isAdmin, router])

  return (
    <span
      onClick={handleClick}
      role="banner"
      style={{ cursor: 'pointer', userSelect: 'none' }}
    >
      {children}
    </span>
  )
}
```

### 5.3 Header 적용

```tsx
// src/components/layout/Header.tsx (수정)
import { AdminSecretTap } from './AdminSecretTap'

export function Header() {
  return (
    <header>
      <AdminSecretTap>
        <span className="text-xl font-bold">은둔마을</span>
      </AdminSecretTap>
      {/* 나머지 네비게이션 유지 */}
    </header>
  )
}
```

### 5.4 인터랙션 흐름

```
사용자가 "은둔마을" 로고를 3초 내 5회 클릭
    |
    +-- 탭 카운터 확인 (useRef, 리렌더 없음)
    |
    +-- [5회 도달 + 관리자]
    |     +-- router.push('/admin')
    |     +-- 기존 관리자 인증 흐름 유지
    |
    +-- [5회 도달 + 비관리자]
    |     +-- 아무 반응 없음
    |
    +-- [5회 미도달]
          +-- 카운터 누적 (3초 윈도우)
```

### 5.5 기존 `/admin` 라우트 보호 (변경 없음)

웹의 `/admin/page.tsx`는 이미 `useIsAdmin()` 훅으로 보호:
- 비관리자 → `/admin/login`으로 리다이렉트
- 비인증 → 홈으로 리다이렉트

URL 직접 입력 시에도 기존 보호 로직이 동작하므로 추가 보안 조치 불필요.

---

## 6. 설정 탭 기능 이전

### 6.1 앱 버전 정보

**현재 위치**: `settings/index.tsx` (설정 탭 화면)
**이전 위치**: 관리자 페이지(`/admin`) 하단

```tsx
// admin/index.tsx 하단에 추가
import Constants from 'expo-constants'

<View style={styles.footer}>
  <Text style={styles.versionText}>
    v{Constants.expoConfig?.version ?? '0.0.0'}
  </Text>
</View>
```

일반 사용자에게 앱 버전 정보는 불필요하며, 관리자만 디버깅 목적으로 필요.

### 6.2 로그아웃 기능

**현재 위치**: 관리자 페이지 내 (기존 위치 유지)
**향후**: 마이페이지 구현 시 마이페이지로 이전

### 6.3 기능 이전 매핑

| 기존 설정 탭 기능 | 이전 위치 | 비고 |
|------------------|----------|------|
| 앱 버전 표시 | 관리자 페이지 하단 | 일반 사용자 불필요 |
| 관리자 페이지 버튼 | 제거 (롱프레스로 대체) | — |
| (향후) 테마 설정 | 마이페이지 | user_preferences 연동 |
| (향후) 알림 설정 | 마이페이지 | — |
| (향후) 계정 관리 | 마이페이지 | — |

---

## 7. 탭 슬롯 활용 계획

설정 탭 제거로 확보된 슬롯 활용 옵션:

### Option A: 마이페이지 탭 추가 (권장)

```
[홈] [그룹] [검색] [마이] [글쓰기(숨김)]
```

현재 웹에만 있는 마이페이지(`/my`)를 앱에도 추가:
- 활동 요약 (글/댓글/반응/스트릭)
- 감정 캘린더
- 저장한 영상 (유튜브 기능 Phase 2)
- 앱 버전 정보 (하단)
- 로그아웃

### Option B: 4탭 유지

```
[홈] [그룹] [검색] [글쓰기(숨김)]
```

탭을 추가하지 않고 깔끔한 3탭 구조 유지. 마이페이지는 홈 헤더의 프로필 아이콘으로 접근.

### Option C: 영상 탭 추가 (유튜브 기능 구현 시)

```
[홈] [영상] [그룹] [검색] [글쓰기(숨김)]
```

유튜브 큐레이션 기능 구현 시 전용 탭으로 배치. 단, 원본 설계에서는 "탭 추가 없음, 홈 더보기로 접근"이 결정사항.

**권장**: Option A (마이페이지). 웹과의 기능 대칭성 확보 + 설정/프로필 기능의 자연스러운 안착점.

---

## 8. 파일 변경 목록

### 8.1 앱 (gns-hermit-comm)

| 작업 | 파일 | 변경 내용 |
|------|------|----------|
| 신규 | `src/components/AdminLongPress.tsx` | 롱프레스 래퍼 컴포넌트 |
| 수정 | `src/components/ScreenHeader.tsx` | 타이틀에 `AdminLongPress` 래핑 |
| 수정 | `src/app/(tabs)/_layout.tsx` | 설정 탭 항목 제거 |
| 삭제 | `src/app/(tabs)/settings.tsx` | 설정 탭 화면 삭제 |
| 삭제 | `src/app/settings/index.tsx` | 설정 페이지 삭제 |
| 수정 | `src/app/admin/index.tsx` | 하단에 앱 버전 표시 추가 |

### 8.2 웹 (web-hermit-comm)

| 작업 | 파일 | 변경 내용 |
|------|------|----------|
| 신규 | `src/components/layout/AdminSecretTap.tsx` | 5회 탭 래퍼 컴포넌트 |
| 수정 | `src/components/layout/Header.tsx` | 로고에 `AdminSecretTap` 래핑 |

### 8.3 중앙 (supabase-hermit)

변경 없음. `app_admin` 테이블, RLS, 관리자 체크 로직 모두 기존 유지.

---

## 9. 엣지 케이스 및 대응

| 상황 | 대응 |
|------|------|
| 사용자가 우연히 롱프레스 | 비관리자에게는 아무 반응 없음 (햅틱/애니메이션 없음). 관리자라면 admin으로 이동하지만 의도치 않은 이동은 뒤로가기로 복귀 |
| 앱 롱프레스 중 손가락 이동 (pan) | `LongPressGestureHandler`는 이동 거리 초과 시 자동 취소 (기본 10px) |
| 웹 로고 더블클릭과 5회 탭 충돌 | 더블클릭은 텍스트 선택 트리거 → `userSelect: 'none'`으로 방지 |
| 웹에서 3초 윈도우 초과 | 오래된 탭은 자동 제거, 카운터 리셋 |
| useIsAdmin 쿼리 로딩 중 롱프레스 | `isAdmin`이 `undefined` → falsy → 무반응. 쿼리 완료 후 재시도하면 정상 동작 |
| 관리자 권한 박탈 후 캐시 | React Query 60초 staleTime → 최대 60초간 진입 가능하나, Layer 2(라우트 보호)에서 차단 |
| 관리자가 앱 로고 없는 화면에서 접근 | ScreenHeader가 없는 화면은 홈으로 이동 후 접근. 모든 주요 화면에 ScreenHeader 있으므로 실용적 문제 없음 |

---

## 10. 보안 분석

### 10.1 공격 벡터 검토

| 공격 | 위험도 | 대응 |
|------|--------|------|
| 롱프레스로 관리자 발견 시도 | 낮음 | 비관리자에게 아무 피드백 없음. 히든 도어 존재 자체를 알 수 없음 |
| 소스 코드에서 `/admin` 라우트 발견 | 낮음 | URL 접근해도 Layer 2(라우트 보호) + Layer 3(RLS)에서 차단 |
| React Query 캐시 조작 | 낮음 | 클라이언트 캐시는 UI 게이팅용. DB 레벨 RLS가 실제 권한 강제 |
| 네트워크 요청 분석 | 낮음 | `app_admin` 조회는 자기 행만 읽기 가능 (RLS). 타인 관리자 여부 확인 불가 |

### 10.2 기존 보안과 달라지는 점

**없음**. 설정 탭 제거와 롱프레스 추가는 순수 UI 변경. 인증/인가 로직 변경 없음.

---

## 11. 구현 순서

```
1단계: AdminLongPress 컴포넌트 구현 (앱)
  - react-native-gesture-handler LongPress 래퍼
  - expo-haptics 피드백 연동
  - ScreenHeader에 적용

2단계: 설정 탭 제거 (앱)
  - _layout.tsx에서 설정 탭 항목 삭제
  - settings.tsx, settings/index.tsx 삭제
  - admin/index.tsx에 앱 버전 정보 이전

3단계: AdminSecretTap 컴포넌트 구현 (웹)
  - 5회 연속 클릭 로직
  - Header.tsx에 적용

4단계: 테스트
  - 관리자 계정: 롱프레스 → /admin 정상 이동 확인
  - 비관리자 계정: 롱프레스 → 무반응 확인
  - URL 직접 접근: 기존 보호 로직 정상 동작 확인
```

---

## 12. 요약

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 앱 탭 구조 | 5탭 (홈/그룹/검색/글쓰기/설정) | 4탭 (홈/그룹/검색/글쓰기) |
| 관리자 진입 (앱) | 설정 탭 → 관리자 버튼 | 로고 롱프레스 800ms |
| 관리자 진입 (웹) | URL 직접 입력 (`/admin`) | 로고 5회 클릭 (3초 윈도우) |
| 비관리자 경험 | 빈 설정 화면 (버전만 표시) | 히든 도어 존재를 알 수 없음 |
| 앱 버전 정보 | 설정 탭 | 관리자 페이지 하단 |
| 인증/보안 | 3중 레이어 | 변경 없음 (3중 레이어 유지) |
| 신규 컴포넌트 | — | AdminLongPress (앱), AdminSecretTap (웹) |
| 삭제 파일 | — | settings.tsx, settings/index.tsx |
| 확보된 탭 슬롯 | — | 마이페이지 추가 권장 (Option A) |
