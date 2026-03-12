# 감정분석 파이프라인 업그레이드 설계

> 작성: 2026-03-12 | 감정분석 구현 가이드 메모 분석 기반
> 출처: [감정분석 구현 완벽 가이드](memo/은둔마을%20감정분석%20구현%20완벽%20가이드%20Gemini%20+%20Supabase%20+%20React%20Native.md)
> 상태: **E1 구현 완료 (2026-03-13)**, E2/E3 대기

---

## 1. 현황 vs 메모 분석 요약

### 이미 구현됨 (변경 불필요)

| 항목 | 현재 상태 |
|---|---|
| 비동기 웹훅 아키텍처 | DB trigger → Edge Function (analyze-post) |
| 재시도 로직 | 2회 지수 백오프, retryable/non-retryable 분류 |
| Realtime + 폴링 폴백 | usePostDetailAnalysis (5s 폴링, 2분 타임아웃, on-demand 폴백) |
| 중복 분석 방지 | post_id UNIQUE + 60초 쿨다운 |
| stuck 정리 | cleanup_stuck_analyses RPC |
| 프롬프트 인젝션 방어 | sanitizeUserInput + 시스템 프롬프트 제한 |
| EmotionTags UI | 앱(RN) + 웹(Next.js) 모두 구현 |

### 핵심 차이점 — 업그레이드 대상

| # | 현재 | 메모 권장 | 영향도 | 우선순위 |
|---|---|---|---|---|
| G1 | 13개 단순 감정 레이블 (string[]) | **8개 임상 카테고리 + 강도 점수(0-1)** | DB 스키마 + Edge Function + UI 전면 변경 | 높음 |
| G2 | risk level 없음 | **4단계 위기 감지** (normal/elevated/high/critical) | 신규 기능, 사용자 안전 직결 | **최우선** |
| G3 | 최소 영어 프롬프트 | **한국어 전문 프롬프트 + 은어 사전** | Edge Function 프롬프트만 변경 | 높음 |
| G4 | gemini-2.5-flash | **flash-lite(기본) + flash(위기 재분석)** 2-tier | Edge Function 로직 변경 | 중간 |
| G5 | JSON 배열 출력 | **Structured output (JSON Schema 강제)** | Edge Function 설정 변경 | 높음 |
| G6 | 추적 없음 | **api_usage 테이블** (일일 호출/토큰) | 신규 테이블 | 낮음 |
| G7 | 알림 없음 | **emotion_alerts 테이블 + 자동 트리거** | 신규 테이블 + 관리자 UI | 중간 |

---

## 2. 구현 전략 — 3단계 점진적 업그레이드

### 원칙
- **기존 파이프라인 안정성 유지** — 현재 작동하는 분석 흐름을 깨뜨리지 않음
- **하위 호환** — 기존 post_analysis 데이터는 마이그레이션으로 변환
- **단계적 전환** — 프롬프트 → 스키마 → UI 순서로 점진적 적용

---

### Phase E1: 프롬프트 + 구조화 출력 업그레이드 (G3, G5)

> 가장 낮은 위험, 가장 높은 즉시 효과. DB 변경 없이 분석 품질 향상.

**변경 대상**: Edge Function `_shared/analyze.ts`

#### 1a. 시스템 프롬프트 한국어 전환

현재:
```
"You are an emotion classifier. You ONLY output a JSON array..."
```

변경:
```
"당신은 한국의 은둔형 외톨이(사회적 고립 청년) 전문 감정 분석가입니다.
한국 온라인 커뮤니티 문화, 인터넷 은어, 초성 줄임말에 깊은 이해가 있습니다.
..."
```

핵심 추가 규칙:
- ㅋ(단독) = 빈정거림, ㅋㅋㅋ+ = 진짜 웃음
- ㅠㅠ 반복 횟수 = 슬픔 강도
- "살자" = 자살 우회 표현 (CRITICAL 위기 신호)
- "멘붕", "읽씹", "킹받다" 등 은어 해석
- 작은 성취("편의점 갔다 왔어요") 반드시 hope/relief로 포착

#### 1b. Structured Output 적용

현재: `responseMimeType` 미사용, 자유 형식 JSON 배열 파싱
변경: `responseMimeType: 'application/json'` + `responseJsonSchema` 적용

```typescript
generationConfig: {
  temperature: 0.1,
  maxOutputTokens: 512,
  responseMimeType: 'application/json',
  responseJsonSchema: {
    type: 'object',
    properties: {
      emotions: {
        type: 'array',
        items: { type: 'string', enum: ALLOWED_EMOTIONS },
        maxItems: 3
      },
      emotion_scores: {
        type: 'object',
        // 각 감정별 0.0-1.0 점수
      },
      risk_level: {
        type: 'string',
        enum: ['normal', 'elevated', 'high', 'critical']
      },
      risk_indicators: {
        type: 'array',
        items: { type: 'string' }
      },
      context_notes: { type: 'string' }
    },
    required: ['emotions', 'risk_level']
  }
}
```

**호환 전략**: 기존 `emotions` 배열 형식 유지하면서 `risk_level` 등 새 필드 추가.
post_analysis 테이블에 아직 없는 컬럼은 Phase E2에서 추가.
Phase E1에서는 emotions 배열만 DB에 저장하고, 나머지는 로그로 기록.

#### 1c. 감정 카테고리 결정

**메모의 8개 임상 카테고리 vs 현재 13개 레이블**

| 메모 카테고리 | 현재 매칭 | 판단 |
|---|---|---|
| loneliness (외로움) | 외로움, 고립감 | 통합 가능 |
| anxiety (불안) | 불안, 두려움 | 통합 가능 |
| depression (우울) | 슬픔 | 유사 |
| hopelessness (무기력) | 무기력 | 일치 |
| shame (수치심) | — | 신규 |
| anger (분노) | 답답함 | 유사 |
| hope (희망) | 기대감, 설렘 | 통합 가능 |
| relief (안도) | 안도감, 평온함, 즐거움 | 통합 가능 |

**결정: 현재 13개 레이블 유지, 메모의 카테고리를 상위 그룹으로 활용.**

이유:
- 13개 → 8개 전환은 기존 데이터 + UI + 검색 + RPC 전면 변경 필요
- 대신 `emotion_scores`에 8개 상위 카테고리 점수를 병행 저장
- UI에서는 기존 13개 레이블 표시 유지, 관리자 대시보드에서 8개 카테고리 집계 활용

**변경 파일**: Edge Function `_shared/analyze.ts` (1파일)
**위험도**: 낮음 (프롬프트만 변경, DB 스키마 불변)
**테스트**: 기존 게시글 5건 수동 재분석으로 품질 비교

---

### Phase E2: DB 스키마 + 위기 감지 (G1, G2, G6, G7)

> DB 변경 포함. 마이그레이션 필요.

#### 2a. post_analysis 테이블 확장

```sql
ALTER TABLE public.post_analysis
  ADD COLUMN IF NOT EXISTS emotion_scores JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS risk_level TEXT DEFAULT 'normal'
    CHECK (risk_level IN ('normal', 'elevated', 'high', 'critical')),
  ADD COLUMN IF NOT EXISTS risk_indicators TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS context_notes TEXT,
  ADD COLUMN IF NOT EXISTS model_version TEXT DEFAULT 'gemini-2.5-flash';

CREATE INDEX IF NOT EXISTS idx_post_analysis_risk
  ON public.post_analysis(risk_level)
  WHERE risk_level IN ('high', 'critical');
```

#### 2b. emotion_alerts 테이블 (신규)

```sql
CREATE TABLE IF NOT EXISTS public.emotion_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id BIGINT REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  risk_level TEXT NOT NULL,
  risk_indicators TEXT[] NOT NULL,
  acknowledged BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- RLS: 관리자만 조회 가능
ALTER TABLE public.emotion_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "emotion_alerts_admin_select" ON public.emotion_alerts
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.app_admin WHERE user_id = auth.uid())
  );
```

#### 2c. 자동 알림 트리거

```sql
CREATE OR REPLACE FUNCTION public.create_emotion_alert()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.risk_level IN ('high', 'critical') THEN
    INSERT INTO public.emotion_alerts (post_id, user_id, risk_level, risk_indicators)
    SELECT NEW.post_id, p.user_id, NEW.risk_level, NEW.risk_indicators
    FROM public.posts p WHERE p.id = NEW.post_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_post_analysis_risk_alert
  AFTER INSERT OR UPDATE OF risk_level ON public.post_analysis
  FOR EACH ROW
  WHEN (NEW.risk_level IN ('high', 'critical'))
  EXECUTE FUNCTION public.create_emotion_alert();
```

#### 2d. api_usage 테이블 (선택, 낮은 우선순위)

```sql
CREATE TABLE IF NOT EXISTS public.api_usage (
  id SERIAL PRIMARY KEY,
  date DATE DEFAULT CURRENT_DATE NOT NULL UNIQUE,
  gemini_calls INT DEFAULT 0,
  tokens_used INT DEFAULT 0
);

CREATE OR REPLACE FUNCTION public.increment_api_usage(
  p_tokens INT DEFAULT 0
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.api_usage (date, gemini_calls, tokens_used)
  VALUES (CURRENT_DATE, 1, p_tokens)
  ON CONFLICT (date) DO UPDATE
  SET gemini_calls = api_usage.gemini_calls + 1,
      tokens_used = api_usage.tokens_used + p_tokens;
END;
$$;
```

**변경 파일**: 마이그레이션 1-2개, Edge Function, shared/constants.ts, shared/types.ts
**위험도**: 중간 (DDL 추가, 기존 컬럼 불변)
**의존성**: Phase E1 완료 후

---

### Phase E3: UI + 2-Tier 모델 + 위기 자원 (G4, 나머지)

> 사용자 체감 변화. UI 변경 포함.

#### 3a. 2-Tier 모델 전략

```
1차: gemini-2.5-flash-lite (기본, 저비용)
  ↓ risk_level === 'high' || 'critical'
2차: gemini-2.5-flash (재분석, 고정확도)
```

Edge Function에서 1차 분석 후 risk가 high/critical이면 자동으로 flash로 재분석.
결과 차이가 있으면 flash 결과 채택.

#### 3b. 위기 자원 표시 (앱/웹 UI)

risk_level이 'high' 이상일 때 사용자에게 부드러운 톤으로 자원 안내:

```
"혹시 힘든 마음이 드시나요? 도움이 필요하시면 아래를 눌러주세요."
- 자살예방상담전화 1393 (24시간)
- 정신건강위기상담전화 1577-0199 (24시간)
```

**윤리 원칙** (메모에서 강조):
- "위험이 감지되었습니다" 같은 알람성 표현 금지
- 사용자가 한 번 탭으로 dismiss 가능
- 세션 수준 빈도 조절 (매 글마다 X)
- **자동 신고/계정 잠금 절대 금지**

#### 3c. 관리자 대시보드 — emotion_alerts 조회

앱/웹 관리자 화면에서:
- 미확인 알림 목록 (risk_level + risk_indicators)
- acknowledged 처리 기능
- 감정 트렌드 차트에 risk 분포 추가

#### 3d. 사용자 자기 감정 태깅 (하이브리드, 선택)

글 작성 시 이모지 감정 선택기 → initial_emotions(이미 존재)와 AI 분석 비교.
이미 `posts.initial_emotions` 컬럼이 있으므로 UI만 추가하면 됨.

**변경 파일**: Edge Function, 앱 UI 2-3파일, 웹 UI 2-3파일
**위험도**: 중간~높음 (사용자 체감 변화)
**의존성**: Phase E2 완료 후

---

## 3. 구현 우선순위 + 트리거 조건

| Phase | 우선순위 | 트리거 | 예상 소요 |
|---|---|---|---|
| **E1** | 높음 | R1-R5 완료 후 즉시 | 2-3시간 |
| **E2** | 높음 | E1 완료 + 품질 검증 후 | 3-4시간 |
| **E3** | 중간 | E2 완료 + 관리자 UI 설계 후 | 4-6시간 |

**E1은 독립 실행 가능** — DB 변경 없이 프롬프트만 개선하므로 v3 Release 5 이후 바로 착수 가능.

---

## 4. 위험 관리

### 하위 호환
- E1: 출력 형식 변경 없음 (emotions 배열 유지). 기존 UI 영향 0.
- E2: 신규 컬럼만 추가 (ALTER ADD). 기존 데이터 불변. NULL 허용.
- E3: 기존 분석 결과에 risk_level='normal' 기본값. 소급 적용 불필요.

### 롤백
- E1: 프롬프트를 이전 버전으로 되돌리면 즉시 복원
- E2: DROP COLUMN / DROP TABLE로 롤백 (데이터 손실 감수)
- E3: UI 변경 revert (git)

### 비용 영향
- E1: 비용 변경 없음 (같은 모델, 프롬프트 길이만 증가 ~200토큰)
- E2: 비용 변경 없음
- E3: flash-lite 전환 시 비용 **감소** (입력 $0.10 vs $0.30, 출력 $0.40 vs $2.50)

---

## 5. 메모에서 채택하지 않는 항목

| 항목 | 제외 근거 |
|---|---|
| 13개 → 8개 카테고리 전환 | 기존 데이터/UI/RPC 전면 변경 필요, ROI 대비 위험 과다 |
| pg_cron 배치 분석 | cleanup_stuck_analyses로 충분, 별도 배치 불필요 |
| KoELECTRA/KcBERT 자체 호스팅 | GPU 인프라 비현실적 (1인 비영리) |
| 감정분석 opt-out | 현재 규모에서 불필요, 법률 검토 비용 과다 |
| 별도 emotion_analysis 테이블 | 기존 post_analysis 확장이 더 효율적 |

---

## 6. 관련 문서

| 문서 | 관계 |
|---|---|
| [감정분석 구현 가이드 (메모)](memo/은둔마을%20감정분석%20구현%20완벽%20가이드%20Gemini%20+%20Supabase%20+%20React%20Native.md) | 원본 연구 자료 |
| [v3 실행 계획서](expected/DESIGN-maintenance-v3-execution.md) | R1-R5 완료 후 이 설계 착수 |
| [v2 장기 과제](expected/DESIGN-maintenance-v2.md) | Backlog 항목과 병행 가능 |
| [IMPLEMENTATION-GUIDE.md](IMPLEMENTATION-GUIDE.md) | Backlog에 E1-E3 추가 |
