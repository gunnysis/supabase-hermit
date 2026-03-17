# 오늘의 하루 — 구현 작업 지시서

> **설계**: [DESIGN.md](DESIGN.md) | **근거**: [RESEARCH.md](RESEARCH.md)
> **대상**: Claude (전권 위임, 자율 판단 후 결과 보고)

---

## 실행 규칙

- 마이그레이션은 **중앙 레포에서만** 생성
- `db.sh push` 후 gen-types → sync → verify 자동 체이닝 확인
- 구현 완료 후 CLAUDE.md, SCHEMA.md 문서 갱신

---

## Phase 0: 앱 마이페이지 — 완료 (2026-03-16)

앱 탭 3→4개 (홈/검색/작성[숨김]/**나**). 웹 /my의 모바일 버전.

**산출물**: `my.tsx`, `api/my.ts`, hooks 2개, 컴포넌트 2개 (ActivitySummary, EmotionWaveNative)

---

## Phase 1: 오늘의 하루 MVP — 완료 (2026-03-16)

**마이그레이션**: `20260323000001_daily_post.sql` (30번째)

**중앙**: posts 확장(post_type, activities) + 인덱스 3개 + 트리거 4개 WHEN 조건 + 뷰 재생성 + RPC 3개 + 상수(ACTIVITY_PRESETS, DAILY_CONFIG) + 타입(post_type, activities)

**앱 신규**: DailyPostCard, DailyPostForm, ActivityTagSelector, HomeCheckinBanner, hooks 2개, API 3개
**앱 수정**: _layout(탭), index(배너), PostCard(분기), api/index, constants

**웹 신규**: DailyPostCard, DailyPostForm, ActivityTagSelector, HomeCheckinBanner, hooks 2개, API 3개
**웹 수정**: PostCard(분기), PublicFeed(배너), postsApi, create/page, constants

---

## Phase 2a: 나의 패턴 — 완료 (2026-03-16)

> 조건 없이 실행 가능. 데이터 부족 시 빈 상태 UX.

**배경**: 감정 캘린더/트렌드/타임라인은 Phase 1에서 이미 자동 포함됨 (기존 RPC에 post_type 필터 없음). 남은 핵심: **활동-감정 상관관계** — "외출한 날 평온함이 자주"를 보여줘서 학습된 무력감을 반증.

### Step 1: 마이그레이션

**파일**: `supabase/migrations/2026MMDD000001_daily_insights.sql`

```sql
CREATE OR REPLACE FUNCTION get_daily_activity_insights(
  p_days INT DEFAULT 30
)
RETURNS JSON
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := (SELECT auth.uid());
  v_since DATE := CURRENT_DATE - p_days;
  v_total INT;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM posts
  WHERE author_id = v_user_id AND post_type = 'daily'
    AND deleted_at IS NULL AND created_at::DATE >= v_since;

  IF v_total < 7 THEN
    RETURN json_build_object(
      'total_dailies', v_total,
      'activity_emotion_map', '[]'::JSON
    );
  END IF;

  RETURN json_build_object(
    'total_dailies', v_total,
    'activity_emotion_map', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
      FROM (
        SELECT
          a AS activity,
          COUNT(DISTINCT p.id)::INT AS count,
          (
            SELECT COALESCE(json_agg(json_build_object(
              'emotion', sub.emotion, 'pct', sub.pct
            )), '[]'::JSON)
            FROM (
              SELECT e AS emotion,
                ROUND(COUNT(*)::NUMERIC * 100
                  / NULLIF(SUM(COUNT(*)) OVER(), 0)) AS pct
              FROM posts p2
              JOIN post_analysis pa ON pa.post_id = p2.id,
              LATERAL unnest(pa.emotions) AS e
              WHERE p2.author_id = v_user_id AND p2.post_type = 'daily'
                AND p2.deleted_at IS NULL AND p2.created_at::DATE >= v_since
                AND a = ANY(p2.activities)
              GROUP BY e ORDER BY COUNT(*) DESC LIMIT 2
            ) sub
          ) AS emotions
        FROM posts p, unnest(p.activities) AS a
        WHERE p.author_id = v_user_id AND p.post_type = 'daily'
          AND p.deleted_at IS NULL AND p.created_at::DATE >= v_since
        GROUP BY a HAVING COUNT(DISTINCT p.id) >= 3
        ORDER BY COUNT(DISTINCT p.id) DESC LIMIT 5
      ) t
    )
  );
END;
$$;
```

### Step 2: 상수

`shared/constants.ts`에 추가:
```typescript
export const DAILY_INSIGHTS_CONFIG = {
  MIN_DAILIES_FOR_INSIGHTS: 7,
  MIN_ACTIVITY_COUNT: 3,
} as const;
```

앱/웹 barrel re-export에 `DAILY_INSIGHTS_CONFIG` 추가.

### Step 3: 앱 구현

| 파일 | 역할 |
|------|------|
| `src/shared/lib/api/my.ts` | `getDailyInsights(days)` 추가 |
| `src/features/my/hooks/useDailyInsights.ts` | useQuery, staleTime=1h |
| `src/features/my/components/DailyInsights.tsx` | 패턴 바 차트 + 메시지 |
| `src/app/(tabs)/my.tsx` 수정 | EmotionCalendar 위에 삽입 |

**DailyInsights 로직**:
- `total_dailies < 7`: "아직 패턴을 찾고 있어요 ({n}/7일)"
- 데이터 있음: 활동별 감정 비율 바 + "💡 외출한 날에 평온함이 자주 나타나요"

### Step 4: 웹 구현

동일 구조. `postsApi.ts`에 API, `my/hooks/`에 hook, `my/components/`에 컴포넌트, `my/page.tsx` 수정.

### 검증

- [ ] 7일 미만 → 빈 상태 + 진행 표시
- [ ] 7일+ → 활동별 감정 패턴 정상
- [ ] 앱/웹 다크/라이트

---


