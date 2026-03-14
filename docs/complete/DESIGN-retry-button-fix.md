# 감정분석 재시도 버튼 수정 설계

## 날짜: 2026-03-15

## 문제

감정분석 '다시 시도하기' 버튼이 작동하지 않는 것처럼 보이는 복합 원인:

### 1. content_too_short에서 영구 재시도 루프
- `status=done, emotions=[], error_reason=content_too_short` 상태
- 앱: 레거시 경로(L132)에서 재시도 버튼 표시
- 웹: `!hasEmotions` 조건으로 재시도 버튼 표시
- 재시도 → Edge Function → 같은 결과 → 버튼 그대로 → 무한 반복

### 2. 앱 소프트 실패 무시
- `invokeSmartService`는 에러를 throw가 아닌 반환값으로 전달
- `handleRetryAnalysis`가 반환값 미확인 → 실패해도 아무 피드백 없음

### 3. 앱 로딩 상태 없음
- 재시도 버튼에 로딩/disabled 상태 없음
- 사용자가 동작 여부를 알 수 없음

### 4. MAX_RETRY_COUNT 하드코딩
- `EmotionTags.tsx`: `const MAX_RETRY_COUNT = 3`
- `post/[id].tsx`: `>= 3`
- `ANALYSIS_CONFIG.MAX_RETRY_COUNT`: 중앙 상수

## 수정

### 앱
1. `EmotionTags.tsx`: `isRetrying` prop 추가, `done + empty emotions` 재시도 차단
2. `PostDetailBody.tsx`: `isRetrying` prop 전달
3. `post/[id].tsx`: 로딩 상태, 반환값 체크, 중앙 상수 사용, Toast 피드백
4. `EmotionTags.tsx`: `MAX_RETRY_COUNT` → `ANALYSIS_CONFIG.MAX_RETRY_COUNT`

### 웹
1. `PostDetailView.tsx`: `analysis?.error_reason === 'content_too_short'` 시 재시도 버튼 숨김
2. `PostDetailView.tsx`: `analysis?.status` 활용하여 적절한 메시지 표시
