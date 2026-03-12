# 클라이언트 아키텍처 — 은둔마을

> 최종 업데이트: 2026-03-13 (v7: Phase E1 반영, 그룹 시스템 제거 반영, re-export 목록 갱신)

앱(React Native/Expo)과 웹(Next.js)이 공유하는 Supabase 백엔드 연동 구조를 정리한 문서.

---

## 공유 코드 관리

### 단일 정본 (Single Source of Truth)

중앙 프로젝트(`supabase-hermit`)에서 관리하는 공유 코드:

| 파일 | 내용 | 앱 배포 경로 | 웹 배포 경로 |
|---|---|---|---|
| `shared/constants.ts` | 감정 상수, 디자인 토큰, 모션 프리셋 | `src/shared/lib/constants.generated.ts` | `src/lib/constants.generated.ts` |
| `shared/types.ts` | 비즈니스 타입 (Post, Comment 등) | `src/types/database.types.ts` | `src/types/database.types.ts` |
| `shared/utils.ts` | 순수 유틸 함수 (validatePostInput, validateCommentInput) | `src/shared/lib/utils.generated.ts` | `src/lib/utils.generated.ts` |
| `types/database.gen.ts` | Supabase 자동 생성 DB 타입 | `src/types/database.gen.ts` | `src/types/database.gen.ts` |

### Re-export 패턴

앱/웹의 기존 타입/상수 파일은 generated 파일을 re-export하는 래퍼:

```
앱: src/shared/lib/constants.ts
  → export { ALLOWED_EMOTIONS, EMOTION_EMOJI, REACTION_COLOR_MAP, SHARED_PALETTE,
             EMOTION_COLOR_MAP, MOTION, EMPTY_STATE_MESSAGES, GREETING_MESSAGES,
             SEARCH_HIGHLIGHT, SEARCH_CONFIG, ADMIN_CONSTANTS,
             ANALYSIS_STATUS, ANALYSIS_CONFIG, VALIDATION } from './constants.generated'
  → export type { AllowedEmotion, ReactionColorKey } from './constants.generated'
  → + 앱 전용 상수 (ALIAS_ADJECTIVES, ALIAS_ANIMALS, PAGE_SIZE 등)

앱: src/types/index.ts
  → export * from './database.types'

웹: src/lib/constants.ts
  → export { ALLOWED_EMOTIONS, EMOTION_EMOJI, REACTION_COLOR_MAP, SHARED_PALETTE,
             EMOTION_COLOR_MAP, MOTION, EMPTY_STATE_MESSAGES, GREETING_MESSAGES,
             SEARCH_HIGHLIGHT, SEARCH_CONFIG, ADMIN_CONSTANTS } from './constants.generated'
  → + 웹 전용 상수 (VALIDATION, ADJECTIVES, ANIMALS, PAGE_SIZE 등)

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
[사용자] 게시글 작성/수정
    │
    ▼
[Supabase] posts INSERT 또는 UPDATE (content/title 변경)
    │
    ├─ [DB Trigger 1] trg_create_pending_analysis → post_analysis에 pending 행 생성
    │
    ├─ [DB Trigger 2] analyze_post_on_insert/update → analyze-post Edge Function
    │                       │
    │                       ▼
    │                   status → 'analyzing' 설정
    │                       │
    │                       ▼
    │                   Gemini API (callGeminiWithRetry: 최대 2회, 1s→2s 백오프)
    │                       │
    │                       ├─ 성공 → status='done', emotions 저장
    │                       └─ 실패 → status='failed', retry_count++, error_reason 기록
    │                       │
    │                       ▼
    │                   [Realtime] postgres_changes UPDATE
    │                       │
    │                       ▼
    │                   클라이언트 자동 수신 → UI 업데이트
    │
    └─ [클라이언트 fallback] status 기반 폴링 + on-demand 재시도
```

### 비용 보호 (쿨다운)

| 항목 | 내용 |
|---|---|
| 트리거 레벨 | `WHEN (OLD.content IS DISTINCT FROM NEW.content OR OLD.title IS DISTINCT FROM NEW.title)` — 실제 내용 변경 시에만 발동 |
| Edge Function 레벨 | `analyzeAndSave` 내 60초 쿨다운 — `analyzed_at` 기준으로 60초 이내 재분석 스킵 |
| 수동 재시도 | `analyze-post-on-demand`는 `force: true`로 쿨다운 우회 (사용자 명시 요청) |

### 클라이언트 분석 대기 전략

**앱 (status 기반 폴링 + 단계적 fallback)**:

| 단계 | 조건 | 동작 |
|---|---|---|
| 1 | 즉시 | `post_analysis` 초기 조회 (status, retry_count 포함) |
| 2 | status=pending/analyzing | 5초 간격 refetchInterval 자동 폴링 (최대 2분) |
| 3 | 10초 후 status≠done | 1차 `analyze-post-on-demand` Edge Function 호출 |
| 4 | 20초 후 status≠done | 2차 `analyze-post-on-demand` 호출 (최대 2회) |
| 5 | status=failed & retry_count<3 | 재시도 버튼 표시 |
| 6 | status=failed & retry_count≥3 | 최종 실패 메시지 표시 |

**웹 (Realtime + 타이머)**:

| 단계 | 시점 | 동작 |
|---|---|---|
| 1 | 즉시 | `post_analysis` 초기 조회 |
| 2 | 즉시 | Realtime `postgres_changes` 구독 (`*`: INSERT + UPDATE 감지) |
| 3 | 15초 후 | 결과 없으면 `analyze-post-on-demand` Edge Function 호출 |
| 4 | +5초 | Realtime 누락 대비 수동 invalidate |

### 앱 구현 (`usePostDetailAnalysis`)

```
마운트
  ├─ useQuery: postAnalysis 조회 (ANALYSIS_CONFIG.STALE_TIME_MS)
  ├─ refetchInterval: status=pending/analyzing → 5초 폴링 (MAX_POLLING_MS=2분)
  ├─ useEffect: Realtime 구독 (post_analysis INSERT/UPDATE → invalidate)
  └─ useEffect: 단계적 fallback (FALLBACK_DELAYS: [10초, 20초])
       └─ 캐시 확인 → 미완료면 invokeSmartService → 3초 후 invalidate
```

### 웹 구현 (`usePostAnalysis`)

```
마운트
  ├─ useQuery: postAnalysis 초기 조회
  ├─ useEffect: Realtime 구독 (event: * — INSERT/UPDATE 모두 감지)
  └─ useEffect: 15초 타이머
       └─ 캐시 확인 → 없으면 invokeAnalyzeOnDemand(postId, content, title)
            └─ 5초 후 invalidate
```

### 분석 재시도 UI

**앱 EmotionTags (status 기반)**:

| 상태 | UI |
|---|---|
| pending / analyzing | 스켈레톤 애니메이션 |
| done | 감정 태그 표시 |
| failed & retry_count < 3 | "분석 재시도" 버튼 |
| failed & retry_count >= 3 | "분석할 수 없는 글이에요" 최종 메시지 |

**웹 PostDetailView**:

| 상태 | UI |
|---|---|
| emotions 없음 | "감정 분석 재시도" 버튼 (RefreshCw 아이콘) → `invokeAnalyzeOnDemand` 호출 |
| 재시도 중 | RefreshCw 스핀 애니메이션 |

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
| `analyze-post` | 활성 | X | DB Trigger 자동 (INSERT + UPDATE) |
| `analyze-post-on-demand` | 활성 | O | fallback + 수동 재시도 (쿨다운 우회) |
| ~~`smart-service`~~ | 삭제 | - | analyze-post-on-demand로 대체 |
| ~~`recommend-posts-by-emotion`~~ | 삭제 | - | RPC 직접 호출로 대체 |

### 감정분석 프롬프트 (Phase E1)

**`_shared/analyze.ts`**: 한국어 전문 감정분석가 시스템 프롬프트 + Gemini Structured Output.

| 항목 | 내용 |
|---|---|
| 모델 | `gemini-2.5-flash` (환경변수 `GEMINI_MODEL`로 변경 가능) |
| 출력 형식 | Structured Output (`responseMimeType: 'application/json'` + `responseSchema`) |
| 응답 스키마 | `emotions` (string[], 최대 3개) + `risk_level` (normal/elevated/high/critical) + `risk_indicators` (string[]) + `context_notes` (string) |
| 프롬프트 특화 | 은둔형 외톨이 맥락, 한국어 은어/초성 해석 (ㅋ, ㅠㅠ, 멘붕, 읽씹 등), 위기 신호 감지, 작은 성취 인식 |
| DB 저장 | Phase E1: `emotions` 배열만 저장, risk 정보는 로그로만 기록 (Phase E2에서 DB 컬럼 추가 예정) |

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

src/features/posts/components/
  ├─ EmotionTags.tsx         → EMOTION_EMOJI
  ├─ CommunityPulse.tsx      → EMOTION_EMOJI, EMOTION_COLOR_MAP (감정 버블 시각화)
  ├─ EmotionFilterBar.tsx    → ALLOWED_EMOTIONS, EMOTION_COLOR_MAP (감정 필터 칩)
  ├─ TrendingPosts.tsx       → 트렌딩 게시글 가로 스크롤
  ├─ GreetingBanner.tsx      → GREETING_MESSAGES (시간대별 인사)
  ├─ MoodSelector.tsx        → EMOTION_COLOR_MAP (글쓰기 감정 선택)
  ├─ EmotionCalendar.tsx     → EMOTION_COLOR_MAP (감정 캘린더 히트맵)
  ├─ EmotionWave.tsx         → 감정 타임라인 차트
  └─ ReactionBar.tsx         → 리액션 타입별 차별화 애니메이션 (heart=pulse, laugh=wiggle, sad=droop, surprise=pop)

src/app/_layout.tsx
  ├─ 화면 전환 애니메이션 (ios_from_right, slide_from_bottom, fade 등)
  └─ OTA 업데이트: Alert.alert()로 사용자 확인 후 적용 (자동 적용 → 확인 방식으로 변경)
```

### 웹 (web)

```
src/types/database.ts (re-export)
  └─ src/types/database.types.ts (generated from shared/types.ts)

src/lib/constants.ts (re-export + 웹 전용)
  └─ src/lib/constants.generated.ts (generated from shared/constants.ts)

src/lib/logger.ts              → Sentry 연동 로거 (dev=console, prod=Sentry)
src/lib/sanitize.ts            → DOMPurify 기반 HTML 새니타이저 (XSS 방지)
src/lib/view-transition.ts     → View Transitions API 래퍼

src/features/posts/hooks/usePostAnalysis.ts
  ├─ src/features/posts/api/postsApi.ts (invokeAnalyzeOnDemand)
  └─ @supabase/supabase-js (Realtime 구독)

src/features/posts/components/
  ├─ EmotionTags.tsx         → EMOTION_EMOJI
  ├─ CommunityPulse.tsx      → EMOTION_EMOJI, EMOTION_COLOR_MAP (감정 버블 시각화)
  ├─ EmotionFilterBar.tsx    → ALLOWED_EMOTIONS, EMOTION_COLOR_MAP (감정 필터 칩)
  ├─ TrendingPosts.tsx       → 트렌딩 게시글 가로 스크롤
  ├─ GreetingBanner.tsx      → GREETING_MESSAGES (시간대별 인사)
  ├─ MoodSelector.tsx        → EMOTION_COLOR_MAP (글쓰기 감정 선택)
  ├─ EmotionCalendar.tsx     → EMOTION_COLOR_MAP (감정 캘린더 히트맵)
  ├─ EmotionWave.tsx         → 감정 타임라인 차트
  ├─ PostCard.tsx            → View Transitions (startViewTransition)
  └─ PostDetailView.tsx      → View Transitions (뒤로가기), sanitizeHtml (XSS 방지)

src/app/my/page.tsx            → 나의 공간 (활동 요약, 감정 캘린더, 타임라인)
src/app/global-error.tsx       → 루트 에러 바운더리 (Sentry 캡처)
src/instrumentation.ts         → Next.js 서버/엣지 Sentry 초기화
```
