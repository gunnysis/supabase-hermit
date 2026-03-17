# v4 종합 개선 실행 계획서

> 작성일: 2026-03-17
> 작성자: Claude (개발 책임자, 전권 위임)
> 범위: 중앙/웹/앱 3개 레포 — 개발, 유지보수, 리팩토링, 디자인 패턴, 성능, UX/UI
> 기반: 마이페이지 종합 점검, 감정 타임라인 개선, 기술부채 분석, 코드 감사 4종

---

## 0. 현재 상태 스냅샷

| 구분 | 현황 |
|---|---|
| 중앙 | 마이그레이션 37개, 테이블 10개, RPC 28개, 뷰 1개, shared/ 3파일 |
| 웹 | Next.js 16, TypeScript strict, shadcn/Radix, TanStack Query, `as any` 0개, 테스트 3개 |
| 앱 | Expo SDK 55, RN 0.83, NativeWind 4, TanStack Query, `as any` 0개, 테스트 121개 |
| 배포 | 웹: Vercel Hobby, 앱: EAS Build (dev/preview/prod) |
| 관리자 | `app_admin` 테이블 + `admin_cleanup_*` RPC 2개 → **최소 유지 (선택지 A)** |

---

## 1. 설계 원칙

1. **안정성 우선** — 작동하는 코드를 깨뜨리지 않음. 마이그레이션은 멱등성 보장
2. **배포 단위 사고** — Phase가 아닌 Release로 관리, 각 Release는 독립 배포 가능
3. **변경 최소화** — 요청된 것만 구현, 부수적 리팩토링은 경계
4. **사용자 1명 현실** — 과도한 인프라/비용 설계 배제
5. **자율 판단, 결과 책임** — 구현/디버깅/설계 전권, 문제 시 자체 해결
6. **관리자 = 운영 도구** — 사용자 관리가 아닌 운영 편의 도구로 한정

---

## 2. Release 구성 총괄

```
R1 — 마이페이지 즉시 수정 (P0+P1)     ← ✅ 완료 (2026-03-17)
R1.5 — 웹/앱 기능 동기화              ← ✅ 완료 (2026-03-17)
R2 — 감정 타임라인 종합 개선           ← UX/UI + 리팩토링
R3 — 접근성 + UX 개선 (P2)            ← ✅ 완료 (2026-03-17)
R4 — DB/RPC 최적화 (P3)               ← ✅ 완료 (2026-03-17)
R5 — 디자인 패턴 + 코드 품질          ← 리팩토링 + 패턴 표준화
R6 — 관리자 운영 도구 정비             ← 관리자 최소 유지 (선택지 A)
Backlog — 장기 개선                    ← 테스트, 문서, 인프라
```

### R1.5 — 웹/앱 기능 동기화 (완료)

| # | 작업 | 상태 |
|---|---|---|
| 1 | 앱 `useUnblockUser` 훅 추가 | ✅ |
| 2 | 앱 `BlockedUsersSection` 컴포넌트 신규 생성 | ✅ |
| 3 | 앱 마이페이지 설정 섹션 + 차단 관리 추가 | ✅ |
| 4 | 앱 마이페이지 로그아웃 추가 (익명 경고 포함) | ✅ |
| 5 | 앱 `useMarkRead` 훅 추가 (개별 알림 읽음) | ✅ |
| 6 | 앱 알림 화면 탭 시 개별 읽음 처리 | ✅ |
| 7 | 앱 `useBlockedAliases` enabled 파라미터 추가 | ✅ |
| 8 | 앱 `ProfileSection` todayDaily 캐스팅 안전성 개선 | ✅ |
| 9 | 앱 `DailyInsights` 로딩 스켈레톤 추가 | ✅ |

---

## 3. Release 1 — 마이페이지 즉시 수정 (P0 + P1)

> 목표: 타입 불일치, API 중복, 에러 처리, 성능 문제 해결
> 영향: 중앙 1파일 + 웹 7파일 + 앱 7파일

### 3.1 중앙

| # | 작업 | 파일 | 상세 |
|---|---|---|---|
| 1a | ActivitySummary 타입 수정 | `shared/types.ts` | `streak_days` → `streak`, `first_post_at` 제거 |
| 1b | sync 실행 | `scripts/sync-to-projects.sh` | 웹/앱에 수정된 타입 배포 |

### 3.2 웹

| # | 작업 | 파일 | 상세 |
|---|---|---|---|
| 1c | getMyAlias 중복 제거 | `postsApi.ts` | `getMyAlias()` 삭제, import 변경 |
| 1d | 로컬 ActivitySummary 타입 제거 | `myApi.ts` | 중앙 타입 사용으로 전환 |
| 1e | todayDaily 캐스팅 수정 | `ProfileSection.tsx` | `as { emotions?: }` → Post 타입 사용 |
| 1f | staleTime 최적화 | `useTodayDaily.ts` | `staleTime: 0` → `60_000` |
| 1g | unblock 에러 toast | `BlockedUsersSection.tsx` | `toast.error('차단 해제에 실패했어요')` 추가 |
| 1h | getUnreadCount 에러 로깅 | `notificationsApi.ts` | `logger.error` 추가 |
| 1i | enabled 파라미터 추가 | `useEmotionTimeline.ts` | `enabled = true` 파라미터 |

### 3.3 앱

| # | 작업 | 파일 | 상세 |
|---|---|---|---|
| 1j | 로컬 ActivitySummary 타입 제거 | `my.ts` | 중앙 타입 사용으로 전환 |
| 1k | 색상 팔레트 통일 | `DailyInsights.tsx`, `EmotionWaveNative.tsx` | `text-gray-800` → `text-stone-900` (4곳) |
| 1l | isLoading 스켈레톤 | `EmotionWaveNative.tsx` | `isLoading` destructure + Skeleton 표시 |
| 1m | staleTime 최적화 | `useTodayDaily.ts` | `staleTime: 0` → `60_000` |
| 1n | enabled 파라미터 추가 | `useEmotionTimeline.ts` | `enabled = true` 파라미터 |

### 3.4 배포 체크리스트

- [ ] 중앙: `shared/types.ts` 수정
- [ ] 중앙: `bash scripts/sync-to-projects.sh` 실행
- [ ] 웹: 로컬 타입 제거 + import 변경 + 빌드 확인
- [ ] 웹: `vercel --prod --yes` 배포
- [ ] 앱: 로컬 타입 제거 + 빌드 확인
- [ ] 앱: `npm test` 14 suites 통과
- [ ] 중앙: `bash scripts/verify.sh` 정합성 검증

---

## 4. Release 2 — 감정 타임라인 종합 개선

> 목표: EmotionWave/EmotionWaveNative UX 리디자인 + 코드 리팩토링
> 기반: DESIGN-emotion-timeline-improvement.md
> 영향: 중앙 1파일 + 웹 3파일 + 앱 1파일

### 4.1 UX/UI 개선

| # | 개선 | 웹 | 앱 | 상세 |
|---|---|---|---|---|
| 2a | 호버/탭 툴팁 | ✅ | ✅ | 바 위에 날짜 + 감정 비율 표시 |
| 2b | 요일 라벨 | ✅ | ✅ | "N일" → "월", "화" 한글 요일 + 오늘 강조 |
| 2c | 차트 높이 확대 | ✅ | ✅ | h-24(96px) → h-32(128px) |
| 2d | 빈 상태 개선 | ✅ | ✅ | null → 고스트 바 + "아직 데이터가 없어요" 메시지 |
| 2e | 인사이트 문장 | ✅ | ✅ | "이번 주 가장 많이 나눈 감정은 X이에요" |
| 2f | 세그먼트 구분 | ✅ | ✅ | 1px 간격으로 인접 색상 구분 |
| 2g | 입장 애니메이션 | ✅ | — | 스태거 growUp (reduced-motion 대응) |

### 4.2 리팩토링

| # | 작업 | 파일 | 상세 |
|---|---|---|---|
| 2h | 바 데이터 변환 공유 | `shared/utils.ts` | `processEmotionTimeline()` 이미 존재 — 활용 확인 |
| 2i | 스켈레톤 높이 고정 | `EmotionWave.tsx` | `Math.random()` 제거 → 고정 패턴 |

### 4.3 배포 체크리스트

- [ ] 웹: EmotionWave 호버 툴팁 동작 확인
- [ ] 앱: EmotionWaveNative 탭 인터랙션 확인
- [ ] 양쪽: 빈 데이터 상태에서 고스트 바 표시 확인
- [ ] 웹: reduced-motion 미디어 쿼리 대응 확인

---

## 5. Release 3 — 접근성 + UX 개선 (P2)

> 목표: ARIA 속성, 키보드 접근성, 빈 상태 UX
> 영향: 웹 3파일 + 앱 2파일

### 5.1 접근성

| # | 작업 | 대상 | 상세 |
|---|---|---|---|
| 3a | 프로그레스 바 ARIA | 웹/앱 `DailyInsights.tsx` | `role="progressbar"`, `aria-valuenow`, `aria-valuemax`, `aria-label` |
| 3b | 툴팁 ARIA | 웹 `EmotionWave.tsx` | `role="tooltip"` + `aria-describedby` + 키보드 접근 |

### 5.2 UX

| # | 작업 | 대상 | 상세 |
|---|---|---|---|
| 3c | 빈 activity_emotion_map | 웹/앱 `DailyInsights.tsx` | `return null` → "활동 데이터를 모으는 중이에요" 안내 메시지 |

### 5.3 배포 체크리스트

- [ ] 웹: 스크린 리더로 프로그레스 바 읽기 확인
- [ ] 웹: 키보드 Tab으로 EmotionWave 바 탐색 확인
- [ ] 양쪽: 활동 데이터 없는 상태에서 안내 메시지 표시 확인

---

## 6. Release 4 — DB/RPC 최적화 (P3)

> 목표: 타임존 정합성, 보안 권한, 쿼리 성능
> 영향: 중앙 1 마이그레이션 + 웹 2파일 + 앱 2파일

### 6.1 마이그레이션 (신규)

파일명: `20260328000001_mypage_rpc_optimization.sql`

```sql
-- 6.1a: get_emotion_timeline KST 타임존 적용
CREATE OR REPLACE FUNCTION public.get_emotion_timeline(p_days INT DEFAULT 7)
RETURNS TABLE(day DATE, emotion TEXT, cnt BIGINT)
LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'public' AS $$
BEGIN
  RETURN QUERY
  SELECT (pa.analyzed_at AT TIME ZONE 'Asia/Seoul')::DATE,
         unnest(pa.emotions),
         COUNT(*)::BIGINT
  FROM post_analysis pa
  WHERE pa.analyzed_at >= (now() AT TIME ZONE 'Asia/Seoul' - (p_days || ' days')::INTERVAL)
        AT TIME ZONE 'Asia/Seoul'
  GROUP BY 1, 2
  ORDER BY 1, 3 DESC;
END;
$$;

-- 6.1b: get_my_activity_summary INVOKER 전환
CREATE OR REPLACE FUNCTION public.get_my_activity_summary()
RETURNS JSON
LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'public' AS $$
  -- (기존 본문 유지, SECURITY DEFINER → INVOKER만 변경)
$$;

-- 6.1c: get_user_emotion_calendar 성능 최적화
CREATE OR REPLACE FUNCTION public.get_user_emotion_calendar(
  p_user_id UUID,
  p_start DATE DEFAULT (CURRENT_DATE - 30)::DATE,
  p_end DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(day DATE, emotions TEXT[], post_count INT)
LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'public' AS $$
BEGIN
  RETURN QUERY
  SELECT d.day::DATE,
    COALESCE(array_agg(DISTINCT e) FILTER (WHERE e IS NOT NULL), '{}')::TEXT[],
    COUNT(DISTINCT p.id)::INT
  FROM generate_series(p_start, p_end, '1 day'::INTERVAL) AS d(day)
  LEFT JOIN posts p ON p.author_id = p_user_id
    AND p.deleted_at IS NULL
    AND p.created_at >= d.day::TIMESTAMPTZ          -- 인덱스 활용 가능
    AND p.created_at < (d.day + 1)::TIMESTAMPTZ     -- 범위 비교
  LEFT JOIN post_analysis pa ON pa.post_id = p.id
  LEFT JOIN LATERAL unnest(pa.emotions) AS e ON TRUE
  GROUP BY d.day
  ORDER BY d.day;
END;
$$;
```

### 6.2 클라이언트 API 추출

| # | 작업 | 대상 | 상세 |
|---|---|---|---|
| 4a | EmotionCalendar API 추출 | 웹 `myApi.ts` | 인라인 → `getUserEmotionCalendar()` 함수 추출 |
| 4b | EmotionCalendar API 추출 | 앱 `my.ts` | 동일 |
| 4c | EmotionCalendar import 변경 | 웹/앱 `EmotionCalendar.tsx` | 인라인 함수 → API 모듈 import |

### 6.3 배포 체크리스트

- [ ] 중앙: `bash scripts/db.sh push --dry-run` → 마이그레이션 확인
- [ ] 중앙: `bash scripts/db.sh push` → 자동 gen-types + sync + verify
- [ ] 웹: 감정 캘린더 데이터 정상 표시 확인
- [ ] 웹: 감정 타임라인 KST 날짜 확인 (자정 전후)
- [ ] 앱: 동일 확인
- [ ] 롤백 SQL 준비 (SECURITY DEFINER 복원, DATE 캐스팅 복원)

### 6.4 롤백 SQL

```sql
-- INVOKER → DEFINER 복원 (장애 시)
-- get_emotion_timeline, get_my_activity_summary 본문을 SECURITY DEFINER로 재생성
-- get_user_emotion_calendar: p.created_at::DATE = d.day::DATE 복원
```

---

## 7. Release 5 — 디자인 패턴 + 코드 품질

> 목표: 코드 패턴 표준화, 리팩토링, 디자인 시스템 정비
> 영향: 웹 5-8파일 + 앱 3-5파일

### 7.1 Realtime 패턴 추출

| # | 작업 | 대상 | 상세 |
|---|---|---|---|
| 5a | useRealtimeChannel 공통 훅 | 웹 `hooks/` | Realtime 구독 패턴 추출 (comments, reactions, post_analysis 3곳 공통화) |

**현재 패턴** (각 컴포넌트에서 반복):
```typescript
useEffect(() => {
  const channel = supabase.channel(`entity-${id}`)
    .on('postgres_changes', { ... }, () => queryClient.invalidateQueries(...))
    .subscribe()
  return () => { supabase.removeChannel(channel) }
}, [id])
```

**개선**:
```typescript
// hooks/useRealtimeChannel.ts
function useRealtimeChannel(table: string, filter: string, queryKeys: string[][]) { ... }

// 사용
useRealtimeChannel('comments', `post_id=eq.${postId}`, [['comments', postId]])
```

### 7.2 캐시 무효화 세분화

| # | 작업 | 상세 |
|---|---|---|
| 5b | boardPosts 키 세분화 | `['boardPosts']` 전체 무효화 → `['boardPosts', boardId]` 세분화 |

### 7.3 PostDetailView 분리

| # | 작업 | 상세 |
|---|---|---|
| 5c | 서브 컴포넌트 분리 | 200+ 라인 → PostHeader, PostContent, PostActions, PostComments 분리 |

### 7.4 에러 처리 패턴 표준화

| # | 작업 | 상세 |
|---|---|---|
| 5d | API 에러 패턴 통일 | 모든 API 함수: `logger.error('[함수명]', error.message, { code: error.code })` + throw |
| 5e | 훅 onError 표준 | mutation 훅: `onError → logger.error + toast.error` 일관 적용 |

### 7.5 디자인 시스템 정비

| # | 작업 | 웹 | 앱 | 상세 |
|---|---|---|---|---|
| 5f | 로딩 패턴 통일 | ✅ | ✅ | 모든 데이터 훅에 isLoading → Skeleton 표시 패턴 |
| 5g | 빈 상태 패턴 | ✅ | ✅ | 데이터 없을 때 일관된 EmptyState 컴포넌트 사용 |
| 5h | 트랜지션 표준 | ✅ | — | 중앙 MOTION 상수 활용한 일관된 애니메이션 타이밍 |

### 7.6 배포 체크리스트

- [ ] 웹: Realtime 구독 정상 작동 확인 (댓글, 리액션, 감정분석)
- [ ] 웹: PostDetailView 렌더링 정상 확인
- [ ] 웹: 에러 발생 시 toast 표시 확인
- [ ] 앱: 로딩/빈 상태 UI 확인
- [ ] Sentry 에러 그루핑 정상 확인

---

## 8. Release 6 — 관리자 운영 도구 정비 (선택지 A)

> 목표: 그룹 게시판 제거 후 관리자 역할을 **운영 관리**로 재정립
> 원칙: 최소 유지 — 현재 유용한 것 보존, 불필요한 것 제거, 향후 확장 가능성 열어둠

### 8.1 현황 분석

| 구성 요소 | 현재 상태 | 판정 |
|---|---|---|
| `app_admin` 테이블 | user_id, created_at | **유지** — 관리자 식별 기반 |
| `admin_cleanup_posts()` RPC | hard DELETE with CASCADE | **유지** — 테스트 데이터 정리에 유용 |
| `admin_cleanup_comments()` RPC | hard DELETE | **유지** — 동상 |
| 관리자 RLS (is_admin 체크) | soft_delete_post/comment에서 사용 | **유지** — 관리자 삭제 권한 |
| 웹 관리자 대시보드 | AdminDashboard 컴포넌트 | **정비** — 그룹 관련 제거, 운영 도구 유지 |
| 앱 관리자 진입 | AdminLongPress 컴포넌트 | **정비** — 그룹 관련 제거 |

### 8.2 변경 작업

| # | 작업 | 상세 |
|---|---|---|
| 6a | 웹 관리자 대시보드 정리 | 그룹 관련 UI 요소 제거, 남은 기능: 테스트 데이터 정리, 감정분석 현황 |
| 6b | 앱 관리자 패널 정리 | 동일 |
| 6c | 관리자 역할 문서화 | CLAUDE.md에 관리자 = 운영 도구 명시 |

### 8.3 향후 확장 가능성 (구현하지 않음, 필요 시 추가)

- 신고된 글 검토 대시보드
- 감정분석 실패 모니터링 (stuck 분석 현황)
- 공지사항 기능
- 사용자 통계 (일간/주간 활성 사용자)

### 8.4 배포 체크리스트

- [ ] 웹: 관리자 대시보드 진입 → 그룹 관련 요소 없음 확인
- [ ] 앱: 관리자 패널 진입 → 정상 동작 확인
- [ ] 관리자 테스트 데이터 정리 기능 동작 확인

---

## 9. Backlog — 장기 개선

> 우선순위 낮음 또는 규모가 커서 별도 Release 필요한 항목

### 9.1 테스트 확대

| 대상 | 현재 | 목표 | 우선순위 |
|---|---|---|---|
| 웹 | 3개 (validation) | 핵심 훅/API 10개+ | P2 |
| 앱 | 121개 (14 suites) | API 훅 커버 확대 | P3 |
| E2E | 앱 Maestro만 | 웹 Playwright 추가 | P3 |

### 9.2 성능 최적화

| 항목 | 상세 | 우선순위 |
|---|---|---|
| useUnreadCount 폴링 → Realtime | 30초 폴링을 Supabase Realtime 구독으로 전환 | P2 |
| Realtime 채널 수 모니터링 | 다수 화면 동시 구독 시 성능 체크 | P2 |
| EmotionCalendar 메모이제이션 | 앱 렌더링 최적화 | P3 |
| 이미지 캐싱 전략 | 앱 expo-image 캐시 정책 설정 | P3 |

### 9.3 인프라 + 보안

| 항목 | 상세 | 우선순위 |
|---|---|---|
| 레거시 테이블 DROP | groups/group_members 완전 제거 (현재 사용 안 함) | P2 |
| user_blocks orphan 정책 | 탈퇴 사용자 별칭 처리 | P3 |
| CSP unsafe-eval 제거 시도 | Next.js 프로덕션에서 eval 필요 여부 확인 | P3 |
| Sentry 쿼터 모니터링 | 2,500건/월 초과 시 Rate Limiting | P3 |

### 9.4 UX/UI 장기 개선

| 항목 | 상세 | 우선순위 |
|---|---|---|
| 앱 푸시 알림 | expo-notifications + FCM/APNs 연동 | P2 |
| 앱 차단 관리 UI | BlockedUsersSection 신규 컴포넌트 | P2 |
| 앱 설정 섹션 | 마이페이지 내 설정 탭 추가 | P2 |
| 오프라인 mutation 큐 | TanStack Query mutation 오프라인 큐 | P3 |
| iOS Universal Links | 딥링크 완성 | P3 |

### 9.5 문서 정비

| 항목 | 상세 | 우선순위 |
|---|---|---|
| SCHEMA.md 갱신 | v2/v3 RPC 섹션 업데이트 | P2 |
| 완료 설계 문서 이동 | DESIGN-v2, v3 → docs/complete/ | P3 |
| search_posts_v2 주석 | COMMENT ON FUNCTION 추가 | P3 |

---

## 10. Release 실행 순서 + 의존성

```
R1 ─────────────> R2 ─────────────> R3
(마이페이지 P0+P1) (감정 타임라인)     (접근성 P2)
                                      │
R4 ─────────────────────────────────> R5
(DB/RPC 최적화)                       (디자인 패턴)
                                      │
                  R6 ─────────────────┘
                  (관리자 정비)
```

**의존성**:
- R1 → R2: 감정 타임라인 개선은 R1의 `useEmotionTimeline` enabled 파라미터 적용 후
- R1 → R3: 접근성 개선은 R1의 기본 수정 완료 후
- R4 독립: DB 마이그레이션은 클라이언트와 병렬 가능
- R5는 R1-R4 완료 후: 패턴 표준화는 개별 수정 완료 후
- R6 독립: 관리자 정비는 언제든 실행 가능

### 실행 타임라인

| Release | 예상 소요 | 누적 |
|---|---|---|
| R1 | 2-3시간 | Day 1 |
| R2 | 3-4시간 | Day 1-2 |
| R3 | 1-2시간 | Day 2 |
| R4 | 2-3시간 | Day 2-3 |
| R5 | 3-4시간 | Day 3-4 |
| R6 | 1-2시간 | Day 4 |

**총 예상: 4-5일** (버퍼 20% 포함)

---

## 11. 리스크 매트릭스

| 리스크 | 확률 | 영향 | 대응 |
|---|---|---|---|
| ActivitySummary 타입 변경 시 빌드 실패 | 중간 | 중간 | sync 후 즉시 빌드 테스트, 로컬 타입 우회 코드 제거 확인 |
| SECURITY INVOKER 전환 후 데이터 미표시 | 낮음 | 높음 | RLS가 이미 `auth.uid()` 필터링 → 대부분 안전. 롤백 SQL 준비 |
| get_emotion_timeline KST 전환 시 데이터 불연속 | 낮음 | 중간 | 전환 시점에 1회 불연속 발생 가능, 자연 해소 |
| Realtime 패턴 추출 시 구독 누락 | 중간 | 중간 | 기존 테스트로 검증, 배포 후 실시간 업데이트 확인 |
| Vercel Hobby 배포 실패 | 높음 | 낮음 | `vercel --prod --yes` 수동 배포 |
| PostDetailView 분리 시 렌더링 깨짐 | 중간 | 중간 | 분리 전후 스크린샷 비교, props 전달 누락 확인 |

---

## 12. 성공 기준

| Release | 기준 |
|---|---|
| R1 | `as any` 0개 유지, 웹/앱 빌드 성공, sync+verify 통과, staleTime 효과 확인 (Network 탭) |
| R2 | EmotionWave 호버 툴팁 동작, 요일 라벨 표시, 빈 상태 메시지, 인사이트 문장 |
| R3 | 스크린 리더 프로그레스 바 읽기, 키보드 탐색 가능, 빈 데이터 안내 메시지 |
| R4 | KST 자정 전후 데이터 정합성, 캘린더 쿼리 성능 (EXPLAIN 확인) |
| R5 | Realtime 3곳 공통 훅 사용, 에러 처리 패턴 일관, PostDetailView 정상 렌더링 |
| R6 | 관리자 대시보드 그룹 요소 없음, cleanup RPC 정상 동작 |

---

## 13. 통합된 기존 설계 문서

이 문서는 다음 설계 문서들을 통합합니다:

| 문서 | 상태 | 통합 위치 |
|---|---|---|
| `DESIGN-mypage-comprehensive-audit.md` | 검증 완료 (16개 이슈) | R1, R3, R4 |
| `DESIGN-emotion-timeline-improvement.md` | 설계 완료 | R2 |
| `memo/REVIEW-dev-lead-analysis.md` | 리뷰 완료 (R1-R5 판정) | 전체 구조 참조 |
| `docs/audit/tech-debt.md` | 감사 완료 | R5, Backlog |

---

## 14. 비변경 사항

- DB 스키마 (테이블/뷰) 구조 변경 없음
- RPC 반환값 변경 없음 (함수 시그니처 유지)
- shared/constants.ts 변경 없음
- 네비게이션 구조 변경 없음
- 앱 번들 ID / 웹 도메인 변경 없음
- Sentry 플랜 변경 없음 (Developer 무료 유지)

---

## 15. 보고 기준

다음 경우에만 사용자에게 보고:
1. Release 배포 완료 시 (성공/실패)
2. 롤백 필요 시
3. 설계 변경이 필요한 예상치 못한 문제 발견 시
4. Backlog 항목 중 긴급 격상이 필요한 경우
5. 사용자 입력이 필요한 경우 (`needs.md`)

그 외 구현/디버깅/테스트는 자율 진행.
