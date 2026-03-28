# 기술부채 + 개선 백로그

> **최종 갱신**: 2026-03-28

## 범례
- `[ ]` 미착수 | `[~]` 진행중 | `[x]` 완료

---

## P0 — 긴급 (서비스 영향)

모두 해결됨.

---

## P1 — 높음 (품질/안전)

### DB
- [x] post_type CHECK 제약조건 (v3, 2026-03-16)
- [x] post_analysis.analyzed_at 기본값 NULL (v3, 2026-03-16)
- [x] 알림 페이지네이션 인덱스 (v3, 2026-03-16)
- [x] display_alias partial unique index (v3, 2026-03-16)
- [x] 답글 유효성 검증 트리거 (v3, 2026-03-16)

### 타입
- [x] shared/types.ts에 Notification, UserBlock, ActivityInsight, ActivitySummary 추가 (v3)
- [x] 웹 `as any` 6곳 제거 (v2+v3, 2026-03-16)
- [x] 웹 DailyPostForm `<any>` 2곳 → 구체적 타입 (v3)
- [x] 웹 Notification 타입 중앙 통합 (v3)

### 유틸
- [x] validateDailyPostInput() 추가 (v3)

### UI Overflow 방지 (2026-03-17)
- [x] 앱 FlashList getItemType (post/daily 재활용 풀 분리)
- [x] 앱 PostBody RenderHTML `<pre>` 커스텀 렌더러 (수평 ScrollView) + blockquote overflow hidden
- [x] 앱 PostCard/PostDetailBody/CommentItem display_name `truncate` + `flex-shrink` + `max-w-[60%]`
- [x] 앱 CommentItem 답글 들여쓰기 ml-8→ml-6
- [x] 앱 ContentEditor maxHeight 600 (400→600 확대, 2026-03-28)
- [x] 웹 PostCard/CommentItem display_name `truncate` + `max-w-[60%]`

---

## P2 — 중간 (개선)

### DB
- [x] groups/group_members 레거시 테이블 완전 DROP (migration 26에서 완료, 2026-03-19)
- [ ] user_blocks.blocked_alias 정리 — 차단은 별칭 기반이므로 orphan은 무해하나, 탈퇴 시 정리 함수 고려
- [ ] Storage `post-images` 버킷 삭제 — Dashboard에서 수동 삭제 필요 (SQL 직접 삭제 불가)
- [ ] ANALYSIS_CONFIG.COOLDOWN_SECONDS DB config 테이블로 이동 (Phase E)
- [ ] 타임존 로직 단일 함수로 통합 (Edge Function + DB RPC 양쪽에 KST 로직 산재)

### UX/기능
- [x] 빈 글 제출 방지 — stripHtmlForValidation으로 빈 HTML 차단 (2026-03-17)
- [x] 오늘의 하루 바텀시트 체크인 — DailyBottomSheet (3단계 snap 프로그레시브 디스클로저, 2026-03-17)
- [x] 오늘의 하루 스트릭 보상 — get_my_streak RPC + StreakBadge (마일스톤 5단계 + streak freeze, #43, 2026-03-17)
- [x] 감정 흐름 차트 — EmotionTrendChart 순수 View 기반 (Skia 불필요, 2026-03-17)
- [x] pg_cron 자동화 — cleanup_stuck_analyses 5분마다 (#42, Dashboard pg_cron 활성화 필요)
- [x] 댓글 페이지네이션 — 웹 getComments limit=100 추가 (2026-03-17)

### 웹
- [ ] 웹 테스트 커버리지 확대 (현재 3개 → 핵심 훅/API 커버)
- [x] useUnreadCount 30초 폴링 → Realtime 구독 전환 (2026-03-21)
- [x] 마이페이지 섹션별 에러 바운더리 (SectionErrorBoundary, 2026-03-18)
- [x] 에러 바운더리 컴포넌트 추가 (전역 — 5개 라우트 error.tsx + RouteError 공통 컴포넌트, 2026-03-22)
- [ ] PostDetailView 200+ 라인 → 서브 컴포넌트 분리
- [x] Realtime 구독 패턴 추출 (useRealtimeTable 공통 훅, 4곳 적용, 2026-03-21)
- [x] 캐시 무효화 전략 세분화 — TanStack Query prefix 매칭으로 이미 동작 중 (2026-03-21)

### 앱
- [ ] 테스트 커버리지 확대 (현재 6파일/121테스트 → 핵심 API 훅 커버)
- [ ] ANR 개선 — Sentry에서 Background/Foreground ANR 3건 보고 (3/22~3/26, 프로파일링 필요)
- [x] Realtime 채널 수 — 홈 1채널만 활성, 상세 진입 시 3채널 추가 (적정, 2026-03-21)
- [x] EmotionCalendar/EmotionWaveNative React.memo 적용 (2026-03-21)

---

## P3 — 낮음 (닦기)

### 문서
- [ ] SCHEMA.md v2/v3 RPC 섹션 업데이트 (현재 헤더에 "마이그레이션 27개" → 51개)

### 코드
- [x] 웹 YesterdayReactionBanner localStorage 키 user-specific 전환 (2026-03-21)
- [ ] 웹 낙관적 업데이트 패턴 공통화 (useComments 3x, useReactions)
- [x] search_posts_v2 COMMENT ON FUNCTION — migration 44에서 33개 RPC 일괄 문서화 (2026-03-21)

---

## 완료 이력

| 날짜 | 항목 | 마이그레이션 |
|------|------|------------|
| 2026-03-16 | v2 점검: 타임존, 별칭 레이스컨디션, 알림/차단 | #36 |
| 2026-03-16 | v3 정비: CHECK, 인덱스, 타입, 유틸, 웹 타입 안전성 | #37 |
| 2026-03-17 | overflow 방지: FlashList, RenderHTML, display_name truncate, 에디터 maxHeight | — |
| 2026-03-17 | daily Evolution P1+P2: generated column, 별칭, RPC 3개, insights KST, 마이크로인터랙션, 주간회고, 커스텀활동, motion | #39 |
| 2026-03-17 | daily Evolution P3: Push 리마인더 설정 UI (expo-notifications, 4시간대, 옵트인) | — |
| 2026-03-18 | 마이페이지 동기화: 웹 SectionErrorBoundary, 로그아웃 경고, 앱 캘린더 범례/스켈레톤, 문구 통일 | — |
| 2026-03-18 | 에러 전략 통일: API throw 표준화, QueryCache/MutationCache 전역 토스트, meta.silent, 죽은코드 삭제 | — |
| 2026-03-18 | 마이페이지 UX 폴리시: WeeklySummary 스켈레톤/빈상태, EmotionWave 키보드접근, BlockedUsers 개별isPending | — |
| 2026-03-18 | 마이페이지 종합: 인증 안정화(SIGNED_OUT 재세션+캐시클리어), 코드품질(useQueries+getActivityLabel중앙+ErrorBoundary로깅), 디자인(문구버그+칩표준+색상통일) | — |
| 2026-03-18 | 오늘의하루: validateDailyPostInput 활용, alert→toast 전환, ActivityTagSelector 에러처리 | — |
| 2026-03-21 | 서비스 유지보수: 웹 admin 에러체크, 앱 useAuth 타이머 cleanup, 댓글 캐시무효화, 접근성 레이블, 알림 isPending+조건표시, audit/CLAUDE.md 갱신 | — |
| 2026-03-21 | 기술부채 해소: 웹 useRealtimeTable 공통훅(4곳), useUnreadCount Realtime 전환, 앱 React.memo(2컴포넌트), YesterdayReactionBanner user-specific key, RPC COMMENT 33개 | #44 |
| 2026-03-21 | Daily v2: get_my_daily_history + get_monthly_emotion_report RPC, 앱/웹 DailyHistory + MonthlyReport + WeeklySummary(웹 신규) | #45 |
| 2026-03-21 | Daily 버그 개편: 삭제 캐시 6쿼리 무효화(치명), 감정 fallback 순서, 웹 edit fallback, 앱 키보드 처리, 배너 자동 리셋 | — |
| 2026-03-21 | 서비스 전체 개선: GestureHandlerRootView 추가, QueryClient 최적화(experimental 제거, 4xx 재시도 방지), 앱 의존성(TanStack 5.91, Supabase 2.99) | — |
| 2026-03-22 | Sentry 에러 분석+해결: block_user 방어적 처리(#46), 웹 DOMPurify SSR 수정, extractErrorMessage 진단강화, blocks.ts APIError 래핑, Sentry fingerprint, 6이슈 resolved | #46 |
| 2026-03-22 | 바텀시트 UX: DailyBottomSheet Glassmorphism+그림자+마이크로인터랙션, 배너 문구 통일, 웹 DailyPostForm 헤더날짜+칩ring | — |
| 2026-03-27 | Sentry 일괄 수정: DB migration push(시게시판+이미지제거), 웹 DOMPurify 동적import(SSR호환), jsdom 제거, 앱 extractErrorMessage 확장+핑거프린트 개선, 14이슈 resolved | #47-48 |
| 2026-03-28 | 시 게시판 제거: board_id=13 삭제, 게시글 자유게시판 이관, 앱/웹 poem 탭·분기 코드 정리, 게시판 탭 UI 제거(단일 게시판) | #49 |
| 2026-03-28 | 글 작성 UX 개선: 웹 임시저장(useDraft+localStorage), 앱/웹 저장 상태 표시(DraftStatus) | — |
| 2026-03-28 | 에디터 개선 Phase 1: 웹 밑줄+링크+텍스트정렬(3 Tiptap 확장), 앱 글자수 HTML→텍스트 수정 | — |
| 2026-03-28 | 에디터 개선 Phase 2: 웹 정렬 SVG 아이콘+링크 SVG, 앱/웹 제목 카운터(00/100), 앱 maxHeight 400→600+프로그레스바+읽기시간, 웹 읽기시간 | — |
| 2026-03-28 | 글 작성 여정 개선: 웹 모바일 pb-24, 웹 beforeunload(작성+수정), 앱 작성 후 상세 이동, 에러 메시지 네트워크 구분 | — |
| 2026-03-28 | 유지보수 점검: 앱 HTML엔티티 카운트 수정, draft status 3초 리셋(앱/웹), EditForm formState.isDirty 활용, Suspense fallback, 에러감지 대소문자 | — |
| 2026-03-28 | DB lint 수정: search_posts_v2 image_url 제거(DROP+재생성), admin_cleanup author_id, get_my_streak STABLE→VOLATILE | #50-51 |
| 2026-03-28 | 성능: 앱 Realtime invalidate전환, FlashList estimatedItemSize, renderItem 추출, search pagination O(1), 웹 PostCard memo+useMemo | — |
| 2026-03-28 | 품질: 웹 PublicFeed 재시도버튼, PostCard 키보드접근, EmotionFilterBar aria-label, CreatePostForm label, 앱 emoji fallback, NetInfo catch | — |
