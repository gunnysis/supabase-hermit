# 감정분석 재시도 및 실패 증상 개선 설계

> 작성일: 2026-03-06
> 상태: 설계 완료, 구현 대기

---

## 1. 현황 및 장애 분석

### 1.1 현재 아키텍처

```
게시글 INSERT/UPDATE
  |
  v
DB Trigger (analyze_post_on_insert / analyze_post_on_update)
  |
  v  supabase_functions.http_request (timeout: 5000ms)
  |
  v
[analyze-post] Edge Function (Deno)
  |
  +-- payload 검증 (table, schema, type)
  +-- UPDATE 시 content/title 변경 여부 확인
  +-- analyzeAndSave() 호출
       |
       +-- stripHtml → 10자 미만이면 skip
       +-- 쿨다운 60초 확인 (force=false)
       +-- Gemini API 호출 (1회)
       +-- JSON.parse(raw.trim()) → emotions 추출
       +-- post_analysis UPSERT (emotions, analyzed_at)
       |
       v
  Realtime (postgres_changes) → 클라이언트 수신

[클라이언트 폴백]
  15초 후 post_analysis 없으면 → analyze-post-on-demand (force=true) 1회 호출
  5초 후 수동 invalidate
```

### 1.2 실제 장애 사례 (2026-03-05, 게시글 #62)

| 시점 | 이벤트 | 결과 |
|---|---|---|
| 22:58:01 | 게시글 #62 "과도한 방어기제" INSERT | 트리거 정상 발동 |
| 22:58:01 | analyze-post → Gemini API 호출 | Gemini 응답이 JSON 배열이 아닌 형태 |
| 22:58:01 | JSON.parse(raw.trim()) 실패 | `{ ok: false, reason: "json_parse_error" }` 반환 |
| 22:58:01 | **post_analysis에 아무것도 기록 안 됨** | DB에 행 없음 |
| ~22:58:16 | 클라이언트 15초 폴백 → on-demand 호출 | 동일하게 json_parse_error |
| 이후 | 사용자가 재시도 버튼 클릭 | 동일 실패 (일시적 Gemini 응답 이상) |
| **영구** | **post_analysis 행 없음 → 감정 태그 미표시** | **복구 경로 없음** |

> 수동 조사 시 동일 content로 Gemini 직접 호출하면 정상 응답 `["무기력", "답답함"]` 확인.
> on-demand에 content를 명시적으로 전달하면 성공. → 일시적 Gemini 응답 비결정성이 원인.

### 1.3 문제점 요약

| # | 문제 | 심각도 | 설명 |
|---|---|---|---|
| P1 | Gemini 응답 파싱 취약 | **높음** | `JSON.parse(raw.trim())`만 수행. Gemini가 `` ```json [...] ``` `` 코드블록으로 감싸면 파싱 실패 |
| P2 | 실패 시 DB 기록 없음 | **높음** | 실패해도 post_analysis에 행이 없어 클라이언트가 "대기중" vs "실패" 구분 불가 |
| P3 | 서버 재시도 없음 | 중간 | Gemini 429/5xx 등 일시적 오류에 1회 시도로 종료 |
| P4 | 클라이언트 폴백 1회 | 중간 | 15초 후 1회만 시도. 실패하면 사용자가 수동 재시도해야 함 |
| P5 | 재시도 횟수 무제한 | 낮음 | 사용자가 재시도 버튼 무한 클릭 가능 → API 비용 |
| P6 | 분석 상태 미추적 | 낮음 | pending/analyzing/done/failed 구분 없음 |

---

## 2. 설계

### 2.1 변경 범위

```
[Phase 1 - 즉시 수정] Edge Function만 변경 (앱 레포)
  - P1 해결: Gemini 응답 파싱 강화
  - P3 해결: 서버 사이드 재시도

[Phase 2 - DB 스키마] 마이그레이션 + Edge Function + 클라이언트
  - P2, P4, P5, P6 해결: 상태 추적 + 지능형 재시도
```

---

### 2.2 Phase 1: Edge Function 즉시 수정

#### 2.2.1 Gemini 응답 파싱 강화 (P1 해결)

**파일**: `supabase/functions/_shared/analyze.ts`

현재:
```typescript
const raw = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
const parsed = JSON.parse(raw.trim()) as unknown;
```

변경:
```typescript
const raw = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';

// Gemini가 마크다운 코드블록으로 감싸는 경우 처리
// 예: ```json\n["무기력", "답답함"]\n```
// 예: ```\n["무기력"]\n```
let cleaned = raw.trim();
cleaned = cleaned.replace(/^```(?:json)?\s*\n?/i, '').replace(/\n?\s*```\s*$/g, '').trim();

const parsed = JSON.parse(cleaned) as unknown;
```

**테스트 케이스**:
```
입력: '["무기력", "답답함"]'         → 통과 (기존)
입력: '```json\n["무기력"]\n```'      → 통과 (신규)
입력: '```\n["슬픔", "불안"]\n```'    → 통과 (신규)
입력: '  ["평온함"]  '                → 통과 (기존 trim)
입력: 'The emotions are...'          → 실패 → P3 재시도로 넘어감
```

#### 2.2.2 서버 사이드 재시도 (P3 해결)

**파일**: `supabase/functions/_shared/analyze.ts`

```typescript
/**
 * Gemini API 호출 + 재시도.
 * 429 (rate limit), 5xx (서버 오류), 파싱 실패 시 최대 2회 재시도.
 * 지수 백오프: 1초 → 2초.
 *
 * Edge Function 전체 타임아웃(~25초)을 고려하여 최대 3회(초기+2재시도).
 */
const MAX_RETRIES = 2;

async function callGeminiWithRetry(
  url: string,
  body: object,
): Promise<{ emotions: string[] }> {
  let lastError: string = 'unknown';

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    if (attempt > 0) {
      const delay = 1000 * Math.pow(2, attempt - 1); // 1s, 2s
      await new Promise((r) => setTimeout(r, delay));
    }

    // --- Gemini HTTP 요청 ---
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      lastError = `gemini_api_error_${res.status}`;
      // 429, 5xx만 재시도. 4xx(400, 403 등)는 즉시 실패.
      if (res.status !== 429 && res.status < 500) {
        throw new Error(lastError);
      }
      console.warn(`[analyze] Gemini ${res.status}, attempt ${attempt + 1}/${MAX_RETRIES + 1}`);
      continue;
    }

    // --- 응답 파싱 ---
    const data = await res.json();
    const raw = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';

    let cleaned = raw.trim();
    cleaned = cleaned.replace(/^```(?:json)?\s*\n?/i, '').replace(/\n?\s*```\s*$/g, '').trim();

    try {
      const parsed = JSON.parse(cleaned) as unknown;
      const emotions = Array.isArray(parsed)
        ? parsed
            .filter((e): e is string => typeof e === 'string' && VALID_EMOTIONS.has(e))
            .slice(0, 3)
        : [];

      if (emotions.length === 0) {
        lastError = 'no_valid_emotions';
        console.warn(`[analyze] 유효 감정 없음 (raw: ${raw}), attempt ${attempt + 1}`);
        continue; // 재시도
      }

      return { emotions };
    } catch {
      lastError = 'json_parse_error';
      console.warn(`[analyze] JSON 파싱 실패 (raw: ${raw}), attempt ${attempt + 1}`);
      continue; // 재시도
    }
  }

  throw new Error(lastError);
}
```

**재시도 조건 요약**:

| 상황 | 재시도 여부 | 이유 |
|---|---|---|
| HTTP 429 (Rate Limit) | O | 일시적 |
| HTTP 5xx (서버 오류) | O | 일시적 |
| HTTP 4xx (400, 403 등) | X | 영구적 오류 (API키 만료 등) |
| JSON 파싱 실패 | O | Gemini 응답 비결정성 |
| 유효 감정 0개 | O | Gemini가 빈 배열/무관한 텍스트 반환 |

**타이밍**:
```
시도 1 (즉시) → 실패 → 1초 대기
시도 2         → 실패 → 2초 대기
시도 3         → 실패 → 최종 실패
총 최대: ~3초 + 3회 API 호출 (Edge Function 25초 제한 내)
```

---

### 2.3 Phase 2: DB 상태 추적 + 클라이언트 개선

#### 2.3.1 post_analysis 테이블 확장

**마이그레이션**: `20260311000001_analysis_status_retry.sql`

```sql
-- 1) 상태 관리 컬럼 추가
ALTER TABLE public.post_analysis
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'done'
    CHECK (status IN ('pending', 'analyzing', 'done', 'failed')),
  ADD COLUMN IF NOT EXISTS retry_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS error_reason TEXT,
  ADD COLUMN IF NOT EXISTS last_attempted_at TIMESTAMPTZ;

-- 2) 기존 데이터 마이그레이션: emotions 있으면 done
-- (DEFAULT 'done'이므로 기존 행은 자동으로 done)

-- 3) 분석 누락 게시글에 pending 행 생성
INSERT INTO post_analysis (post_id, status, emotions)
SELECT p.id, 'pending', '{}'
FROM posts p
LEFT JOIN post_analysis pa ON p.id = pa.post_id
WHERE pa.post_id IS NULL AND p.deleted_at IS NULL
ON CONFLICT (post_id) DO NOTHING;

-- 4) 상태별 조회 인덱스
CREATE INDEX IF NOT EXISTS idx_post_analysis_status
  ON post_analysis (status)
  WHERE status IN ('pending', 'failed');
```

#### 2.3.2 게시글 INSERT 시 pending 행 자동 생성

```sql
-- posts INSERT 전에 post_analysis pending 행 생성
CREATE OR REPLACE FUNCTION public.create_pending_analysis()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.post_analysis (post_id, status, emotions)
  VALUES (NEW.id, 'pending', '{}')
  ON CONFLICT (post_id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_create_pending_analysis
  AFTER INSERT ON public.posts
  FOR EACH ROW
  EXECUTE FUNCTION public.create_pending_analysis();
```

> AFTER INSERT로 설정. BEFORE INSERT는 아직 id가 할당 전일 수 있으므로 AFTER 사용.
> 기존 `analyze_post_on_insert` 트리거보다 먼저 실행되도록 트리거명 알파벳순 보장 불필요 — 둘 다 AFTER INSERT이고 pending 행은 ON CONFLICT DO NOTHING.

#### 2.3.3 게시글 UPDATE 시 analyzing으로 전환

```sql
-- posts UPDATE (content/title 변경) 시 status를 analyzing으로 전환
CREATE OR REPLACE FUNCTION public.mark_analysis_analyzing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.post_analysis
  SET status = 'analyzing',
      last_attempted_at = now()
  WHERE post_id = NEW.id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_mark_analysis_analyzing
  AFTER UPDATE OF content, title ON public.posts
  FOR EACH ROW
  WHEN (OLD.content IS DISTINCT FROM NEW.content OR OLD.title IS DISTINCT FROM NEW.title)
  EXECUTE FUNCTION public.mark_analysis_analyzing();
```

#### 2.3.4 상태 흐름

```
게시글 INSERT
  |
  +--[trg_create_pending_analysis]--> post_analysis: status='pending'
  |
  +--[analyze_post_on_insert]-------> analyze-post Edge Function
                                        |
                                        +-- 성공 --> status='done', emotions=[...], retry_count=0
                                        |
                                        +-- 실패 --> status='failed', error_reason='...', retry_count++

게시글 UPDATE (content/title)
  |
  +--[trg_mark_analysis_analyzing]--> post_analysis: status='analyzing'
  |
  +--[analyze_post_on_update]-------> analyze-post Edge Function (동일 흐름)

클라이언트 재시도
  |
  +--[analyze-post-on-demand]-------> status='analyzing' → 성공/실패 동일 흐름
```

```
                    +---------+
   POST INSERT ---->| pending |
                    +----+----+
                         |
                   Edge Function 호출
                         |
                    +----v------+
                    | analyzing |<------- POST UPDATE (content/title)
                    +----+------+        클라이언트 재시도 (on-demand)
                         |
              +----------+----------+
              |                     |
         +----v---+           +-----v----+
         |  done  |           |  failed  |
         +--------+           +-----+----+
           emotions=[...]           |
                              retry_count < 3?
                                    |
                              +-----+-----+
                              | yes       | no
                              v           v
                         재시도 가능   최종 실패
                         (버튼 표시)  (버튼 숨김)
```

#### 2.3.5 Edge Function 변경 (Phase 2)

**`_shared/analyze.ts` - analyzeAndSave() 수정**:

```typescript
export async function analyzeAndSave(params: {
  supabaseUrl: string;
  supabaseServiceKey: string;
  geminiApiKey: string;
  postId: number;
  content: string;
  title?: string;
  force?: boolean;
}): Promise<AnalyzeResult> {
  const { supabaseUrl, supabaseServiceKey, geminiApiKey, postId, content, title, force = false } = params;
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  const text = stripHtml(content);
  if (text.length < 10) {
    return { ok: true, skipped: 'content_too_short' };
  }

  // 쿨다운 (force=true면 건너뜀)
  if (!force) {
    const { data: existing } = await supabase
      .from('post_analysis')
      .select('analyzed_at')
      .eq('post_id', postId)
      .maybeSingle();

    if (existing?.analyzed_at) {
      const diffMs = Date.now() - new Date(existing.analyzed_at).getTime();
      if (diffMs < COOLDOWN_MS) {
        return { ok: true, skipped: 'cooldown_60s' };
      }
    }
  }

  // status → analyzing (행이 없으면 생성)
  await supabase
    .from('post_analysis')
    .upsert(
      {
        post_id: postId,
        status: 'analyzing',
        last_attempted_at: new Date().toISOString(),
      },
      { onConflict: 'post_id' },
    );

  try {
    // Gemini 호출 (재시도 포함)
    const { emotions } = await callGeminiWithRetry(geminiUrl, geminiBody);

    // 성공 → done
    const { error } = await supabase
      .from('post_analysis')
      .upsert(
        {
          post_id: postId,
          emotions,
          status: 'done',
          error_reason: null,
          retry_count: 0,
          analyzed_at: new Date().toISOString(),
          last_attempted_at: new Date().toISOString(),
        },
        { onConflict: 'post_id' },
      );

    if (error) {
      console.error('[analyze] upsert 오류:', error);
      return { ok: false, reason: error.message };
    }
    return { ok: true, emotions };

  } catch (err) {
    const reason = err instanceof Error ? err.message : 'unknown';

    // 실패 → failed + retry_count 증가
    // retry_count는 서버에서 현재 값을 읽어 +1
    const { data: current } = await supabase
      .from('post_analysis')
      .select('retry_count')
      .eq('post_id', postId)
      .maybeSingle();

    const newRetryCount = (current?.retry_count ?? 0) + 1;

    await supabase
      .from('post_analysis')
      .upsert(
        {
          post_id: postId,
          status: 'failed',
          error_reason: reason,
          retry_count: newRetryCount,
          last_attempted_at: new Date().toISOString(),
        },
        { onConflict: 'post_id' },
      );

    console.error(`[analyze] 최종 실패 (post_id=${postId}, retry=${newRetryCount}):`, reason);
    return { ok: false, reason };
  }
}
```

#### 2.3.6 posts_with_like_count 뷰 확장

```sql
CREATE OR REPLACE VIEW public.posts_with_like_count
WITH (security_invoker = true) AS
SELECT
  p.id, p.title, p.content, p.author_id, p.created_at,
  p.board_id, p.group_id, p.is_anonymous, p.display_name,
  p.member_id, p.image_url, p.initial_emotions,
  COALESCE(r_agg.total_count, 0)::integer AS like_count,
  COALESCE(c_agg.comment_count, 0)::integer AS comment_count,
  pa.emotions,
  COALESCE(pa.status, 'pending') AS analysis_status  -- 신규
FROM posts p
LEFT JOIN post_analysis pa ON pa.post_id = p.id
LEFT JOIN LATERAL (
  SELECT SUM(r.count) AS total_count FROM reactions r WHERE r.post_id = p.id
) r_agg ON true
LEFT JOIN LATERAL (
  SELECT COUNT(*)::integer AS comment_count FROM comments c WHERE c.post_id = p.id AND c.deleted_at IS NULL
) c_agg ON true
WHERE p.deleted_at IS NULL;
```

#### 2.3.7 클라이언트 변경

**A. `usePostDetailAnalysis.ts` — 상태 기반 폴링 + 지능형 폴백**

```typescript
export function usePostDetailAnalysis(postId: number) {
  const queryClient = useQueryClient();
  const fallbackCalledRef = useRef(false);

  useEffect(() => {
    fallbackCalledRef.current = false;
  }, [postId]);

  const { data: postAnalysis, isLoading: analysisLoading } = useQuery({
    queryKey: ['postAnalysis', postId],
    queryFn: () => api.getPostAnalysis(postId),
    enabled: postId > 0,
    staleTime: 5 * 60 * 1000,
    // pending/analyzing 상태면 3초 간격 폴링 → done/failed 시 중단
    refetchInterval: (query) => {
      const status = query.state.data?.status;
      return status === 'pending' || status === 'analyzing' ? 3000 : false;
    },
  });

  // Realtime 구독 (기존과 동일)
  useEffect(() => {
    const channel = supabase
      .channel(`post-analysis-${postId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'post_analysis',
        filter: `post_id=eq.${postId}`,
      }, () => {
        queryClient.invalidateQueries({ queryKey: ['postAnalysis', postId] });
      })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [postId, queryClient]);

  // 15초 폴백: status가 pending/analyzing이면 on-demand 호출
  useEffect(() => {
    if (postId <= 0) return;
    const timer = setTimeout(async () => {
      if (fallbackCalledRef.current) return;
      const cached = queryClient.getQueryData<PostAnalysis>(['postAnalysis', postId]);

      // 변경: null 체크 → status 기반
      if (!cached || cached.status === 'pending' || cached.status === 'analyzing') {
        fallbackCalledRef.current = true;
        const post = queryClient.getQueryData<{ content?: string; title?: string }>(['post', postId]);
        if (post?.content) {
          await api.invokeSmartService(postId, post.content, post.title);
          setTimeout(() => {
            queryClient.invalidateQueries({ queryKey: ['postAnalysis', postId] });
          }, 5000);
        }
      }
    }, 15000);
    return () => clearTimeout(timer);
  }, [postId, queryClient]);

  return { postAnalysis, analysisLoading };
}
```

**B. `EmotionTags.tsx` — 상태별 UI**

```typescript
interface EmotionTagsProps {
  emotions: string[];
  isLoading?: boolean;
  analysisStatus?: 'pending' | 'analyzing' | 'done' | 'failed';
  retryCount?: number;
  onPress?: (emotion: string) => void;
  onRetry?: () => void;
}

export function EmotionTags({
  emotions,
  isLoading,
  analysisStatus,
  retryCount = 0,
  onPress,
  onRetry,
}: EmotionTagsProps) {

  // 1. 로딩 / pending / analyzing → 스켈레톤
  if (isLoading || analysisStatus === 'pending' || analysisStatus === 'analyzing') {
    return (
      <View className="mb-4">
        <Text className="text-sm text-stone-500 dark:text-stone-400 mb-2">
          감정을 분석하고 있어요...
        </Text>
        <EmotionTagsSkeleton />
      </View>
    );
  }

  // 2. 실패 + 재시도 가능 (3회 미만)
  if (analysisStatus === 'failed' && retryCount < 3 && onRetry) {
    return (
      <View className="mb-4">
        <Text className="text-sm text-stone-500 dark:text-stone-400 mb-2">
          감정 분석에 실패했어요
        </Text>
        <Pressable
          onPress={onRetry}
          className="rounded-full bg-stone-100 dark:bg-stone-800 px-3 py-1.5 self-start active:opacity-70">
          <Text className="text-sm text-stone-600 dark:text-stone-300">
            다시 시도하기
          </Text>
        </Pressable>
      </View>
    );
  }

  // 3. 실패 + 재시도 소진 (3회 이상)
  if (analysisStatus === 'failed' && retryCount >= 3) {
    return (
      <View className="mb-4">
        <Text className="text-sm text-stone-400 dark:text-stone-500 mb-2">
          감정 분석을 완료하지 못했어요
        </Text>
      </View>
    );
  }

  // 4. 성공 + 감정 있음 → 태그 표시
  if (emotions?.length > 0) {
    return (
      <View className="mb-4">
        <Text className="text-sm text-stone-500 dark:text-stone-400 mb-2">이 글의 감정</Text>
        <View className="flex-row flex-wrap gap-2">
          {emotions.map((emotion) => (
            <EmotionTag key={emotion} emotion={emotion} onPress={onPress} />
          ))}
        </View>
      </View>
    );
  }

  // 5. done이지만 감정 없음 (글이 너무 짧은 경우 등)
  return null;
}
```

**C. `PostDetailBody.tsx` — props 전달**

```typescript
<EmotionTags
  emotions={postAnalysis?.emotions ?? []}
  isLoading={analysisLoading && postAnalysis == null}
  analysisStatus={postAnalysis?.status}
  retryCount={postAnalysis?.retry_count}
  onPress={onEmotionPress}
  onRetry={onRetryAnalysis}
/>
```

**D. 재시도 핸들러 — 횟수 제한**

```typescript
const handleRetryAnalysis = useCallback(async () => {
  if (!post?.content) return;

  // 재시도 횟수 제한
  if ((postAnalysis?.retry_count ?? 0) >= 3) {
    Toast.show({ type: 'info', text1: '더 이상 재시도할 수 없습니다.' });
    return;
  }

  try {
    await api.invokeSmartService(postId, post.content, post.title);
    queryClient.invalidateQueries({ queryKey: ['postAnalysis', postId] });
  } catch {
    Toast.show({ type: 'error', text1: '분석 요청에 실패했습니다.' });
  }
}, [post, postId, postAnalysis, queryClient]);
```

**E. `api/analysis.ts` — PostAnalysis 타입 확장**

```typescript
// 반환 타입에 status 등 추가
export async function getPostAnalysis(postId: number): Promise<PostAnalysis | null> {
  const { data, error } = await supabase
    .from('post_analysis')
    .select('post_id, emotions, analyzed_at, status, retry_count, error_reason')
    .eq('post_id', postId)
    .maybeSingle();

  if (error) {
    logger.error('[API] getPostAnalysis:', error.message);
    return null;
  }
  return data as PostAnalysis | null;
}
```

#### 2.3.8 shared/types.ts 확장

```typescript
export interface PostAnalysis {
  post_id: number;
  emotions: string[];
  analyzed_at: string | null;
  status: 'pending' | 'analyzing' | 'done' | 'failed';
  retry_count: number;
  error_reason: string | null;
}
```

---

## 3. 변경 파일 목록

### Phase 1 (앱 레포만)

| 파일 | 변경 내용 |
|---|---|
| `supabase/functions/_shared/analyze.ts` | 코드블록 파싱 + callGeminiWithRetry |

### Phase 2 (중앙 + 앱)

| 위치 | 파일 | 변경 내용 |
|---|---|---|
| 중앙 | `supabase/migrations/20260311000001_analysis_status_retry.sql` | post_analysis 컬럼 추가 + 트리거 2개 + 뷰 갱신 + 인덱스 |
| 중앙 | `shared/types.ts` | PostAnalysis 타입 확장 |
| 앱 | `supabase/functions/_shared/analyze.ts` | 상태 기록 (analyzing→done/failed) |
| 앱 | `src/features/posts/hooks/usePostDetailAnalysis.ts` | status 기반 폴링 + 폴백 |
| 앱 | `src/features/posts/components/EmotionTags.tsx` | 상태별 UI |
| 앱 | `src/features/posts/components/PostDetailBody.tsx` | props 전달 |
| 앱 | `src/app/post/[id].tsx` | retry_count 기반 재시도 제한 |
| 앱 | `src/shared/lib/api/analysis.ts` | select 컬럼 추가 |

---

## 4. 시나리오별 동작 검증

### 시나리오 1: 정상 흐름 (가장 흔함)

```
1. 글 작성 → pending 행 생성 → 트리거 → Edge Function → Gemini 성공
2. post_analysis: status=done, emotions=["무기력","답답함"]
3. Realtime → 클라이언트 즉시 반영
4. UI: 스켈레톤 → 감정 태그 표시 (1~3초)
```

### 시나리오 2: Gemini 응답 코드블록 (P1, 기존 실패 케이스)

```
1. 글 작성 → pending → 트리거 → Gemini 응답: ```json\n["슬픔"]\n```
2. Phase 1 파싱 강화로 코드블록 제거 → 정상 파싱
3. post_analysis: status=done, emotions=["슬픔"]
→ 기존에는 실패했던 케이스가 성공으로 전환
```

### 시나리오 3: Gemini 일시 장애 (429/5xx)

```
1. 글 작성 → pending → 트리거 → Gemini 429
2. 1초 대기 → 재시도 → Gemini 200 → 성공
3. post_analysis: status=done
→ 사용자는 1초 추가 지연만 경험
```

### 시나리오 4: Gemini 지속 장애 (3회 모두 실패)

```
1. 글 작성 → pending → 트리거 → 3회 실패
2. post_analysis: status=failed, retry_count=1, error_reason="gemini_api_error_500"
3. UI: "감정 분석에 실패했어요" + "다시 시도하기" 버튼
4. 사용자 재시도 → on-demand (force=true) → 3회 시도 → 성공
5. post_analysis: status=done, retry_count=0
```

### 시나리오 5: 최종 실패 (3회 재시도 소진)

```
1. 자동 트리거 실패 (retry_count=1)
2. 15초 폴백 실패 (retry_count=2)
3. 사용자 수동 재시도 실패 (retry_count=3)
4. UI: "감정 분석을 완료하지 못했어요" (재시도 버튼 숨김)
→ retry_count >= 3 이상은 관리자 확인 필요 (모니터링 대상)
```

### 시나리오 6: 글 수정 후 재분석

```
1. 기존 done 상태 → 사용자가 content 수정
2. trg_mark_analysis_analyzing → status=analyzing
3. analyze_post_on_update 트리거 → Edge Function → 성공
4. status=done, 새 emotions
5. Realtime UPDATE → 클라이언트 즉시 반영
```

---

## 5. 모니터링

Phase 2 적용 후 다음 쿼리로 실패 현황 추적 가능:

```sql
-- 실패한 분석 목록
SELECT pa.post_id, pa.error_reason, pa.retry_count, pa.last_attempted_at,
       p.title
FROM post_analysis pa
JOIN posts p ON p.id = pa.post_id
WHERE pa.status = 'failed'
ORDER BY pa.last_attempted_at DESC;

-- 상태별 집계
SELECT status, count(*) FROM post_analysis GROUP BY status;

-- pending이 오래된 건 (트리거 미발동 의심)
SELECT post_id, last_attempted_at
FROM post_analysis
WHERE status = 'pending'
  AND last_attempted_at < now() - interval '5 minutes';
```

---

## 6. 구현 순서 (권장)

```
1. Phase 1: analyze.ts 파싱 강화 + 재시도     ← 즉시 적용, 가장 큰 효과
2. Phase 2-DB: 마이그레이션 작성 + push + sync
3. Phase 2-EF: analyze.ts에 상태 기록 로직 추가
4. Phase 2-Client: 클라이언트 상태 기반 UI 변경
5. 검증: 테스트 게시글로 전체 흐름 확인
```
