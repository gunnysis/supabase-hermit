# 마이페이지 앱/웹 동기화 개선 설계

> **작성일**: 2026-03-18
> **상태**: 완료 (2026-03-18)

## 배경

마이페이지 클릭 시 문제 발생 신고. 원인 분석 결과:
1. 웹에 섹션별 에러 바운더리 없어 하나의 RPC 실패 시 전체 페이지 크래시
2. 앱/웹 간 기능·문구·정책 불일치 다수 발견

## 변경 범위

### P0 — 안정성

#### 1. 웹 마이페이지 섹션별 에러 바운더리
- **파일**: `src/features/my/components/SectionErrorBoundary.tsx` (신규)
- **변경**: `my/page.tsx`에서 각 섹션을 `SectionErrorBoundary`로 감싸기
- **동작**: 에러 발생 시 해당 섹션만 "불러올 수 없어요" + 재시도 버튼 표시
- 나머지 섹션은 정상 렌더링 유지

#### 2. 웹 로그아웃 경고 다이얼로그
- **파일**: `src/features/my/components/ProfileSection.tsx` (웹)
- **변경**: 로그아웃 버튼 클릭 시 확인 다이얼로그 추가
- **문구**: "익명 사용자가 로그아웃하면 새로운 계정이 생성되어 기존 글을 수정/삭제할 수 없게 됩니다."
- 앱의 Alert.alert 패턴과 동일한 UX

### P1 — 동기화

#### 3. EmotionCalendar 앱 범례 + 스켈레톤 추가
- **파일**: `src/features/posts/components/EmotionCalendar.tsx` (앱)
- **추가**:
  - 로딩 스켈레톤 (웹과 동일 패턴)
  - 색상 범례 (사용된 감정 이모지 + 색상 칩)
  - "최근 N일" 라벨

#### 4. ActivitySummary 문구 통일
- **앱**: "댓글" → "작성한 댓글", "반응" → "보낸 반응"
- **파일**: `src/features/my/components/ActivitySummary.tsx` (앱)

#### 5. 웹 my/ feature 모듈 audit 업데이트
- **파일**: `docs/audit/web-audit.md`
- web-audit에 my/ 모듈의 컴포넌트 목록이 누락됨 (ProfileSection, StreakBadge, WeeklySummary, EmotionTrendChart, BlockedUsersSection 없음)

## 구현 순서

1. 웹 SectionErrorBoundary 생성 + page.tsx 적용
2. 웹 ProfileSection 로그아웃 경고 추가
3. 앱 EmotionCalendar 범례/스켈레톤 추가
4. 앱 ActivitySummary 문구 통일
5. audit 파일 갱신
6. tech-debt 업데이트

## 사이드이펙트 체크

- [ ] 삭제 연쇄: 없음 (UI만 변경)
- [ ] 동기화: shared/ 변경 없음, 앱/웹 각각 수정
- [ ] 타임존: 해당 없음
- [ ] 에러 전파: ErrorBoundary 추가로 오히려 개선
- [ ] 캐시: 변경 없음
- [ ] 호환성: 기존 API/타입 변경 없음
