# hermit-comm(은둔마을) 대규모 리팩토링 실전 가이드

**리포지토리가 private이라 소스코드에 직접 접근은 못했지만**, Sentry 에러 로그, Expo 빌드 히스토리, Gmail/Drive의 프로젝트 기록, 그리고 웹 버전(`web-hermit-comm`) 아키텍처 단서를 종합 분석해서 실전 리팩토링 가이드를 작성했다. 현재 앱 버전 **gns-hermit-comm@1.7.0**, Expo 안드로이드 빌드 안정화 완료(3월 5~8일 연속 성공), Sentry 주간 에러 **120건**(모바일 101건) — 지금이 리팩토링 적기다.

---

## 현재 상태 진단: Sentry가 말해주는 코드의 문제들

Sentry 주간 리포트(2/28~3/7)에서 확인된 핵심 이슈 세 가지가 리팩토링 방향을 결정한다.

**첫째, ANR(Application Not Responding) — 치명적 성능 문제.** `GNS-HERMIT-COMM-9`, `GNS-HERMIT-COMM-A` 두 건의 ANR이 Pixel 6 Pro(Android 12)에서 `fatal` 레벨로 발생했다. 스택트레이스가 네이티브 C++ 레벨(`pthread_cond_wait`, `condition_variable::wait`)에서 멈춘 걸 보면, **메인 스레드를 블로킹하는 무거운 동기 작업**이 있다는 뜻이다. 대용량 리스트 렌더링, 이미지 처리, 또는 Supabase 쿼리가 UI 스레드를 막고 있을 가능성이 높다.

**둘째, `APIError: 게시글을 찾을 수 없습니다.`** — 미처리 Promise Rejection. Galaxy Z Flip3(Android 15)에서 v1.6.0 개발환경에서 발생했는데, 스택트레이스를 보면 커스텀 `APIError` 클래스가 `_construct` → `Wrapper` 패턴으로 상속되어 있고, `asyncGeneratorStep`으로 비동기 호출을 처리한다. 문제는 이 에러가 **onunhandledrejection**으로 잡혔다는 점 — 즉 **글로벌 에러 핸들링이 빠져있다**.

**셋째, 웹 버전 `src/features/posts/components/PostContent.tsx`의 DOMPurify 에러**와 jsdom ESM/CJS 호환 문제. 웹 앱은 이미 feature-based 구조(`src/features/posts/components/`)를 쓰고 있는데, 모바일 앱도 이 패턴을 따라가면 코드 공유와 일관성 면에서 큰 이득이다.

---

## 아키텍처 개편: feature-based 구조로 전환하기

웹 버전이 이미 `src/features/` 패턴을 쓰고 있으니, 모바일 앱도 동일한 구조로 맞추는 게 핵심이다. **app/ 폴더는 라우트만, features/ 폴더에 모든 비즈니스 로직**을 넣는 패턴이 2025~2026 Expo 생태계의 표준이다.

```
src/
├── app/                          # Expo Router — thin re-exports만!
│   ├── _layout.tsx               # 루트: Provider 래핑, 폰트, 스플래시
│   ├── +not-found.tsx
│   ├── (auth)/
│   │   ├── _layout.tsx           # Stack navigator
│   │   └── login.tsx             # → export { LoginScreen as default } from '@/features/auth'
│   ├── (tabs)/
│   │   ├── _layout.tsx           # Bottom tabs
│   │   ├── index.tsx             # → re-export FeedScreen
│   │   ├── community.tsx
│   │   └── profile.tsx
│   └── post/
│       └── [id].tsx              # → re-export PostDetailScreen
│
├── features/                     # 핵심! 기능별 모듈
│   ├── auth/
│   │   ├── login-screen.tsx
│   │   ├── use-auth-store.ts     # Zustand
│   │   └── components/
│   │       └── login-form.tsx
│   ├── feed/
│   │   ├── feed-screen.tsx
│   │   ├── post-detail-screen.tsx
│   │   ├── api.ts                # React Query + Supabase 호출
│   │   └── components/
│   │       ├── post-card.tsx
│   │       └── post-list.tsx
│   ├── community/
│   │   ├── community-screen.tsx
│   │   ├── api.ts
│   │   └── components/
│   └── settings/
│
├── components/ui/                # 2개+ feature에서 공유하는 UI만
│   ├── button.tsx
│   ├── text.tsx
│   └── image.tsx
│
├── lib/                          # 인프라 레이어
│   ├── supabase.ts               # Supabase 클라이언트 (단일 인스턴스)
│   ├── api-error.ts              # APIError 클래스 + 글로벌 핸들러
│   ├── storage.ts                # MMKV 추상화
│   └── hooks/
│       ├── use-realtime.ts       # Realtime 구독 훅
│       └── use-app-state.ts
│
└── translations/
    └── ko.json
```

**라우트 파일은 진짜 한 줄만** 써야 한다. 이게 Expo Router의 핵심 철학이다:

```typescript
// src/app/(tabs)/index.tsx
export { FeedScreen as default } from '@/features/feed/feed-screen';
```

이렇게 하면 Fast Refresh가 깨지지 않고, 라우팅과 비즈니스 로직이 완전히 분리된다. **barrel export(`index.ts`에서 전부 내보내기)는 금지** — React Native에서 Fast Refresh 문제를 일으킨다.

---

## Supabase 클라이언트 제대로 세팅하기

현재 앱에서 Supabase 클라이언트 설정이 어떻게 되어있는지 정확히는 모르지만, 2025년 최신 패턴과 익명 커뮤니티 앱에 맞는 설정은 이렇다:

```typescript
// src/lib/supabase.ts
import 'expo-sqlite/localStorage/install';  // Expo 55+ 최신 폴리필
import { createClient } from '@supabase/supabase-js';
import { AppState } from 'react-native';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL!;
const supabaseKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    storage: localStorage,           // expo-sqlite 폴리필 사용
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,        // ← 네이티브앱 필수! 안하면 Realtime 버그
  },
});

// 토큰 자동 갱신 — 앱이 백그라운드에서 돌아올 때
AppState.addEventListener('change', (state) => {
  if (state === 'active') {
    supabase.auth.startAutoRefresh();
  } else {
    supabase.auth.stopAutoRefresh();
  }
});
```

**`detectSessionInUrl: false`를 빠뜨리면** Realtime에서 delete 이벤트만 수신되는 심각한 버그가 생긴다(Supabase GitHub #26980). 반드시 확인하자.

만약 현재 `@react-native-async-storage/async-storage`를 쓰고 있다면, **`expo-sqlite/localStorage/install`**로 교체하는 게 Expo 공식 권장이다. 또는 보안이 중요하면 `expo-secure-store` + AES-256 암호화 조합을 쓸 수 있다.

---

## 익명 인증과 RLS: 은둔마을의 핵심 설계

은둔형 외톨이를 위한 커뮤니티앱이니 **익명성이 제1원칙**이다. Supabase Anonymous Sign-Ins를 활용하면 개인정보 없이 authenticated 역할을 부여할 수 있다:

```typescript
// 앱 첫 실행 시 자동 익명 로그인
const { data, error } = await supabase.auth.signInAnonymously();
// JWT에 is_anonymous 클레임이 포함됨
```

RLS 정책은 이렇게 설계한다:

```sql
-- 모든 인증 사용자(익명 포함)가 게시글 읽기 가능
CREATE POLICY "read_posts" ON posts
  FOR SELECT TO authenticated USING (true);

-- 게시글 작성 — 자기 글만
CREATE POLICY "create_posts" ON posts
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = author_id);

-- 게시글 수정/삭제 — 자기 글만, 영구 회원만
CREATE POLICY "update_own_posts" ON posts AS RESTRICTIVE
  FOR UPDATE TO authenticated
  USING (auth.uid() = author_id)
  WITH CHECK ((auth.jwt()->>'is_anonymous')::boolean IS FALSE);
```

**익명 계정 정리 SQL**도 반드시 스케줄링해야 한다 — Supabase에 자동 정리 기능이 없다:

```sql
DELETE FROM auth.users
WHERE is_anonymous IS TRUE AND created_at < now() - interval '30 days';
```

나중에 사용자가 원하면 계정을 연결(`linkIdentity`)할 수 있는데, React Native에서는 브라우저 리다이렉트 이슈가 있어서 `signInWithIdToken` + nonce 방식이 더 안전하다.

---

## ANR 해결과 성능 최적화 전략

주간 101건의 모바일 에러 중 ANR이 가장 치명적이다. **세 가지 핵심 조치**로 해결한다.

**FlatList → FlashList 교체.** 커뮤니티 피드는 게시글이 계속 늘어나는 리스트다. `@shopify/flash-list`는 컴포넌트 재활용(recycling)으로 FlatList 대비 **CPU 32% 감소, 프레임 타임 29% 감소**를 보여준다. 마이그레이션도 쉽다:

```typescript
import { FlashList } from '@shopify/flash-list';

<FlashList
  data={posts}
  renderItem={({ item }) => <PostCard post={item} />}
  estimatedItemSize={200}           // 필수! 아이템 예상 높이
  keyExtractor={(item) => item.id}
/>
```

**expo-image 도입.** React Native 기본 Image 컴포넌트 대신 `expo-image`를 쓰면 디스크/메모리 캐싱, blurhash 플레이스홀더, 부드러운 트랜지션을 얻는다. FlashList와 함께 쓸 때는 **`recyclingKey`를 반드시 넣어야** 이전 이미지가 깜빡이는 현상을 방지한다:

```typescript
<Image
  source={{ uri: post.imageUrl }}
  recyclingKey={post.id}
  transition={200}
  contentFit="cover"
  placeholder={{ blurhash: post.blurhash }}
  cachePolicy="memory-disk"
/>
```

**AsyncStorage → MMKV 전환.** `react-native-mmkv`는 AsyncStorage보다 약 **30배 빠르고 동기 API**다. 설정값, 캐시, 사용자 preferences 저장에 이상적이다. 다만 Expo Go에서는 안 돌아가므로 `expo prebuild` + dev client가 필요하다(이미 EAS Build 쓰고 있으니 문제없다).

---

## 에러 핸들링 체계화: APIError부터 글로벌 핸들러까지

Sentry에서 포착된 `APIError: 게시글을 찾을 수 없습니다.`가 **onunhandledrejection**으로 잡혔다는 건, 비동기 호출 체인에서 에러가 새고 있다는 뜻이다. 글로벌 에러 핸들링 레이어를 만들자:

```typescript
// src/lib/api-error.ts
export class APIError extends Error {
  constructor(
    message: string,
    public code: string,
    public status?: number
  ) {
    super(message);
    this.name = 'APIError';
  }
}

// Supabase 호출 래퍼
export async function querySupabase<T>(
  queryFn: () => Promise<{ data: T | null; error: any }>
): Promise<T> {
  const { data, error } = await queryFn();
  if (error) {
    throw new APIError(
      error.message || '알 수 없는 오류',
      error.code || 'UNKNOWN',
      error.status
    );
  }
  if (!data) {
    throw new APIError('데이터를 찾을 수 없습니다.', 'NOT_FOUND', 404);
  }
  return data;
}
```

```typescript
// features/feed/api.ts — React Query에서 사용
import { useQuery } from '@tanstack/react-query';
import { querySupabase, APIError } from '@/lib/api-error';

export function usePost(id: string) {
  return useQuery({
    queryKey: ['post', id],
    queryFn: () => querySupabase(() =>
      supabase.from('posts').select('*').eq('id', id).single()
    ),
    retry: (count, error) => {
      if (error instanceof APIError && error.code === 'NOT_FOUND') return false;
      return count < 3;
    },
  });
}
```

이렇게 하면 **"게시글을 찾을 수 없습니다"** 에러가 React Query의 에러 상태로 깔끔하게 처리되고, Sentry에 unhandled rejection으로 올라가지 않는다.

---

## Realtime 구독: 제대로 된 정리 패턴

커뮤니티 앱이면 새 게시글이 실시간으로 올라와야 한다. 근데 React Native에서 Supabase Realtime 쓸 때 **구독 정리(cleanup)를 안 하면 메모리 누수 + ANR의 원인**이 된다:

```typescript
// src/lib/hooks/use-realtime.ts
import { useEffect, useRef } from 'react';
import { AppState } from 'react-native';
import { supabase } from '@/lib/supabase';

export function useRealtimePosts(onNewPost: (post: any) => void) {
  const channelRef = useRef<ReturnType<typeof supabase.channel> | null>(null);

  useEffect(() => {
    const channel = supabase
      .channel('feed:posts', { config: { private: true } })  // 프로덕션은 private!
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'posts',
      }, (payload) => {
        onNewPost(payload.new);
      })
      .subscribe();

    channelRef.current = channel;

    const appSub = AppState.addEventListener('change', (state) => {
      if (state === 'active' && !supabase.realtime.isConnected()) {
        supabase.realtime.connect();
      }
    });

    return () => {
      supabase.removeChannel(channel);  // 반드시!
      appSub.remove();
    };
  }, [onNewPost]);
}
```

**`supabase.removeChannel()`을 빠뜨리면** 채널이 계속 쌓이면서 메모리 누수가 생기고, 결국 ANR로 이어질 수 있다.

---

## Auth 상태 관리: Zustand 기반 패턴

React Context로 auth 상태를 관리하고 있다면, **Zustand로 전환**하면 리렌더링이 줄고 코드도 간결해진다:

```typescript
// src/features/auth/use-auth-store.ts
import { create } from 'zustand';
import { Session, User } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';

type AuthStore = {
  session: Session | null;
  user: User | null;
  initialized: boolean;
  isAnonymous: boolean;
  initialize: () => () => void;
};

export const useAuthStore = create<AuthStore>((set) => ({
  session: null,
  user: null,
  initialized: false,
  isAnonymous: false,
  initialize: () => {
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        set({
          session,
          user: session?.user ?? null,
          initialized: true,
          isAnonymous: session?.user?.is_anonymous ?? false,
        });
      }
    );
    return () => subscription.unsubscribe();
  },
}));
```

루트 `_layout.tsx`에서 초기화하고, 인증 라우팅을 처리한다:

```typescript
// src/app/_layout.tsx
import { useEffect } from 'react';
import { Slot, useRouter, useSegments } from 'expo-router';
import { useAuthStore } from '@/features/auth/use-auth-store';

export default function RootLayout() {
  const { session, initialized, initialize } = useAuthStore();
  const segments = useSegments();
  const router = useRouter();

  useEffect(() => {
    const cleanup = initialize();
    return cleanup;
  }, []);

  useEffect(() => {
    if (!initialized) return;
    const inAuth = segments[0] === '(auth)';
    if (!session && !inAuth) router.replace('/(auth)/login');
    else if (session && inAuth) router.replace('/(tabs)');
  }, [session, initialized]);

  if (!initialized) return null; // 또는 스플래시 스크린 유지

  return <Slot />;
}
```

---

## 긴급 조치 체크리스트: 오늘 당장 시작하기

지금까지의 분석을 기반으로, **우선순위별 실행 계획**이다:

1. **`detectSessionInUrl: false` 확인** — Supabase 클라이언트 설정에 이게 없으면 Realtime 버그가 생긴다. 1분이면 확인 가능
2. **Realtime 구독 cleanup 점검** — 모든 `useEffect`에서 `supabase.removeChannel()` 호출하는지 확인. ANR의 유력 원인
3. **APIError unhandled rejection 수정** — `querySupabase` 래퍼 + React Query로 에러 체인 정리. 주간 101건 에러의 상당수가 여기서 나올 것
4. **feature-based 폴더 구조 전환** — 웹 앱과 동일한 `src/features/` 패턴 적용. 가장 큰 구조적 개선
5. **FlatList → FlashList 마이그레이션** — 피드 화면부터 시작. `estimatedItemSize` 넣는 것만 잊지 말 것

CI가 `web-hermit-comm`에서 계속 실패하고 있는 것도 확인됐다(3월 6~8일 모든 커밋에서 9개 annotation과 함께 실패). 웹 앱의 jsdom ESM/CJS 호환 문제(`@exodus/bytes`)도 함께 정리하면 좋다.

---

## 결론: 구조가 바뀌면 에러가 줄어든다

현재 은둔마을 모바일 앱은 **주간 101건의 에러**를 뿜고 있고, 그 중 ANR이 가장 치명적이다. 하지만 이건 코드가 나쁜 게 아니라, **앱이 성장하면서 초기 구조가 한계에 도달한 것**이다. v1.0부터 v1.7.0까지 빠르게 기능을 쌓았고, 이제 구조적 부채를 갚을 타이밍이 왔다.

핵심 전략은 단순하다. **`app/`은 라우트만, `features/`에 비즈니스 로직, `lib/`에 인프라**. 이 삼분법만 지키면 코드 네비게이션이 직관적이 되고, 에러 추적도 쉬워지고, 웹 앱과 코드/패턴을 공유할 수 있게 된다. FlashList + expo-image + MMKV 삼총사를 도입하면 ANR은 크게 줄어들 것이고, `querySupabase` 래퍼 + React Query 조합이면 unhandled rejection은 사라진다.

Laravel에서 React Native로 스택을 전환하면서 쌓은 도메인 지식(고립·은둔 청년 커뮤니티)은 기술 스택이 바뀌어도 그대로 살아있다. 이번 리팩토링이 끝나면 은둔마을은 훨씬 안정적이고 확장 가능한 앱이 될 거다. 화이팅 🔥