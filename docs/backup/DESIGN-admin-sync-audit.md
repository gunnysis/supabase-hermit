# 관리자 기능 앱/웹 동기화 점검 보고서

> 작성일: 2026-03-07
> 최종 검증일: 2026-03-07 (실제 코드 대조 완료)
> 목적: 앱과 웹의 관리자 기능 차이 식별 + DB 스키마 갭 + 동기화 방안 수립

---

## 1. 기능 비교표

| # | 기능 | 앱 (React Native) | 웹 (Next.js) | 동기화 상태 |
|---|------|-------------------|-------------|-------------|
| 1 | 관리자 로그인 | email + password (`signInWithPassword`) | email + password (`signInWithPassword`) | 동일 |
| 2 | 로그인 후 이동 | `replaceAdmin(router)` (히스토리 교체) | `router.push('/admin')` (히스토리 추가) | **불일치** |
| 3 | 권한 체크 훅 | `useIsAdmin()` (인자 없음, 내부에서 user.id) | `useIsAdmin(userId)` (인자 받음) | **시그니처 불일치** |
| 4 | 권한 체크 반환 | `{ isAdmin: boolean\|null, isLoading }` 커스텀 | `useQuery` 원본 `{ data: boolean, isLoading }` | **반환 형태 불일치** |
| 5 | 라우트 보호 | `_layout.tsx` 3단계 (auth→admin→redirect) | 없음 (`page.tsx` 내부에서 조건부 렌더링) | **앱이 더 견고** |
| 6 | 관리자 진입점 | 홈 헤더 "관리자" 버튼 + 설정 탭 | URL 직접 입력 (`/admin`) 만 가능 | **불일치** |
| 7 | 그룹 생성 | 이름 + **초대코드 수동 입력(필수)** + 설명 | 이름 + 설명 (**코드 자동 생성, 입력 불가**) | **불일치** |
| 8 | 초대코드 생성 방식 | 관리자 직접 입력, `autoCapitalize="characters"` | `Math.random().toString(36).slice(2,8).toUpperCase()` | **불일치** |
| 9 | 초대코드 복사 | 없음 | 클립보드 복사 버튼 (lucide `Copy` 아이콘) | **웹만 있음** |
| 10 | 초대코드 재생성 | 없음 | `regenerateInviteCode()` + 자동 클립보드 복사 | **웹만 있음** |
| 11 | 초대코드 공유 | `Share.share()` 네이티브 공유 | 없음 (복사만) | **앱만 있음** |
| 12 | 그룹 목록 훅 | `useMyManagedGroups()` (내부에서 userId) | `useAdminGroups(userId)` (외부에서 전달) | **시그니처 불일치** |
| 13 | 그룹 삭제 | `Alert.alert` 확인 → `deleteGroup(groupId)` | `ConfirmDialog` → `deleteMutation.mutate(groupId)` | 동일 (플랫폼 차이) |
| 14 | 삭제 확인 메시지 | "보드와 게시글·댓글이 모두 삭제됩니다" | "모든 게시글과 댓글이 삭제됩니다" | **문구 불일치** |
| 15 | 로그아웃 후 처리 | `signOut` → `signInAnonymously` → `/(tabs)` | `signOut` → `router.push('/')` | **불일치** |
| 16 | 생성 폼 토글 | 항상 노출 | `showCreateForm` 토글로 접기/펼치기 | **웹만 있음** |
| 17 | 로딩 UI | 텍스트 ("확인 중...", "권한 확인 중...") | Skeleton UI | **불일치** |
| 18 | 에러 처리 | `APIError` 클래스 + `toFriendlyErrorMessage()` | `throw error` (Supabase 원본) + `toast` (sonner) | **패턴 불일치** |
| 19 | 앱 버전 표시 | 설정 탭에 표시 (`expo-constants`) | 없음 | **앱만 있음** |
| 20 | 입력 검증 | 이메일 정규식 + 길이 제한 (100/50/500자) | 필수 필드만 (`required` 속성) | **앱이 더 엄격** |
| 21 | `createGroupWithBoard` 인자 | 객체 `{ name, inviteCode, description }` | 개별 `(name, description, ownerId)` | **시그니처 불일치** |
| 22 | 테스트 | `adminApi.test.ts` 존재 | 없음 | **앱만 있음** |
| 23 | `checkAppAdmin` 위치 | `shared/lib/admin.ts` | `features/admin/api/adminApi.ts` | **모듈 구조 불일치** |
| 24 | queryKey (isAdmin) | `['app_admin', userId]` | `['isAdmin', userId]` | **네이밍 불일치** |
| 25 | queryKey (groups) | `['admin', 'myManagedGroups']` | `['admin', 'myManagedGroups', userId]` | **구조 불일치** |
| 26 | 그룹 삭제 방식 | `.delete().eq('id', groupId)` (직접 DELETE) | `.delete().eq('id', groupId)` (직접 DELETE) | 동일 (RLS 문제 공유) |

---

## 2. DB 스키마 갭 (코드 검증에서 발견)

### 2.1 groups 테이블 UPDATE/DELETE RLS 정책 누락 (치명적)

**현재 상태**: `groups` 테이블에 RLS가 활성화되어 있지만, UPDATE/DELETE 정책이 정의되지 않음.

```sql
-- 20260301000002_rls.sql에 정의된 groups 정책 (전부)
CREATE POLICY "Everyone can read groups" ON public.groups FOR SELECT USING (true);
CREATE POLICY "Only app_admin can create groups as owner" ON public.groups FOR INSERT
  WITH CHECK ((SELECT auth.uid()) IN (SELECT user_id FROM public.app_admin) AND owner_id = (SELECT auth.uid()));
-- UPDATE 정책: 없음
-- DELETE 정책: 없음
```

**영향**:
- 웹 `deleteGroup()`: `.from('groups').delete().eq('id', groupId)` → RLS에 의해 **0행 삭제** (에러 없이 무시됨)
- 웹 `regenerateInviteCode()`: `.from('groups').update(...)` → RLS에 의해 **0행 갱신** (에러 없이 무시됨)
- 앱 `deleteGroup()`: 동일한 문제

**실제 동작 추정**: Supabase에서 RLS 활성화 + 해당 작업의 정책 미정의 → 해당 작업은 **조용히 실패** (에러 반환 없이 영향 0행). 앱/웹 코드 모두 `error` 필드만 체크하고 영향 행수를 체크하지 않으므로 성공으로 처리됨.

**수정 필요**: 마이그레이션 추가

```sql
-- groups UPDATE: owner만 수정 가능
CREATE POLICY "Owner can update own groups" ON public.groups FOR UPDATE
  USING ((SELECT auth.uid()) = owner_id)
  WITH CHECK ((SELECT auth.uid()) = owner_id);

-- groups DELETE: owner만 삭제 가능
CREATE POLICY "Owner can delete own groups" ON public.groups FOR DELETE
  USING ((SELECT auth.uid()) = owner_id);
```

### 2.2 invite_code 길이 CHECK 제약 없음

**현재 상태**: `invite_code TEXT` — UNIQUE 제약만 있고 길이 제한 없음.

```sql
-- 20260303000001_core_redesign.sql
ALTER TABLE groups ADD CONSTRAINT groups_invite_code_unique UNIQUE (invite_code);
-- 길이 CHECK: 없음
```

앱은 클라이언트에서 50자 제한을 검증하지만, DB 레벨에서는 무제한.

**수정 권장**:
```sql
ALTER TABLE groups ADD CONSTRAINT groups_invite_code_length
  CHECK (invite_code IS NULL OR length(invite_code) BETWEEN 4 AND 50);
```

### 2.3 app_admin INSERT/UPDATE/DELETE 정책 없음

**현재 상태**: SELECT 정책만 존재. 관리자 등록/해제는 Supabase Dashboard 또는 service_role 키로만 가능.

**의도된 설계**: 관리자 관리는 서버 사이드에서만 가능하도록 의도적으로 제한한 것으로 판단. 현 시점에서 수정 불필요.

---

## 3. 주요 불일치 상세 분석

### 3.1 관리자 진입점 차이

**앱에는 2개의 진입점, 웹에는 0개**:

| 진입점 | 앱 | 웹 |
|--------|----|----|
| 홈 헤더 "관리자" 버튼 | `isAdmin=true`일 때 ScreenHeader 우측에 표시 → `pushAdmin(router)` | 없음 |
| 설정 탭 | "운영자 관리 페이지" 링크 → `pushAdminLogin(router)` | 없음 |
| URL 직접 입력 | 가능 (`/admin`) | 가능 (`/admin`) |

**문제**: 웹에서는 관리자가 `/admin` URL을 기억해야 함. 진입점이 전혀 없음.

**DESIGN-admin-longpress.md와의 연계**: 롱프레스 히든 도어 도입 시 앱의 홈 헤더 "관리자" 버튼도 제거 대상. 현재 문서에서 이 버튼을 언급하지 않았으므로 수정 필요.

### 3.2 초대코드 생성 방식

**앱**: 관리자가 초대코드를 직접 타이핑 (필수 입력)
```typescript
// adminApi.ts (앱)
createGroupWithBoard({ name, inviteCode, description })
// inviteCode는 사용자 입력값 (예: "WELCOME2025"), 필수
```

**웹**: 6자리 랜덤 코드 자동 생성 (입력 불가)
```typescript
// adminApi.ts (웹)
const inviteCode = Math.random().toString(36).slice(2, 8).toUpperCase()
createGroupWithBoard(name, description, ownerId)
// inviteCode는 함수 내부에서 자동 생성, 관리자가 지정할 수 없음
```

**문제점**:
- 같은 관리자가 앱에서 그룹을 만들면 커스텀 코드, 웹에서 만들면 랜덤 코드 → 일관성 없음
- 앱에서 초대코드 중복 시 500 에러 (UNIQUE 제약). 웹은 랜덤이라 충돌 확률 낮음
- 앱은 대문자 자동 변환(`autoCapitalize="characters"`)이지만, DB에는 대소문자 구분 저장
- 웹은 커스텀 코드를 지정할 방법이 아예 없음 (기억하기 쉬운 코드 불가)

**권장**: 선택 입력 방식으로 통일 (입력하면 커스텀 코드, 비우면 자동 생성)
- 관리자가 의미 있는 코드를 원하면 직접 지정 가능 (예: "SPRING2026")
- 코드를 고민하기 싫으면 비워두면 자동 생성
- 중복 시 명확한 에러 메시지 ("이미 사용 중인 초대 코드입니다") 표시
- 앱/웹 모두 동일한 UX 제공

### 3.3 초대코드 재생성 (웹만 존재)

```typescript
// adminApi.ts (웹)
export async function regenerateInviteCode(groupId: number): Promise<string> {
  const newCode = Math.random().toString(36).slice(2, 8).toUpperCase()
  const supabase = createClient()
  const { error } = await supabase
    .from('groups')
    .update({ invite_code: newCode })
    .eq('id', groupId)
  if (error) throw error
  return newCode
}
```

**앱에 없는 이유**: 앱은 초대코드를 수동 입력하므로 재생성 개념이 약했음
**권장**: 앱에도 재생성 기능 추가 (코드 유출 시 필수). 재생성 시에도 커스텀 코드 입력 또는 자동 생성 선택 가능

**주의**: 이 함수는 groups UPDATE RLS 정책이 없어 현재 실제로 동작하지 않을 가능성 높음 (섹션 2.1 참조)

### 3.4 useIsAdmin 훅 시그니처

**앱**:
```typescript
// useIsAdmin.ts (앱)
export function useIsAdmin() {
  const { user } = useAuth()
  const userId = user?.id
  const { data, isLoading } = useQuery({
    queryKey: ['app_admin', userId],
    queryFn: () => checkAppAdmin(userId ?? undefined),
    enabled: !!userId,
    staleTime: 1000 * 60,
  })
  const isAdmin = userId == null ? false : (data ?? null)
  return { isAdmin, isLoading }
}
```

**웹**:
```typescript
// useIsAdmin.ts (웹)
export function useIsAdmin(userId: string | null) {
  return useQuery({
    queryKey: ['isAdmin', userId],
    queryFn: () => checkAppAdmin(userId!),
    enabled: !!userId,
    staleTime: 60 * 1000,
  })
}
```

**불일치 정리**:
| 항목 | 앱 | 웹 |
|------|----|----|
| 인자 | 없음 (내부에서 useAuth) | `userId: string \| null` |
| queryKey | `['app_admin', userId]` | `['isAdmin', userId]` |
| 반환값 | `{ isAdmin: boolean\|null, isLoading }` | useQuery 원본 `{ data, isLoading, ... }` |
| null 처리 | `userId == null ? false : (data ?? null)` | `enabled: !!userId` (비활성화) |
| import 경로 | `shared/lib/admin.ts` | `features/admin/api/adminApi.ts` |

### 3.5 createGroupWithBoard API 구조

**앱 (`adminApi.ts`)**:
```typescript
interface CreateGroupWithBoardInput {
  name: string           // 100자 이내
  inviteCode: string     // 50자 이내, 필수
  description?: string   // 500자 이내
}

export async function createGroupWithBoard(input: CreateGroupWithBoardInput) {
  // 1. auth.getUser() → userId
  // 2. 입력 검증 (name, inviteCode 필수, 길이 제한)
  // 3. groups INSERT (invite_code = input.inviteCode)
  // 4. group_members INSERT (role='owner')
  // 5. boards INSERT (name='일반')
  // 반환: { groupId, inviteCode }
}
```

**웹 (`adminApi.ts`)**:
```typescript
export async function createGroupWithBoard(
  name: string,
  description: string,
  ownerId: string
) {
  // 1. inviteCode = Math.random()...
  // 2. groups INSERT (invite_code = 자동생성)
  // 3. boards INSERT (name='일반')
  // 4. group_members INSERT (role='owner')
  // 반환: Group 객체
}
```

**불일치 요약**:
| 항목 | 앱 | 웹 |
|------|----|----|
| 인자 | 객체 `{ name, inviteCode, description }` | 개별 `(name, description, ownerId)` |
| 초대코드 | 외부 입력 (필수) | 내부 자동 생성 (입력 불가) |
| userId 조회 | 함수 내부 `auth.getUser()` | 외부에서 `ownerId` 전달 |
| 입력 검증 | 있음 (길이 제한, 필수 체크, trim) | 없음 |
| INSERT 순서 | groups → members → boards | groups → boards → members |
| 반환값 | `{ groupId, inviteCode }` | `Group` 전체 객체 |
| 에러 클래스 | `APIError(status, message)` | `throw error` (Supabase 원본) |

### 3.6 로그인 후 네비게이션

| 항목 | 앱 | 웹 |
|------|----|----|
| 로그인 성공 | `replaceAdmin(router)` — 히스토리 교체, 뒤로가기로 로그인 돌아가지 않음 | `router.push('/admin')` — 히스토리 추가, 뒤로가기로 로그인 돌아감 |
| 이미 로그인 | `useEffect`에서 자동 `replaceAdmin` | 자동 리다이렉트 없음 |

**웹 문제**: 관리자가 로그인 후 브라우저 뒤로가기를 누르면 로그인 페이지로 돌아감 → 다시 자동 리다이렉트되지 않아 혼란 유발.
**권장**: 웹도 `router.replace('/admin')`로 변경.

### 3.7 로그아웃 후 처리

**앱**:
```typescript
await auth.signOut()
await auth.signInAnonymously()  // 익명 세션 재생성
router.replace('/(tabs)')
```

**웹**:
```typescript
await signOut()
router.push('/')  // 비인증 상태로 홈
```

**차이점**: 앱은 익명 사용자로 자동 재로그인하여 앱 기능(게시글 열람 등)을 계속 사용 가능. 웹은 비인증 상태로 홈 이동.

---

## 4. 동기화 권장 방안

### 4.1 groups UPDATE/DELETE RLS 정책 추가 (P0 — DB 버그 수정)

**변경 대상**: 중앙 마이그레이션 신규

```sql
-- groups UPDATE: owner만 수정 가능
CREATE POLICY "Owner can update own groups" ON public.groups FOR UPDATE
  USING ((SELECT auth.uid()) = owner_id)
  WITH CHECK ((SELECT auth.uid()) = owner_id);

-- groups DELETE: owner만 삭제 가능
CREATE POLICY "Owner can delete own groups" ON public.groups FOR DELETE
  USING ((SELECT auth.uid()) = owner_id);
```

이 정책 없이는 `deleteGroup()`, `regenerateInviteCode()` 모두 실제로 동작하지 않음.

### 4.2 invite_code 길이 CHECK 추가 (P0 — DB 안전장치)

```sql
ALTER TABLE groups ADD CONSTRAINT groups_invite_code_length
  CHECK (invite_code IS NULL OR length(invite_code) BETWEEN 4 AND 50);
```

### 4.3 초대코드: 선택 입력으로 통일 (앱/웹 모두 변경)

**변경 대상**: 앱 `adminApi.ts`, 앱 `admin/index.tsx`, 웹 `adminApi.ts`, 웹 `admin/page.tsx`

```typescript
// 공통 초대코드 생성 로직 (shared/로 이동 가능)
function generateInviteCode(): string {
  return Math.random().toString(36).slice(2, 8).toUpperCase()
}
```

**통일 로직**: 입력하면 커스텀 코드 사용, 비우면 자동 생성
```typescript
// createGroupWithBoard 내부
const finalCode = inviteCode?.trim() || generateInviteCode()
```

앱 그룹 생성 폼:
- 초대코드 입력 필드 **유지하되 필수 → 선택으로 변경**
- placeholder: "비워두면 자동 생성됩니다"
- 생성 완료 시 최종 코드 표시 + 공유 버튼

웹 그룹 생성 폼:
- 초대코드 입력 필드 **추가 (선택)**
- placeholder: "비워두면 자동 생성됩니다"
- 생성 완료 시 최종 코드 표시 + 복사 버튼

### 4.4 초대코드 재생성: 앱에 추가

**변경 대상**: 앱 `adminApi.ts`, 앱 `admin/index.tsx`

```typescript
// adminApi.ts (앱에 추가)
export async function regenerateInviteCode(groupId: number): Promise<string> {
  const newCode = generateInviteCode()
  const { error } = await supabase
    .from('groups')
    .update({ invite_code: newCode })
    .eq('id', groupId)
  if (error) throw new APIError(500, error.message)
  return newCode
}
```

그룹 목록의 각 카드에 "코드 재생성" 버튼 추가.

### 4.5 웹 로그인 후 네비게이션 수정

```typescript
// 현재 (웹 admin/login/page.tsx)
router.push('/admin')

// 수정
router.replace('/admin')  // 뒤로가기 시 로그인으로 돌아가지 않도록
```

### 4.6 입력 검증: 웹에 추가

**변경 대상**: 웹 `adminApi.ts`, 웹 `admin/page.tsx`

현재 웹은 `required` HTML 속성만 사용. 앱의 검증 로직을 웹에도 적용:
- 그룹명: 100자 이내 + trim
- 설명: 500자 이내
- 초대코드 (입력 시): 4~50자, 대문자 변환

### 4.7 삭제 확인 메시지: 통일

**통일 문구**: "그룹의 모든 게시글과 댓글이 함께 삭제됩니다."

### 4.8 queryKey 통일

| 훅 | 앱 현재 | 웹 현재 | 통일안 |
|-----|---------|---------|--------|
| useIsAdmin | `['app_admin', userId]` | `['isAdmin', userId]` | `['admin', 'isAdmin', userId]` |
| useAdminGroups | `['admin', 'myManagedGroups']` | `['admin', 'myManagedGroups', userId]` | `['admin', 'managedGroups', userId]` |

### 4.9 API 함수 시그니처: 장기적으로 shared/ 패턴 도입 검토

현재는 앱/웹이 각각 `adminApi.ts`를 독립적으로 관리. 로직이 달라지는 근본 원인.

**단기**: 각 레포의 API를 수동으로 맞춤
**장기**: `shared/admin-api.ts`를 중앙에서 관리하고 sync하는 방안 검토 (단, Supabase 클라이언트 생성 방식이 앱/웹 다르므로 완전 공유는 어려움)

---

## 5. 우선순위별 작업 목록

### P0: DB 레벨 버그 (즉시 수정)

| # | 작업 | 대상 | 이유 |
|---|------|------|------|
| 1 | groups UPDATE/DELETE RLS 정책 추가 | 중앙 마이그레이션 | `deleteGroup()`, `regenerateInviteCode()` 조용히 실패 중 |
| 2 | invite_code 길이 CHECK 제약 추가 | 중앙 마이그레이션 | DB 레벨 입력 검증 없음 |

### P1: 기능 불일치 (반드시 수정)

| # | 작업 | 대상 | 이유 |
|---|------|------|------|
| 3 | 앱/웹 초대코드를 선택 입력으로 통일 | 앱/웹 adminApi.ts, admin 페이지 | 같은 관리자가 앱/웹에서 다른 경험 |
| 4 | 앱에 초대코드 재생성 기능 추가 | 앱 adminApi.ts, admin/index.tsx | 코드 유출 시 대응 수단 없음 |
| 5 | 앱에 초대코드 복사 기능 추가 | 앱 admin/index.tsx | `Clipboard.setStringAsync()` |
| 6 | 웹 로그인 후 `router.push` → `router.replace` | 웹 admin/login/page.tsx | 뒤로가기 시 로그인으로 돌아감 |

### P2: 품질 불일치 (권장)

| # | 작업 | 대상 | 이유 |
|---|------|------|------|
| 7 | 웹에 입력 검증 추가 (길이 제한, trim) | 웹 adminApi.ts, admin/page.tsx | 검증 없이 DB 에러 의존은 위험 |
| 8 | 삭제 확인 메시지 통일 | 앱/웹 admin 페이지 | UX 일관성 |
| 9 | 웹 라우트 보호 강화 (layout 패턴) | 웹 admin/layout.tsx 신규 | 앱은 _layout.tsx 보호, 웹은 없음 |

### P3: 코드 품질 (선택)

| # | 작업 | 대상 | 이유 |
|---|------|------|------|
| 10 | queryKey 네이밍 통일 | 앱/웹 hooks | 디버깅/캐시 관리 일관성 |
| 11 | useIsAdmin 시그니처 통일 | 앱/웹 hooks | 코드 패턴 일관성 |
| 12 | 웹에 adminApi 테스트 추가 | 웹 tests/ | 앱에는 있고 웹에 없음 |
| 13 | 에러 처리 패턴 통일 | 앱/웹 adminApi | APIError vs raw throw |

---

## 6. 구현 변경 상세

### 6.1 마이그레이션: groups RLS + invite_code CHECK

```sql
-- 파일: supabase/migrations/YYYYMMDDHHMMSS_fix_groups_rls.sql

-- groups UPDATE: owner만 수정 가능
DROP POLICY IF EXISTS "Owner can update own groups" ON public.groups;
CREATE POLICY "Owner can update own groups" ON public.groups FOR UPDATE
  USING ((SELECT auth.uid()) = owner_id)
  WITH CHECK ((SELECT auth.uid()) = owner_id);

-- groups DELETE: owner만 삭제 가능
DROP POLICY IF EXISTS "Owner can delete own groups" ON public.groups;
CREATE POLICY "Owner can delete own groups" ON public.groups FOR DELETE
  USING ((SELECT auth.uid()) = owner_id);

-- invite_code 길이 제약
ALTER TABLE groups DROP CONSTRAINT IF EXISTS groups_invite_code_length;
ALTER TABLE groups ADD CONSTRAINT groups_invite_code_length
  CHECK (invite_code IS NULL OR length(invite_code) BETWEEN 4 AND 50);
```

### 6.2 그룹 생성 폼 수정 (앱/웹 통일)

**앱 현재 (3필드)**:
```
[그룹 이름]     필수
[초대 코드]     필수, 수동 입력
[설명]          선택
[그룹 생성]
```

**웹 현재 (2필드)**:
```
[그룹 이름]     필수
[설명]          선택
[그룹 생성]
→ 초대 코드 자동 생성 (관리자 지정 불가)
```

**통일 후 (앱/웹 동일, 3필드)**:
```
[그룹 이름]     필수
[초대 코드]     선택, "비워두면 자동 생성됩니다"
[설명]          선택
[그룹 생성]
→ 생성 완료 시 최종 초대 코드 표시 + 공유/복사 버튼
```

**변경 포인트**:
- 앱: `inviteCode` 필수 → 선택으로 변경, placeholder 추가
- 웹: `inviteCode` 입력 필드 신규 추가 (선택)
- 앱/웹 공통: 미입력 시 `generateInviteCode()` 자동 생성

### 6.3 앱 그룹 카드 수정

**현재**:
```
+-------------------------------+
| 그룹명                         |
| 설명 (2줄)                     |
| 코드: XXXX · 2026.03.07       |
| [공유] [삭제]                   |
+-------------------------------+
```

**수정 후**:
```
+-------------------------------+
| 그룹명                         |
| 설명 (2줄)                     |
| 코드: XXXXXX · 2026.03.07     |
| [복사] [재생성] [공유] [삭제]   |
+-------------------------------+
```

### 6.4 웹 라우트 보호 강화

**현재**: `admin/layout.tsx` 없음 — `admin/page.tsx` 내부에서 조건부 렌더링

**권장**: layout 레벨 보호 추가

```tsx
// admin/layout.tsx (신규)
'use client'

import { useRouter } from 'next/navigation'
import { useEffect } from 'react'
import { useAuth } from '@/features/auth/useAuth'
import { useIsAdmin } from '@/features/admin/hooks/useIsAdmin'

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter()
  const { user, isLoading: authLoading } = useAuth()
  const { data: isAdmin, isLoading: adminLoading } = useIsAdmin(user?.id ?? null)

  useEffect(() => {
    if (authLoading || adminLoading) return
    if (!user) { router.replace('/admin/login'); return }
    if (isAdmin === false) { router.replace('/'); return }
  }, [authLoading, adminLoading, user, isAdmin, router])

  if (authLoading || adminLoading) return <div className="min-h-screen flex items-center justify-center">확인 중...</div>
  if (!user || !isAdmin) return null

  return <>{children}</>
}
```

---

## 7. DESIGN-admin-longpress.md와의 연계

롱프레스 히든 도어 설계 시 고려해야 할 추가 사항 (본 검증에서 발견):

| 항목 | 현재 상태 | 롱프레스 전환 시 필요 작업 |
|------|----------|------------------------|
| 홈 헤더 "관리자" 버튼 | `isAdmin=true`일 때 ScreenHeader 우측 노출 | **제거 필요** — 롱프레스로 대체 |
| 설정 탭 "운영자 관리 페이지" | 설정 탭에서 링크 | 설정 탭 자체 제거로 자동 해소 |
| 웹 진입점 | URL 직접 입력만 | AdminSecretTap 추가로 해소 |

---

## 8. 파일 경로 참조

### 앱 (gns-hermit-comm)
```
src/app/(tabs)/_layout.tsx          — 탭 구조
src/app/(tabs)/settings.tsx         — 설정 탭 (관리자 진입점)
src/app/(tabs)/index.tsx            — 홈 (ScreenHeader에 관리자 버튼)
src/app/admin/_layout.tsx           — 관리자 라우트 보호
src/app/admin/login.tsx             — 관리자 로그인
src/app/admin/index.tsx             — 관리자 대시보드
src/features/admin/api/adminApi.ts  — API 함수 (create/delete/getGroups)
src/features/admin/hooks/useIsAdmin.ts     — 권한 체크 훅
src/features/admin/hooks/useDeleteGroup.ts — 그룹 삭제 훅
src/shared/lib/admin.ts            — checkAppAdmin 헬퍼
src/shared/lib/navigation.ts       — push/replaceAdmin 함수
```

### 웹 (web-hermit-comm)
```
src/app/admin/page.tsx              — 관리자 대시보드
src/app/admin/login/page.tsx        — 관리자 로그인
src/app/admin/layout.tsx            — 없음 (추가 필요)
src/features/admin/api/adminApi.ts  — API 함수 (5개)
src/features/admin/hooks/useIsAdmin.ts     — 권한 체크 훅
src/features/admin/hooks/useAdminGroups.ts — 그룹 목록+삭제 훅
src/components/layout/Header.tsx    — 관리자 코드 없음
src/components/layout/BottomNav.tsx — 관리자 코드 없음
```

### 중앙 (supabase-hermit)
```
supabase/migrations/20260301000001_schema.sql   — app_admin, groups 테이블
supabase/migrations/20260301000002_rls.sql      — app_admin/groups RLS
supabase/migrations/20260303000001_core_redesign.sql — invite_code UNIQUE
supabase/migrations/20260310000001_comprehensive_improvements.sql — soft_delete admin 체크
shared/types.ts                                 — AppAdmin 인터페이스
```

---

## 9. 요약

### 동기화 현황

- **동일한 부분**: 로그인 방식 (signInWithPassword), DB 스키마/타입, 기본 기능 범위 (그룹 CRUD)
- **DB 레벨 버그**: groups UPDATE/DELETE RLS 정책 누락 → 그룹 삭제/초대코드 재생성이 조용히 실패
- **핵심 불일치**: 초대코드 생성 방식 (수동 필수 vs 자동 고정), 재생성 기능 유무, 관리자 진입점, 로그인 네비게이션
- **품질 차이**: 앱이 입력 검증/에러 처리/라우트 보호/테스트에서 우위

### 동기화 방향

1. **DB 먼저 수정**: groups RLS 정책 추가 (없으면 앱/웹 모두 삭제/수정 불가)
2. 앱/웹 각각의 장점을 교차 적용:
   - 앱 → 웹: 입력 검증, 라우트 보호 패턴 (layout.tsx), 테스트
   - 웹 → 앱: 재생성 기능, 클립보드 복사, 생성 폼 토글
3. 통일: 초대코드 선택 입력 (입력하면 커스텀, 비우면 자동 생성)
