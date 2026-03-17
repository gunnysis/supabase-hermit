# 마이페이지 개선 설계

## 현황 분석

### 현재 구성 (웹/앱 동일)
1. **활동 요약** — 글/댓글/반응/연속기록 4개 카드
2. **나의 패턴** — 활동-감정 상관관계 (7일+ daily 필요)
3. **감정 캘린더** — 30일 히트맵
4. **감정 타임라인** — 커뮤니티 7일 감정 분포

### 발견된 문제

#### P0 — 네비게이션 부재 (웹)
- BottomNav에 마이페이지 링크 없음 (홈/검색/글쓰기만)
- Header에도 마이페이지/프로필 링크 없음
- 사용자가 `/my` 경로를 직접 입력해야만 접근 가능

#### P1 — 프로필/설정 기능 부재 (웹)
- 내 별칭 확인 불가
- 로그아웃 버튼 없음 (어디서도 로그아웃 불가)
- 차단 관리 UI 없음 (API만 존재)
- 설정 페이지 없음

#### P2 — 코드 품질
- 웹: `getMyActivitySummary()` 페이지 컴포넌트에 인라인 정의
- 캐시 키 불일치: 웹 `myActivity` vs 앱 `activitySummary`
- `dailyInsights` 캐시가 daily post 생성 후 무효화 안 됨
- EmotionCalendar/EmotionWave 로딩 중 null 반환 (깜빡임)

## 개선 범위

### 웹 (주요)

#### 1. 네비게이션에 마이페이지 추가
- BottomNav: `User` 아이콘 4번째 탭 추가
- Header: 프로필 아이콘 추가 (모바일+데스크톱)

#### 2. 마이페이지 리디자인
```
[프로필 섹션]
  - 내 별칭 표시
  - 로그아웃 버튼

[활동 요약] — 기존 유지, 스켈레톤 개선

[나의 패턴] — 기존 유지

[감정 캘린더] — 로딩 스켈레톤 추가

[감정 타임라인] — 로딩 스켈레톤 추가

[설정 섹션]
  - 차단 관리 (차단 목록 + 해제)
```

#### 3. 코드 정리
- API 함수 추출 → `features/my/api/myApi.ts`
- 캐시 키 통일 → `activitySummary`
- `dailyInsights` 캐시 무효화 추가
- 로딩 스켈레톤 추가

### 앱
- 캐시 무효화 수정 (activitySummary → daily post 생성 시)
- 이미 네비게이션/프로필은 존재하므로 변경 최소

## 구현 파일 목록

### 웹 — 신규
| 파일 | 설명 |
|---|---|
| `src/features/my/api/myApi.ts` | 마이페이지 API 모듈 |
| `src/features/my/components/ProfileSection.tsx` | 프로필 + 로그아웃 섹션 |
| `src/features/my/components/BlockedUsersSection.tsx` | 차단 관리 섹션 |

### 웹 — 수정
| 파일 | 변경 |
|---|---|
| `src/components/layout/BottomNav.tsx` | 마이페이지 탭 추가 |
| `src/components/layout/Header.tsx` | 프로필 아이콘 추가 |
| `src/app/my/page.tsx` | 리디자인 (프로필/차단/스켈레톤) |
| `src/features/my/hooks/useCreateDaily.ts` | dailyInsights 캐시 무효화 |
| `src/features/posts/components/EmotionCalendar.tsx` | 로딩 스켈레톤 |
| `src/features/posts/components/EmotionWave.tsx` | 로딩 스켈레톤 |
| `src/features/my/components/DailyInsights.tsx` | 로딩 스켈레톤 |

### 앱 — 수정
| 파일 | 변경 |
|---|---|
| `src/features/my/hooks/useCreateDaily.ts` | activitySummary 캐시 무효화 |

## 비변경 사항
- DB 스키마 변경 없음
- RPC 추가 없음
- shared/ 변경 없음
