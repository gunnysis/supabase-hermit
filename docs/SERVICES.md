# 연동 서비스 및 비용 관리

> **최종 갱신**: 2026-03-22

## 서비스 현황

| 서비스 | 플랜 | 월 비용 | 용도 | 계정 |
|--------|------|--------|------|------|
| **Supabase** | Free | $0 | DB, Auth, Realtime, Edge Functions, Storage | qkr133456@gmail.com |
| **Vercel** | Hobby Plus | $0 | 웹 호스팅 (Next.js) | qkr133456@gmail.com |
| **Expo/EAS** | Starter | $0 | 앱 빌드/배포 | parkgunny |
| **Sentry** | Developer | $0 | 에러 모니터링 (앱+웹) | qkr133456@gmail.com (org: gunnys) |
| **Gemini API** | 무료 티어 | $0 | 감정분석 AI (gemini-2.5-flash) | Google API Key |

**월 총 비용: $0**

---

## Supabase

### 접속 정보
- **Organization**: gunny_apps (`hauogokwvtxkyojwnamk`)
- **Project**: gns-hermit-comm (`qwrjebpsjjdxhhhllqcw`)
- **Region**: ap-northeast-2 (서울)
- **Dashboard**: https://supabase.com/dashboard/project/qwrjebpsjjdxhhhllqcw

### Free 플랜 한도

| 항목 | 한도 | 현재 사용 (2026-03-22) |
|------|------|----------------------|
| DB 크기 | 500MB | 극소 (posts 22, comments 3) |
| 대역폭 | 2GB/월 | 극소 |
| Edge Function 호출 | 50만/월 | 극소 |
| Realtime 메시지 | 200만/월 | 극소 |
| Auth MAU | 5만 | 극소 |
| Storage | 1GB | 미사용 |
| **비활성 일시정지** | **7일** | **주의 필요** |

### 주의사항
- **7일 비활성 시 프로젝트 자동 일시정지** → 재활성화 대기 시간 발생
- 일시정지 시 앱/웹에서 "서버에 연결할 수 없습니다" 에러 → 다시 시도 버튼 제공 (2026-03-22 구현)
- Pro 재업그레이드: 사용자 증가로 Free 한도 초과 시

### Edge Functions
| 함수 | JWT | 호출 방식 | 비용 영향 |
|------|-----|---------|---------|
| `analyze-post` | X | DB Trigger (post INSERT/UPDATE) | 글 작성마다 Gemini API 호출 |
| `analyze-post-on-demand` | O | 수동 요청 | 사용자 선택 시만 |

### CLI 접근
```bash
source .env && npx supabase login --token "$SUPABASE_ACCESS_TOKEN"
npx supabase projects list
```

---

## Vercel

### 접속 정보
- **Team**: jeonggeon park's projects (`team_Xto7f0LaYvQxu5nMKKSuROsN`)
- **Project**: web
- **Framework**: Next.js 16
- **Node.js**: 24.x
- **Domain**: www.eundunmaeul.store
- **Dashboard**: https://vercel.com

### Hobby Plus 한도

| 항목 | 한도 |
|------|------|
| 빌드 | 동시 1개 (turbo) |
| 대역폭 | 100GB/월 |
| Serverless 실행 | 100GB-hrs/월 |
| Edge 실행 | 500,000/월 |
| 이미지 최적화 | 1,000/월 |

### 배포 방식
- git push 후 `vercel --prod` 수동 배포 (자동 배포 Canceled 빈번)
- 빌드 머신: turbo

### CLI 접근
```bash
# .env의 VERCEL_ACCESS_TOKEN 사용
curl -H "Authorization: Bearer $VERCEL_ACCESS_TOKEN" "https://api.vercel.com/v2/user"
```

---

## Expo / EAS

### 접속 정보
- **Account**: parkgunny (`0fa9d2d8-d48d-4681-955c-3af999679ca8`)
- **Project ID**: bc4199dd-30ad-42bb-ba1c-4e6fce0eecdd
- **Dashboard**: https://expo.dev

### Starter 플랜 한도

| 항목 | 한도 |
|------|------|
| EAS Build | 월 30회 (iOS+Android) |
| EAS Update | 월 1,000 사용자 |
| 팀 멤버 | 1명 |

### 빌드 프로필
| 프로필 | 채널 | 용도 |
|--------|------|------|
| development | - | 개발 클라이언트 (apk) |
| preview | preview | 내부 테스트 (apk) |
| production | production | Play Store (app-bundle, autoIncrement) |

### CLI 접근
```bash
# .env의 EXPO_ACCESS_TOKEN 사용
npx eas whoami
```

---

## Sentry

### 접속 정보
- **Organization**: gunnys (`4510919956430848`)
- **Dashboard**: https://gunnys.sentry.io
- **CLI 토큰 만료**: 2026-04-07

### 프로젝트

| 프로젝트 | slug | 플랫폼 | DSN 환경변수 |
|---------|------|--------|-------------|
| 앱 | gns-hermit-comm | react-native | EXPO_PUBLIC_SENTRY_DSN |
| 웹 | web-hermit-comm | javascript-nextjs | NEXT_PUBLIC_SENTRY_DSN |

### Developer 플랜 한도

| 항목 | 월 한도 | 사용량 (30일, 2026-03-22) | 사용률 |
|------|--------|-------------------------|--------|
| Errors | 5,000 | 633 | 12.7% |
| Transactions | 10,000 | 266 | 2.7% |
| Replays | 50 | 1 | 2% |

### 샘플링 설정

| 항목 | 앱 | 웹 |
|------|-----|-----|
| tracesSampleRate | 미설정 (기본값) | 0.1 (10%) |
| replaysSessionSampleRate | - | 0 (비활성) |
| replaysOnErrorSampleRate | - | 0.5 (50%) |

### CLI 접근
```bash
sentry auth status
sentry project list gunnys
sentry issue list gunnys/gns-hermit-comm --query "is:unresolved"
sentry issue list gunnys/web-hermit-comm --query "is:unresolved"
```

---

## Gemini API

### 접속 정보
- **모델**: gemini-2.5-flash
- **API Key 환경변수**: GEMINI_API_KEY
- **호출 위치**: Edge Function `analyze-post` (`supabase/functions/_shared/analyze.ts`)

### 무료 티어 한도

| 항목 | 한도 |
|------|------|
| RPM (요청/분) | 15 |
| TPM (토큰/분) | 100만 |
| RPD (요청/일) | 1,500 |

### 비용 최적화 현황
- 쿨다운: 60초 (동일 글 재수정 시 재호출 방지)
- `post_type='daily'`는 트리거 미발동 (AI skip, 사용자 감정 직접 저장)
- 입력 제한: content 2,000자 + title 200자
- 출력 제한: maxOutputTokens 512
- 재시도: 최대 2회 (지수 백오프)

---

## 토큰/키 보관

모든 토큰과 API 키는 중앙 레포 `.env`에 보관:

| 환경변수 | 서비스 | 용도 |
|---------|--------|------|
| SUPABASE_ACCESS_TOKEN | Supabase | Management API |
| SUPABASE_SERVICE_ROLE_KEY | Supabase | 서비스 역할 (admin) |
| EXPO_PUBLIC_SUPABASE_ANON_KEY | Supabase | 클라이언트 접근 |
| VERCEL_ACCESS_TOKEN | Vercel | 배포/API |
| EXPO_ACCESS_TOKEN | Expo | EAS CLI |
| SENTRY_PERSONAL_TOKEN | Sentry | CLI 인증 |
| GEMINI_API_KEY | Google | 감정분석 |
| ANTHROPIC_API_KEY | Anthropic | (미사용, 예비) |

---

## 비용 증가 시 대응 계획

### Phase 1: Free 한도 초과 시
- Supabase Pro ($25/월) 재업그레이드 우선
- Sentry → 에러 샘플링 강화 (앱 tracesSampleRate 설정)

### Phase 2: 사용자 DAU 100+ 시
- Gemini API 유료 전환 검토
- Vercel Pro ($20/월) 검토 (빌드/대역폭)
- EAS Build 유료 검토 (빌드 횟수)

### Phase 3: 수익화 이후
- 사용량 기반 비용 모니터링 대시보드 구축
- 프리미엄 기능 과금 구조 설계

---

## 변경 이력

| 날짜 | 변경 |
|------|------|
| 2026-03-22 | 초기 작성. Supabase Pro→Free 다운그레이드, 전 서비스 무료 전환 |
