# 유튜브 영상 큐레이션 — 설계 수정안

> 원본: `docs/DESIGN-youtube-videos.md`
> 작성일: 2026-03-07
> 목적: 원본 설계를 앱/웹/중앙 레포에 적용할 때 발견된 문제점과 개선안을 정리

---

## 1. 스키마 수정

### 1.1 `description` -> `admin_comment` 컬럼명 변경

**문제**: `youtube_videos.description`이 YouTube 원본 description과 혼동됨. 설계 문서 자체에서도 "관리자 작성 소개 코멘트 (YouTube 설명과 별도)"라고 명시하고 있어 컬럼명이 역할을 반영하지 못함.

**수정**:

```sql
-- 원본
description TEXT,  -- 관리자 작성 소개 코멘트 (YouTube 설명과 별도)

-- 수정
admin_comment TEXT,  -- 관리자 작성 소개 코멘트 (YouTube 원본 description과 구분)
```

관련 RPC(`get_youtube_videos`)와 shared/types.ts의 `YoutubeVideo` 인터페이스도 `adminComment`로 반영.

---

### 1.2 `view_count` 중복 조회 방지 장치 추가

**문제**: Phase 1의 `record_video_view` RPC에 중복 방지가 전혀 없음. 새로고침만으로 조회수 무한 증가 가능.

**수정**: `video_view_logs` 경량 테이블 추가 — Phase 2의 `video_watch_history`와 별개로, Phase 1에서 최소한의 어뷰징 방지 역할.

```sql
-- Phase 1 전용 경량 조회 로그 (Phase 2에서 watch_history로 통합 후 제거 가능)
CREATE TABLE IF NOT EXISTS public.video_view_logs (
  user_id UUID NOT NULL DEFAULT auth.uid(),
  video_id BIGINT NOT NULL REFERENCES youtube_videos(id) ON DELETE CASCADE,
  last_viewed_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, video_id)
);

ALTER TABLE video_view_logs ENABLE ROW LEVEL SECURITY;
-- RPC(SECURITY DEFINER)에서만 접근하므로 직접 정책 불필요
```

```sql
CREATE OR REPLACE FUNCTION record_video_view(p_video_id BIGINT)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_last TIMESTAMPTZ;
BEGIN
  -- 5분 쿨다운: 같은 사용자가 같은 영상을 5분 내 재조회 시 무시
  SELECT last_viewed_at INTO v_last
  FROM video_view_logs
  WHERE user_id = v_user_id AND video_id = p_video_id;

  IF v_last IS NOT NULL AND v_last > now() - INTERVAL '5 minutes' THEN
    RETURN;  -- 쿨다운 내 → 조회수 증가 안 함
  END IF;

  -- 조회 로그 UPSERT
  INSERT INTO video_view_logs (user_id, video_id, last_viewed_at)
  VALUES (v_user_id, p_video_id, now())
  ON CONFLICT (user_id, video_id) DO UPDATE SET last_viewed_at = now();

  -- 조회수 증가
  UPDATE youtube_videos SET view_count = view_count + 1 WHERE id = p_video_id;
END;
$$;
```

**트레이드오프**: 테이블 1개 추가되지만 조회수 신뢰도가 크게 올라감. Phase 2에서 `video_watch_history`로 통합 시 이 테이블은 DROP 가능.

---

### 1.3 `posts` 테이블 변경 시 뷰 재생성

**문제**: `posts`에 `youtube_url`/`youtube_id` 컬럼 추가 시, `posts_with_like_count` 뷰가 명시적 컬럼 목록을 사용하므로 뷰 DROP+CREATE가 필요. 기존 앱/웹 코드가 이 뷰에 의존하므로 한 마이그레이션 안에서 원자적으로 처리해야 함.

**수정**: Phase 2 마이그레이션에 뷰 재생성을 명시적으로 포함.

```sql
-- Phase 2 마이그레이션 내 원자적 처리
BEGIN;
  -- 1. 컬럼 추가
  ALTER TABLE posts ADD COLUMN IF NOT EXISTS youtube_url TEXT;
  ALTER TABLE posts ADD COLUMN IF NOT EXISTS youtube_id TEXT;

  -- 2. 인덱스
  CREATE INDEX IF NOT EXISTS idx_posts_youtube_id
    ON posts(youtube_id) WHERE youtube_id IS NOT NULL AND deleted_at IS NULL;

  -- 3. 뷰 재생성 (기존 컬럼 목록 + youtube_url, youtube_id 추가)
  DROP VIEW IF EXISTS posts_with_like_count;
  CREATE VIEW posts_with_like_count AS
  SELECT
    p.id, p.title, p.content, p.board_id, p.group_id, p.user_id,
    p.is_anonymous, p.initial_emotions,
    p.youtube_url, p.youtube_id,  -- 신규
    p.created_at, p.updated_at, p.deleted_at,
    COALESCE(r.like_count, 0) AS like_count,
    COALESCE(c.comment_count, 0) AS comment_count,
    pa.emotions
  FROM posts p
  LEFT JOIN (
    SELECT post_id, SUM(count) AS like_count FROM reactions GROUP BY post_id
  ) r ON r.post_id = p.id
  LEFT JOIN (
    SELECT post_id, COUNT(*) AS comment_count FROM comments WHERE deleted_at IS NULL GROUP BY post_id
  ) c ON c.post_id = p.id
  LEFT JOIN post_analysis pa ON pa.post_id = p.id;

  ALTER VIEW posts_with_like_count SET (security_invoker = on);
COMMIT;
```

---

## 2. Phase 재조정

### 2.1 Edge Function을 Phase 1으로 이동

**문제**: 원본 설계는 `fetch-youtube-metadata` Edge Function을 Phase 3에 배치. 그러나 관리자가 영상 등록 시 제목/채널명/길이를 수동 입력하는 것은 비현실적. URL 붙여넣기 → 자동 채움이 MVP에 필수.

**수정**:

| Phase | 원본 | 수정안 |
|-------|------|--------|
| Phase 1 | DB + 기본 UI | DB + 기본 UI + **Edge Function** + **관리자 등록 UI** |
| Phase 2 | 게시글 임베드 + 시청 기록 | 게시글 임베드 + 시청 기록 (변동 없음) |
| Phase 3 | Edge Function + 관리자 UI + 고급 기능 | ~~Edge Function + 관리자 UI~~ + 고급 기능만 |

### 2.2 수정된 Phase 구성

**Phase 1: MVP — DB + 기본 UI + 관리자 영상 등록**

중앙 (supabase-hermit):
- 마이그레이션: `youtube_videos`, `video_reactions`, `user_video_reactions`, `video_bookmarks`, `video_view_logs`
- RPC: `get_youtube_videos`, `toggle_video_reaction`, `get_video_reactions`, `record_video_view`, `toggle_video_bookmark`, `get_my_video_bookmarks`, `mark_video_unavailable`
- 공유 타입/상수/유틸리티 업데이트

앱 레포 (Edge Function):
- `fetch-youtube-metadata` — YouTube Data API v3 + oEmbed 폴백

앱:
- dev build 전환 (선행 필수)
- `react-native-youtube-iframe` 설치
- 영상 전용 페이지 (`/videos`, `/videos/[id]`)
- 홈 RecommendedVideos 가로 스크롤 섹션

웹:
- `react-lite-youtube-embed` 설치
- 영상 전용 페이지 + 홈 섹션
- 관리자 영상 등록/관리 UI (`/admin/videos`) — 웹 우선 구현

**Phase 2: 게시글 임베드 + 시청 기록**

중앙:
- `posts` 테이블 확장 (`youtube_url`, `youtube_id`) + 뷰 재생성
- `video_watch_history` 테이블 (기존 `video_view_logs` 통합)
- `get_my_watch_history`, `clear_my_watch_history` RPC

앱/웹:
- 글쓰기 화면 YouTube URL 입력 필드
- PostCard/PostDetailView YouTube 임베드
- 마이페이지 시청 기록 탭

**Phase 3: 고급 기능**

- 감정 기반 영상 추천 RPC (`get_recommended_videos_by_emotion`)
- 플레이리스트 일괄 임포트
- 시간대별 추천 (밤=힐링, 아침=동기부여)
- AI 감정 자동 태깅 (Gemini 파이프라인 재사용)
- 영상 댓글 기능

---

## 3. 앱 UI/UX 수정

### 3.1 홈 화면 섹션 배치 순서 변경

**문제**: 기존 홈 구조에 RecommendedVideos를 추가하면 첫 게시글이 화면 아래로 밀림. UX 최적화(2026-03-11)에서 게시글 영역 확대를 위해 상단을 compact화 한 작업과 상충.

**수정**: RecommendedVideos를 EmotionTrend 앞으로 이동. 영상은 시각적 임팩트가 크므로 인사말 바로 아래가 자연스럽고, EmotionTrend는 데이터가 쌓여야 의미 있으므로 아래로.

```
[ListHeader]
  GreetingBanner (compact)
  RecommendedVideos (가로 스크롤, 최대 3개)   <-- EmotionTrend 앞으로
  EmotionTrend (compact)
  TrendingPosts (compact)
[PostCard 목록]
```

추가 조건:
- `is_featured` 영상이 0개면 RecommendedVideos 섹션 자체를 렌더링하지 않음
- 홈에서는 최대 **3개**만 표시 (원본 5개 → 3개로 축소)
- 카드 너비 w-40 → w-36으로 축소하여 섹션 높이 ~120px 이내 유지

### 3.2 ReactionBar 컴포넌트 설계

**문제**: 기존 `ReactionBar`에 `targetType` prop을 추가하면 내부에서 RPC 호출 분기가 발생하여 컴포넌트 복잡도 증가.

**수정**: 훅 레벨에서 분기하고 ReactionBar에는 콜백만 전달.

```tsx
// --- 훅 레벨 분기 ---
// usePostReaction.ts (기존)
export function usePostReaction(postId: number) {
  return useMutation({
    mutationFn: (type: string) =>
      supabase.rpc('toggle_reaction', { p_post_id: postId, p_type: type }),
    // ...optimistic update
  })
}

// useVideoReaction.ts (신규)
export function useVideoReaction(videoId: number) {
  return useMutation({
    mutationFn: (type: string) =>
      supabase.rpc('toggle_video_reaction', { p_video_id: videoId, p_type: type }),
    // ...optimistic update
  })
}

// --- 컴포넌트 사용 ---
// PostDetail
const { mutate: toggle } = usePostReaction(postId)
<ReactionBar reactions={postReactions} onToggle={toggle} />

// VideoDetail
const { mutate: toggle } = useVideoReaction(videoId)
<ReactionBar reactions={videoReactions} onToggle={toggle} />
```

ReactionBar 자체는 순수 UI 컴포넌트로 유지 — `reactions` 데이터 + `onToggle` 콜백만 받음.

---

## 4. 웹 추가 고려사항

### 4.1 영상 상세 페이지 SEO

영상 상세 페이지(`/videos/[id]`)에 `generateMetadata`로 OG 메타데이터 설정 필요.

```tsx
// src/app/videos/[id]/page.tsx
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const video = await getVideo(params.id)
  return {
    title: `${video.title} | 은둔마을`,
    description: video.admin_comment || `${video.channel_name} 채널의 영상`,
    openGraph: {
      images: [video.thumbnail_url || getYoutubeThumbnail(video.youtube_id, 'hq')],
    },
  }
}
```

### 4.2 반응형 그리드 썸네일 해상도

기존 웹의 `max-w-2xl` 컨테이너 안에서 2열 grid 사용 시, 카드 너비가 좁아짐.

```
max-w-2xl = 672px
2열 + gap-4 = (672 - 16) / 2 = 328px per card
→ mq 썸네일 (320x180)이면 약간 늘어남
→ hq 썸네일 (480x360) 사용이 적합
```

모바일 1열에서는 전체 너비를 사용하므로 hq 통일로 충분. `maxres`(1280x720)는 불필요.

---

## 5. 앱 dev build 전환 — 선행 작업

### 5.1 전환이 필요한 이유

`react-native-youtube-iframe`은 `react-native-webview` 네이티브 모듈에 의존. Expo Go에서는 네이티브 모듈 사용 불가 → EAS development build가 필수.

### 5.2 전환 작업 목록

```
1. eas.json에 development 프로필 추가 (또는 확인)
2. npx expo install react-native-webview
3. app.json/app.config.ts에 expo-dev-client 플러그인 확인
4. eas build --profile development --platform all
5. dev build 앱 설치 후 기존 기능 회귀 테스트
6. 이후 react-native-youtube-iframe 설치
```

이 전환은 YouTube 기능과 무관하게 독립적으로 진행 가능하며, 완료 후 YouTube 기능 개발 착수.

---

## 6. 구현 순서

Phase 1 내에서의 권장 구현 순서:

```
1단계: 앱 dev build 전환 (독립 선행, 회귀 테스트 포함)

2단계: 중앙 DB 작업
  - 마이그레이션 작성 (테이블 + RLS + RPC + 인덱스)
  - shared/types.ts — YoutubeVideo, VideoBookmark 등 타입 추가
  - shared/constants.ts — EMPTY_STATE_MESSAGES 추가
  - shared/youtube-utils.ts 신규 생성
  - sync-to-projects.sh에 youtube-utils.ts sync 대상 추가
  - db.sh push → gen-types → sync (자동)

3단계: Edge Function (앱 레포)
  - fetch-youtube-metadata 작성 (JWT 관리자 검증 + YouTube API + oEmbed 폴백)
  - 로컬 테스트 후 배포

4단계: 웹 관리자 UI
  - /admin/videos 페이지 (URL 입력 → 메타데이터 자동 채움 → 감정 태그 선택 → 등록)
  - 관리자가 실제 영상을 등록할 수 있어야 5~6단계 개발/테스트 가능

5단계: 웹 사용자 UI
  - /videos 전체 목록 + /videos/[id] 상세 (react-lite-youtube-embed)
  - 홈 RecommendedVideos 섹션
  - 리액션 + 북마크

6단계: 앱 사용자 UI
  - /videos 전체 목록 + /videos/[id] 상세 (react-native-youtube-iframe)
  - 홈 RecommendedVideos 섹션
  - 리액션 + 북마크
```

**웹을 앱보다 먼저 하는 이유:**
- 웹에서 관리자 영상 등록 UI를 먼저 만들어야 테스트 데이터 확보 가능
- `react-lite-youtube-embed`는 설치만으로 바로 동작 (dev build 불필요)
- 웹에서 UI/UX 검증 후 앱에 적용하면 수정 비용 감소

---

## 7. 수정 사항 요약

| # | 영역 | 원본 | 수정안 | 이유 |
|---|------|------|--------|------|
| 1 | 스키마 | `description TEXT` | `admin_comment TEXT` | YouTube description과 혼동 방지 |
| 2 | 스키마 | `record_video_view` 단순 증가 | `video_view_logs` + 5분 쿨다운 | 조회수 어뷰징 방지 |
| 3 | 스키마 | posts 변경 시 뷰 미언급 | 뷰 DROP+CREATE 원자적 처리 명시 | 앱/웹 뷰 의존성 보호 |
| 4 | Phase | Edge Function = Phase 3 | Edge Function = Phase 1 | 수동 메타데이터 입력 비현실적 |
| 5 | Phase | 관리자 UI = Phase 3 | 관리자 UI = Phase 1 | 영상 등록 없이 테스트 불가 |
| 6 | 앱 UI | RecommendedVideos: EmotionTrend 아래 | EmotionTrend 앞으로 | 시각적 임팩트 + 데이터 의존성 |
| 7 | 앱 UI | 홈 최대 5개 | 홈 최대 3개, w-36 | 홈 과밀 방지 |
| 8 | 앱 코드 | ReactionBar에 targetType prop | 훅 레벨 분기 + 콜백 전달 | 컴포넌트 단순성 유지 |
| 9 | 웹 | SEO 미언급 | generateMetadata OG 설정 | 영상 공유 시 미리보기 필요 |
| 10 | 선행 | dev build 전환 미언급 | 독립 선행 작업으로 분리 | YouTube 기능과 무관하게 진행 가능 |
