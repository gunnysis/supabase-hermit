# Daily v2 — "기록 → 회고 → 발견" 순환 완성

> 작성일: 2026-03-21

## 현황

v1은 기록(create/edit), 즉각 인사이트(streak, weekly summary, activity insights), 발견(same mood dailies, yesterday reactions)에 집중. **회고** 축이 약함 — 과거 daily를 되돌아볼 수 있는 전용 뷰가 없고, 월간 요약도 없다.

## v2 스코프

### D1. Daily 히스토리 (나의 기록)

**문제**: 과거 daily를 보려면 피드 스크롤 or 검색뿐. 전용 뷰 없음.

**해결**:
- RPC: `get_my_daily_history(p_limit INT, p_offset INT)` — 내 daily 목록 역순
- 반환: id, emotions, activities, content, created_date_kst, like_count, comment_count
- 앱/웹 마이페이지에 "나의 기록" 섹션 추가

### D2. 월간 감정 리포트

**문제**: weekly summary는 1주 단위. 더 큰 그림 없음.

**해결**:
- RPC: `get_monthly_emotion_report(p_year INT, p_month INT)` — 월간 요약
- 반환: days_logged, top_emotions[], top_activities[], emotion_distribution[]
- 앱/웹 마이페이지에 "이번 달 회고" 카드

### D3. 웹 WeeklySummary 동기화

**문제**: 앱에만 WeeklySummary 있음, 웹 누락.

**해결**: 앱 WeeklySummary 로직을 웹에 포팅.

## 마이그레이션

`20260331000001_daily_v2.sql`:
- `get_my_daily_history(p_limit, p_offset)` — SECURITY INVOKER
- `get_monthly_emotion_report(p_year, p_month)` — SECURITY INVOKER

## 사이드이펙트

- 기존 기능 변경 없음 (순수 추가)
- 새 RPC 2개, 새 컴포넌트 4개 (앱 2, 웹 2)
- shared/ 변경 없음
