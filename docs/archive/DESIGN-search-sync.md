# 검색 페이지 디자인/UX/레이아웃 앱/웹 동기화 개선 설계

> 작성: 2026-03-13 | 상태: 구현 완료

## 1. 현황 분석

### 1.1 구조 비교

| 항목 | 앱 (React Native) | 웹 (Next.js) | 차이점 |
|------|-------------------|-------------|--------|
| 메인 파일 | `src/app/search.tsx` (443줄) | `SearchView.tsx` (415줄) | 비슷한 규모, 독립 구현 |
| 컴포넌트 분리 | SearchResultCard, SearchResultList, EmotionPostList 별도 | SearchView 단일 파일 내 인라인 | **앱이 더 분리됨** |
| 감정 칩 개수 | 7개 (일부만 표시) | 13개 (ALLOWED_EMOTIONS 전체) | **불일치** |
| 스크롤 방식 | FlashList + onEndReached (threshold 0.3) | IntersectionObserver (threshold 0.1) | 플랫폼 차이 (정상) |
| URL 상태 | 없음 (인메모리) | searchParams 동기화 | **웹만 URL 영속** |
| 최근 검색 저장 | draftStorage (AsyncStorage) | localStorage | 플랫폼 차이 (정상) |
| 하이라이트 | HighlightText (Text 컴포넌트) | HighlightText (mark 태그) | 플랫폼 차이 (정상) |
| 감정필터 해제 UI | 감정 칩 재클릭 | "필터 해제" 버튼 + 칩 재클릭 | **웹에만 명시적 해제 버튼** |
| 초기 화면 감정 탐색 | 2열 wrap 그리드 | flex wrap 그리드 | 비슷 |

### 1.2 공유 인프라 현황

**중앙에서 공유 (constants.ts + types.ts):**
- `SEARCH_HIGHLIGHT` — 하이라이트 색상 (light/dark)
- `SEARCH_CONFIG` — debounce 400ms, page 20, recent max 8, stale 30s, min query 2
- `SearchResult` 인터페이스 — 17개 필드
- `SearchSort` 타입 — relevance | recent | popular
- `ALLOWED_EMOTIONS` — 13개 감정
- `EMOTION_EMOJI` — 감정별 이모지
- `EMOTION_COLOR_MAP` — 감정별 gradient + family + category
- `EMPTY_STATE_MESSAGES.search` — 빈 상태 메시지

**각 클라이언트 독립 구현:**
- 검색 UI 레이아웃 전체
- SearchResultCard 렌더링
- 최근 검색 관리 (recent-searches.ts)
- 감정 칩 스타일링
- 정렬 UI
- 로딩/에러/빈 상태 UI

### 1.3 핵심 불일치 목록

| # | 불일치 | 심각도 | 설명 |
|---|--------|--------|------|
| D1 | 감정 칩 개수 | 🔴 높음 | 앱 7개 vs 웹 13개 — 같은 서비스인데 탐색 가능한 감정이 다름 |
| D2 | 초기 화면 "감정으로 찾기" 레이아웃 | 🟡 중간 | 앱은 2열 고정 grid, 웹은 flex wrap — 시각적 차이 |
| D3 | 정렬 버튼 스타일 | 🟡 중간 | 앱: happy-600 bg / 웹: primary bg — 색상 계열 다름 |
| D4 | SearchResultCard 구조 | 🟡 중간 | 정보 배치, 줄 수 제한, 메타데이터 순서 미세 차이 |
| D5 | 감정 필터 해제 방법 | 🟢 낮음 | 웹에만 명시적 "필터 해제" 버튼 존재 |
| D6 | 빈 상태 메시지 | 🟢 낮음 | 앱은 자체 메시지, 웹은 EMPTY_STATE_MESSAGES.search 혼용 |
| D7 | 감정 칩 active 스타일 | 🟡 중간 | 앱: gradient bg + border / 웹: solid bg + border — 미세 차이 |

---

## 2. 개선 목표

### 2.1 원칙

1. **시각적 동일성보다 경험적 일관성** — 플랫폼 네이티브 패턴 존중하되, 사용자가 "같은 서비스"로 인식해야 함
2. **중앙 상수 확장** — 정렬 옵션, 빈 상태, 감정 칩 순서 등 반복 정의를 공유 상수로 통합
3. **최소 변경** — 동작하는 코드를 깨지 않고 불일치만 해소

### 2.2 비목표

- 앱/웹 검색 컴포넌트 코드 공유 (플랫폼 차이로 비현실적)
- 검색 RPC 변경 (현재 search_posts_v2 충분)
- 새 DB 마이그레이션

---

## 3. 개선 항목

### S1. 감정 칩 개수 통일 (D1 해결)

**현황:** 앱은 감정 7개만 하드코딩, 웹은 `ALLOWED_EMOTIONS` 13개 전체 사용.

**해결:** 앱도 `ALLOWED_EMOTIONS` 전체 13개 사용하도록 수정. 가로 스크롤 영역이므로 13개도 충분히 수용 가능.

**변경:**
- 앱 `search.tsx`: 하드코딩된 감정 배열 → `ALLOWED_EMOTIONS` import 사용

### S2. 중앙 검색 상수 확장

**현재 SEARCH_CONFIG에 없는 반복 정의:**

```typescript
// 두 클라이언트에서 동일하게 정의하는 것들
const SORT_OPTIONS = [
  { value: 'relevance', label: '관련도순' },
  { value: 'recent', label: '최신순' },
  { value: 'popular', label: '인기순' },
]

const EMOTION_ONLY_LIMIT = 50  // 앱, 웹: getPostsByEmotion limit
```

**추가할 중앙 상수:**

```typescript
// shared/constants.ts에 추가
export const SEARCH_SORT_OPTIONS = [
  { value: 'relevance', label: '관련도순' },
  { value: 'recent', label: '최신순' },
  { value: 'popular', label: '인기순' },
] as const

export const SEARCH_CONFIG = {
  ...기존,
  EMOTION_ONLY_LIMIT: 50,      // 감정 전용 모드 페이지 크기
  RESULT_TITLE_LINES: 2,        // 결과 카드 제목 줄 수
  RESULT_CONTENT_LINES: 3,      // 결과 카드 본문 줄 수
  RESULT_MAX_EMOTIONS: 2,       // 결과 카드에 표시할 감정 최대 개수
} as const
```

**효과:** 정렬 라벨 변경 시 한 곳만 수정, 카드 표시 규격 통일.

### S3. SearchResultCard 표시 규격 통일 (D4 해결)

**통일할 규격 (SEARCH_CONFIG에서 관리):**

| 항목 | 통일값 | 현재 앱 | 현재 웹 |
|------|--------|---------|---------|
| 제목 줄 수 | 2 | 2 | 2 |
| 본문 줄 수 | 3 | 3 | 3 |
| 감정 태그 최대 | 2 | 2 | 2 |
| 감정 스트라이프 | 좌측 3px | ✅ | ✅ |
| 메타데이터 순서 | 작성자 → 👍수 → 💬수 → 날짜 | ✅ | ✅ |

**현재 이미 거의 일치.** SEARCH_CONFIG 상수로 명시화만 진행.

### S4. 정렬 버튼 스타일 통일 (D3 해결)

**현황:**
- 앱: active = `happy-600` bg (golden), inactive = `stone-800` bg
- 웹: active = `primary` bg (shadcn 테마), inactive = `muted` bg

**방향:** 두 플랫폼 모두 **감정 테마 색상(happy 계열)** 사용으로 통일. 은둔마을 브랜드 컬러가 golden/happy 계열이므로 앱 스타일 기준.

**변경:**
- 웹: 정렬 버튼 active 스타일을 `bg-happy-500 text-white dark:bg-happy-600` 으로 변경

### S5. 초기 화면 "감정으로 찾기" 레이아웃 통일 (D2 해결)

**현황:**
- 앱: 2열 고정 grid (FlexWrap)
- 웹: flex wrap (자연스러운 줄바꿈)

**방향:** **flex wrap 방식으로 통일.** 감정 13개가 모두 표시되면 2열 고정보다 자연스러운 흐름이 적합.

**변경:**
- 앱: 2열 고정 grid → flex wrap + gap-2 (현재 웹 방식과 동일)

### S6. 감정 칩 active 스타일 통일 (D7 해결)

**현황:**
- 앱: `LinearGradient` bg (EMOTION_COLOR_MAP.gradient) + border
- 웹: `solid bg` (gradient[0]) + border

**방향:** 웹도 gradient 적용이 이상적이나, CSS gradient + rounded-full 조합의 복잡성 대비 효과가 낮음.
**결정:** **gradient[0] (밝은 색) + border 방식으로 통일.** 미세한 gradient 차이보다 색상 계열 일치가 중요.

- 앱도 gradient 대신 `gradient[0]` 단색 사용 (또는 유지 — 플랫폼 특성으로 허용 범위)
- **판단:** 이 항목은 gradient가 앱의 시각적 품질을 높이므로, 앱은 gradient 유지하고 웹만 gradient[0] 단색 사용하는 것도 수용. **경험적 일관성** 관점에서 색상 계열만 일치하면 충분.

### S7. 빈 상태 메시지 통일 (D6 해결)

**방향:** 두 클라이언트 모두 `EMPTY_STATE_MESSAGES.search` 사용. 추가로 검색 모드별 빈 상태 메시지 분리.

**추가할 상수:**

```typescript
export const EMPTY_STATE_MESSAGES = {
  ...기존,
  search: { title: '검색 결과가 없어요', description: '다른 키워드로 검색하거나\n감정으로 탐색해보세요.' },
  search_emotion: { title: '이 감정의 이야기가 아직 없어요', description: '비슷한 마음을 느끼고 있다면,\n용기 내어 이야기해 주세요.' },
}
```

### S8. 감정 필터 해제 UX 개선 (D5 해결)

**현황:** 웹에만 "필터 해제" 텍스트 버튼이 있음. 앱은 감정 칩 재클릭만.

**방향:** 두 플랫폼 모두 **감정 칩 재클릭으로 해제** + **필터 상태바에 X 아이콘으로 해제** 지원.
- 앱: 필터 상태바에 감정 해제 X 아이콘 추가
- 웹: 현재 "필터 해제" 텍스트를 X 아이콘으로 변경 (더 간결)

---

## 4. 변경 범위 요약

### 중앙 (supabase-hermit)

| 파일 | 변경 내용 |
|------|-----------|
| `shared/constants.ts` | SEARCH_SORT_OPTIONS 추가, SEARCH_CONFIG 확장, EMPTY_STATE_MESSAGES.search_emotion 추가 |

### 앱 (gns-hermit-comm)

| 파일 | 변경 내용 |
|------|-----------|
| `src/app/search.tsx` | ALLOWED_EMOTIONS 전체 사용, 초기 감정 grid flex wrap 변경, SEARCH_SORT_OPTIONS import, 빈 상태 EMPTY_STATE_MESSAGES 사용 |

### 웹 (web-hermit-comm)

| 파일 | 변경 내용 |
|------|-----------|
| `src/features/posts/components/SearchView.tsx` | SEARCH_SORT_OPTIONS import, 정렬 버튼 happy 색상 적용, 빈 상태 EMPTY_STATE_MESSAGES 사용, 필터 해제 X 아이콘 |

---

## 5. 구현 순서

```
Phase 1: 중앙 상수 확장
  ├─ S2. SEARCH_SORT_OPTIONS, SEARCH_CONFIG 확장
  └─ S7. EMPTY_STATE_MESSAGES.search_emotion 추가

Phase 2: 앱 수정
  ├─ S1. 감정 칩 13개 (ALLOWED_EMOTIONS)
  ├─ S5. 초기 감정 grid flex wrap
  ├─ S8. 필터 상태바 감정 해제 X
  └─ S7. 빈 상태 메시지 통일

Phase 3: 웹 수정
  ├─ S4. 정렬 버튼 happy 색상
  ├─ S8. 필터 해제 X 아이콘
  └─ S7. 빈 상태 메시지 통일

Phase 4: 동기화 + 검증
  └─ sync-to-projects.sh → verify.sh
```

**예상 영향:** DB 변경 없음, 마이그레이션 없음. 순수 프론트엔드 + 공유 상수 변경.

---

## 6. 스크린 와이어프레임

### 6.1 초기 화면 (통일 후)

```
┌──────────────────────────────────┐
│  [←]  [🔍 제목, 내용 검색...   ✕]│  ← 검색 입력
├──────────────────────────────────┤
│ [고립감🫥][무기력😶][불안😰][외로움😔][슬픔😢]...  ← 가로 스크롤 13개
├──────────────────────────────────┤
│                                  │
│  최근 검색어              전체 삭제│
│  ─────────────────────────────── │
│  🕐 외로움 관련 글           [✕] │
│  🕐 무기력할 때               [✕] │
│  🕐 불안                     [✕] │
│                                  │
│  감정으로 찾기                    │
│  ─────────────────────────────── │
│  [🫥 고립감] [😶 무기력] [😰 불안]│  ← flex wrap
│  [😔 외로움] [😢 슬픔] [💭 그리움]│
│  [😨 두려움] [😤 답답함] [💫 설렘]│
│  [🌱 기대감] [😮‍💨 안도감] [😌 평온함]│
│  [😊 즐거움]                     │
└──────────────────────────────────┘
```

### 6.2 검색 결과 (통일 후)

```
┌──────────────────────────────────┐
│  [←]  [🔍 외로움            ✕]  │
├──────────────────────────────────┤
│ [고립감][무기력][불안][외로움✓]...│  ← 선택된 감정 강조
├──────────────────────────────────┤
│ [관련도순✓] [최신순] [인기순]    │  ← happy 색상 active
│ '외로움' + 외로움  12건  [✕감정] │
├──────────────────────────────────┤
│ ┌────────────────────────────┐   │
│ █ <<외로움>>이 밀려올 때         │  ← 감정 스트라이프 + 하이라이트
│ █ 밤에 혼자 있으면 <<외로움>>    │
│ █ 이 느껴져서...                 │
│ █ [😔외로움] [😢슬픔]           │  ← 최대 2개
│ █ 익명  👍3  💬5  3시간 전      │
│ └────────────────────────────┘   │
│ ┌────────────────────────────┐   │
│ █ 직장에서의 <<외로움>>          │
│ █ ...                            │
│ └────────────────────────────┘   │
│         [로딩 스켈레톤...]       │  ← 무한 스크롤
└──────────────────────────────────┘
```

### 6.3 감정 전용 모드 (감정 칩만 선택, 텍스트 없음)

```
┌──────────────────────────────────┐
│  [←]  [🔍 제목, 내용 검색...   ] │
├──────────────────────────────────┤
│ [고립감][무기력][불안✓]...       │
├──────────────────────────────────┤
│ 불안  24건                 [✕감정]│
├──────────────────────────────────┤
│ ┌────────────────────────────┐   │
│ │ PostCard (일반 카드, 하이라이트 없음)│
│ └────────────────────────────┘   │
│ ┌────────────────────────────┐   │
│ │ PostCard                       │
│ └────────────────────────────┘   │
└──────────────────────────────────┘
```

---

## 7. 위험 요소 및 대응

| 위험 | 대응 |
|------|------|
| 앱 감정 칩 13개로 증가 시 가로 스크롤 UX | 이미 ScrollView horizontal 사용 중, 문제 없음 |
| SEARCH_SORT_OPTIONS 추가 시 기존 import 깨짐 | 기존 코드에서 로컬 정의만 제거, named import 추가 |
| 웹 happy 색상 클래스 미존재 | tailwind.config에 happy 색상 팔레트 이미 정의되어 있음 |

---

## 8. 후속 검토 (이번 범위 외)

- **검색 결과 이미지 썸네일**: 현재 앱/웹 모두 미표시. 추후 image_url 활용 검토
- **검색 자동완성/추천 검색어**: DB에 검색 로그 없으므로 현재 불가
- **감정 조합 필터 (다중 선택)**: search_posts_v2가 단일 감정만 지원, RPC 변경 필요
- **최근 검색 클라우드 동기화**: 현재 로컬 스토리지, user_preferences 활용 가능
