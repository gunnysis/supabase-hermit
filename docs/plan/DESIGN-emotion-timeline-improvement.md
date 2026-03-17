# 감정 타임라인 종합 개선 설계

## 현황 분석

### 현재 구현
- **웹**: `EmotionWave.tsx` — stacked bar chart, h-24, 인라인 API
- **앱**: `EmotionWaveNative.tsx` — 동일 로직, RN 컴포넌트
- **RPC**: `get_emotion_timeline(p_days)` → `(day, emotion, cnt)[]`
- **데이터**: 커뮤니티 전체 게시글의 감정 분석 결과 집계

### 발견된 문제

#### UX/UI
1. 바에 인터랙션 없음 (호버/탭 시 정보 없음)
2. 날짜 라벨이 "N일"만 — 요일 정보 없음
3. h-24(96px)로 차트가 너무 작아 세그먼트 식별 어려움
4. 빈 데이터 시 컴포넌트 사라짐 (null 반환)
5. 인사이트 텍스트 없음 — 데이터만 나열
6. 세그먼트 간 구분선 없어 인접 색상 구분 어려움

#### 코드 품질
7. 웹: API 함수가 컴포넌트 내 인라인 정의
8. 웹/앱: 바 데이터 변환 로직 중복 (useMemo 내부)
9. 웹: useQuery hook 없이 직접 호출

#### 성능
10. 매 렌더링마다 전체 바 데이터 재계산 (useMemo 의존성은 있으나 내부 로직 무거움)
11. 바 높이 계산에 Math.random() 사용 (스켈레톤) — SSR 불일치 가능

## 개선 범위

### 1. UX/UI 개선
- **호버 툴팁 (웹)**: 바에 마우스 올리면 날짜 + 감정 비율 표시
- **요일 라벨**: "월", "화" 등 한글 요일 + 오늘 강조
- **차트 높이**: h-24 → h-32 (128px)
- **빈 상태**: 고스트 바 + 메시지
- **인사이트 문장**: "이번 주 가장 많이 나눈 감정은 X이에요"
- **세그먼트 간격**: 1px 흰색 간격으로 구분
- **입장 애니메이션**: 스태거 growUp (reduced-motion 대응)

### 2. 리팩토링
- 웹: API를 `myApi.ts`로 추출, `useEmotionTimeline` 훅 생성
- 바 데이터 변환 로직을 shared utils로 추출 (pure function)

### 3. 성능 개선
- 스켈레톤 높이 고정 (랜덤 제거)
- 변환 로직 최적화 (단일 패스)

## 구현 파일

### 중앙 — 수정
| 파일 | 변경 |
|---|---|
| `shared/utils.ts` | `processEmotionTimeline()` 순수 함수 추가 |

### 웹 — 수정
| 파일 | 변경 |
|---|---|
| `features/my/api/myApi.ts` | `getEmotionTimeline()` 추가 |
| `features/my/hooks/useEmotionTimeline.ts` | 신규 훅 |
| `features/posts/components/EmotionWave.tsx` | 완전 리디자인 |

### 앱 — 수정
| 파일 | 변경 |
|---|---|
| `features/my/components/EmotionWaveNative.tsx` | 리디자인 |

## 비변경 사항
- DB 스키마/RPC 변경 없음
