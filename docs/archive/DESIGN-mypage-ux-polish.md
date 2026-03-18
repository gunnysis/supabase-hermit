# 마이페이지 UX 폴리시 설계

> **작성일**: 2026-03-18
> **상태**: 완료 (2026-03-18)

## 개선 항목 5개

### 1. WeeklySummary 로딩 스켈레톤 (P2)
- **현상**: `if (isLoading || !data) return null` → 로딩 중 섹션 사라짐
- **수정**: isLoading일 때 스켈레톤 표시
- **대상**: 웹 `WeeklySummary.tsx`, 앱 `WeeklySummary.tsx`

### 2. WeeklySummary 빈 상태 메시지 (P3)
- **현상**: `days_logged === 0`이면 null 반환 → 섹션 숨김
- **수정**: "이번 주는 아직 기록이 없어요" 메시지 + 네비게이션 유지
- **대상**: 웹/앱 동일

### 3. EmotionWave 키보드 접근성 (P2)
- **현상**: hover(onMouseEnter/Leave) 전용 → 키보드 접근 불가
- **수정**: tabIndex + onFocus/onBlur 추가
- **대상**: 웹 `EmotionWave.tsx` (앱은 Pressable onPress로 이미 대응)

### 4. 활동 요약 모바일 반응형 (P3)
- **현상**: `grid-cols-3` 고정 → 좁은 화면에서 텍스트 잘림 가능
- **수정**: 카드 내부 패딩 최소화, 폰트 크기 유지 (현재도 text-[10px]으로 충분 작음)
- **판단**: 실제로 max-w-2xl 컨테이너 안에서 3컬럼이면 각 카드 최소 ~100px — 충분함. 수정 불필요.

### 5. BlockedUsers 개별 isPending (P3)
- **현상**: unblock mutation의 isPending이 전역 → 하나 해제 시 전체 비활성화
- **수정**: 현재 해제 중인 alias를 로컬 state로 추적
- **대상**: 웹 `BlockedUsersSection.tsx`, 앱 `BlockedUsersSection.tsx`

## 사이드이펙트 체크
- [ ] 삭제 연쇄: 없음
- [ ] 동기화: 앱/웹 동일 패턴 적용
- [ ] 에러: 기존 에러 처리 유지
- [ ] 캐시: 변경 없음
