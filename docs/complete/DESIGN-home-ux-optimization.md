# 홈 화면 게시글 영역 UX/UI 최적화 설계

> 작성일: 2026-03-06
> 대상: 앱(React Native) + 웹(Next.js) 홈 화면

---

## 1. 현재 문제 분석

### 1.1 앱 홈 화면 레이아웃 스택 (위→아래)

```
+--------------------------------------------------+
| SafeAreaView (cream-100 bg)                       |
|  Container (cream-50 bg)                          |
|   ScreenHeader (BlurView)                         |  ~130px 고정
|    - "은둔마을" 제목 (24px bold)                    |   28px
|    - "따뜻한 이야기가 있는 곳" 서브타이틀             |   20px
|    - 게시판 description (xs)                       |   16px
|    - 검색 바 (border-2, px-4, py-3)               |   ~48px
|    - SortTabs (mt-3, py-2.5)                      |   ~44px
|   ScreenHeader 끝                                 |
|                                                   |
|   GreetingBanner (mx-4 mb-3 px-5 py-4)           |   ~56px
|   View px-4:                                      |
|    EmotionTrend (p-4 mb-4, border, rounded)       |   ~72px
|    TrendingPosts (mb-4, 가로 스크롤, w-44 카드)    |   ~120px
|   View 끝                                         |
|                                                   |
|   PostList (FlashList, flex-1, min-h-0)           |   ← 남은 공간
|    PostCard (mx-4 mb-3.5, p-4, rounded-2xl)      |
+--------------------------------------------------+
| Tab Bar                                           |   ~80px
+--------------------------------------------------+
```

### 1.2 핵심 문제

**스크롤 진입 전 게시글이 보이지 않는다.**

일반적인 모바일(390x844 기준) 화면에서:

| 영역 | 높이 (추정) |
|---|---|
| SafeArea 상단 | ~50px |
| ScreenHeader (제목+서브+검색+정렬) | ~160px |
| GreetingBanner | ~56px |
| EmotionTrend | ~72px |
| TrendingPosts | ~120px |
| **소계 (게시글 전까지)** | **~458px** |
| Tab Bar | ~80px |
| SafeArea 하단 | ~34px |
| **게시글 가용 영역** | **~272px (32%)** |

첫 화면에서 게시글이 0.5~1개만 보이거나, 트렌딩이 3개 이상이면 첫 게시글이 fold 아래로 밀려남.

### 1.3 웹 홈 화면 레이아웃

```
+--------------------------------------------------+
| Header (sticky, h-14)                             |   56px
| main (max-w-2xl mx-auto px-4 py-6)               |
|   PublicFeed:                                     |
|    GreetingBanner                                 |   ~56px
|    CommunityPulse (감정 버블, 최대 8개)            |   ~90px
|    EmotionFilterBar (가로 스크롤, 13개 감정)       |   ~40px
|    TrendingPosts (가로 스크롤, w-44)              |   ~100px
|    Separator                                      |   1px
|    SortTabs                                       |   ~40px
|    PostCard 목록 (space-y-3)                      |   ← 나머지
+--------------------------------------------------+
```

웹은 스크롤이 자연스러워 앱만큼 심하진 않지만, GreetingBanner + CommunityPulse + EmotionFilterBar + TrendingPosts로 ~286px을 소비한 후 게시글 시작.

---

## 2. 설계 원칙

1. **게시글 우선 (Content-First)**: 첫 화면에서 게시글이 최소 2개 보여야 함
2. **보조 섹션은 축소/접기**: 인사말, 감정 트렌드, 트렌딩은 보조 정보 — 최소 높이로
3. **검색은 접근성 유지**: 검색 바는 유지하되 높이를 줄임
4. **스크롤 시 자연스러운 퇴장**: 고정 헤더는 최소화

---

## 3. 앱 개선안

### 3.1 ScreenHeader 경량화

**현재**: ScreenHeader가 ~160px (제목+서브+description+검색바+정렬탭)

**변경**:
- 서브타이틀 제거 (제목 "은둔마을"만으로 충분)
- 게시판 description 제거 (이미 알고 있는 정보)
- 검색 바 높이 축소: py-3 → py-2, border-2 → border
- SortTabs mt-3 → mt-2로 여백 축소

```
변경 전 ScreenHeader: ~160px
변경 후 ScreenHeader: ~100px  (절감 ~60px)
```

**ScreenHeader 변경 후**:
```tsx
<ScreenHeader title="은둔마을">
  <View className="flex-row items-center gap-2 mt-2">
    <Pressable
      onPress={() => pushSearch(router)}
      className="flex-1 flex-row items-center rounded-xl border border-cream-200
                 dark:border-stone-600 bg-cream-50 dark:bg-stone-800 px-3 py-2">
      <Text className="text-sm text-gray-500 dark:text-stone-400">검색</Text>
    </Pressable>
  </View>
  <SortTabs value={sortOrder} onChange={setSortOrder} />
</ScreenHeader>
```

### 3.2 GreetingBanner + EmotionTrend + TrendingPosts → 통합 축소

**현재**: 3개 섹션이 합계 ~248px

**방안 A: PostList의 ListHeaderComponent로 통합**

GreetingBanner, EmotionTrend, TrendingPosts를 FlashList 밖에서 꺼내지 않고, PostList의 **ListHeaderComponent**로 이동. 이렇게 하면:
- 게시글과 함께 자연스럽게 스크롤 아웃
- 고정 영역이 ScreenHeader만 남음 → 게시글 가용 영역 극대화
- 스크롤 시작 시 보조 섹션이 올라가며 게시글이 전면에 노출

```
변경 전: ScreenHeader(고정) + Greeting(고정) + Emotion(고정) + Trending(고정) + PostList(스크롤)
변경 후: ScreenHeader(고정) + PostList(스크롤, Header에 Greeting+Emotion+Trending 포함)
```

**방안 B: 보조 섹션 높이 압축**

각 섹션을 더 작게:
- GreetingBanner: px-5 py-4 → px-4 py-2.5 (56px → 40px)
- EmotionTrend: p-4 → p-3 (72px → 56px)
- TrendingPosts: 트렌딩 카드 높이 축소 w-44 → w-36, 섹션 mb-4 → mb-2

**권장: 방안 A + B 조합**
- 보조 섹션을 ListHeaderComponent로 이동 (스크롤 아웃)
- 동시에 각 섹션 높이도 압축

### 3.3 PostCard 최적화

현재 PostCard: mx-4 mb-3.5 → 양쪽 16px + 하단 14px 마진

**변경**:
- mb-3.5 → mb-2.5 (카드 간격 14px → 10px)
- 감정 태그 섹션 mb-3 → mb-2
- 본문 미리보기 mb-3 → mb-2
- 전체적으로 카드 내부 패딩 p-4 유지 (읽기 편의성)

### 3.4 개선 후 예상 레이아웃

```
+--------------------------------------------------+
| SafeArea 상단                                      |   ~50px
| ScreenHeader (제목 + 검색 + 정렬)                   |   ~100px (현 160px)
+--------------------------------------------------+
| FlashList (스크롤 가능)                             |
|   [ListHeader]                                    |
|    GreetingBanner (compact)                       |   ~40px
|    EmotionTrend (compact)                         |   ~56px
|    TrendingPosts (compact)                        |   ~100px
|   [PostCard 1]                                    |   ← 첫 화면에 노출!
|   [PostCard 2]                                    |   ← 첫 화면에 노출!
|   [PostCard 3...]                                 |
+--------------------------------------------------+
| Tab Bar                                           |   ~80px
+--------------------------------------------------+

게시글 가용 영역: 844 - 50 - 100 - 80 - 34 = 580px
ListHeader 스크롤 아웃 전: 580 - 196 = 384px → 게시글 ~2개 보임
ListHeader 스크롤 아웃 후: 580px 전체 → 게시글 ~3.5개 보임
```

---

## 4. 웹 개선안

### 4.1 보조 섹션 축소

**CommunityPulse (감정 버블)**: 버블 최대 크기 72→56px, 최대 표시 8→5개
**EmotionFilterBar**: 높이 유지 (이미 적절)
**TrendingPosts**: 현재 적절

### 4.2 GreetingBanner 간소화

```tsx
// 변경 전: py-4
// 변경 후: py-3
<div className="rounded-xl bg-gradient-to-r ... px-4 py-3">
  <p className="text-sm font-semibold ...">{greeting}</p>
  <p className="text-xs text-muted-foreground mt-0.5">{message}</p>
</div>
```

### 4.3 섹션 간격 축소

PublicFeed의 `space-y-4` → `space-y-3` (16px→12px 간격)

### 4.4 PostCard 간격

PostCard 목록의 `space-y-3` → `space-y-2.5`

---

## 5. 변경 파일 목록

### 앱

| 파일 | 변경 |
|---|---|
| `src/app/(tabs)/index.tsx` | ScreenHeader 경량화 + 보조 섹션을 PostList ListHeader로 이동 |
| `src/features/posts/components/PostList.tsx` | ListHeaderComponent prop 추가 |
| `src/features/posts/components/GreetingBanner.tsx` | padding 축소 (py-4→py-2.5) |
| `src/features/posts/components/EmotionTrend.tsx` | padding 축소 (p-4→p-3, mb-4→mb-2) |
| `src/features/posts/components/TrendingPosts.tsx` | 카드 w-44→w-40, mb-4→mb-2 |
| `src/features/posts/components/PostCard.tsx` | mb-3.5→mb-2.5, 내부 여백 미세 조정 |
| `src/shared/components/ScreenHeader.tsx` | subtitle prop 유지하되 홈에서 미사용 |
| `src/shared/components/SortTabs.tsx` | mt-3→mt-2 |

### 웹

| 파일 | 변경 |
|---|---|
| `src/features/posts/components/PublicFeed.tsx` | space-y-4→space-y-3 |
| `src/features/posts/components/GreetingBanner.tsx` | py-4→py-3, 텍스트 xs |
| `src/features/posts/components/CommunityPulse.tsx` | 버블 max 56px, 최대 5개 |
| `src/features/posts/components/PostCard.tsx` | 내부 여백 미세 조정 |

---

## 6. 시각적 Before/After 비교

### 앱 (390x844 기준)

```
=== BEFORE (첫 화면) ===          === AFTER (첫 화면) ===

┌──────────────────┐             ┌──────────────────┐
│ 은둔마을          │ ScreenHeader│ 은둔마을          │ ScreenHeader
│ 따뜻한 이야기...  │             │ [  검색  ]        │ (compact)
│ 누구나 자유롭게...│             │ 최신순 | 인기순   │
│ [  검색바  ]      │             ├──────────────────┤
│ 최신순 | 인기순   │             │ 좋은 아침이에요   │ ← 스크롤 가능
├──────────────────┤             │ 요즘: 무기력 불안  │
│ 좋은 아침이에요   │ Greeting   │ [트렌딩1][트렌딩2] │
│ 오늘도 힘내세요   │             ├──────────────────┤
├──────────────────┤             │ ┌──────────────┐ │ PostCard 1
│ 요즘 마을 분위기  │ Emotion    │ │ 과도한 방어기제│ │
│ 무기력 불안 슬픔  │ Trend      │ │ 사람은 각자... │ │
├──────────────────┤             │ │ 답답함 무기력  │ │
│ 지금 뜨는 글      │ Trending   │ └──────────────┘ │
│ [카드1][카드2]    │             │ ┌──────────────┐ │ PostCard 2
│                   │             │ │ 아픈 상처가...│ │
├──────────────────┤             │ │ 지하철에서... │ │
│ ┌──────────────┐ │ PostCard 1  │ └──────────────┘ │
│ │ 과도한 방어...│ │ ← fold 근처 │                   │
│ │ 사람은 각자...│ │             │                   │
│ └──────────────┘ │             │                   │
├──────────────────┤             ├──────────────────┤
│      Tab Bar     │             │      Tab Bar     │
└──────────────────┘             └──────────────────┘

게시글 노출: ~0.5개               게시글 노출: ~2개
```

---

## 7. 구현 핵심: PostList에 ListHeader 지원

```tsx
// PostList.tsx — ListHeaderComponent prop 추가
interface PostListProps {
  posts: Post[];
  loading: boolean;
  error: string | null;
  onRefresh: () => void;
  onLoadMore?: () => void;
  hasMore?: boolean;
  emptyTitle?: string;
  emptyDescription?: string;
  listHeader?: React.ReactElement;  // 신규
}

// FlashList에 전달
<FlashList
  data={posts}
  ListHeaderComponent={listHeader}
  // ...기존 props
/>
```

```tsx
// index.tsx — 보조 섹션을 listHeader로 전달
const listHeader = useMemo(() => (
  <View>
    <GreetingBanner />
    <View className="px-4">
      <EmotionTrend days={7} />
      <TrendingPosts />
    </View>
  </View>
), []);

<PostList
  posts={posts}
  listHeader={listHeader}
  // ...기존 props
/>
```

이렇게 하면 GreetingBanner, EmotionTrend, TrendingPosts가 게시글 리스트와 함께 스크롤되어, 스크롤하면 게시글이 전체 화면을 차지하게 됨.

---

## 8. 구현 순서

```
1. PostList에 listHeader prop 추가
2. index.tsx에서 보조 섹션을 listHeader로 이동
3. ScreenHeader 경량화 (서브타이틀/description 제거, 검색바 축소)
4. 각 보조 컴포넌트 높이 축소
5. PostCard 간격 미세 조정
6. 웹 동일 패턴 적용
```
