# 나눠볼까요 버튼 점검 — 설계 문서

> 작성: 2026-03-19 | 범위: 앱 + 웹(동기화 점검)

## 배경

홈 화면 `HomeCheckinBanner`의 "나눠볼까요?" 버튼 → `DailyBottomSheet` 동작 전체 체인을 서비스 관점에서 점검.

## 동작 체인

```
HomeCheckinBanner("나눠볼까요?")
  → onCreatePress()
  → openDailySheet()
  → dailySheetRef.current?.snapToIndex(0)
  → DailyBottomSheet 열림 (45%)
  → 감정 선택 → "나누기"
  → createDaily() → supabase.rpc('create_daily_post')
```

## 발견된 문제 (3개)

### P1: DailyBottomSheet 닫기 시 상태 미초기화

**파일**: `DailyBottomSheet.tsx`

시트를 열어 감정/활동을 선택한 뒤 제출하지 않고 닫으면(스와이프 다운 또는 백드롭 탭), `emotions`/`activities`/`note` 상태가 유지됨. 다음 열기 시 이전 선택이 남아 있어 혼란 유발.

- `onSuccess` 콜백에서만 초기화 (라인 52-56)
- `onClose`/`onChange(-1)` 시 초기화 없음

**수정**: `onChange` 핸들러에서 `index === -1`일 때 상태 초기화.

### P2: listHeader useMemo 의존성 누락

**파일**: `index.tsx:136-157`

```tsx
const listHeader = useMemo(
  () => (
    <HomeCheckinBanner onCreatePress={openDailySheet} />  // ← 사용
  ),
  [emotionFilter, handleEmotionSelect],  // ← openDailySheet 누락
);
```

`openDailySheet`은 stable `useCallback([], [])`이라 현재 기능상 문제 없지만, React 컴파일러/strict mode에서 경고 발생 가능. 의존성 배열에 추가.

### P3: DailyBottomSheet 접근성 누락

**파일**: `DailyBottomSheet.tsx` vs `DailyPostForm.tsx`

DailyPostForm에는 감정 칩에 `accessibilityLabel`, `accessibilityRole="checkbox"`, `accessibilityState={{ checked }}` 존재. DailyBottomSheet에는 없음.

**수정**: DailyPostForm과 동일한 접근성 속성 추가.

## 변경 범위

| 파일 | 변경 | 영향 |
|------|------|------|
| `앱/DailyBottomSheet.tsx` | 닫기 시 상태 초기화 + 접근성 추가 | UX + a11y |
| `앱/index.tsx` | useMemo deps 보정 | 코드 정합성 |

## 사이드이펙트 체크

- [x] 삭제 연쇄: 없음 (state 초기화만)
- [x] 동기화: 앱 전용 컴포넌트, 웹에 영향 없음
- [x] TZ: 변경 없음
- [x] 에러 처리: 기존 유지
- [x] 캐시: 변경 없음
- [x] 하위 호환: 없음 (내부 state만)

## 웹 점검 결과

웹은 "나눠볼까요?" 클릭 시 `/create?type=daily` 페이지로 이동 (BottomSheet 미사용). 동일 RPC 사용, 문제 없음.
