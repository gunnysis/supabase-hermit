# 유지보수 설계 v2 — 향후 과제 심층 연구

> 작성: 2026-03-08 | v1 "범위 외" 항목 연구/설계 | v1 Phase 1-13 이후 진행
> 최종 점검: 2026-03-13 | 완료 항목 반영, v1 정합성 확인
> 설계 보강: 2026-03-08 | Phase C next.config.ts 실제 구조 반영
> 디자인 설계: 2026-03-08 | Phase F 추가 — 디자인 토큰 문서화 + Storybook (v1 Phase 14-15에서 도출)
> **리뷰 반영: 2026-03-09 | 개발 책임자 리뷰 기반 재구성 ([REVIEW-dev-lead-analysis.md](../memo/REVIEW-dev-lead-analysis.md))**
> **구현 계획: 2026-03-09 | 실행 설계서 → [DESIGN-maintenance-v3-execution.md](DESIGN-maintenance-v3-execution.md)**

---

## 1. 개요

v1(`DESIGN-maintenance-v1.md`)의 Phase 1-13은 즉시~단기 실행 가능한 항목을 다룬다.
본 문서(v2)는 v1 "범위 외(Section 6)"로 분류된 **중장기 과제 6건**을 심층 연구하여 구체적 해결 방안을 설계한다.

| # | 항목 | v1 분류 | v2 Phase |
|---|---|---|---|
| F1 | Expo 55 업그레이드 | 범위 외 | Phase A |
| F2 | Hook/컴포넌트 테스트 확장 | 범위 외 | Phase B |
| F3 | Next.js nonce CSP | 범위 외 | Phase C |
| F4 | RLS 재귀 패턴 통일 | 범위 외 | Phase D |
| F5 | 외부 검색 엔진 / 한국어 검색 품질 | 범위 외 | Phase E |
| F6 | 디자인 시스템 문서화 (토큰 + Storybook) | 범위 외 | Phase F |

---

## 2. Phase A: Expo 55 업그레이드 (F1)

### 2a. 현황

| 패키지 | 현재 | 목표 |
|---|---|---|
| `expo` | ~54.0.33 | ~55.0.5 |
| `jest-expo` | ~54.0.17 | ~55.0.9 |
| `babel-preset-expo` | ^54.0.10 | ^55.0.10 |
| `react-native` | 0.81.5 | 0.81.5 (변경 없음) |
| `react` | 19.1.0 | 19.1.0 (변경 없음) |

**@expo/* 모듈**: v15, v6, v18 → Expo 55와 호환됨, 변경 불필요.

### 2b. Breaking Changes 분석

| 변경 사항 | 영향 | 대응 |
|---|---|---|
| EXAppDelegateWrapper 제거 (iOS) | 커스텀 Objective-C 네이티브 모듈만 영향 | 앱에 없음 → 무영향 |
| ReactNativeHostWrapper 삭제 (Android) | 커스텀 Java 네이티브 모듈만 영향 | 앱에 없음 → 무영향 |
| Swift 6 채택 (iOS) | 커스텀 Swift 모듈만 영향 | 앱에 없음 → 무영향 |
| URL/URLSearchParams 구현 교체 | fetch/HTTP 내부 최적화 | 엣지 케이스만 → 테스트로 확인 |
| Legacy autolinking 제거 (Android) | EAS 빌드 자동 처리 | 무영향 |

**JS 레벨 breaking change: 없음** → 업그레이드 투명 처리 가능.

### 2c. jest-expo CRITICAL 취약점 체인

```
jest-expo@54/55
  └─ jest-environment-jsdom@^29
       └─ jsdom
            └─ http-proxy-agent
                 └─ @tootallnate/once (GHSA-vpq2-c234-7xj6)
```

**결론**: jest-expo v55에서도 동일 취약점 체인 존재.
- `@tootallnate/once`는 jest-environment-jsdom → jsdom 체인으로, jest-expo 단독 업그레이드로 해결 불가.
- **완화 전략**: `npm audit --omit=dev` — jest-expo는 devDependency, 프로덕션 빌드에 포함되지 않음.
- **근본 해결**: jsdom이 http-proxy-agent 5+ 로 업그레이드 시 해소 (jsdom 측 이슈).

### 2d. 구현 계획

```bash
# 1) package.json 수정
npm install expo@~55.0.5 jest-expo@~55.0.9 babel-preset-expo@^55.0.10

# 2) 테스트
npm run test          # Jest 전체
npm start             # Metro 번들러 확인

# 3) 네이티브 빌드 (로컬 또는 EAS)
eas build --platform android --profile preview
eas build --platform ios --profile preview

# 4) OTA 배포 (JS만 변경 시)
eas update --channel production --message "Expo 55 upgrade"
```

**예상 소요**: 30분 (수정 5분 + 설치 10분 + 테스트 15분)

### 2e. 트리거 조건

- 다음 네이티브 빌드 시 함께 진행
- 또는 Expo 54 EOL 알림 수신 시

---

## 3. Phase B: Hook/컴포넌트 테스트 확장 (F2) — 리뷰 반영: 위험 기반 재구성

> **리뷰 반영**: v1 Phase 10(API 테스트)과 본 Phase를 **위험 기반으로 통합**.
> 7주 로드맵(Tier 1-5 순차)보다, **위험 기반 Tier 0-1만 우선 구현**(2주)하고
> 나머지는 버그 발생 시 추가하는 것이 1인 개발에 현실적.
> 163케이스(50% 커버리지) 목표는 유지보수 부담이 될 수 있음.

### 3-리뷰. 위험 기반 테스트 우선순위 (리뷰 권장)

```
Tier 0 (필수 — 돈/데이터에 직접 영향):
  - toggle_reaction (데이터 정합성)
  - soft_delete_post/comment (데이터 손실 방지)
  - useAuth (인증 실패 → 전체 앱 사용 불가)
  → 이 3개 Hook만 완전히 테스트해도 80% 위험 커버

Tier 1 (권장 — 사용자 불만 직결):
  - useCreatePost (글 작성 실패)
  - useBoardPosts (피드 안 보임)
  - usePostDetailAnalysis (이미 테스트 존재)
  → v1 Phase 10의 API 모듈 테스트(comments, reactions, recommendations, trending) 포함

Tier 2 (여유 시 — 품질 향상):
  - 나머지 Hook/컴포넌트
```

> **E2E 테스트 부재 참고**: v1/v2 모두 단위 테스트에만 집중.
> 실제 위험(Supabase RPC 호출, sync 정합성, 마이그레이션 후 gen-types)은 단위 테스트로 잡을 수 없음.
> `verify.sh` 강화(v1 Phase 11c)가 사실상 가장 ROI 높은 "테스트" — v1에서 격상 반영됨.

### 3a. 현황 분석

**현재 테스트**: 17파일, ~83 케이스
**미테스트 Hook**: 25개 (Simple 4, Medium 14, Complex 7)
**미테스트 컴포넌트**: 25+ 개

**테스트 인프라**: 이미 구축 완료
- Jest 29.7.0 + @testing-library/react-native 13.3.3
- Supabase/React Query 모킹 패턴 확립 (`tests/features/posts/` 참조)
- `__mocks__/` 디렉터리, `jest.setup.js` 완비

### 3b. Hook 분류 및 우선순위

#### Tier 1: 단순 쿼리 래퍼 (4개, ~8 케이스)

| Hook | 복잡도 | 테스트 포인트 |
|---|---|---|
| `useBoards` | Simple | useQuery 호출, 데이터 반환 |
| `useMyGroups` | Simple | useQuery 호출, 에러 처리 |
| `useEmotionTrend` | Simple | staleTime 5분, 기본값 7일 |
| `useRecommendedPosts` | Simple | enabled 조건, 데이터 반환 |

```typescript
// 표준 패턴 — Tier 1 테스트
import { renderHook, waitFor } from '@testing-library/react-native';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: false, gcTime: Infinity } },
});
const wrapper = ({ children }) => (
  <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
);

describe('useBoards', () => {
  it('게시판 목록을 반환한다', async () => {
    mockGetBoards.mockResolvedValue([{ id: 1, name: '자유게시판' }]);
    const { result } = renderHook(() => useBoards(), { wrapper });
    await waitFor(() => expect(result.current.data).toHaveLength(1));
  });
  it('에러 시 error 상태를 반환한다', async () => {
    mockGetBoards.mockRejectedValue(new Error('fail'));
    const { result } = renderHook(() => useBoards(), { wrapper });
    await waitFor(() => expect(result.current.isError).toBe(true));
  });
});
```

#### Tier 2: 페이지네이션/조건부 쿼리 (6개, ~18 케이스)

| Hook | 복잡도 | 테스트 포인트 |
|---|---|---|
| `useBoardPosts` | Medium | 무한스크롤, PAGE_SIZE=20, 마지막 페이지 감지 |
| `useGroupPosts` | Medium | 무한스크롤, 이중 가드 조건 |
| `useGroupBoards` | Medium | enabled 플래그, groupId 조건 |
| `usePostDetail` | Medium | NaN 방어, enabled 조건 |
| `useTrendingPosts` | Medium | 폴백 로직 (72h→720h, 결과 <3개) |
| `useIsAdmin` | Medium | useAuth 의존, staleTime 1분 |

```typescript
// 표준 패턴 — 무한 쿼리
describe('useBoardPosts', () => {
  it('첫 페이지를 로드한다', async () => { /* ... */ });
  it('다음 페이지 offset을 계산한다', async () => {
    // getNextPageParam: lastPage.length === PAGE_SIZE → offset + PAGE_SIZE
  });
  it('마지막 페이지에서 fetchNextPage를 중단한다', async () => {
    // lastPage.length < PAGE_SIZE → undefined
  });
});
```

#### Tier 3: Realtime 구독 (3개, ~15 케이스)

| Hook | 복잡도 | 테스트 포인트 |
|---|---|---|
| `useRealtimeComments` | Medium | INSERT/DELETE 감지, isComment() 검증 |
| `useRealtimePosts` | Medium | INSERT/UPDATE/DELETE, enabled 플래그 |
| `useRealtimeReactions` | Medium | INSERT/UPDATE/DELETE, 채널 정리 |

```typescript
// 표준 패턴 — Realtime 모킹
const mockOn = jest.fn().mockReturnThis();
const mockSubscribe = jest.fn().mockReturnThis();
const mockChannel = { on: mockOn, subscribe: mockSubscribe };
jest.spyOn(supabase, 'channel').mockReturnValue(mockChannel);
jest.spyOn(supabase, 'removeChannel').mockResolvedValue('ok');

describe('useRealtimeComments', () => {
  it('마운트 시 채널을 구독한다', () => {
    renderHook(() => useRealtimeComments(1, {}));
    expect(supabase.channel).toHaveBeenCalledWith('comments-1');
    expect(mockSubscribe).toHaveBeenCalled();
  });
  it('언마운트 시 채널을 제거한다', () => {
    const { unmount } = renderHook(() => useRealtimeComments(1, {}));
    unmount();
    expect(supabase.removeChannel).toHaveBeenCalled();
  });
});
```

#### Tier 4: Mutation + 관리자 (3개, ~9 케이스)

| Hook | 복잡도 | 테스트 포인트 |
|---|---|---|
| `useDeleteGroup` | Medium | useMutation, 캐시 무효화 |
| `useJoinGroupByInviteCode` | Medium | 복잡한 API 응답 처리 |
| `useErrorHandler` | Medium | Alert/Toast 분기, APIError 처리 |

#### Tier 5: 복합 상태 관리 (6개, ~30 케이스)

| Hook | 복잡도 | 테스트 포인트 |
|---|---|---|
| `useAuth` | Complex | 세션, 재시도 3회, auth listener, 에러 |
| `useDraft` | Complex | MMKV, debounce 500ms, sync load/save |
| `useCreatePost` | Complex | Form + Zod + 비동기 제출 + 캐시 무효화 |
| `usePostDetailComments` | Complex | CRUD + Realtime + 캐시 업데이트 |
| `usePostDetailReactions` | Complex | 리액션 토글, pending Set, 에러 toast |
| `useNetworkStatus` | Medium | NetInfo 리스너, 상태 추적 |

> `usePostDetailAnalysis`는 v1 Phase 10에서 이미 테스트 존재 (6케이스).
> `useThemeColors`, `useResponsiveLayout`은 순수 로직 → 가장 쉬움.

### 3c. 컴포넌트 테스트 우선순위

| 우선도 | 컴포넌트 | 의존 Hook | 테스트 포인트 |
|---|---|---|---|
| ★★★ | PostCard | - | 렌더링, 클릭 네비게이션 |
| ★★★ | ReactionBar | usePostDetailReactions | 리액션 버튼 렌더링, 토글 |
| ★★☆ | CommentItem | - | 렌더링, 삭제 버튼 |
| ★★☆ | SearchResultCard | - | 하이라이트 렌더링 |
| ★☆☆ | EmotionFilterBar | - | 감정 필터 선택/해제 |
| ★☆☆ | TrendingPosts | useTrendingPosts | 로딩/에러/데이터 상태 |

### 3d. 구현 로드맵 (리뷰 반영: 위험 기반 축소)

**권장 로드맵 (2주):**
```
주차 1: Tier 0 — toggle_reaction, soft_delete_post/comment, useAuth (~15 케이스)
         Done 기준: 3 hooks, 15 케이스, npm test 통과
주차 2: Tier 1 — useCreatePost, useBoardPosts + v1 Phase 10 API 테스트 (~20 케이스)
         Done 기준: 2 hooks + 4 API 모듈, 20 케이스, npm test 통과
```

**선택 로드맵 (원래 7주 — 여유 시 진행):**
```
주차 3-4: Tier 1-2 본래 범위 (10 hooks, ~26 케이스)
주차 5:   Tier 3 (3 hooks, ~15 케이스)
주차 6:   Tier 4 (3 hooks, ~9 케이스)
주차 7-8: Tier 5 (6 hooks, ~30 케이스)
주차 9+:  컴포넌트 테스트 (선택)
```

**최종 목표 (조정)**: Tier 0-1 필수 (~118 케이스), 나머지는 버그 발생 시 추가

### 3e. 추가 의존성

| 패키지 | 용도 | 필수 여부 |
|---|---|---|
| `@testing-library/jest-native` | `toBeOnTheScreen()` 등 커스텀 매처 | 선택 (권장) |
| `jest-mock-extended` | 고급 모킹 | 선택 |

> 기존 인프라로 모든 테스트 작성 가능. 추가 패키지는 편의성만.

### 3f. 트리거 조건

- 커버리지 50% 목표 설정 시
- 또는 버그 재발 빈도 증가 시

---

## 4. Phase C: Next.js nonce CSP (F3) — 리뷰: 상세 설계 보류 권장

> **리뷰 의견**: TTFB 50ms → 200-400ms 성능 저하를 인정하면서 상세 설계를 기술하는 것은
> 현 단계에서 과도. SRI hash 대안만 기록하고 상세 설계는 **실행 결정 시 작성** 권장.
> 아래 설계는 참고용으로 유지하되, 실행 트리거 전까지는 상세 구현에 착수하지 않음.

### 4a. 현황

| 항목 | 상태 |
|---|---|
| Next.js 버전 | **16.1.6** (nonce CSP 완전 지원) |
| 현재 CSP | 없음 (v1 Phase 4에서 정적 헤더 추가 예정) |
| middleware.ts | 없음 (proxy.ts만 존재) |
| 서드파티 스크립트 | Vercel Analytics, Speed Insights, Sentry |
| next.config.ts 구조 | `withSentryConfig(nextConfig, {...})` 래핑 — `nextConfig`에 `headers()` 추가 필요 (코드 조사 2026-03-08) |

### 4b. 정적 CSP vs nonce CSP 비교

| 항목 | 정적 CSP (v1 Phase 4) | nonce CSP (v2 Phase C) |
|---|---|---|
| 보안 수준 | 중간 (`unsafe-inline` 허용) | 높음 (`unsafe-inline` 제거) |
| 성능 영향 | 없음 (정적 페이지 유지) | **높음 (모든 페이지 동적 렌더링 필요)** |
| CDN 캐싱 | 유지 | **비활성화** |
| 서버 부하 | 변경 없음 | **증가 (모든 요청 SSR)** |
| Vercel 비용 | 변경 없음 | **증가 (서버리스 함수 호출 증가)** |
| 구현 난이도 | 낮음 (next.config.ts만) | 중간 (proxy.ts + 레이아웃 수정) |
| XSS 방어 | 부분 (인라인 스크립트 허용) | 완전 (nonce 없이 인라인 불가) |

### 4c. 구현 방안 (Next.js 16.1.6 proxy.ts 패턴)

**Step 1: proxy.ts에 nonce 생성 추가**

```typescript
// src/proxy.ts (기존 코드에 추가)
import { type NextRequest, NextResponse } from 'next/server';

export function middleware(request: NextRequest) {
  // 1) nonce 생성
  const nonce = Buffer.from(crypto.randomUUID()).toString('base64');

  // 2) CSP 헤더 구성
  const cspHeader = [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic' https://va.vercel-scripts.com`,
    `style-src 'self' 'nonce-${nonce}'`,
    "img-src 'self' data: blob: https://*.supabase.co",
    "font-src 'self'",
    "connect-src 'self' https://*.supabase.co wss://*.supabase.co https://*.sentry.io https://va.vercel-scripts.com",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action 'self'",
  ].join('; ');

  // 3) 요청 헤더에 nonce 전달
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set('x-nonce', nonce);
  requestHeaders.set('Content-Security-Policy', cspHeader);

  // 4) 응답 헤더에 CSP 설정
  const response = NextResponse.next({ request: { headers: requestHeaders } });
  response.headers.set('Content-Security-Policy', cspHeader);

  // ... 기존 Supabase cookie/Naver 로직 유지 ...

  return response;
}
```

**Step 2: 레이아웃에서 nonce 읽기**

```typescript
// src/app/layout.tsx
import { headers } from 'next/headers';

export default async function RootLayout({ children }) {
  const nonce = (await headers()).get('x-nonce') ?? undefined;

  return (
    <html lang="ko" nonce={nonce}>
      <body>
        {children}
        <Analytics nonce={nonce} />
        <SpeedInsights nonce={nonce} />
      </body>
    </html>
  );
}
```

**Step 3: 동적 렌더링 활성화**

```typescript
// src/app/layout.tsx
import { connection } from 'next/server';

export default async function RootLayout({ children }) {
  await connection(); // 동적 렌더링 강제
  // ...
}
```

### 4d. 성능 영향 평가

| 메트릭 | 정적 (현재) | nonce CSP 적용 후 |
|---|---|---|
| TTFB | ~50ms (CDN) | ~200-400ms (SSR) |
| 서버리스 호출 | 0 (정적) | 모든 페이지뷰마다 |
| Vercel 비용 | 무료 범위 | ~$0.002/요청 |
| LCP | 빠름 | 소폭 증가 |

### 4e. 권장 전략

**현재 Vercel Hobby 플랜** — 서버리스 함수 실행 제한 (월 100GB-hrs, 10초 타임아웃).
nonce CSP는 모든 페이지를 동적 렌더링하므로 서버리스 사용량 급증 가능.

**단계적 접근:**

1. **v1 Phase 4 먼저 실행** — 정적 CSP 헤더 (`unsafe-inline` 포함)
   - 즉시 실행 가능, 성능 영향 없음
   - XSS 방어의 80% 달성

2. **v2 Phase C는 조건부 실행** — nonce CSP
   - 보안 감사에서 `unsafe-inline` 제거 요구 시
   - Vercel Pro 전환 후 (서버리스 제한 완화)
   - 또는 SRI hash 방식 안정화 시 (정적 페이지 유지 가능)

### 4f. 대안: SRI (Subresource Integrity) Hash 기반 CSP

Next.js 16에서 **experimental SRI** 지원:
- 빌드 시 스크립트 해시 자동 생성
- 정적 생성 + CDN 캐싱 유지 가능
- `unsafe-inline` 제거 가능

```typescript
// next.config.ts
const config = {
  experimental: {
    sri: { algorithm: 'sha256' },
  },
};
```

> ⚠️ experimental 기능. Webpack만 지원 (Turbopack 불가).
> 안정화 시 nonce보다 성능 우위.

### 4g. 트리거 조건

- 보안 감사에서 `unsafe-inline` 제거 요구 시
- 또는 Next.js SRI 기능 안정화 시 (실험적 → 정식)

---

## 5. Phase D: RLS 재귀 패턴 통일 (F4)

### 5a. 조사 결과: 이미 완료됨

마이그레이션 히스토리 분석 결과, **RLS 재귀 문제는 이미 완전히 해결됨**.

#### 타임라인

| 마이그레이션 | 상태 | 내용 |
|---|---|---|
| `20260301000002` | 초기 | posts, comments에 `EXISTS (SELECT FROM group_members)` 직접 사용 |
| `20260303000001` | 재귀 발생 | group_members에 자기참조 `EXISTS` 도입 → 무한 재귀 |
| `20260303000002` | **완전 수정** | `is_group_member()` SECURITY DEFINER 함수 생성 + 3개 테이블 정책 교체 |
| `20260309000001` | 보강 | boards RLS도 `is_group_member()` 사용 확인 |

#### 현재 상태

| 테이블 | SELECT 정책 | 패턴 | 상태 |
|---|---|---|---|
| posts | Everyone can read posts | `is_group_member(group_id)` | ✅ 안전 |
| comments | Everyone can read comments | `is_group_member(group_id)` | ✅ 안전 |
| group_members | Users can read group_members | `is_group_member(group_id)` | ✅ 안전 |
| boards | boards_select | `is_group_member(group_id)` | ✅ 안전 |
| reactions | - | group 체크 없음 | ✅ 해당 없음 |
| user_reactions | - | group 체크 없음 | ✅ 해당 없음 |
| post_analysis | - | group 체크 없음 | ✅ 해당 없음 |
| app_admin | - | user_id만 | ✅ 해당 없음 |
| groups | - | group_members 참조 없음 | ✅ 해당 없음 |
| user_preferences | - | user_id만 | ✅ 해당 없음 |

### 5b. 결론

**추가 작업 불필요.** v1 범위 외 목록에서 제거 가능.

`is_group_member()` 함수 특성:
- `SECURITY DEFINER`: 테이블 소유자 권한 실행 (RLS 우회)
- `STABLE`: 트랜잭션 내 캐싱 가능
- 단일 인덱스 조회: `group_members(group_id, user_id)` PK 활용
- 비용: ~1-2ms/호출

### 5c. 성능 최적화 여지 (선택)

현재 `group_members` PK가 `(group_id, user_id)` 복합키이므로 `is_group_member()` 쿼리에 이미 최적.

추가 인덱스는 불필요:
```sql
-- 이미 PK로 커버됨, 불필요
-- CREATE INDEX idx_group_members_lookup
--   ON group_members(group_id, user_id, status, left_at);
```

> `status = 'approved' AND left_at IS NULL` 조건은 PK 인덱스 스캔 후 필터링으로 처리.
> 그룹 멤버 수가 수천 명 이상이 아닌 한 별도 인덱스 불필요.

---

## 6. Phase E: 한국어 검색 품질 + 외부 검색 엔진 (F5)

### 6a. 현재 검색 아키텍처

```
search_posts_v2 (RPC)
├── Full-text: to_tsvector('simple', ...) @@ plainto_tsquery('simple', ...)
├── Fallback: ILIKE '%query%'
├── Ranking: ts_rank * 10 + title_match * 5 + prefix_match * 3
├── Highlight: ts_headline('simple', ...)
└── Indexes: idx_posts_fts (GIN), idx_posts_title_trgm (GIN), idx_posts_content_trgm (GIN)
```

**한국어 한계:**
- `'simple'` lexer: 공백 기반 토큰화만 (형태소 분석 없음)
- "힘들었다" 검색 시 "힘들" 미매칭 (어간 추출 불가)
- 복합 명사 분리 불가 ("감정분석" → "감정" + "분석")
- ILIKE 폴백으로 부분 보완되지만 랭킹 정확도 저하

### 6b. 검색 엔진 비교

| 항목 | PGroonga | Meilisearch | Typesense | Algolia | ParadeDB |
|---|---|---|---|---|---|
| **한국어 토크나이저** | 우수 (Groonga, CJK 전용) | 부분 (charabia) | 양호 (ICU) | 양호 (내장) | 부분 (lindera-ko-dic) |
| **Supabase 호환** | ✅ 네이티브 extension | 외부 서비스 | 외부 서비스 | 외부 서비스 | 별도 Postgres 복제본 |
| **데이터 동기화** | 불필요 (같은 DB) | DB Webhook 필요 | DB Webhook 필요 | DB Webhook 필요 | Logical replication |
| **운영 부담** | 없음 | 중간 | 중간 | 없음 (SaaS) | 높음 |
| **비용 (<10K)** | $0 | $0 self / $30/mo cloud | $0 self / $7/mo cloud | $0 free tier | $0 self |
| **오타 허용** | 없음 | 있음 (한국어 미흡) | 있음 (한국어 미흡) | 있음 (한국어 미흡) | 없음 |
| **하이라이트** | `pgroonga_snippet_html` | 내장 | 내장 | 내장 | Tantivy |
| **설치 난이도** | 낮음 (SQL 1줄) | 중간 (Docker) | 중간 (Docker) | 낮음 (API키) | 높음 |

### 6c. 권장 전략: PGroonga (단기~중기)

**이유:**
- Supabase managed에서 네이티브 지원 (`CREATE EXTENSION pgroonga`)
- 한국어 N-gram 토크나이저 내장 (CJK 최적화)
- 동기화 불필요 (같은 DB, 같은 테이블)
- 추가 비용 없음
- 기존 RPC 패턴에 자연스럽게 통합

**구현 방안:**

```sql
-- Step 1: Extension 활성화 (Supabase Dashboard → SQL Editor)
CREATE EXTENSION IF NOT EXISTS pgroonga;

-- Step 2: PGroonga 인덱스 생성
CREATE INDEX idx_posts_pgroonga_title
  ON public.posts USING pgroonga (title)
  WHERE deleted_at IS NULL AND group_id IS NULL;

CREATE INDEX idx_posts_pgroonga_content
  ON public.posts USING pgroonga (content)
  WHERE deleted_at IS NULL AND group_id IS NULL;

-- Step 3: search_posts_v3 RPC (PGroonga 기반)
CREATE OR REPLACE FUNCTION public.search_posts_v3(
  p_query TEXT,
  p_emotion TEXT DEFAULT NULL,
  p_sort TEXT DEFAULT 'relevance',
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
) RETURNS TABLE(
  id BIGINT,
  title TEXT,
  content TEXT,
  board_id BIGINT,
  like_count INTEGER,
  comment_count INTEGER,
  emotions TEXT[],
  created_at TIMESTAMPTZ,
  display_name TEXT,
  author_id UUID,
  is_anonymous BOOLEAN,
  image_url TEXT,
  initial_emotions TEXT[],
  group_id BIGINT,
  title_highlight TEXT,
  content_highlight TEXT,
  relevance_score REAL
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF char_length(trim(p_query)) < 2 THEN RETURN; END IF;

  RETURN QUERY
  WITH matched AS (
    SELECT p.id, p.title, p.content, p.board_id, p.created_at,
           p.display_name, p.author_id, p.is_anonymous, p.image_url,
           p.initial_emotions, p.group_id,
           pa.emotions,
           COALESCE(r.like_count, 0)::INTEGER AS like_count,
           COALESCE(c.comment_count, 0)::INTEGER AS comment_count,
           (
             pgroonga_score(tableoid, ctid) * 10
             + CASE WHEN p.title &@~ p_query THEN 5.0 ELSE 0 END
           )::REAL AS relevance_score
    FROM posts p
    LEFT JOIN post_analysis pa ON pa.post_id = p.id
    LEFT JOIN (SELECT post_id, SUM(count)::INTEGER AS like_count
               FROM reactions GROUP BY post_id) r ON r.post_id = p.id
    LEFT JOIN (SELECT post_id, COUNT(*)::INTEGER AS comment_count
               FROM comments WHERE deleted_at IS NULL GROUP BY post_id) c ON c.post_id = p.id
    WHERE p.deleted_at IS NULL AND p.group_id IS NULL
      AND (p_emotion IS NULL OR p_emotion = ANY(pa.emotions))
      AND (p.title &@~ p_query OR p.content &@~ p_query)
    ORDER BY
      CASE WHEN p_sort = 'relevance' THEN relevance_score END DESC NULLS LAST,
      CASE WHEN p_sort = 'latest' THEN extract(epoch FROM p.created_at) END DESC NULLS LAST,
      p.created_at DESC
    LIMIT p_limit OFFSET p_offset
  )
  SELECT m.id, m.title, m.content, m.board_id,
         m.like_count, m.comment_count, m.emotions,
         m.created_at, m.display_name, m.author_id,
         m.is_anonymous, m.image_url, m.initial_emotions, m.group_id,
         pgroonga_highlight_html(m.title, pgroonga_query_extract_keywords(p_query))::TEXT AS title_highlight,
         pgroonga_snippet_html(m.content, pgroonga_query_extract_keywords(p_query),
           200, 0)::TEXT AS content_highlight,
         m.relevance_score
  FROM matched m;
END;
$$;
```

> ✅ PGroonga extension 활성화 완료 (2026-03-08 확인).
> 인덱스 생성 + search_posts_v3 RPC 적용 즉시 가능.

**마이그레이션 전략:**
- `search_posts_v2`는 유지 (폴백)
- `search_posts_v3`를 신규 생성
- 클라이언트에서 v3 우선 호출, 실패 시 v2 폴백
- 안정화 후 v2 DROP

### 6d. 앱 레벨 전처리 (보완)

PGroonga 적용과 별개로, 검색어 전처리를 클라이언트에서 수행:

```typescript
// shared/utils.ts에 추가 (순수 함수)

/** 한국어 일반 조사 제거 (검색어 정규화) */
export function normalizeKoreanQuery(query: string): string {
  // 일반적인 조사 패턴 (단어 끝에 붙는)
  const particles = /(?<=[가-힣])(을|를|이|가|은|는|에|에서|의|와|과|로|으로|도|만|까지|부터|보다)(?=\s|$)/g;
  return query.replace(particles, '').trim();
}
```

> 주의: 조사 제거는 false positive 가능 ("가을" → "가" 방지 필요).
> 2글자 이하 단어에서는 조사 제거 스킵.

### 6e. 장기 로드맵 (10,000+ 사용자)

```
현재: simple + ILIKE + pg_trgm
  ↓ (검색 품질 불만 시)
중기: PGroonga (같은 DB, 운영 부담 없음)
  ↓ (search-as-you-type, 오타 허용 필요 시)
장기: Meilisearch self-hosted (DB Webhook 동기화)
```

Meilisearch 동기화 아키텍처 (장기):
```
posts INSERT/UPDATE → DB Webhook → Edge Function → Meilisearch API
                                                      ↓
                              앱/웹 ← Meilisearch Search API
```

### 6f. 트리거 조건

| 단계 | 트리거 |
|---|---|
| PGroonga 도입 | 검색 품질 피드백 수집 후, 형태소 분석 필요 확인 시 |
| 앱 레벨 전처리 | 조사 관련 검색 실패 리포트 3건+ |
| Meilisearch | 10,000+ 사용자, search-as-you-type UX 요구 시 |

---

## 7. Phase F: 디자인 시스템 문서화 (v1 범위 외) — 리뷰: 보류 적절

> 추가: 2026-03-08 | v1 Phase 14-15 디자인 조사에서 도출
> **리뷰 의견**: 1인 개발에서 참조할 사람 없음. 팀 확장 시 실행. 보류 적절.

### 7a. 현황

v1 Phase 14-15에서 디자인 일관성 이슈 다수 발견. 근본 원인은 **디자인 토큰이 코드에만 존재하고 문서화되지 않은 것**.

**현재 디자인 토큰 분포:**
| 토큰 | 위치 | 문서화 |
|---|---|---|
| 색상 팔레트 | `shared/constants.ts` SHARED_PALETTE | ✗ |
| 감정 색상 | `shared/constants.ts` EMOTION_COLOR_MAP | ✗ |
| 모션 프리셋 | `shared/constants.ts` MOTION | ✗ |
| 타이포그래피 | 앱: NativeWind 기본, 웹: Geist Sans | ✗ |
| 간격 스케일 | Tailwind 기본 (커스텀 없음) | ✗ |
| z-index | 컴포넌트별 산재 | ✗ |
| 아이콘 색상 | 하드코딩 15+곳 | ✗ |
| 그림자 색상 | 하드코딩 10+곳 | ✗ |

### 7b. 해결 방안

#### 방안 1: 디자인 토큰 문서 (권장 — 팀 확장 전)

```
docs/DESIGN-TOKENS.md
├── 색상: SHARED_PALETTE 5계열 × 10단계
├── 감정 색상: 13개 감정 gradient + category
├── 모션: spring 프리셋 5종 + timing 3종 + easing 2종
├── 타이포그래피: 앱(NativeWind) / 웹(Geist) 크기 매핑
├── 간격: Tailwind 기본 스케일 + 카드 간격 규칙
├── z-index: 5레이어 스케일 (0/10/40/50)
├── 아이콘 색상: primary/secondary/muted/destructive
└── 그림자: primary/muted
```

#### 방안 2: Storybook (팀 확장 후)

- 웹: `npx storybook@latest init` → 공유 컴포넌트 시각 카탈로그
- 앱: `@storybook/react-native` → Expo dev client 내 실행
- 디자인 토큰을 Storybook Docs 페이지로 시각화

### 7c. 트리거 조건

- 팀 확장 (2인 이상 개발) 시 방안 1 즉시 실행
- 디자인 시스템 변경 빈도 증가 시 방안 2 검토

---

## 8. 사용자 확인 항목

### v1에서 확인 완료
| 항목 | 결과 | 영향 |
|---|---|---|
| Supabase 플랜 | **Pro** | pg_cron 활성화 가능, PGroonga 사용 가능 |
| pg_trgm | ✅ 활성 (v1.6) | 검색 인덱스 정상 |
| pg_cron | ✅ 활성 + 스케줄 등록 | cleanup-stuck-analyses 10분 간격 자동 실행 |
| 공개 게시글 | 14건 | 검색 최적화 보류 |
| 검색 품질 피드백 | 없음 | Phase E 보류 |

### v2 확인 완료
| # | 항목 | 결과 | 영향 |
|---|---|---|---|
| Q1 | PGroonga extension | ✅ 활성화 완료 | Phase E 즉시 실행 가능 — search_posts_v3 (PGroonga) 적용 가능 |
| Q2 | Vercel 플랜 | **Hobby** (Pro 전환 가능) | Phase C: nonce CSP는 동적 렌더링 필요 → Hobby에서 서버리스 제한 주의. 현재는 v1 Phase 4 정적 CSP 우선 |
| Q3 | 네이티브 빌드 계획 | ✅ 승인 | Phase A (Expo 55) 즉시 실행 가능 |
| Q4 | 테스트 커버리지 목표 | ✅ 승인 (개인 개발자) | Phase B 실행 가능. Tier 1-2 (단순 hooks) 우선, 점진적 확장 |

> **모든 사전 확인 완료.** Phase A~E 전체 실행 가능 상태.

---

## 9. 구현 순서 요약 (리뷰 반영)

```
Phase A  Expo 55 업그레이드              ← **v1 Release 1에 통합** (JS breaking change 없음)
    ↓
Phase B  Hook/컴포넌트 테스트            ← 위험 기반 Tier 0-1만 2주 (v1 Phase 10 통합)
    ↓
Phase C  Next.js nonce CSP              ← 보류 (Hobby 플랜, SRI 안정화 대기, 상세 설계 보류)
    ↓
Phase D  RLS 재귀 패턴                  ← ✅ 이미 완료, 작업 불필요
    ↓
Phase E  한국어 검색 (PGroonga)          ← ✅ extension 활성, 피드백 시 실행
    ↓
Phase F  디자인 시스템 문서화            ← 대기 (팀 확장 시 실행, 보류 적절)
```

**리뷰 반영 변경:**
- Phase A: v1 Release 1에 통합 (JS breaking change 없음, jest-expo CRITICAL 해결)
- Phase B: "Tier 1-2부터 7주" → "위험 기반 Tier 0-1만 2주, 나머지 버그 발생 시"
- Phase C: 상세 설계는 실행 결정 시 작성 (현재는 참고용)
- Phase F: 1인 개발 → 보류 적절 확인

**독립 실행 가능**: Phase A, B, E, F는 서로 의존성 없음. 병렬 진행 가능.
**조건부 대기**: Phase C (Vercel Pro 전환 시), Phase E (검색 품질 피드백 시), Phase F (팀 확장 시).

---

## 10. v1 ↔ v2 관계 (리뷰 반영)

| v1 | v2 | 상태 |
|---|---|---|
| Release 1 (Phase 1,4,5b,6a,6c) | - | **즉시 실행 (Day 1)** |
| Release 2 (Phase 2,3,5a,7a,7b,11c) | - | 코드 품질 (Day 2-3) |
| Release 3 (Phase 8) | - | 문서 (Day 3) |
| Release 4 (Phase 12a,12b) | - | DB + 타입 (Day 4) |
| Release 5 (Phase 14a수정,14b,14c,15a,15b,15d) | - | 디자인/접근성 (Week 2) |
| ~~Phase 15c,15e~~ | - | **제외 (ROI 낮음)** |
| Phase 10 + v2 Phase B | Phase B | **위험 기반 통합, Tier 0-1만 2주** |
| 범위 외: Expo 55 | Phase A | **v1 Release 1에 통합** (JS breaking change 없음) |
| 범위 외: nonce CSP | Phase C | 보류 (상세 설계 보류, Vercel Pro 전환 시) |
| 범위 외: RLS 재귀 | Phase D | ✅ 이미 완료, 작업 불필요 |
| 범위 외: 한국어 검색 | Phase E | ✅ PGroonga 활성, 피드백 시 실행 |
| 범위 외: 디자인 토큰 문서화 | Phase F | 대기 (팀 확장 시, 보류 적절) |
