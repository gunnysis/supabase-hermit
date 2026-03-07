# 관리자 시스템 통합 재설계

> 작성일: 2026-03-07
> 대상: 중앙(supabase-hermit) + 앱(React Native/Expo SDK 54) + 웹(Next.js)
> 상태: 설계 완료 — 구현 대기
> 원본: DESIGN-admin-longpress.md + DESIGN-admin-sync-audit.md 병합

---

## 1. 현재 상태와 문제

### 1.1 현재 관리자 시스템 전체 구조

```
[DB] app_admin 테이블 (user_id PK)
  ├── RLS: SELECT 자기 행만 / INSERT·UPDATE·DELETE 정책 없음
  ├── groups INSERT: app_admin만 가능
  ├── groups UPDATE/DELETE: 정책 없음 (버그)
  └── soft_delete_post/comment: app_admin이면 타인 글도 삭제 가능

[앱] 현재 5탭 구조 → 변경 계획: 4탭 (설정 탭 제거)
  ├── 홈 ScreenHeader 우측: "관리자" 버튼 (isAdmin=true일 때)
  ├── 설정 탭: 앱 버전 + "운영자 관리 페이지" 링크
  ├── /admin/login: email+password 로그인
  ├── /admin/_layout.tsx: 3단계 라우트 보호
  └── /admin/index.tsx: 그룹 생성(초대코드 수동 필수) + 목록 + 삭제 + 공유

[웹] 4링크 하단 네비 (관리자 링크 없음)
  ├── /admin/login: email+password 로그인
  ├── /admin (layout 보호 없음, page 내부 체크만)
  └── /admin/page.tsx: 그룹 생성(코드 자동) + 목록 + 삭제 + 코드 복사/재생성
```

### 1.2 식별된 문제 (우선순위순)

| 등급 | 문제 | 영향 |
|------|------|------|
| **치명** | groups UPDATE/DELETE RLS 정책 누락 | `deleteGroup()`, `regenerateInviteCode()` 조용히 실패 (0행 처리, 에러 없음) |
| **치명** | invite_code 길이 CHECK 없음 | DB 레벨 입력 검증 부재 |
| **높음** | 설정 탭이 일반 사용자에게 빈 화면 (앱 버전+관리자 링크뿐) | UX 공간 낭비, 탭 슬롯 낭비 |
| **높음** | 초대코드 앱/웹 불일치 (수동 vs 자동) | 같은 관리자에게 다른 경험 |
| **높음** | 관리자 진입점 불일치 (앱 2개 / 웹 0개) | 웹 관리자 URL 직접 입력 필요 |
| **중간** | useIsAdmin 훅 시그니처/반환/queryKey 불일치 | 코드 유지보수 어려움 |
| **중간** | 웹 라우트 보호 취약 (layout 없음) | page 레벨 체크만, 새 admin 페이지 추가 시 보호 누락 위험 |
| **중간** | 웹 로그인 후 `router.push` (뒤로가기 시 로그인 복귀) | UX 혼란 |
| **낮음** | createGroupWithBoard API 시그니처 불일치 | 앱: 객체 인자, 웹: 개별 인자 |
| **낮음** | 삭제 확인 메시지 불일치 | 미세 UX 차이 |

---

## 2. 설계 결정

| 항목 | 결정 | 이유 |
|------|------|------|
| 설정 탭 | **순수 제거** (4탭으로 축소) | 일반 사용자에게 빈 화면, 탭 슬롯 낭비. 대체 탭 없이 제거 |
| 홈 헤더 "관리자" 버튼 | **제거** | 롱프레스로 대체, 일반 사용자에게 노출 불필요 |
| 관리자 진입 (앱) | 로고 **롱프레스 800ms** | Instagram 패턴, 히든 도어 |
| 관리자 진입 (웹) | 로고 **5회 연속 클릭** (3초 윈도우) | Android 개발자 옵션 패턴 |
| 비관리자 피드백 | **무반응** (햅틱/애니메이션 없음) | 히든 도어 존재 은닉 |
| 앱 버전 정보 | **관리자 대시보드 하단으로 이전** | 설정 탭 제거에 따른 버전 정보 재배치 |
| 초대코드 | **선택 입력** (비우면 자동 생성) | 앱/웹 통일, 커스텀+자동 모두 지원 |
| 웹 라우트 보호 | **layout.tsx** 신규 추가 | 앱 패턴 이식, 일관성 확보 |
| API 통일 방향 | **단기 수동 동기화** | shared/ 공유는 Supabase 클라이언트 차이로 어려움 |

---

## 3. 중앙 DB 변경 (Phase 0)

모든 클라이언트 작업의 선행 조건. 이 마이그레이션 없이는 그룹 삭제/수정이 동작하지 않음.

### 3.1 마이그레이션 SQL

```sql
-- 파일: supabase/migrations/YYYYMMDDHHMMSS_admin_groups_rls_fix.sql

-- ============================================================
-- groups UPDATE: owner만 수정 가능
-- ============================================================
DROP POLICY IF EXISTS "Owner can update own groups" ON public.groups;
CREATE POLICY "Owner can update own groups" ON public.groups FOR UPDATE
  USING ((SELECT auth.uid()) = owner_id)
  WITH CHECK ((SELECT auth.uid()) = owner_id);

-- ============================================================
-- groups DELETE: owner만 삭제 가능
-- ============================================================
DROP POLICY IF EXISTS "Owner can delete own groups" ON public.groups;
CREATE POLICY "Owner can delete own groups" ON public.groups FOR DELETE
  USING ((SELECT auth.uid()) = owner_id);

-- ============================================================
-- invite_code 길이 제약 (4~50자, NULL 허용)
-- ============================================================
ALTER TABLE groups DROP CONSTRAINT IF EXISTS groups_invite_code_length;
ALTER TABLE groups ADD CONSTRAINT groups_invite_code_length
  CHECK (invite_code IS NULL OR length(invite_code) BETWEEN 4 AND 50);
```

### 3.2 shared/types.ts 변경

```typescript
// CreateGroupInput 타입 추가 (앱/웹 공통)
export interface CreateGroupInput {
  name: string            // 1~100자
  inviteCode?: string     // 4~50자, 선택 (미입력 시 자동 생성)
  description?: string    // 0~500자
}
```

### 3.3 shared/constants.ts 변경

```typescript
// ADMIN 관련 상수 추가
export const ADMIN_CONSTANTS = {
  INVITE_CODE_MIN_LENGTH: 4,
  INVITE_CODE_MAX_LENGTH: 50,
  GROUP_NAME_MAX_LENGTH: 100,
  GROUP_DESC_MAX_LENGTH: 500,
} as const

// 삭제 확인 메시지 통일
export const CONFIRM_MESSAGES = {
  deleteGroup: '그룹의 모든 게시글과 댓글이 함께 삭제됩니다.',
} as const
```

---

## 4. 앱 변경

### 4.1 탭 구조 변경

**변경 전**: `[홈] [그룹] [검색] [글쓰기(숨김)] [설정]` — 5탭 (설정 내용: 앱 버전 + 관리자 링크뿐)
**변경 후**: `[홈] [그룹] [검색] [글쓰기(숨김)]` — 4탭 (설정 탭 순수 제거, 대체 탭 없음)

> 설정 탭의 기존 기능 재배치:
> - 앱 버전 → 관리자 대시보드 하단
> - 관리자 페이지 링크 → 롱프레스 히든 도어로 대체

### 4.2 히든 도어: AdminLongPress 컴포넌트

```tsx
// src/components/AdminLongPress.tsx
import { Gesture, GestureDetector } from 'react-native-gesture-handler'
import * as Haptics from 'expo-haptics'
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSequence,
  withTiming,
  runOnJS,
} from 'react-native-reanimated'
import { useIsAdmin } from '@/features/admin/hooks/useIsAdmin'
import { router } from 'expo-router'

interface Props {
  children: React.ReactNode
}

export function AdminLongPress({ children }: Props) {
  const { isAdmin } = useIsAdmin()
  const scale = useSharedValue(1)

  const navigateAdmin = () => {
    if (isAdmin) {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium)
      router.push('/admin')
    }
  }

  const animatePress = () => {
    scale.value = withSequence(
      withTiming(0.95, { duration: 80 }),
      withTiming(1, { duration: 120 })
    )
  }

  // onEnd: success=true일 때만 실행 (800ms 이상 유지 후 손 뗌)
  // onFinalize와 달리 취소된 제스처(손가락 이동 등)에서는 호출되지 않음
  const longPress = Gesture.LongPress()
    .minDuration(800)
    .onEnd((_event, success) => {
      if (success) {
        runOnJS(animatePress)()
        runOnJS(navigateAdmin)()
      }
    })

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

### 4.3 ScreenHeader 수정

```tsx
// src/shared/components/ScreenHeader.tsx (수정)
import { AdminLongPress } from '@/components/AdminLongPress'

export function ScreenHeader({ title, rightContent, ... }) {
  // 기존 관리자 버튼 관련 코드 제거
  // (홈 index.tsx의 adminButton 변수도 제거)

  return (
    <View style={styles.header}>
      <AdminLongPress>
        <Text style={styles.title}>{title}</Text>
      </AdminLongPress>
      {rightContent}
    </View>
  )
}
```

### 4.4 홈 화면 관리자 버튼 제거

```tsx
// src/app/(tabs)/index.tsx (수정)
// 삭제할 코드:
// const adminButton = !isAdminLoading && isAdmin === true ? ( ... ) : undefined
// useIsAdmin import 제거 (ScreenHeader에서 처리)
```

### 4.5 관리자 대시보드 기능 통일

```tsx
// src/app/admin/index.tsx 주요 변경:

// 1. 초대코드 필드: 필수 → 선택
// placeholder: "비워두면 자동 생성됩니다"

// 2. 그룹 카드 버튼 추가:
// [복사] [재생성] [공유] [삭제]

// 3. 앱 버전 정보 하단에 표시

// 4. 삭제 확인 메시지 통일
// CONFIRM_MESSAGES.deleteGroup 사용
```

### 4.6 adminApi.ts 수정

```typescript
// 1. inviteCode 선택으로 변경
interface CreateGroupWithBoardInput {
  name: string
  inviteCode?: string    // 선택 (필수 → 선택)
  description?: string
}

// 2. generateInviteCode 추가
function generateInviteCode(): string {
  return Math.random().toString(36).slice(2, 8).toUpperCase()
}

// 3. createGroupWithBoard 내부
const finalCode = input.inviteCode?.trim() || generateInviteCode()

// 4. regenerateInviteCode 추가
// RLS가 owner_id=auth.uid()를 강제하므로 owner가 아닌 사용자의 요청은 0행 처리됨
// 클라이언트 레벨에서도 owner_id 방어 추가 (UX 에러 메시지 명확화)
export async function regenerateInviteCode(groupId: number, ownerId: string): Promise<string> {
  const { data: { user } } = await supabase.auth.getUser()
  if (user?.id !== ownerId) throw new APIError(403, '그룹 소유자만 초대코드를 재생성할 수 있습니다.')

  const newCode = generateInviteCode()
  const { error, count } = await supabase
    .from('groups')
    .update({ invite_code: newCode })
    .eq('id', groupId)
    .select('id', { count: 'exact', head: true })
  if (error) throw new APIError(500, error.message)
  if (count === 0) throw new APIError(403, '권한이 없거나 그룹이 존재하지 않습니다.')
  return newCode
}
```

### 4.7 앱 파일 변경 목록

| 작업 | 파일 | 변경 |
|------|------|------|
| 신규 | `src/components/AdminLongPress.tsx` | 롱프레스 히든 도어 래퍼 |
| 수정 | `src/shared/components/ScreenHeader.tsx` | 타이틀에 AdminLongPress 래핑 |
| 수정 | `src/app/(tabs)/_layout.tsx` | 설정 탭 제거 (5탭→4탭) |
| 수정 | `src/app/(tabs)/index.tsx` | 관리자 버튼 제거 |
| 수정 | `src/app/admin/index.tsx` | 초대코드 선택화 + 복사/재생성 버튼 + 버전 정보 이전 + 삭제 메시지 통일 |
| 수정 | `src/features/admin/api/adminApi.ts` | inviteCode 선택 + generateInviteCode + regenerateInviteCode |
| 삭제 | `src/app/(tabs)/settings.tsx` | 설정 탭 화면 |
| 삭제 | `src/app/settings/index.tsx` | 설정 페이지 |

---

## 5. 웹 변경

### 5.1 히든 도어: AdminSecretTap 컴포넌트

```tsx
// src/components/layout/AdminSecretTap.tsx
'use client'

import { useRef, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { useAuthContext } from '@/features/auth/AuthProvider'
import { useIsAdmin } from '@/features/admin/hooks/useIsAdmin'

const TAP_COUNT = 5
const TAP_WINDOW_MS = 3000

export function AdminSecretTap({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const { user } = useAuthContext()
  const { data: isAdmin } = useIsAdmin(user?.id ?? null)
  const tapsRef = useRef<number[]>([])

  const handleClick = useCallback(() => {
    const now = Date.now()
    tapsRef.current = tapsRef.current.filter(t => now - t < TAP_WINDOW_MS)
    tapsRef.current.push(now)

    if (tapsRef.current.length >= TAP_COUNT) {
      tapsRef.current = []
      if (isAdmin) {
        router.push('/admin')
      }
    }
  }, [isAdmin, router])

  return (
    <span onClick={handleClick} style={{ cursor: 'pointer', userSelect: 'none' }}>
      {children}
    </span>
  )
}
```

### 5.2 Header 수정

```tsx
// src/components/layout/Header.tsx
import { AdminSecretTap } from './AdminSecretTap'

export function Header() {
  return (
    <header className="sticky top-0 z-50 border-b bg-background/80 backdrop-blur-sm">
      <div className="max-w-2xl mx-auto px-4 h-14 flex items-center justify-between">
        <AdminSecretTap>
          <Link href="/" className="font-bold text-lg tracking-tight">
            은둔마을
          </Link>
        </AdminSecretTap>
        {/* 기존 네비게이션 유지 */}
      </div>
    </header>
  )
}
```

### 5.3 라우트 보호 layout 추가

```tsx
// src/app/admin/layout.tsx (신규)
'use client'

import { useRouter, usePathname } from 'next/navigation'
import { useEffect } from 'react'
import { useAuthContext } from '@/features/auth/AuthProvider'
import { useIsAdmin } from '@/features/admin/hooks/useIsAdmin'

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const pathname = usePathname()
  const { user, loading: authLoading } = useAuthContext()
  const { data: isAdmin, isLoading: adminLoading } = useIsAdmin(user?.id ?? null)

  // /admin/login은 보호 대상에서 제외 (무한 리다이렉트 방지)
  const isLoginPage = pathname === '/admin/login'

  useEffect(() => {
    if (isLoginPage) return
    if (authLoading || adminLoading) return
    if (!user) { router.replace('/admin/login'); return }
    if (isAdmin === false) { router.replace('/'); return }
  }, [isLoginPage, authLoading, adminLoading, user, isAdmin, router])

  if (isLoginPage) return <>{children}</>

  if (authLoading || adminLoading) {
    return <div className="min-h-screen flex items-center justify-center text-muted-foreground">확인 중...</div>
  }
  if (!user || !isAdmin) return null

  return <>{children}</>
}
```

### 5.4 로그인 페이지 수정

```tsx
// src/app/admin/login/page.tsx (수정)
// router.push('/admin') → router.replace('/admin')
```

### 5.5 관리자 대시보드 수정

```tsx
// src/app/admin/page.tsx 주요 변경:

// 1. 초대코드 입력 필드 추가 (선택)
// placeholder: "비워두면 자동 생성됩니다"

// 2. createGroupWithBoard 호출 시 inviteCode 전달

// 3. 삭제 확인 메시지 통일
// CONFIRM_MESSAGES.deleteGroup 사용

// 4. 입력 검증 추가 (길이 제한)

// 5. page 내부의 isAdmin 조건부 렌더링 제거 (layout에서 처리)
```

### 5.6 adminApi.ts 수정

```typescript
// 1. createGroupWithBoard 시그니처 변경
export async function createGroupWithBoard(
  name: string,
  description: string,
  ownerId: string,
  inviteCode?: string,  // 선택 파라미터 추가
): Promise<Group> {
  const finalCode = inviteCode?.trim() || generateInviteCode()
  // ... INSERT with finalCode
}

// 2. 입력 검증 추가
// name: 1~100자, trim
// description: 0~500자
// inviteCode: 4~50자 (입력 시)

// 3. deleteGroup에 owner_id 필터 추가 (기존: .eq('id', groupId) 만)
export async function deleteGroup(groupId: number, ownerId: string) {
  const { error, count } = await supabase
    .from('groups')
    .delete()
    .eq('id', groupId)
    .eq('owner_id', ownerId)       // owner 본인만 삭제 가능
    .select('id', { count: 'exact', head: true })
  if (error) throw error
  if (count === 0) throw new Error('권한이 없거나 그룹이 존재하지 않습니다.')
}

// 4. regenerateInviteCode에 owner_id 필터 추가 (기존 함수 수정)
export async function regenerateInviteCode(groupId: number, ownerId: string) {
  const newCode = generateInviteCode()
  const { error, count } = await supabase
    .from('groups')
    .update({ invite_code: newCode })
    .eq('id', groupId)
    .eq('owner_id', ownerId)       // owner 본인만 재생성 가능
    .select('id', { count: 'exact', head: true })
  if (error) throw error
  if (count === 0) throw new Error('권한이 없거나 그룹이 존재하지 않습니다.')
  return newCode
}

// 5. handleSignOut: router.push('/') → router.replace('/') (뒤로가기 방지)
```

### 5.7 웹 파일 변경 목록

| 작업 | 파일 | 변경 |
|------|------|------|
| 신규 | `src/components/layout/AdminSecretTap.tsx` | 5회 클릭 히든 도어 |
| 신규 | `src/app/admin/layout.tsx` | 라우트 보호 layout |
| 수정 | `src/components/layout/Header.tsx` | 로고에 AdminSecretTap 래핑 |
| 수정 | `src/app/admin/login/page.tsx` | `router.push` → `router.replace` |
| 수정 | `src/app/admin/page.tsx` | 초대코드 필드 추가 + 검증 + 삭제 메시지 통일 + isAdmin 분기 제거 |
| 수정 | `src/features/admin/api/adminApi.ts` | inviteCode 선택 파라미터 + 입력 검증 + generateInviteCode + deleteGroup/regenerateInviteCode에 owner_id 필터 추가 |

---

## 6. 보안

### 6.1 보안 레이어 (변경 전후 비교)

```
변경 전:
  Layer 1: useIsAdmin() → UI 게이팅 (설정 탭 / 홈 헤더 버튼)
  Layer 2: admin/_layout.tsx (앱만) → 라우트 보호
  Layer 3: RLS → app_admin INSERT만 / UPDATE·DELETE 없음 (버그)

변경 후:
  Layer 1: useIsAdmin() → UI 게이팅 (롱프레스 / 시크릿 탭)
  Layer 2: admin/_layout.tsx (앱+웹) → 라우트 보호 통일
  Layer 3: RLS → app_admin + groups UPDATE·DELETE 정책 추가 (버그 수정)
```

### 6.2 공격 벡터

| 공격 | 위험도 | 대응 |
|------|--------|------|
| 롱프레스로 관리자 발견 | 낮음 | 비관리자에게 아무 피드백 없음 |
| `/admin` URL 직접 접근 | 낮음 | Layer 2(layout 보호) + Layer 3(RLS) |
| React Query 캐시 조작 | 낮음 | UI 게이팅 뿐, DB 레벨 RLS 강제 |
| app_admin 직접 INSERT | 없음 | RLS: INSERT 정책 없음, Dashboard/service_role만 가능 |

### 6.3 롱프레스 인터랙션 흐름

```
사용자가 "은둔마을" 타이틀을 800ms 이상 누름
    |
    +-- useIsAdmin() 캐시 확인 (React Query, 60초 staleTime)
    |
    +-- [관리자]
    |     +-- 햅틱 Medium Impact
    |     +-- 스케일 바운스 (0.95 → 1.0)
    |     +-- router.push('/admin')
    |     +-- Layer 2 통과 → 대시보드 표시
    |
    +-- [비관리자]
          +-- 무반응 (햅틱/애니메이션 없음)
          +-- 히든 도어 존재 인지 불가
```

---

## 7. 앱/웹 관리자 기능 통일 명세

### 7.1 그룹 생성 폼 (앱/웹 동일)

```
+--------------------------------------------------+
| 그룹 생성                               [접기 v]  |
+--------------------------------------------------+
| 그룹 이름 *                                       |
| [                                        ] 0/100 |
|                                                   |
| 초대 코드                                         |
| [비워두면 자동 생성됩니다               ] 0/50    |
|                                                   |
| 설명                                              |
| [                                        ] 0/500 |
|                                                   |
| [그룹 생성]                                       |
+--------------------------------------------------+
```

생성 성공 시:
- 앱: Alert로 초대 코드 표시 + [확인] / [공유하기] 버튼
- 웹: toast로 초대 코드 표시 + 자동 클립보드 복사

### 7.2 그룹 카드 (앱/웹 동일 기능)

```
+-------------------------------+
| 그룹명                         |
| 설명 (2줄)                     |
| 코드: XXXXXX · 2026.03.07     |
| [복사] [재생성] [공유] [삭제]   |  <- 앱
| [복사] [재생성] [삭제]          |  <- 웹 (공유 대신 복사만)
+-------------------------------+
```

### 7.3 삭제 확인 (앱/웹 동일 문구)

```
제목: "'그룹명' 그룹을 삭제할까요?"
설명: "그룹의 모든 게시글과 댓글이 함께 삭제됩니다."
버튼: [취소] [삭제]
```

### 7.4 관리자 페이지 레이아웃

```
+--------------------------------------------------+
| [<- 뒤로]  관리자                     [로그아웃]   |
+--------------------------------------------------+
| 그룹 생성 (토글)                                   |
| 내가 만든 그룹 목록 (카드)                          |
+--------------------------------------------------+
| v{앱 버전}                                        |  <- 하단
+--------------------------------------------------+
```

---

## 8. 코드 리팩토링

### 8.1 queryKey 통일

| 훅 | 현재 (앱) | 현재 (웹) | 통일안 |
|-----|-----------|-----------|--------|
| useIsAdmin | `['app_admin', userId]` | `['isAdmin', userId]` | `['admin', 'isAdmin', userId]` |
| useAdminGroups | `['admin', 'myManagedGroups']` | `['admin', 'myManagedGroups', userId]` | `['admin', 'groups', userId]` |

### 8.2 generateInviteCode 공유

```typescript
// shared/constants.ts에 추가 (sync 대상)
export function generateInviteCode(): string {
  return Math.random().toString(36).slice(2, 8).toUpperCase()
}
```

앱/웹 모두 `constants.generated.ts`에서 import하여 동일 로직 보장.

> **주의**: `shared/constants.ts`에 함수를 추가하면 sync 시 앱(`constants.generated.ts`)과 웹(`constants.generated.ts`) 모두에 복사된다.
> 기존 `constants.ts`는 상수(`as const`)만 포함하고 있었으므로, 함수 추가 시 번들러/린터 호환성을 확인할 것.
> 대안: 함수를 `shared/utils.ts`로 분리하고 별도 sync 대상에 추가하는 방법도 가능.

### 8.3 입력 검증 공유

```typescript
// shared/constants.ts에 추가
export function validateGroupInput(input: {
  name: string
  inviteCode?: string
  description?: string
}): string | null {
  const name = input.name.trim()
  if (!name) return '그룹 이름을 입력해주세요.'
  if (name.length > ADMIN_CONSTANTS.GROUP_NAME_MAX_LENGTH) return `그룹 이름은 ${ADMIN_CONSTANTS.GROUP_NAME_MAX_LENGTH}자 이내로 입력해주세요.`

  if (input.inviteCode?.trim()) {
    const code = input.inviteCode.trim()
    if (code.length < ADMIN_CONSTANTS.INVITE_CODE_MIN_LENGTH) return `초대 코드는 ${ADMIN_CONSTANTS.INVITE_CODE_MIN_LENGTH}자 이상이어야 합니다.`
    if (code.length > ADMIN_CONSTANTS.INVITE_CODE_MAX_LENGTH) return `초대 코드는 ${ADMIN_CONSTANTS.INVITE_CODE_MAX_LENGTH}자 이내로 입력해주세요.`
  }

  if (input.description && input.description.length > ADMIN_CONSTANTS.GROUP_DESC_MAX_LENGTH) {
    return `설명은 ${ADMIN_CONSTANTS.GROUP_DESC_MAX_LENGTH}자 이내로 입력해주세요.`
  }

  return null // 유효
}
```

---

## 9. 구현 순서

```
Phase 0: DB 수정 (선행 필수, 다른 작업 차단)
  1. 마이그레이션 작성 (groups RLS + invite_code CHECK)
  2. shared/types.ts — CreateGroupInput 추가
  3. shared/constants.ts — ADMIN_CONSTANTS + CONFIRM_MESSAGES + generateInviteCode + validateGroupInput
  4. db.sh push → gen-types → sync
  5. 앱/웹에서 deleteGroup, regenerateInviteCode 동작 검증

Phase 1: 관리자 기능 동기화 (앱/웹 독립 병렬 가능)
  [앱]
  6. adminApi.ts — inviteCode 선택화 + generateInviteCode + regenerateInviteCode
  7. admin/index.tsx — 초대코드 선택 + 복사/재생성 버튼 + 삭제 메시지 통일

  [웹]
  8. adminApi.ts — inviteCode 파라미터 추가 + 입력 검증
  9. admin/page.tsx — 초대코드 필드 추가 + 삭제 메시지 통일
  10. admin/login/page.tsx — router.replace 수정
  11. admin/layout.tsx — 라우트 보호 신규

Phase 2: 히든 도어 + 설정 탭 제거 (Phase 1 완료 후)

  [앱]
  12. AdminLongPress.tsx 신규
  13. ScreenHeader.tsx 수정 (AdminLongPress 래핑)
  14. (tabs)/index.tsx — 관리자 버튼 제거
  15. (tabs)/_layout.tsx — 설정 탭 제거 (Tabs.Screen 삭제)
  16. (tabs)/settings.tsx + settings/index.tsx 삭제
  17. admin/index.tsx — 앱 버전 정보 하단 추가

  [웹]
  18. AdminSecretTap.tsx 신규
  19. Header.tsx 수정 (AdminSecretTap 래핑)

Phase 3: 코드 품질 (선택, 기능 영향 없음)
  20. queryKey 네이밍 통일 (앱/웹)
  21. 웹 adminApi 테스트 추가
```

**Phase 의존성**:
```
Phase 0 (DB) ──┬── Phase 1 (기능 동기화) ── Phase 2 (히든 도어 + 탭 제거)
               └── Phase 3 (품질) — 독립 실행 가능
```

---

## 10. 엣지 케이스

| 상황 | 대응 |
|------|------|
| 비관리자가 우연히 롱프레스 | 무반응. 히든 도어 존재 인지 불가 |
| 관리자가 롱프레스 중 손가락 이동 | Gesture Handler가 이동 10px 초과 시 자동 취소 |
| 웹 로고 더블클릭 텍스트 선택 | `userSelect: 'none'`으로 방지 |
| useIsAdmin 로딩 중 롱프레스 | `isAdmin` undefined → falsy → 무반응. 로딩 완료 후 재시도 정상 |
| 관리자 권한 박탈 후 캐시 | 60초 staleTime 내 진입 가능하나 Layer 2(layout)에서 차단 |
| 초대코드 중복 입력 | UNIQUE 제약 → Supabase 에러 → "이미 사용 중인 초대 코드입니다" 안내 |
| 초대코드 4자 미만 입력 | 클라이언트 validateGroupInput에서 차단 + DB CHECK 이중 보호 |
| groups 삭제 후 CASCADE | boards, group_members CASCADE 삭제. posts는 group_id SET NULL |
| 앱 관리자 로그아웃 후 일반 사용자 복귀 | 앱은 `signInAnonymously()`로 익명 세션 유지. 관리자 로그아웃 → 익명 재로그인 필요. 웹은 단순 `signOut()` |
| app_admin에 INSERT 정책 없음 (의도적) | 관리자 등록은 Supabase Dashboard 또는 service_role 키로만 가능. 자가 등록 차단 |

---

## 11. 변경 요약

| 영역 | 변경 전 | 변경 후 |
|------|---------|---------|
| **DB** | groups UPDATE/DELETE RLS 없음 (버그) | owner 기반 UPDATE/DELETE 정책 추가 |
| **DB** | invite_code 길이 무제한 | 4~50자 CHECK 제약 |
| **앱 탭** | 5탭 (설정 포함) | 4탭 (설정 탭 순수 제거) |
| **앱 진입** | 설정 탭 + 홈 관리자 버튼 | 로고 롱프레스 800ms |
| **웹 진입** | URL 직접 입력만 | 로고 5회 클릭 |
| **웹 보호** | page 내부 조건부 렌더링 | layout.tsx 라우트 보호 |
| **웹 로그인** | `router.push` | `router.replace` |
| **초대코드** | 앱: 수동 필수 / 웹: 자동 고정 | 앱/웹: 선택 입력 (비우면 자동) |
| **초대코드 재생성** | 웹만 | 앱/웹 모두 |
| **초대코드 복사** | 웹만 | 앱/웹 모두 |
| **삭제 메시지** | 앱/웹 불일치 | 통일 ("그룹의 모든 게시글과 댓글이 함께 삭제됩니다") |
| **입력 검증** | 앱만 엄격 | 앱/웹 동일 (shared 공유 함수) |
| **보안 레이어** | 앱 3중 / 웹 2중 | 앱/웹 모두 3중 |
| **비관리자 경험** | 빈 설정 화면 노출 | 히든 도어 존재 자체 은닉 |
| **신규 파일** | — | AdminLongPress, AdminSecretTap, admin/layout.tsx |
| **삭제 파일** | — | settings.tsx, settings/index.tsx |
