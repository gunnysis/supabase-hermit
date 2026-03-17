# 감정 칩 표준화 및 앱/웹 동기화 설계

> 작성: 2026-03-13 | 상태: 구현 중

## 1. 문제 분석

### 1.1 구조적 불일치

| 위치 | 앱 | 웹 | 문제 |
|------|----|----|------|
| 홈 피드 감정 필터 | `EmotionTrend` — 상위 3개만 | `EmotionFilterBar` — 13개 전체 + "전체" | 앱 사용자는 3개만 필터 가능 |
| `EmotionFilterBar` | 정의만 존재, 미사용 (dead code) | `PublicFeed`에서 활성 사용 | 낭비 |

### 1.2 스타일 파편화

**같은 플랫폼 내에서 감정 칩이 3가지 다른 스타일로 렌더링됨:**

| 위치 | 모서리 | 패딩 | 폰트 | 비활성 bg |
|------|--------|------|------|-----------|
| 검색 필터 칩 | `rounded-full` | `px-3 py-1.5` | `text-xs` | `stone-100` / `muted` |
| 검색 "감정으로 찾기" | `rounded-xl` | `px-3 py-2` | `text-sm` | `stone-50` / `muted` |
| EmotionFilterBar (홈) | `rounded-full` | `px-3.5 py-2` / `px-3 py-1.5` | `text-xs` | 하드코딩 / `muted` |

### 1.3 재발 원인

- 감정 칩 표준 스타일 미정의 — 각 컴포넌트가 독립적으로 스타일링
- 공유 컴포넌트 미활용 — EmotionFilterBar 존재하나 검색에서 인라인 구현
- 구조 설계 문서 부재 — 홈과 검색의 감정 필터 관계 미정의

## 2. 표준 정의

### 2.1 감정 칩 표준 스타일 (Standard Emotion Chip)

| 속성 | 표준값 | 비고 |
|------|--------|------|
| 모서리 | `rounded-full` (알약형) | 모든 인터랙티브 감정 칩에 적용 |
| 패딩 | `px-3 py-1.5` | 소형 칩 |
| 폰트 | `text-xs` | 소형 칩 |
| 활성 bg | `EMOTION_COLOR_MAP[emotion].gradient[0]` | inline style |
| 활성 border | 플랫폼 기본 border | 앱: `border-stone-300`, 웹: `border-border` |
| 활성 font | `font-semibold` | 선택 강조 |
| 비활성 bg | 플랫폼 muted | 앱: `bg-stone-100 dark:bg-stone-800`, 웹: `bg-muted` |
| 비활성 text | 플랫폼 muted-foreground | 앱: `text-stone-600 dark:text-stone-300`, 웹: 상속 |

### 2.2 감정 칩 사용 장소별 규격

| 장소 | "전체" 버튼 | 데이터 소스 | 스크롤 | 추가 요소 |
|------|------------|-----------|--------|----------|
| 홈 피드 필터 | O | `ALLOWED_EMOTIONS` 13개 | 가로 스크롤 | — |
| 검색 상단 필터 | X | `ALLOWED_EMOTIONS` 13개 | 가로 스크롤 | — |
| 검색 "감정으로 찾기" | X | `ALLOWED_EMOTIONS` 13개 | flex wrap | — |

## 3. 개선 항목

### F1. 앱 홈 피드에 EmotionFilterBar 추가

**현재:** EmotionTrend(상위 3개)만 사용.
**개선:** EmotionTrend 아래에 EmotionFilterBar 추가 (웹의 CommunityPulse + EmotionFilterBar 패턴과 동일).

- EmotionTrend: 트렌드 시각화 (정보 제공)
- EmotionFilterBar: 전체 감정 필터 (인터랙션)

**변경:** `src/app/(tabs)/index.tsx` — listHeader에 EmotionFilterBar import + 배치.

### F2. EmotionFilterBar 스타일 표준 정렬

**앱 EmotionFilterBar** 문제:
- 하드코딩 색상 (`#292524`, `#F5F5F4` 등) → NativeWind 클래스 사용
- `px-3.5 py-2` → `px-3 py-1.5` (표준 패딩)
- 과도한 shadow/elevation → 제거 (표준과 일치)

### F3. 검색 "감정으로 찾기" 칩 스타일 표준화

**앱 + 웹 공통:**
- `rounded-xl` → `rounded-full`
- `px-3 py-2 text-sm` → `px-3 py-1.5 text-xs`
- 비활성 bg를 필터 칩과 통일

### F4. 재발 방지 — CLAUDE.md 규칙 추가

감정 칩 표준 스타일 규칙을 CLAUDE.md에 명시하여 향후 새 컴포넌트 작성 시 준수.

## 4. 변경 파일

| 레포 | 파일 | 변경 |
|------|------|------|
| 앱 | `src/app/(tabs)/index.tsx` | EmotionFilterBar import + listHeader에 배치 |
| 앱 | `src/features/posts/components/EmotionFilterBar.tsx` | 표준 스타일로 리팩토링 |
| 앱 | `src/app/search.tsx` | "감정으로 찾기" 칩 스타일 표준화 |
| 웹 | `src/features/posts/components/SearchView.tsx` | "감정으로 찾기" 칩 스타일 표준화 |
| 중앙 | `CLAUDE.md` | 감정 칩 표준 규칙 추가 |

## 5. 구현 순서

```
1. 앱 EmotionFilterBar 스타일 표준화 (F2)
2. 앱 홈 피드에 EmotionFilterBar 추가 (F1)
3. 앱 검색 "감정으로 찾기" 칩 표준화 (F3)
4. 웹 검색 "감정으로 찾기" 칩 표준화 (F3)
5. CLAUDE.md 규칙 추가 (F4)
6. TypeScript 컴파일 검증
```
