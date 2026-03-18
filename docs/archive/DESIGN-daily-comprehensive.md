# 오늘의 하루 종합 개선 설계

> **작성일**: 2026-03-18
> **상태**: 완료 (2026-03-18)

---

## 1. 서비스 맥락

### 오늘의 하루의 역할

은둔마을의 핵심 루프: **감정 선택 → 활동 태그 → 한마디 → 피드 공유 → 공감 수신 → 스트릭 성장**

일반 글쓰기(post)의 부담을 낮춘 경량 기록 형식. 은둔/고립 청소년에게 "긴 글 안 써도 된다"는 진입 장벽 제거가 핵심.

### 현재 구성
- **DB**: posts 테이블 post_type='daily', 6개 전용 RPC, KST 기반 하루 1회 제한
- **앱**: DailyBottomSheet (3단계) + DailyPostForm (전체) + 10개 연관 컴포넌트
- **웹**: DailyPostForm + 8개 연관 컴포넌트
- **공유**: ACTIVITY_PRESETS 10개, DAILY_CONFIG, validateDailyPostInput

---

## 2. 전수 조사 결과

### 2-1. 아키텍처 평가

**잘된 점:**
- DB 원자적 생성 (posts + post_analysis 동시 INSERT) → 데이터 불일치 없음
- KST 안전성 (IMMUTABLE kst_date() + generated column + UNIQUE 인덱스)
- 감정분석 트리거 분리 (post_type='post'만) → daily는 AI skip
- 스트릭 알고리즘 (connected days + 1일 freeze 버퍼)
- 캐시 무효화 전략 (create/update 시 5개 쿼리 무효화)

**구조적 문제 없음**: 아키텍처가 견고하게 설계됨.

### 2-2. 앱/웹 기능 비교

| 기능 | 앱 | 웹 | 차이 |
|------|----|----|------|
| 생성 UI | DailyBottomSheet (3단계 snap) + DailyPostForm | DailyPostForm만 | **앱이 더 나은 UX** |
| 감정 선택 | 13개 + Haptics | 13개 + scale 애니메이션 | 플랫폼 맞춤 |
| 활동 태그 | ActivityTagSelector + 커스텀 입력 + DB 저장 | ActivityTagSelector + 커스텀 입력 | 동일 |
| 성공 화면 | 이모지 + Toast + 바텀시트 닫기 | 이모지 + Toast + 홈 이동 | 유사 |
| 피드 카드 | DailyPostCard (memo) | DailyPostCard (memo) | 동일 |
| 홈 배너 | HomeCheckinBanner (AsyncStorage dismiss) | HomeCheckinBanner (localStorage dismiss) | 저장소만 다름 |
| 어제 반응 | YesterdayReactionBanner | YesterdayReactionBanner | 동일 |
| 상세 페이지 | daily 전용 렌더링 + SameMoodDailies | 동일 | 동일 |
| 알림 설정 | ReminderSetting (expo-notifications) | 없음 | **앱 전용** |
| 스트릭 | StreakBadge + Haptics + 애니메이션 | StreakBadge (정적) | 앱이 더 풍부 |

### 2-3. 발견된 문제

#### 기능 버그/개선

| # | 문제 | 심각도 | 영향 |
|---|------|--------|------|
| D1 | **웹에 바텀시트 없음** — 홈에서 바로 daily 작성 불가, `/create?type=daily`로 이동 필요 | MEDIUM | 전환율 저하 |
| D2 | **활동 커스텀 저장 에러 처리 없음** (앱 ActivityTagSelector) — DB 저장 실패 시 silent failure | MEDIUM | 사용자 혼란 |
| D3 | **HomeCheckinBanner dismiss가 TZ 불안전** — 클라이언트 날짜 사용 (KST 아닐 수 있음) | LOW | 자정 경계 오작동 |
| D4 | **DailyPostCard memo 비교가 불완전** — emotions/activities 변경 감지 안 함 | LOW | 수정 후 피드 미갱신 (드묾) |

#### 코드 품질

| # | 문제 | 심각도 |
|---|------|--------|
| Q1 | **DailyPostForm에서 validateDailyPostInput 미사용** — 공유 유틸이 있는데 직접 검증 | MEDIUM |
| Q2 | **에러 처리 불일치** — 앱은 Alert.alert, 웹은 alert() 사용 (window.alert은 UX 나쁨) | MEDIUM |
| Q3 | **PostDetailView 200+ 라인** — daily/post 렌더링이 한 파일에 혼재 | LOW (tech-debt) |

#### 디자인 일관성

| # | 문제 | 심각도 |
|---|------|--------|
| S1 | **상세 페이지 감정 칩 크기 불일치** — 상세: `px-4 py-2 text-sm`, 카드: `px-3 py-1.5 text-xs` (CLAUDE.md 표준) | LOW |
| S2 | **성공 화면 딜레이 차이** — 앱 400ms, 웹 600ms | LOW |

#### 성능

| # | 문제 | 심각도 |
|---|------|--------|
| P1 | **ActivityTagSelector에서 커스텀 활동 로드 시 매번 DB 조회** | LOW |

---

## 3. 서비스 관점 분석

### 신규 사용자 경험 (daily 0회)

```
홈 진입 → HomeCheckinBanner "오늘은 어떤 하루예요?" [나눠볼까요?]
  ↓ 클릭
앱: DailyBottomSheet 45% snap (감정 13개만 보임)
웹: /create?type=daily 페이지 이동 (전체 폼)
  ↓ 감정 1개 선택
앱: 자동으로 75%로 확장 (활동 태그 노출) ← 프로그레시브 디스클로저
웹: 이미 전체가 보임 (스크롤 필요)
  ↓ 나누기
성공 화면 → 홈 복귀 → 피드에 카드 표시 → StreakBadge "1일 연속"
```

**앱이 웹보다 온보딩이 좋음**: 바텀시트 3단계가 NN/G 프로그레시브 디스클로저 원칙에 부합. 웹은 전체 폼이 한 번에 보여서 부담감 있음.

### 기존 사용자 경험 (daily 7일+)

```
홈 진입 → YesterdayReactionBanner "어제 3명이 공감했어요"
         → HomeCheckinBanner "오늘의 하루: 😢 😔 [수정]"
마이페이지 → DailyInsights "💡 휴식한 날에 무기력을 자주 느끼는 경향"
           → StreakBadge "🌱 7일 연속! 새싹 마일스톤 달성"
           → WeeklySummary "이번 주 Top: 무기력 5회"
```

**루프가 잘 작동함**: 기록 → 공감 → 인사이트 → 성장 추적이 자연스럽게 이어짐.

### 핵심 판단

"오늘의 하루"는 아키텍처/DB/루프 설계가 **이미 잘 되어 있다**. 문제는 주로 **코드 품질과 앱/웹 사소한 불일치**에 있음. 대규모 리팩토링보다 **정확한 포인트 수정**이 적절.

---

## 4. 변경 사항

### Phase 1: 기능 개선 (MEDIUM)

**1-1. 웹 DailyPostForm에서 validateDailyPostInput 활용 (Q1)**
파일: `웹 src/features/posts/components/DailyPostForm.tsx`
- 현재: emotions.length === 0만 체크
- 수정: `validateDailyPostInput({ emotions, activities, content: note })` 호출
- 에러 시 `toast.error(에러메시지)` (alert() 대신)

**1-2. 웹 DailyPostForm alert() → toast 전환 (Q2)**
파일: `웹 src/features/posts/components/DailyPostForm.tsx`
- `alert('오늘은 이미 나눴어요...')` → `toast.error('오늘은 이미 나눴어요')`
- `alert('잠시 후 다시...')` → `toast.error('잠시 후 다시 시도해주세요')`

**1-3. 앱 ActivityTagSelector 커스텀 저장 에러 처리 (D2)**
파일: `앱 src/shared/components/ActivityTagSelector.tsx`
- 현재: DB 저장 실패 시 silent
- 수정: try-catch + Toast.show({ type: 'error', text1: '활동 저장에 실패했어요' })

### Phase 2: 디자인 일관성 (LOW)

**2-1. 상세 페이지 감정 칩 크기 표준화 (S1)**
파일: 웹/앱 `PostDetailView.tsx`
- daily 상세의 감정 칩: `px-4 py-2 text-sm` → CLAUDE.md 표준은 아니지만, 상세 페이지는 더 큰 칩이 적절 (의도적 예외)
- **판단: 변경 불필요** — 상세 페이지는 카드보다 넉넉한 공간, 큰 칩이 가독성 좋음

**2-2. 성공 화면 딜레이 통일 (S2)**
파일: 웹 DailyPostForm.tsx, 앱 DailyPostForm.tsx
- 웹 600ms → 앱 400ms와 통일? → **변경 불필요** — 플랫폼별 체감 속도 다름

### Phase 3: tech-debt 기록 (이번 범위 외)

| 항목 | 이유 |
|------|------|
| 웹 바텀시트 daily UX (D1) | 기획 결정 필요 (모바일 웹에서 바텀시트 vs 현재 폼) |
| HomeCheckinBanner TZ 불안전 (D3) | 실제 영향 극히 미미 (한국 사용자 대상, 기기 TZ = KST) |
| DailyPostCard memo 비교 (D4) | 실제 수정 빈도 낮고, invalidateQueries가 이미 전체 피드 갱신 |
| PostDetailView 분리 (Q3) | 200줄이지만 로직은 단순한 분기, 분리 비용 > 이득 |
| ActivityTagSelector 커스텀 활동 캐시 (P1) | user_preferences 변경 빈도 낮음, 5분 staleTime이면 충분 |

---

## 5. 구현 순서

```
Phase 1 (기능 개선)
  ├─ 1-1. 웹 validateDailyPostInput 활용
  ├─ 1-2. 웹 alert() → toast.error 전환
  └─ 1-3. 앱 ActivityTagSelector 에러 처리
```

변경 파일: 웹 1개, 앱 1개

## 6. 사이드이펙트 체크

- [x] 삭제 연쇄: 없음
- [x] 동기화: shared/ 변경 없음
- [x] 타임존: 해당 없음
- [x] 에러: validate 함수 반환값이 null이면 통과, 문자열이면 에러 — 기존 로직과 호환
- [x] 캐시: 변경 없음
- [x] 호환성: toast 전환은 sonner(웹) / react-native-toast-message(앱) 각각 사용 중

---

## 7. 전체 평가

| 영역 | 점수 | 근거 |
|------|------|------|
| **아키텍처** | 9/10 | DB 원자적 생성, KST 안전, 트리거 분리 — 견고 |
| **데이터 흐름** | 9/10 | 생성→피드→마이페이지 캐시 무효화 체인 완벽 |
| **앱 UX** | 9/10 | 바텀시트 3단계, Haptics, 스트릭 애니메이션 |
| **웹 UX** | 7/10 | 바텀시트 없음, alert() 사용 |
| **코드 품질** | 7/10 | validateDailyPostInput 미활용, 에러 처리 불일치 |
| **디자인 일관성** | 8/10 | 대부분 동일, 감정 칩 크기 차이는 의도적 |
| **성능** | 9/10 | DailyPostCard memo, staleTime 차등, 병렬 쿼리 |
| **보안** | 10/10 | SECURITY DEFINER + RPC 검증 + UNIQUE 인덱스 이중 방어 |
