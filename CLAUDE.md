# CLAUDE.md — 은둔마을 Supabase 중앙 프로젝트

이 프로젝트는 은둔마을 앱/웹이 공유하는 **Supabase DB 스키마의 단일 정본(Single Source of Truth)**.

## 구조

```
supabase-hermit/
├── supabase/
│   ├── config.toml                 # Supabase 프로젝트 설정
│   └── migrations/                 # 모든 마이그레이션 원본
│       ├── 20260301000001_schema.sql              # 베이스라인: 테이블/함수/뷰/트리거/인덱스
│       ├── 20260301000002_rls.sql                 # 베이스라인: RLS 정책
│       ├── 20260301000003_infra.sql               # 베이스라인: 권한(grants) + Storage
│       ├── 20260302000000_fix_rls_update_policies.sql  # UPDATE 정책 수정
│       ├── 20260303000001_core_redesign.sql       # 리액션 RPC, 소프트삭제, FK CASCADE, 제약조건
│       ├── 20260303000002_fix_group_members_recursion.sql  # RLS 자기참조 재귀 수정
│       ├── 20260303000003_post_update_reanalysis.sql  # 글 수정 시 감정분석 자동 재실행
│       ├── 20260304000001_fix_reactions_data.sql      # 리액션 데이터 정합성 수정
│       ├── 20260306000001_remove_author_column.sql    # author 컬럼 제거
│       ├── 20260307000001_recommendation_improvements.sql  # 추천 개선 (트렌딩, 감정 폴백, 시간 감쇠)
│       ├── 20260308000001_ux_redesign.sql             # UX 리디자인: initial_emotions, user_preferences, 감정 RPC들
│       ├── 20260309000001_security_performance_fixes.sql  # 보안/성능: boards RLS, 인덱스, RPC 최적화, 제약조건
│       ├── 20260310000001_comprehensive_improvements.sql  # 공개 게시판, 뷰 최적화, 검색 RPC, 동시성/관리자 삭제
│       ├── 20260311000001_fix_rpc_missing_columns.sql     # get_posts_by_emotion RPC 컬럼 보강
│       ├── 20260311000002_fix_search_posts_columns.sql    # search_posts RPC 컬럼 보강
│       ├── 20260311000003_analysis_status_retry.sql       # 감정분석 상태 추적 + 재시도 (status/retry_count/error_reason)
│       └── 20260312000001_search_v2.sql                  # 검색 v2: 풀텍스트 + 관련도 + 하이라이트 + 감정 필터
├── shared/
│   ├── constants.ts                # 공유 상수 (ALLOWED_EMOTIONS, EMOTION_EMOJI, EMOTION_COLOR_MAP, MOTION, EMPTY_STATE_MESSAGES, GREETING_MESSAGES)
│   └── types.ts                    # 공유 비즈니스 타입 (Post, Comment 등)
├── types/
│   └── database.gen.ts             # 자동 생성 DB 타입 (gen-types.sh 산출물)
├── scripts/
│   ├── db.sh                       # Supabase CLI 래퍼 (push/pull/diff/lint/status/gen-types)
│   ├── gen-types.sh                # DB 스키마 -> TypeScript 타입 생성
│   └── sync-to-projects.sh        # 앱/웹 레포로 migrations + config + types 동기화
├── docs/
│   ├── SCHEMA.md                   # DB 스키마 상세 문서
│   ├── SCRIPTS.md                  # 스크립트 사용법 상세
│   ├── CLIENT-ARCHITECTURE.md      # 앱/웹 클라이언트 연동 아키텍처
│   └── DESIGN-home-ux-optimization.md  # 홈 UX/UI 최적화 설계 문서
├── package.json                    # npm scripts 편의용 (의존성 없음)
├── .env                            # SUPABASE_ACCESS_TOKEN (git 제외)
└── CLAUDE.md
```

## DB 스키마 요약

### 테이블 (10개)
| 테이블 | 설명 |
|---|---|
| `groups` | 그룹 (invite_only / request_approve / code_join) |
| `boards` | 게시판 (public/private, 익명모드 설정) |
| `group_members` | 그룹 멤버십 (PK: group_id + user_id) |
| `posts` | 게시글 (소프트삭제 지원, 자동 감정 분석, initial_emotions) |
| `comments` | 댓글 (소프트삭제 지원) |
| `reactions` | 리액션 집계 (post_id + reaction_type 별 count) |
| `user_reactions` | 사용자별 리액션 기록 |
| `post_analysis` | AI 감정 분석 결과 (emotions 배열, status/retry_count/error_reason) |
| `user_preferences` | 사용자 설정 (감정 선호, 테마, 온보딩) |
| `app_admin` | 앱 관리자 |

### 뷰 (1개)
- `posts_with_like_count` — 게시글 + 좋아요수 + 댓글수 + 감정 (security_invoker)

### RPC 함수 (16개)
| 함수 | 설명 |
|---|---|
| `toggle_reaction(post_id, type)` | 리액션 토글 (SECURITY DEFINER + advisory lock) |
| `get_post_reactions(post_id)` | 게시글 리액션 + 사용자 상태 조회 |
| `soft_delete_post(post_id)` | 게시글 소프트삭제 (본인 + 관리자) |
| `soft_delete_comment(comment_id)` | 댓글 소프트삭제 (본인 + 관리자) |
| `is_group_member(group_id)` | 그룹 멤버십 확인 (RLS 재귀 방지) |
| `get_emotion_trend(days)` | 감정 트렌드 집계 (상위 5개, pct 포함) |
| `get_recommended_posts_by_emotion(post_id, limit)` | 감정 기반 추천 (폴백 + 시간 감쇠) |
| `get_trending_posts(hours, limit)` | 트렌딩 게시글 (참여도/시간 가중) |
| `cleanup_orphan_group_members(days)` | 비활성 익명 사용자 정리 |
| `get_posts_by_emotion(emotion, limit, offset)` | 특정 감정 게시글 필터 |
| `get_similar_feeling_count(post_id, days)` | 비슷한 마음 사용자 수 |
| `get_user_emotion_calendar(user_id, start, end)` | 사용자 감정 캘린더 히트맵 |
| `get_emotion_timeline(days)` | 감정 분포 타임라인 |
| `get_my_activity_summary()` | 내 활동 요약 (글/댓글/반응/스트릭) |
| `search_posts(query, limit, offset)` | 게시글 검색 v1 (ILIKE, deprecated) |
| `search_posts_v2(query, emotion, sort, limit, offset)` | 게시글 검색 v2 (풀텍스트 + 관련도 + 하이라이트) |

### Edge Functions (앱 레포에서 관리)
| 함수 | JWT 검증 | 설명 |
|---|---|---|
| `analyze-post` | X | DB Trigger (게시글 INSERT/UPDATE시 자동 호출, 60초 쿨다운, 서버 재시도 2회) |
| `analyze-post-on-demand` | O | 수동 감정 분석 요청 (fallback + 재시도, 쿨다운 우회, 서버 재시도 2회) |

## 워크플로

### 1. 새 마이그레이션 작성
이 디렉터리에서만 작성. 앱/웹 레포에서 직접 만들지 않음.

```bash
# 새 SQL 파일 생성 (타임스탬프 형식: YYYYMMDDHHMMSS)
vi supabase/migrations/20260304000001_description.sql

# dry-run 확인
bash scripts/db.sh push --dry-run

# 적용 (자동으로 gen-types -> sync -> verify 실행됨)
bash scripts/db.sh push
```

> `push` 성공 시 자동으로 타입 재생성(`gen-types.sh`) → 앱/웹 동기화(`sync-to-projects.sh`) → 정합성 검증(`verify.sh`)이 실행된다.
> gen-types 실패 시 sync를 건너뛰고 에러를 표시한다.
> 수동 sync가 필요한 경우: `bash scripts/sync-to-projects.sh`

### 2. Remote 변경 사항 가져오기 (Dashboard에서 수정한 경우)
```bash
bash scripts/db.sh pull
```

### 3. 타입만 재생성
```bash
bash scripts/gen-types.sh
# 또는
bash scripts/db.sh gen-types
```

### 4. 상태 확인
```bash
bash scripts/db.sh status   # 로컬/remote 비교
bash scripts/db.sh lint      # RLS/스키마 린트
bash scripts/db.sh verify    # 레포 간 정합성 검증
```

### 5. npm scripts (편의용)
```bash
npm run push          # db push + gen-types + sync + verify
npm run push:dry      # dry-run
npm run pull          # remote -> local
npm run status        # migration 상태
npm run lint          # RLS/스키마 린트
npm run gen-types     # 타입만 재생성 (변경 감지)
npm run sync          # 동기화만 실행
npm run sync:dry      # 동기화 미리보기
npm run verify        # 레포 간 정합성 검증
```

## 동기화 대상

`sync-to-projects.sh`는 다음 5가지를 앱/웹 레포에 복사한다:

| 소스 (중앙) | 앱 대상 | 웹 대상 |
|---|---|---|
| `supabase/migrations/*.sql` | `supabase/migrations/*.sql` | `supabase/migrations/*.sql` |
| `supabase/config.toml` | `supabase/config.toml` | `supabase/config.toml` |
| `types/database.gen.ts` | `src/types/database.gen.ts` | `src/types/database.gen.ts` |
| `shared/constants.ts` | `src/shared/lib/constants.generated.ts` | `src/lib/constants.generated.ts` |
| `shared/types.ts` | `src/types/database.types.ts` | `src/types/database.types.ts` |

옵션: `--app` (앱만), `--web` (웹만), `--dry` (미리보기)

## 규칙

- **마이그레이션은 여기서만 생성** — 앱/웹 레포의 `supabase/migrations/`는 읽기 전용 복사본
- **push 후 sync 자동 실행** — `db.sh push` 성공 시 자동 처리
- **generated types는 수동 types와 공존** — `database.gen.ts`는 자동 생성, 비즈니스 타입은 별도 관리
- **Edge Functions는 앱 레포** — `supabase/functions/`는 앱에서 관리/배포
- **RLS에서 자기참조 금지** — `group_members` 정책에서 `group_members` 직접 SELECT 하면 무한 재귀. `is_group_member()` SECURITY DEFINER 함수 사용
- **리액션은 RPC만 사용** — `reactions`/`user_reactions` 직접 쓰기 정책 제거됨. `toggle_reaction()` 사용
- **삭제는 소프트삭제** — `posts`, `comments`의 hard DELETE 정책 제거. `soft_delete_post()`, `soft_delete_comment()` 사용
- **멱등 마이그레이션** — `IF NOT EXISTS`, `CREATE OR REPLACE`, `DROP POLICY IF EXISTS` 패턴 적용
- **공유 상수/타입은 `shared/`에서만 수정** — `shared/constants.ts`, `shared/types.ts`는 sync로 앱/웹에 배포. 앱/웹의 generated 파일 직접 수정 금지

## 연결 정보

- Project ref: `qwrjebpsjjdxhhhllqcw`
- 앱 레포: `/mnt/c/Users/Administrator/programming/apps/gns-hermit-comm`
- 웹 레포: `/home/gunny/apps/web`

## 상세 문서

- [DB 스키마 상세](docs/SCHEMA.md) — 테이블/뷰/함수/RLS/트리거/제약조건/Edge Functions 전체
- [스크립트 사용법](docs/SCRIPTS.md) — db.sh, gen-types.sh, sync-to-projects.sh 상세
- [클라이언트 아키텍처](docs/CLIENT-ARCHITECTURE.md) — 앱/웹 심리분석 흐름, 공유 코드 관리, Realtime 패턴
- [홈 UX 최적화 설계](docs/DESIGN-home-ux-optimization.md) — 홈 화면 게시글 영역 확대 설계
