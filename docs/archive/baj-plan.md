# 오늘의 하루 — 개선 계획

> **원칙**: 사람의 마음은 상수로 정의할 수 없다. 사실만 보여주고 해석하지 않는다.

---

## 완료

| # | 항목 |
|---|------|
| - | Daily 상세 화면 (post_type 분기) |
| - | Daily 수정 기능 (mode/initialData) |
| - | 프리셋 순서 (쉬운 것부터) |
| - | 삭제 재작성 안내 |
| - | 웹 포맷 선택 탭 |
| - | `DAILY_QUICK_COMMENTS` 상수 삭제 |

---

## 소통 루프 — 완료 (2026-03-16)

| # | 항목 | 상태 |
|---|------|------|
| 1 | 어제의 반응 카드 (앱/웹) | 완료 |
| 2 | 같은 마음의 하루 (앱/웹) | 완료 |
| 3 | 첫 daily 토스트 (앱/웹) | 완료 |

---

## 그 다음 — 배포 후 2주 데이터 보고 결정

> 아래는 모두 **추측**이다. 실사용 데이터 없이 결정하면 안 된다.
> 2주간 관찰할 것: daily 작성률, 리액션 수, 재방문율, 감정/활동 분포.

### 피드

| 항목 | 조건 |
|------|------|
| "오늘의 마을" 모아보기 | daily 사용자 5명+/일 |
| 배너 참여 수 "N명이 나눴어요" | daily 사용자 3명+/일 |
| daily → 긴 글 연결 | daily 리액션 평균 3+ |

### 작성 경험

| 항목 | 조건 |
|------|------|
| FAB 포맷 선택 (앱) | "괜찮아요" 후 daily 접근 불만 |
| 마이페이지 배너 | 위와 동일 |
| 어제의 나 (폼 상단) | 연속 daily 작성자 존재 |
| 임시 저장 | daily 작성 중단율 확인 |

### 마이페이지

| 항목 | 조건 |
|------|------|
| 주간 감정 요약 | 7일+ 연속 작성자 존재 |
| 비슷한 하루 연결 | daily 사용자 10명+/일 |

### 기술

| 항목 | 조건 |
|------|------|
| 카드 높이 최적화 | 피드 스크롤 성능 이슈 |
| SSR 프리페칭 | 웹 배너 깜빡임 민원 |
| 커스텀 활동 트렌드 | 커스텀 활동 사용률 확인 |

---

## 측정 (배포 후)

기존 DB로 쿼리 가능. 신규 인프라 불필요.

```sql
-- 일별 daily 작성 수
SELECT (created_at AT TIME ZONE 'Asia/Seoul')::DATE, COUNT(*)
FROM posts WHERE post_type = 'daily' AND deleted_at IS NULL
GROUP BY 1 ORDER BY 1 DESC;

-- daily vs 일반 글 리액션 평균
SELECT post_type, ROUND(AVG(like_count), 1)
FROM posts_with_like_count
WHERE created_at > now() - interval '14 days'
GROUP BY post_type;

-- 감정 분포 (daily만)
SELECT e, COUNT(*)
FROM posts p, post_analysis pa, unnest(pa.emotions) AS e
WHERE p.id = pa.post_id AND p.post_type = 'daily' AND p.deleted_at IS NULL
GROUP BY e ORDER BY COUNT(*) DESC;

-- 활동 분포
SELECT a, COUNT(*)
FROM posts, unnest(activities) AS a
WHERE post_type = 'daily' AND deleted_at IS NULL
GROUP BY a ORDER BY COUNT(*) DESC;

-- daily 작성자 재방문율 (2일 연속)
SELECT COUNT(DISTINCT author_id) FROM (
  SELECT author_id FROM posts WHERE post_type = 'daily' AND deleted_at IS NULL
  GROUP BY author_id HAVING COUNT(DISTINCT (created_at AT TIME ZONE 'Asia/Seoul')::DATE) >= 2
) t;
```

---

## 작업 지시

```
@docs/plan/baj/plan.md 항목 1,2,3 구현
```
