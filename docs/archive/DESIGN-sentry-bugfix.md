# Sentry 이슈 일괄 수정 설계

> 작성일: 2026-03-27 | 상태: 구현 중

## 배경

Sentry 점검 결과 미해결 이슈 21건 (앱 19건, 웹 2건) 확인.
서비스 관점에서 사용자에게 직접 영향을 주는 3개 카테고리로 분류하여 우선순위별 수정.

## 이슈 분류

### 1. [긴급] FK Violation — 시 게시판 board_id=13 미존재
- **Sentry**: GNS-HERMIT-COMM-13 (오늘 발생)
- **영향**: 시 게시판에서 글 작성 불가 (앱 사용자 1명 확인)
- **원인**: `POETRY_BOARD_ID=13` 상수가 앱/웹에 배포됐으나, DB 마이그레이션(`20260402000001_poetry_board.sql`) 미적용
- **수정**: `bash scripts/db.sh push`로 pending 마이그레이션 2개 적용
  - `20260402000001_poetry_board.sql` — boards id=13 생성
  - `20260402000002_remove_image_feature.sql` — image_url 컬럼/Storage 정리

### 2. [긴급] DOMPurify SSR 호환 오류 — 웹 게시글 상세 깨짐
- **Sentry**: WEB-HERMIT-COMM-5 (11건), WEB-HERMIT-COMM-3 (23건)
- **영향**: 웹 `/post/[id]` 페이지 전체 렌더링 실패 (unhandled)
- **원인**: DOMPurify 3.x는 Node.js(SSR)에서 `window` 없이 `DOMPurify.sanitize()` 호출 불가. 'use client' 컴포넌트도 Next.js SSR에서 실행됨
- **수정**:
  - PostContent.tsx에서 DOMPurify를 `useEffect` + 동적 `import()`로 클라이언트 전용 실행
  - `jsdom` 의존성 제거 (더 이상 SSR에서 DOMPurify 안 쓰므로 불필요)
  - `next.config.ts`의 `serverExternalPackages: ['jsdom']` 제거

### 3. [개선] unknown_supabase_error 에러 리포팅 품질
- **Sentry**: 8개 이슈 (~25 이벤트, 3/18 집중 발생)
- **영향**: 에러 원인 판별 불가 → 운영 진단 방해
- **원인**: `extractErrorMessage()`가 Supabase 에러 객체의 비표준 필드(`status`, `statusText` 등) 미처리
- **수정**:
  - `extractErrorMessage()` 확장: `status`/`statusText` 필드 추가 + `JSON.stringify` 전체 포함
  - `reportToSentry()` 핑거프린트: `unknown` 폴백 시 에러 타입 기반 분류 추가

### 대응 안 함 (관찰)
- **ANR 3건**: Android 플랫폼 이슈. React Native 앱에서 흔한 백그라운드 ANR. 프로파일링 없이 코드 수정 불가
- **Network request failed**: 일시적 네트워크 단절. 재시도 로직 이미 존재

## 수정 상세

### Fix 1: DB Migration Push

```bash
bash scripts/db.sh push
# → 자동으로 gen-types → sync → verify 실행
```

### Fix 2: PostContent.tsx 재작성

**Before** (SSR에서 DOMPurify 로딩 실패):
```tsx
import DOMPurify from 'dompurify'
const clean = useMemo(() => DOMPurify.sanitize(html, opts), [html])
```

**After** (클라이언트 전용 동적 import):
```tsx
const [clean, setClean] = useState<string | null>(null)
useEffect(() => {
  import('dompurify').then(({ default: dp }) => {
    setClean(dp.sanitize(html, opts))
  })
}, [html])
```

- SSR 시 plain text fallback 표시 (태그 제거)
- 클라이언트 hydration 후 sanitized HTML 렌더링
- jsdom 불필요 → 제거

### Fix 3: extractErrorMessage() 확장

**Before**:
```ts
if (error.message) return error.message;
if (error.code) return `code: ${error.code}`;
// ... 4개 필드만 검사
```

**After**:
```ts
if (error.message) return error.message;
if (error.code) return `code: ${error.code}`;
if (error.details) return `details: ${error.details}`;
if (error.hint) return `hint: ${error.hint}`;
// 추가: HTTP 에러 필드
if (error.status || error.statusText) return `http_error: ${error.status} ${error.statusText}`;
// 전체 키 덤프 (진단용)
const keys = Object.keys(error);
if (keys.length === 0) return 'supabase_empty_error';
return `supabase_error: ${JSON.stringify(error).slice(0, 200)}`;
```

## 사이드이펙트 체크

| 항목 | 확인 |
|------|------|
| 삭제 연쇄 | image_url 컬럼 DROP → 뷰 재생성 포함 ✅ |
| 동기화 | push 후 자동 sync (gen-types → 앱/웹) ✅ |
| 타임존 | 해당 없음 |
| 에러 경로 | PostContent SSR fallback이 plain text → XSS 방지됨 (태그 제거) ✅ |
| 캐시 | TanStack Query 캐시 영향 없음 ✅ |
| 호환성 | jsdom 제거 → PostContent만 사용했으므로 안전 ✅ |

## 작업 순서

1. DB migration push (FK violation 즉시 해소)
2. PostContent.tsx 수정 + jsdom 제거 (웹 배포)
3. extractErrorMessage + reportToSentry 개선 (앱 빌드)
4. Sentry 해결된 이슈 resolve + 문서 갱신
