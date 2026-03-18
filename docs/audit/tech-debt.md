# 기술부채 + 개선 백로그

> **최종 갱신**: 2026-03-18

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
- [x] 앱 ContentEditor maxHeight 400
- [x] 웹 PostCard/CommentItem display_name `truncate` + `max-w-[60%]`

---

## P2 — 중간 (개선)

### DB
- [ ] groups/group_members 레거시 테이블 완전 DROP (현재 사용 안 함, 코드 참조 없음)
- [ ] user_blocks.blocked_alias FK 또는 정리 정책 — 탈퇴 사용자 별칭 orphan 가능
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
- [ ] useUnreadCount 30초 폴링 → Realtime 구독 전환
- [x] 마이페이지 섹션별 에러 바운더리 (SectionErrorBoundary, 2026-03-18)
- [ ] 에러 바운더리 컴포넌트 추가 (전역 — 마이페이지 외 나머지)
- [ ] PostDetailView 200+ 라인 → 서브 컴포넌트 분리
- [ ] Realtime 구독 패턴 추출 (useRealtimeChannel 공통 훅)
- [ ] 캐시 무효화 전략 세분화 (`['boardPosts']` 전체 → `['boardPosts', boardId]`)

### 앱
- [ ] 테스트 커버리지 확대 (현재 6파일/121테스트 → 핵심 API 훅 커버)
- [ ] Realtime 채널 수 모니터링 (다수 화면 동시 구독 시 성능)
- [ ] EmotionCalendar/EmotionWaveNative 메모이제이션 점검

---

## P3 — 낮음 (닦기)

### 문서
- [ ] SCHEMA.md v2/v3 RPC 섹션 업데이트 (현재 헤더에 "마이그레이션 27개" → 37개)
- [ ] docs/plan/DESIGN-v2-improvements.md → docs/complete/ 이동
- [ ] docs/plan/v2-type-refactor.md → docs/complete/ 이동 (구현 완료)
- [ ] docs/plan/DESIGN-v3-refinement.md → docs/complete/ 이동

### 코드
- [ ] 웹 localStorage 날짜 패턴 유틸로 추출 (배너 상태 2곳)
- [ ] 웹 낙관적 업데이트 패턴 공통화 (useComments 3x, useReactions)
- [ ] search_posts_v2 COMMENT ON FUNCTION 추가 (v1 대체 문서화)

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
