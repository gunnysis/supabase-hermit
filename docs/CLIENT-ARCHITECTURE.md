# 클라이언트 아키텍처 — 은둔마을

> 최종 업데이트: 2026-03-03

앱(React Native/Expo)과 웹(Next.js)이 공유하는 Supabase 백엔드 연동 구조를 정리한 문서.

---

## 공유 코드 관리

### 단일 정본 (Single Source of Truth)

중앙 프로젝트(`supabase-hermit`)에서 관리하는 공유 코드:

| 파일 | 내용 | 앱 배포 경로 | 웹 배포 경로 |
|---|---|---|---|
| `shared/constants.ts` | 감정 상수 (ALLOWED_EMOTIONS, EMOTION_EMOJI) | `src/shared/lib/constants.generated.ts` | `src/lib/constants.generated.ts` |
| `shared/types.ts` | 비즈니스 타입 (Post, Comment 등) | `src/types/database.types.ts` | `src/types/database.types.ts` |
| `types/database.gen.ts` | Supabase 자동 생성 DB 타입 | `src/types/database.gen.ts` | `src/types/database.gen.ts` |

### Re-export 패턴

앱/웹의 기존 타입/상수 파일은 generated 파일을 re-export하는 래퍼:

```
앱: src/shared/lib/constants.ts
  → export { ALLOWED_EMOTIONS, EMOTION_EMOJI } from './constants.generated'
  → + 앱 전용 상수 (VALIDATION, ALIAS_ADJECTIVES 등)

앱: src/types/index.ts
  → export * from './database.types'

웹: src/lib/constants.ts
  → export { ALLOWED_EMOTIONS, EMOTION_EMOJI } from './constants.generated'
  → + 웹 전용 상수

웹: src/types/database.ts
  → export * from './database.types'
```

### 수정 워크플로

```bash
# 1. 중앙에서만 수정
vi shared/constants.ts   # 감정 목록 변경 등

# 2. 동기화
bash scripts/sync-to-projects.sh

# 3. Edge Function _shared/analyze.ts의 VALID_EMOTIONS도 수동 일치 확인
```

---

## 심리분석 (감정 분석) 기능

### 전체 흐름

```
[사용자] 게시글 작성
    │
    ▼
[Supabase] posts INSERT
    │
    ├─ [DB Webhook] ──► analyze-post Edge Function
    │                       │
    │                       ▼
    │                   Claude API (haiku-4-5)
    │                       │
    │                       ▼
    │                   post_analysis UPSERT
    │                       │
    │                       ▼
    │                   [Realtime] postgres_changes INSERT
    │                       │
    │                       ▼
    │                   클라이언트 자동 수신 → UI 업데이트
    │
    └─ [15초 fallback] ──► analyze-post-on-demand Edge Function
                               │
                               ▼
                           (동일 분석 흐름)
```

### 클라이언트 분석 대기 전략 (앱/웹 통일)

| 단계 | 시점 | 동작 |
|---|---|---|
| 1 | 즉시 | `post_analysis` 초기 조회 |
| 2 | 즉시 | Realtime `postgres_changes` 구독 (INSERT 감지) |
| 3 | 15초 후 | 결과 없으면 `analyze-post-on-demand` Edge Function 호출 |
| 4 | +5초 | Realtime 누락 대비 수동 invalidate |

### 앱 구현 (`usePostDetailAnalysis`)

```
마운트
  ├─ useQuery: postAnalysis 초기 조회
  ├─ useEffect: Realtime 구독 (분석 결과 있으면 구독 해제)
  └─ useEffect: 15초 타이머
       └─ 캐시 확인 → null이면 invokeSmartService → 5초 후 invalidate
```

### 웹 구현 (`usePostAnalysis`)

```
마운트
  ├─ useQuery: postAnalysis 초기 조회
  ├─ useEffect: Realtime 구독 (분석 결과 있으면 구독 해제)
  └─ useEffect: 15초 타이머
       └─ 캐시 확인 → 없으면 invokeAnalyzeOnDemand(postId, content, title)
            └─ 5초 후 invalidate
```

### 분석 재시도 UI

| 플랫폼 | 위치 | 동작 |
|---|---|---|
| 앱 | `EmotionTags` 컴포넌트 (`onRetry` prop) | "🔄 분석 재시도" 버튼 → `invokeSmartService` 호출 |
| 웹 | `PostDetailView` 헤더 영역 | "감정 분석 재시도" 버튼 (RefreshCw 아이콘) → `invokeAnalyzeOnDemand` 호출 |

---

## 감정 태그 & 검색

### 허용 감정 목록 (13개)

| 감정 | 이모지 |
|---|---|
| 고립감 | 🫥 |
| 무기력 | 😶 |
| 불안 | 😰 |
| 외로움 | 😔 |
| 슬픔 | 😢 |
| 그리움 | 💭 |
| 두려움 | 😨 |
| 답답함 | 😤 |
| 설렘 | 💫 |
| 기대감 | 🌱 |
| 안도감 | 😮‍💨 |
| 평온함 | 😌 |
| 즐거움 | 😊 |

### 앱 감정 검색

```
EmotionTags (onPress) → router.push('/search', { emotion })
                            │
                            ▼
search.tsx → api.searchPosts(query, limit, offset, emotion)
                            │
                            ▼
posts_with_like_count 뷰 → .contains('emotions', [emotion]) 필터
```

### 웹 감정 검색

```
EmotionTags (clickable) → Link href="/search?emotion=..."
```

---

## 리액션

| 단계 | 클라이언트 | 서버 |
|---|---|---|
| 조회 | `get_post_reactions` RPC | reaction_type, count, user_reacted 반환 |
| 토글 | `toggle_reaction` RPC 호출 | reactions + user_reactions 원자적 갱신 |

> `reactions`, `user_reactions` 테이블에 직접 쓰기 정책 없음 — RPC만 사용.

---

## 추천 게시글

| 단계 | 함수 | 설명 |
|---|---|---|
| 조회 | `get_recommended_posts_by_emotion` RPC | 감정 겹치는 공개 글 추천 |

> ~~`recommend-posts-by-emotion` Edge Function~~은 삭제됨. 앱/웹 모두 RPC 직접 호출.

---

## Edge Functions 현황

| 함수 | 상태 | JWT | 용도 |
|---|---|---|---|
| `analyze-post` | 활성 | X | DB Webhook 자동 트리거 |
| `analyze-post-on-demand` | 활성 | O | 15초 fallback + 수동 재시도 |
| ~~`smart-service`~~ | 삭제 | - | analyze-post-on-demand로 대체 |
| ~~`recommend-posts-by-emotion`~~ | 삭제 | - | RPC 직접 호출로 대체 |

---

## 파일 의존성 맵

### 앱 (gns-hermit-comm)

```
src/types/index.ts (re-export)
  └─ src/types/database.types.ts (generated from shared/types.ts)

src/shared/lib/constants.ts (re-export + 앱 전용)
  └─ src/shared/lib/constants.generated.ts (generated from shared/constants.ts)

src/features/posts/hooks/usePostDetailAnalysis.ts
  ├─ src/shared/lib/api/analysis.ts (invokeSmartService)
  └─ src/shared/lib/supabase.ts (Realtime 구독)

src/features/posts/components/EmotionTags.tsx
  └─ src/shared/lib/constants.ts (EMOTION_EMOJI)

src/features/posts/components/EmotionTrend.tsx
  └─ src/shared/lib/constants.ts (EMOTION_EMOJI)

src/app/search.tsx
  ├─ src/shared/lib/api/posts.ts (searchPosts + emotion filter)
  └─ src/shared/lib/constants.ts (ALLOWED_EMOTIONS, EMOTION_EMOJI)
```

### 웹 (web)

```
src/types/database.ts (re-export)
  └─ src/types/database.types.ts (generated from shared/types.ts)

src/lib/constants.ts (re-export + 웹 전용)
  └─ src/lib/constants.generated.ts (generated from shared/constants.ts)

src/features/posts/hooks/usePostAnalysis.ts
  ├─ src/features/posts/api/postsApi.ts (invokeAnalyzeOnDemand)
  └─ @supabase/supabase-js (Realtime 구독)

src/features/posts/components/EmotionTags.tsx
  └─ src/lib/constants.ts (EMOTION_EMOJI)

src/features/posts/components/PostDetailView.tsx
  ├─ src/features/posts/hooks/usePostAnalysis.ts
  └─ src/features/posts/api/postsApi.ts (invokeAnalyzeOnDemand — 재시도)
```
