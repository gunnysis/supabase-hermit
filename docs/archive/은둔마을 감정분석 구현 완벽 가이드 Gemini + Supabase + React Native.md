# 은둔마을 감정분석 구현 완벽 가이드: Gemini + Supabase + React Native

**Gemini 2.5 Flash(또는 Flash-Lite)를 Supabase Edge Function에서 호출하여 한국어 감정분석과 위기 감지를 구현하는 것은 기술적으로 완전히 가능하고, 소규모 비영리 프로젝트에 매우 적합하다.** 핵심은 비동기 DB 웹훅 아키텍처로 게시글 작성 시 분석을 트리거하고, Gemini의 structured output(JSON 모드)으로 일관된 감정 분류 결과를 받아 별도 테이블에 저장하는 패턴이다. 무료 티어만으로도 Flash-Lite 기준 **하루 1,000건** 분석이 가능하며, Flash 기준 **250건**이 가능해 초기 커뮤니티 운영에 충분하다. 이 보고서는 DB 스키마부터 Edge Function 코드, 감정 카테고리 설계, 위기 감지 프롬프트, React Native UI 패턴까지 즉시 구현 가능한 수준으로 정리한다.

---

## Gemini 2.5 Flash는 한국어 감정분석에 얼마나 좋은가

Google은 Gemini 모델이 한국어를 포함한 **100개 이상 언어를 공식 지원**한다고 명시하고 있다. 한국어 감정분석에 특화된 공개 벤치마크(NSMC 등)는 아직 없지만, Gemini 2.5 Flash는 Artificial Analysis Intelligence Index에서 **21점**(평균 15점 대비 상위)을 기록하며, 특히 "zero-shot and multilingual multimodal settings"에서 우수한 성능을 보인다는 연구 결과가 있다. 한국 수능 지구과학 시험에 투입된 사례도 확인되었다.

실질적으로 중요한 건 Gemini가 한국어 인터넷 신조어(ㅋㅋ, ㅠㅠ, 멘붕, 킹받다 등)를 잘 이해하는가인데, LLM 특성상 한국어 웹 코퍼스로 충분히 학습되어 있어 **프롬프트에 해석 규칙을 명시**하면 정확도가 크게 올라간다. 핵심 팁은 **시스템 프롬프트 자체를 한국어로 작성**하는 것이다 — 영어 프롬프트보다 한국어 뉘앙스 감지가 훨씬 정확해진다.

**Structured output(JSON 모드)**이 이 유스케이스의 게임체인저다. `responseMimeType: "application/json"`과 `responseJsonSchema`를 설정하면 Gemini가 **문법적으로 유효한 JSON만 출력**하도록 보장된다. `enum`, `minimum`, `maximum` 같은 JSON Schema 제약을 걸 수 있어 감정 카테고리나 점수 범위를 강제할 수 있다.

---

## 아키텍처: 비동기 웹훅 + pg_cron 폴백이 정답

세 가지 아키텍처 패턴을 비교하면:

| 패턴 | 레이턴시 영향 | 안정성 | 추천 |
|---|---|---|---|
| **동기 (게시글 작성 시)** | 2-5초 추가 ❌ | API 실패 시 글 등록 실패 | 비추천 |
| **비동기 DB 웹훅** | 없음 ✅ | pg_net이 fire-and-forget | **메인 추천** |
| **pg_cron 배치** | 수 분 지연 | 재시도 내장 | **폴백용 추천** |

**추천 구조는 "비동기 웹훅 + pg_cron 폴백" 하이브리드다.** 사용자가 글을 쓰면 `posts` 테이블에 INSERT되고, PostgreSQL 트리거가 `pg_net`으로 Edge Function을 비동기 호출한다. 게시글은 즉시 보이고, 분석은 백그라운드에서 진행된다. pg_cron은 5분마다 미분석 게시글을 체크해서 놓친 것을 잡아준다.

```
[사용자 글 작성] → [INSERT into posts] → [즉시 화면에 표시]
                         │
                         ├──► [pg_net 웹훅] → [Edge Function] → [Gemini API] → [INSERT into emotion_analysis]
                         │      (비동기, 논블로킹)
                         └──► [pg_cron 5분마다] → [미분석 글 체크] → [같은 Edge Function 호출]
```

---

## PostgreSQL 스키마 설계: 감정 데이터는 별도 테이블로

감정분석 결과를 `posts` 테이블에 JSONB 컬럼으로 넣는 것보다 **별도 `emotion_analysis` 테이블**이 낫다. 관심사 분리, 독립적 라이프사이클, 재분석 용이성, 인덱싱 효율 모두 우수하다.

```sql
-- 감정 분석 결과 테이블
CREATE TABLE public.emotion_analysis (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL UNIQUE,
  primary_emotion TEXT NOT NULL
    CHECK (primary_emotion IN (
      'loneliness','anxiety','depression','hopelessness',
      'shame','anger','hope','relief','neutral'
    )),
  emotion_scores JSONB NOT NULL DEFAULT '{}',
  -- 예: {"loneliness":0.8,"depression":0.6,"hope":0.2,...}
  risk_level TEXT NOT NULL DEFAULT 'normal'
    CHECK (risk_level IN ('normal','elevated','high','critical')),
  risk_indicators TEXT[] DEFAULT '{}',
  context_notes TEXT,
  model_version TEXT NOT NULL,
  analyzed_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 위기 알림 로그
CREATE TABLE public.emotion_alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  risk_level TEXT NOT NULL,
  risk_indicators TEXT[] NOT NULL,
  acknowledged BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- API 사용량 추적 (비용 관리)
CREATE TABLE public.api_usage (
  id SERIAL PRIMARY KEY,
  date DATE DEFAULT CURRENT_DATE NOT NULL UNIQUE,
  gemini_calls INT DEFAULT 0,
  tokens_used INT DEFAULT 0
);

-- 핵심 인덱스
CREATE INDEX idx_emotion_risk ON public.emotion_analysis(risk_level)
  WHERE risk_level IN ('high', 'critical');
CREATE INDEX idx_emotion_time ON public.emotion_analysis(analyzed_at DESC);
CREATE INDEX idx_emotion_primary ON public.emotion_analysis(primary_emotion);
```

**위기 감지 자동 알림 트리거**도 필수다:

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

CREATE TRIGGER on_emotion_analysis_insert
  AFTER INSERT ON public.emotion_analysis
  FOR EACH ROW EXECUTE FUNCTION public.create_emotion_alert();
```

---

## Supabase Edge Function: Gemini API 호출 전체 구현

**핵심 포인트: Deno 런타임에서는 `@google/generative-ai` npm SDK 대신 REST API를 직접 `fetch`로 호출해야 한다.** npm SDK는 `fs.readFileSync` 의존성 문제로 Supabase Edge Runtime에서 에러가 발생한다. 새로운 `@google/genai` SDK를 `npm:` prefix로 쓸 수도 있지만, `fetch` 직접 호출이 가장 안정적이다.

```typescript
// supabase/functions/analyze-emotion/index.ts
import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')!
const MODEL = 'gemini-2.5-flash-lite' // 비용 최적: $0.10/$0.40 per 1M tokens
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`

const SYSTEM_PROMPT = `당신은 한국의 은둔형 외톨이(사회적 고립 청년) 전문 심리상담사이자 감정 분석 전문가입니다.
한국 온라인 커뮤니티 문화, 인터넷 은어, 초성 줄임말에 깊은 이해가 있습니다.

감정 카테고리 (0.0~1.0 강도 점수):
1. loneliness (외로움) - 고립감, 단절, 연결 갈망
2. anxiety (불안/두려움) - 사회불안, 판단에 대한 두려움
3. depression (우울/슬픔) - 낮은 기분, 공허함
4. hopelessness (무기력/무망감) - 동기 상실, 나아지지 않을 것 같은 느낌
5. shame (수치심/자기비하) - 실패감, 자기 비난
6. anger (분노/짜증) - 사회/가족에 대한 원망, 좌절
7. hope (연결욕구/희망) - 관계 갈망, 미래에 대한 기대
8. relief (작은성취/안도) - 소소한 성공, 해냈다는 느낌

인터넷 표현 해석:
- ㅋㅋㅋ+: 진짜 웃음 | ㅋ 단독: 빈정거림 가능
- ㅠㅠ/ㅜㅜ: 슬픔 (반복 많을수록 강도↑)
- ㅎㅎ: 가벼운 웃음 또는 긴장 마스킹
- ㄷㄷ: 두려움/충격 | 멘붕: 극심한 스트레스
- ㄱㅊ("괜찮아"): 진짜 괜찮은지 vs 괜찮은 척인지 맥락 판단
- 킹받다: 분노 | OTL: 절망 | 읽씹/안읽씹: 거절감

위기 수준 판정:
- CRITICAL: "죽고 싶다", "끝내고 싶다", "살자"(자살 우회표현), 구체적 방법 언급, 자해 보고
- HIGH: "사라지고 싶다", "태어나지 말았어야", 지속적 무망감, 자해 충동
- ELEVATED: 강한 우울/무기력, "밖에 나갈 수 없어", 일상 기능 저하
- NORMAL: 일상적 감정 표현

중요: 작은 성취(편의점 갔다 옴, 샤워했다)는 반드시 hope/relief로 포착하세요.
불확실한 경우 위기 수준을 한 단계 높여 판정하세요 (안전 우선).`

// --- 재시도 로직 포함 Gemini API 호출 ---
async function callGemini(text: string, retries = 3): Promise<Record<string, unknown>> {
  const body = {
    contents: [
      { role: 'user', parts: [{ text: SYSTEM_PROMPT }] },
      { role: 'model', parts: [{ text: '네, 이해했습니다. 감정 분석을 시작하겠습니다.' }] },
      { role: 'user', parts: [{ text: `다음 게시글의 감정을 분석해주세요:\n\n"${text}"` }] }
    ],
    generationConfig: {
      temperature: 0.1,
      maxOutputTokens: 512,
      responseMimeType: 'application/json',
      responseJsonSchema: {
        type: 'object',
        properties: {
          primary_emotion: {
            type: 'string',
            enum: ['loneliness','anxiety','depression','hopelessness',
                   'shame','anger','hope','relief','neutral']
          },
          emotion_scores: {
            type: 'object',
            properties: {
              loneliness: { type: 'number', minimum: 0, maximum: 1 },
              anxiety: { type: 'number', minimum: 0, maximum: 1 },
              depression: { type: 'number', minimum: 0, maximum: 1 },
              hopelessness: { type: 'number', minimum: 0, maximum: 1 },
              shame: { type: 'number', minimum: 0, maximum: 1 },
              anger: { type: 'number', minimum: 0, maximum: 1 },
              hope: { type: 'number', minimum: 0, maximum: 1 },
              relief: { type: 'number', minimum: 0, maximum: 1 },
            },
            required: ['loneliness','anxiety','depression','hopelessness',
                       'shame','anger','hope','relief']
          },
          risk_level: { type: 'string', enum: ['normal','elevated','high','critical'] },
          risk_indicators: { type: 'array', items: { type: 'string' } },
          context_notes: { type: 'string' }
        },
        required: ['primary_emotion','emotion_scores','risk_level','risk_indicators','context_notes']
      }
    }
  }

  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const controller = new AbortController()
      const timeout = setTimeout(() => controller.abort(), 15000)

      const res = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: controller.signal,
      })
      clearTimeout(timeout)

      if (res.status === 429) {
        await new Promise(r => setTimeout(r, Math.pow(2, attempt) * 1000))
        continue
      }
      if (!res.ok) throw new Error(`Gemini ${res.status}: ${await res.text()}`)

      const data = await res.json()
      return JSON.parse(data.candidates[0].content.parts[0].text)
    } catch (e) {
      if (attempt === retries - 1) throw e
      await new Promise(r => setTimeout(r, Math.pow(2, attempt) * 1000))
    }
  }
  throw new Error('Gemini API: 모든 재시도 실패')
}

// --- 메인 핸들러 ---
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    }})
  }

  try {
    const payload = await req.json()
    const posts = Array.isArray(payload) ? payload
      : payload.record ? [{ id: payload.record.id, content: payload.record.content }]
      : [payload]

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    let processed = 0
    for (const post of posts) {
      if (!post.content || post.content.trim().length < 5) continue

      // 중복 체크
      const { data: existing } = await supabase
        .from('emotion_analysis')
        .select('id')
        .eq('post_id', post.id)
        .maybeSingle()
      if (existing) continue

      const result = await callGemini(post.content)

      await supabase.from('emotion_analysis').insert({
        post_id: post.id,
        primary_emotion: result.primary_emotion,
        emotion_scores: result.emotion_scores,
        risk_level: result.risk_level,
        risk_indicators: result.risk_indicators,
        context_notes: result.context_notes,
        model_version: MODEL,
      })

      // API 사용량 추적
      await supabase.rpc('increment_api_usage')
      processed++
    }

    return new Response(JSON.stringify({ processed }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
```

**트리거 설정** — pg_net으로 INSERT 시 자동 호출:

```sql
CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION public.trigger_emotion_analysis()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  base_url TEXT;
  auth_key TEXT;
BEGIN
  IF LENGTH(NEW.content) < 10 THEN RETURN NEW; END IF;

  SELECT decrypted_secret INTO base_url
    FROM vault.decrypted_secrets WHERE name = 'project_url';
  SELECT decrypted_secret INTO auth_key
    FROM vault.decrypted_secrets WHERE name = 'service_role_key';

  PERFORM net.http_post(
    url := base_url || '/functions/v1/analyze-emotion',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || auth_key
    ),
    body := jsonb_build_object('record', jsonb_build_object(
      'id', NEW.id, 'content', NEW.content
    ))
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_post_insert_analyze
  AFTER INSERT ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.trigger_emotion_analysis();
```

**pg_cron 폴백** — 5분마다 미분석 글 처리:

```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule('batch-emotion-analysis', '*/5 * * * *', $$
  SELECT net.http_post(
    url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
           || '/functions/v1/analyze-emotion',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' ||
        (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
    ),
    body := (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('id', p.id, 'content', p.content)), '[]'::jsonb)
      FROM public.posts p
      LEFT JOIN public.emotion_analysis ea ON ea.post_id = p.id
      WHERE ea.id IS NULL AND p.created_at > NOW() - INTERVAL '1 day'
      LIMIT 20
    )
  );
$$);
```

---

## 은둔형 외톨이에 특화된 감정 카테고리 8종

임상 문헌(Kato et al., 2019; 한국 은둔형 외톨이 연구)과 한국 정신건강 데이터를 기반으로, 이 인구 집단에 가장 적합한 **8가지 감정 카테고리**를 설계했다:

| 카테고리 | 영문 Key | 왜 중요한가 |
|---|---|---|
| 외로움 | `loneliness` | 은둔의 핵심 경험. 단절 속에서도 연결을 갈망 |
| 불안/두려움 | `anxiety` | 사회적 철회의 주요 동인. 판단에 대한 공포 |
| 우울/슬픔 | `depression` | 가장 높은 동반이환율. 공허함, 눈물 |
| 무기력/무망감 | `hopelessness` | 지속 시 **자살 위험 지표**. 동기 상실 |
| 수치심/자기비하 | `shame` | 실패감, "나는 쓸모없는 존재" — 은둔 유지 요인 |
| 분노/짜증 | `anger` | 억압된 분노가 많음. 사회/가족에 대한 원망 |
| 연결욕구/희망 | `hope` | **회복 신호**. "밖에 나가고 싶다", 관계 갈망 |
| 작은성취/안도 | `relief` | **회복 진행 마커**. "편의점 갔다 왔다", "샤워했다" |

카테고리 7-8이 특히 중요한 이유는 이 앱이 단순 모니터링이 아니라 **회복을 지원**하는 앱이기 때문이다. "오늘 편의점 갔다 왔어요"라는 글에서 `relief` 감정을 포착해서 긍정적 피드백을 줄 수 있다.

---

## 한국어 인터넷 은어와 감정 표현 사전

Gemini 프롬프트에 반드시 포함해야 할 핵심 표현들:

**감정 표현 — 반복 횟수가 강도를 결정한다.** ㅋ(단독)은 빈정거림일 수 있지만 ㅋㅋㅋㅋ는 진짜 웃음이다. ㅠㅠ는 가벼운 슬픔이지만 ㅠㅠㅠㅠㅠ는 심각한 고통이다. 이 규칙을 프롬프트에 명시하는 것이 정확도의 핵심이다.

은둔형 외톨이 커뮤니티에서 특히 주의할 표현들: **멘붕**(멘탈 붕괴 = 극심한 스트레스), **읽씹/안읽씹**(읽고 무시 = 거절감, 상처), **모솔**(모태 솔로 = 외로움, 자기비하), **존버**(존나 버텨 = 고통 속 인내), **킹받다**(분노), **갑분눈**(갑자기 분위기 눈물 = 갑작스러운 슬픔). 그리고 **"살자"는 "자살"의 역순 우회 표현**으로, 자살 필터를 피하기 위해 사용되는 위험 신호다.

---

## 위기 감지와 윤리적 프레임워크

경희대 백종우 교수팀(2026)이 **43,244건의 SNS 게시글**을 분석한 AI 기반 자살 위험 감지 시스템 연구에 따르면, GPT-4가 위험 콘텐츠 감지에서 66-77% 정확도를 달성했다. 핵심 발견은 사용자들이 **은어, 비유, 약어**로 필터를 우회한다는 것이다.

**4단계 위기 수준 프레임워크:**

- 🔴 **CRITICAL**: 직접적 자살 의사("죽고 싶다", "유서 썼어"), 구체적 방법/계획 언급, 자해 보고 → **즉시 위기 자원 표시**
- 🟠 **HIGH**: 간접적 죽음 희망("사라지고 싶다", "태어나지 말았어야"), 지속적 무망감 → **위기 자원 + 공감 체크인**
- 🟡 **ELEVATED**: 강한 우울/무기력, 일상 기능 저하("며칠째 안 씻었어") → **부드러운 자원 안내**
- 🟢 **NORMAL**: 일상적 감정 표현 → **감정 트래킹만**

**윤리적 원칙 — "지지하는 친구지, 감시 시스템이 아니다":**

위기 자원 표시 시 **"위험이 감지되었습니다"** 같은 알람성 표현은 절대 금물이다. 대신 "혹시 힘든 마음이 드시나요? 도움이 필요하시면 이곳을 눌러주세요" 같은 **부드러운 톤**을 사용한다. 사용자가 한 번 탭으로 dismiss할 수 있어야 하고, 매 게시글마다 보여주지 말고 세션 수준에서 빈도를 조절해야 한다. **절대 자동으로 외부 기관에 신고하거나 계정을 잠그지 않는다** — 이는 신뢰를 파괴하고 사용자를 떠나게 만든다.

표시할 위기 자원: **자살예방상담전화 1393**(24시간), **정신건강위기상담전화 1577-0199**(24시간), 청소년상담전화 1388. 표시 문구 예시: "지금 전화 한 통이면 당신의 이야기를 들어줄 사람이 있습니다."

**동의 메커니즘**: 온보딩 시 명확한 한국어 설명 필수. "이 커뮤니티는 여러분의 감정을 이해하고 필요할 때 도움을 제공하기 위해 AI 감정 분석을 사용합니다." 감정분석 opt-out 옵션 제공하되, 위기 감지는 opt-out 시에도 유지하는 것이 안전하다(개인정보보호법 준수 여부 법률 검토 필요).

---

## React Native UI 통합 패턴

**감정 태그 컴포넌트** — 게시글에 감정 분석 결과를 표시하는 기본 컴포넌트:

```typescript
// components/EmotionTag.tsx
import { View, Text, StyleSheet } from 'react-native'

const EMOTION_CONFIG: Record<string, { label: string; color: string; emoji: string }> = {
  loneliness:  { label: '외로움',    color: '#6B7DB3', emoji: '🫂' },
  anxiety:     { label: '불안',      color: '#E8A87C', emoji: '😰' },
  depression:  { label: '우울',      color: '#7B8FA1', emoji: '😢' },
  hopelessness:{ label: '무기력',    color: '#95818D', emoji: '😶' },
  shame:       { label: '자기비하',   color: '#C49BBB', emoji: '😣' },
  anger:       { label: '분노',      color: '#E07A5F', emoji: '😤' },
  hope:        { label: '희망',      color: '#81B29A', emoji: '🌱' },
  relief:      { label: '안도',      color: '#F2CC8F', emoji: '😊' },
  neutral:     { label: '평온',      color: '#B8B8B8', emoji: '😐' },
}

export function EmotionTag({ emotion, intensity }: { emotion: string; intensity?: number }) {
  const config = EMOTION_CONFIG[emotion] || EMOTION_CONFIG.neutral
  return (
    <View style={[styles.tag, { backgroundColor: config.color + '20', borderColor: config.color }]}>
      <Text style={styles.emoji}>{config.emoji}</Text>
      <Text style={[styles.label, { color: config.color }]}>{config.label}</Text>
      {intensity != null && (
        <View style={[styles.bar, { width: `${intensity * 100}%`, backgroundColor: config.color }]} />
      )}
    </View>
  )
}
```

**Supabase Realtime 구독 훅** — 감정 분석 완료 시 실시간 UI 업데이트:

```typescript
// hooks/useEmotionUpdates.ts
import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

export function useEmotionAnalysis(postId: string) {
  const [emotion, setEmotion] = useState<any>(null)

  useEffect(() => {
    // 1. 기존 데이터 로드
    supabase
      .from('emotion_analysis')
      .select('*')
      .eq('post_id', postId)
      .maybeSingle()
      .then(({ data }) => { if (data) setEmotion(data) })

    // 2. 실시간 구독 (분석 완료 시 자동 업데이트)
    const channel = supabase
      .channel(`emotion-${postId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'emotion_analysis',
        filter: `post_id=eq.${postId}`,
      }, (payload) => {
        setEmotion(payload.new)
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [postId])

  return emotion
}
```

**수동 감정 태그 + AI 하이브리드 접근**: 글 작성 시 사용자가 이모지 기반 감정 선택기로 자신의 기분을 태그하게 하고(6-8개 이모지 버튼), AI 분석은 백그라운드에서 별도 실행한다. 두 결과를 함께 저장하면 사용자 자기 인식과 AI 감지 사이의 갭을 연구할 수 있다 — 은둔형 외톨이들이 자신의 감정을 정확히 인식하는지 여부도 중요한 인사이트다.

---

## Flash vs Flash-Lite vs 자체 호스팅 모델 비교

| 솔루션 | 비용 (1M 토큰) | 무료 티어 | 정확도 | 감정 다중 분류 | 구현 난이도 |
|---|---|---|---|---|---|
| **Gemini 2.5 Flash-Lite** ⭐ | $0.10 / $0.40 | **1,000 RPD** | 좋음 | ✅ 프롬프트로 | 매우 쉬움 |
| **Gemini 2.5 Flash** | $0.30 / $2.50 | 250 RPD | 우수 | ✅ 프롬프트로 | 매우 쉬움 |
| **KoELECTRA-v3** | 무료 (자체호스팅) | 무제한 | NSMC **90.63%** | ❌ 이진분류만 | GPU 필요 |
| **KcBERT-Large** | 무료 (자체호스팅) | 무제한 | NSMC **90.68%** | ❌ 이진분류만 | GPU 필요 |
| **Naver CLOVA** | 토큰 기반 | 제한적 | 한국어 최적화 | ✅ | 중간 (별도 계정) |

**추천 전략은 2단계 파이프라인이다:**

1단계로 **Gemini 2.5 Flash-Lite**를 메인으로 쓴다. 분류 작업에 충분한 품질이면서 **출력 비용이 Flash 대비 6.25배 저렴**하고, 무료 티어가 하루 1,000건으로 가장 넉넉하다. Google도 Flash-Lite를 "classification tasks, simple information extraction, automation triggers"에 최적이라고 명시한다.

2단계 스케일업 시, 위기 수준이 HIGH/CRITICAL로 감지된 게시글만 **Gemini 2.5 Flash**로 재분석하는 2-tier 전략을 적용한다. 이러면 대부분의 트래픽은 저렴한 Flash-Lite가 처리하고, 위기 판단만 더 정확한 Flash가 담당한다.

**KoELECTRA/KcBERT**는 GPU 서버를 자체 운영해야 하고, 이진 분류(긍정/부정)만 기본 지원하며, 다중 감정 분류를 위해선 커스텀 파인튜닝이 필요하다. 소규모 비영리 프로젝트에서 GPU 인프라를 운영하는 것은 비현실적이므로, Gemini API가 압도적으로 합리적이다. 다만 KcBERT는 **뉴스 댓글 110M건**으로 학습되어 구어체/비속어에 특히 강하므로, 나중에 오프라인 벤치마크용으로 활용할 가치가 있다.

---

## 비용 관리: 무료 티어로 시작하는 전략

**현실적 비용 계산**: 한국어 게시글 평균 100자 기준, 프롬프트 포함 입력 약 500토큰, 출력 약 200토큰으로 잡으면:

- **Flash-Lite 1건당 비용**: ~$0.00005 (입력) + ~$0.00008 (출력) = **약 $0.00013**
- **하루 100건**: ~$0.013 → **월 $0.40** (사실상 무료)
- **하루 1,000건**: ~$0.13 → **월 $3.90**
- **무료 티어로 하루 1,000건** 커버 가능 (Flash-Lite RPD = 1,000)

비용 절감 전략: 10자 미만 게시글 스킵, 중복 분석 방지(`UNIQUE` 제약), `maxOutputTokens: 512`로 출력 제한, `api_usage` 테이블로 일일 사용량 추적, 일일 한도 도달 시 분석 건너뛰기 로직 추가.

---

## 결론: 즉시 시작할 수 있는 구현 체크리스트

이 시스템의 핵심 강점은 **Supabase 생태계 안에서 완결**된다는 것이다. 별도 서버, 큐 시스템, GPU 인프라 없이 Edge Function + PostgreSQL 트리거 + pg_cron만으로 프로덕션급 감정분석 파이프라인을 구축할 수 있다. Gemini의 structured output은 파싱 에러 걱정 없이 일관된 JSON을 보장하고, 한국어 시스템 프롬프트 + 인터넷 은어 해석 규칙을 포함시키면 은둔형 외톨이 커뮤니티에 특화된 정교한 감정 분석이 가능하다.

가장 주의할 점은 **기술적 완성도보다 윤리적 설계**다. 감정분석은 도구이지 목적이 아니다. 위기 감지가 너무 공격적이면 사용자가 떠나고, 너무 느슨하면 위험을 놓친다. "지지하는 친구" 톤을 유지하면서 안전망을 제공하는 균형이 이 프로젝트의 진짜 도전이다. 초기에는 False positive을 허용하되 사용자에게 dismiss 옵션을 항상 제공하고, 실제 운영 데이터가 쌓이면 점진적으로 임계값을 튜닝하는 접근이 현실적이다.