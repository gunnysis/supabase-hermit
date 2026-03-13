# Supabase Advisor 권고사항 수정

> 작성: 2026-03-13 | 상태: 구현 중

## 1. Performance Advisor — RLS initplan 최적화

### 문제
`auth.uid()`, `auth.role()`를 RLS 정책에서 직접 호출하면 **행마다 재평가**됨.
`(select auth.uid())`로 래핑하면 쿼리당 1회만 실행 → 대규모 테이블에서 성능 차이.

### 대상 정책 (6개)

| 테이블 | 정책명 | 현재 | 수정 |
|--------|--------|------|------|
| user_preferences | user_prefs_select | `auth.uid() = user_id` | `(select auth.uid()) = user_id` |
| user_preferences | user_prefs_insert | `auth.uid() = user_id` | `(select auth.uid()) = user_id` |
| user_preferences | user_prefs_update | `auth.uid() = user_id` | `(select auth.uid()) = user_id` |
| posts | Users can update own posts | `auth.uid() = author_id` (USING + WITH CHECK) | `(select auth.uid()) = author_id` |
| comments | Users can update own comments | `auth.uid() = author_id` (USING + WITH CHECK) | `(select auth.uid()) = author_id` |
| post_analysis | post_analysis_select | `auth.role() = 'authenticated'` | `(select auth.role()) = 'authenticated'` |

## 2. Security Advisor — function search_path

### 문제
`get_post_reactions`가 `search_path` 미설정 → search_path 조작 공격 가능.

### 수정
`SET search_path = public` 추가.

## 3. Security Advisor — Extensions in public

### 문제
`pg_trgm`, `pgroonga`가 public 스키마에 설치됨. 사용자가 접근 가능한 public 스키마에 extension이 있으면 보안 위험.

### 수정
`extensions` 스키마로 이동. Supabase는 `extensions` 스키마를 기본 제공하며 `search_path`에 포함됨.

> 주의: pgroonga 연산자(`&@~` 등)는 스키마 이동 후에도 search_path를 통해 접근 가능해야 함.

## 4. Security Advisor — Anonymous Access (조치 불필요 항목)

| 테이블 | 정책 | 판단 |
|--------|------|------|
| posts "Everyone can read posts" | `USING (true)` | 의도적 공개 — 비로그인 접근 허용 설계 |
| comments "Everyone can read comments" | `USING (true)` | 의도적 공개 |
| reactions "Everyone can read reactions" | `USING (true)` | 의도적 공개 |
| boards boards_select | `USING (true)` | 의도적 공개 |
| user_reactions user_reactions_select | 인증 필요 정책이지만 anon role 포함 | SELECT만이라 위험 낮음 |
| storage.objects | 이미지 공개 읽기 | 의도적 공개 |
| cron.job/job_run_details | Supabase 내부 cron | 우리 정책 아님 |
| app_admin | 본인 행만 읽기 (`auth.uid() = user_id`) | 실질적 anon 접근 불가 |

## 5. Security Advisor — Leaked Password Protection

Dashboard에서 활성화 필요 (Auth > Settings > Password Protection).
마이그레이션 대상 아님 → 사용자에게 안내.

## 6. 변경 파일

| 파일 | 변경 |
|------|------|
| `supabase/migrations/20260320000001_advisor_fixes.sql` | RLS initplan + search_path + extension 이동 |
| `CLAUDE.md` | 마이그레이션 목록 업데이트 |
| `docs/SCHEMA.md` | 변경된 정책/함수 반영 |

## 7. 구현 순서

```
1. 마이그레이션 SQL 작성
2. dry-run 확인
3. push 적용 (gen-types + sync + verify 자동)
4. CLAUDE.md + SCHEMA.md 업데이트
5. 설계 문서 complete로 이동
```
