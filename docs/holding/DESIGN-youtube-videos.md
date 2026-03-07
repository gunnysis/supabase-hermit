# 유튜브 영상 큐레이션 기능 설계

> 작성일: 2026-03-06
> 대상: supabase-hermit (DB 스키마) + 앱(React Native/Expo SDK 54) + 웹(Next.js)
> 상태: 기획 단계 — 구현 예정 없음, 설계 문서화 목적

---

## 1. Context

은둔마을은 사회적 고립/은둔을 겪는 사람들을 위한 심리 지원 커뮤니티 플랫폼이다. 현재 게시글/댓글/리액션/감정분석이 있지만, 은둔·고립 관련 유튜브 영상을 큐레이션·공유하는 기능이 없다.

**목적**: 기존 YouTube에 올라와 있는 은둔/고립 관련 유익한 영상(극복기, 심리상담, 힐링 등)을 관리자가 큐레이션하고, 사용자가 게시글에도 영상 URL을 첨부할 수 있게 하여 커뮤니티의 치유·정보 역할을 강화한다.

> 영상을 직접 제작·업로드하는 기능이 아님. YouTube에 이미 공개된 영상을 모아서 보여주는 큐레이션 플랫폼.

---

## 2. 핵심 설계 결정

| 항목 | 결정 | 이유 |
|------|------|------|
| 콘텐츠 관리 | 관리자 큐레이션 + 게시글 URL 임베드 | 품질 보장(큐레이션) + 커뮤니티 참여(임베드) |
| 분류 체계 | 감정 태그만 (기존 13개 감정), 별도 카테고리 없음 | 기존 시스템과 일관성 유지, 단순화 |
| UI 배치 | 홈 섹션(가로 스크롤) + 전용 페이지 + 게시글 임베드 | 기존 TrendingPosts 패턴 재사용 |
| 앱 네비게이션 | 홈 '더보기' → 전용 페이지 (탭 추가 없음) | 기존 4탭 구조 유지, 복잡도 최소화 |
| 상호작용 | 인앱 재생 + 조회수 + 리액션 + 북마크 | |
| 메타데이터 추출 | YouTube Data API v3 (주) + oEmbed (폴백) | Data API로 duration 등 풍부한 정보 확보 |
| 감정 부여 | 관리자 수동 선택 + AI 자동 제안 (향후) | 초기엔 관리자 판단, 추후 제목/설명 기반 AI 분석 |

---

## 3. 패키지 선정

### 3.1 앱 (React Native / Expo SDK 54)

| 패키지 | 버전 | 주간 다운로드 | 선정 이유 |
|--------|------|-------------|----------|
| `react-native-youtube-iframe` | 2.4.1 | ~79k | RN에서 유일하게 검증된 YouTube 플레이어. WebView 기반, Expo dev build 호환 |
| `react-native-webview` | latest | — | youtube-iframe 내부 의존성, Expo config plugin 지원 |

**주의사항:**
- Expo Go에서 실행 불가 → development build 필요
- 저작권 보호/비공개 영상은 "Video unavailable" 에러 → 에러 핸들링 필수
- 전체화면: Android 네이티브 지원, iOS는 `webViewProps={{ allowsFullscreenVideo: true }}` 필요
- WebView 기반이라 성능 오버헤드 존재 → 플레이어 lazy load 권장

**탈락 패키지:**
- `expo-av` / `expo-video`: YouTube 재생 불가 (직접 비디오 파일만 지원)
- `react-native-youtube`: 2021년 이후 미관리, Android에서 YouTube 앱 설치 필수
- `react-native-youtube-bridge`: 커뮤니티 작음, 프로덕션 검증 부족

**사용 예시:**
```tsx
import YoutubePlayer from 'react-native-youtube-iframe'

<YoutubePlayer
  height={220}
  videoId={youtubeId}
  play={playing}
  onChangeState={onStateChange}
  onError={(e) => handleVideoError(e)}
  webViewProps={{
    allowsFullscreenVideo: true,
    mediaPlaybackRequiresUserAction: false,
  }}
/>
```

### 3.2 웹 (Next.js)

| 패키지 | 버전 | 주간 다운로드 | 선정 이유 |
|--------|------|-------------|----------|
| `react-lite-youtube-embed` | latest | ~13k | SSR 호환, 5KB 미만, 썸네일 먼저 로드 → 클릭 시 iframe (224배 빠름) |

**왜 성능 최적화가 중요한가:**
- 일반 YouTube iframe embed = 페이지당 1.3~2.6MB 추가 + 20개 이상 HTTP 요청
- LCP, FID, CLS 모두 악화 → SEO 및 Core Web Vitals 점수 하락
- `react-lite-youtube-embed`는 썸네일만 먼저 로드, 클릭 시에만 iframe 활성화

**탈락 패키지:**
- `react-youtube`: 24만 다운로드지만 2022년 이후 미관리
- `react-player`: 다기능이지만 YouTube 전용에 과도한 번들 크기
- `lite-youtube-embed`: Web Component 방식이라 React hydration과 비호환

**프라이버시 모드:** `youtube-nocookie.com` 사용하면 초기 쿠키 없음 (GDPR 부분 대응). 단, 재생 시작하면 YouTube가 쿠키 설정함.

**사용 예시:**
```tsx
import LiteYouTubeEmbed from 'react-lite-youtube-embed'
import 'react-lite-youtube-embed/dist/LiteYouTubeEmbed.css'

<LiteYouTubeEmbed
  id={youtubeId}
  title={title}
  poster="hqdefault"
  noCookie={true}
/>
```

### 3.3 공통 유틸리티 함수

```typescript
// ===== YouTube URL 파싱 (모든 형식 지원) =====
// youtube.com/watch?v=ID, youtu.be/ID, youtube.com/embed/ID, youtube.com/shorts/ID
const YOUTUBE_REGEX = /(?:https?:\/\/)?(?:www\.)?(?:youtube\.com|youtu\.be)\/(?:watch\?v=|embed\/|v\/|shorts\/)?([a-zA-Z0-9_-]{11})/

export function extractYoutubeId(url: string): string | null {
  const match = url.match(YOUTUBE_REGEX)
  return match ? match[1] : null
}

// ===== 썸네일 URL 생성 (API 호출 불필요, 결정적 URL) =====
export function getYoutubeThumbnail(
  youtubeId: string,
  quality: 'default' | 'mq' | 'hq' | 'sd' | 'maxres' = 'hq'
): string {
  const qualityMap = { default: 'default', mq: 'mqdefault', hq: 'hqdefault', sd: 'sddefault', maxres: 'maxresdefault' }
  return `https://img.youtube.com/vi/${youtubeId}/${qualityMap[quality]}.jpg`
}
// 썸네일 크기: default(120x90), mq(320x180), hq(480x360), sd(640x480), maxres(1280x720)

// ===== ISO 8601 Duration -> 초 (YouTube API 반환 형식 파싱) =====
export function parseDuration(iso8601: string): number {
  const match = iso8601.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/)
  if (!match) return 0
  return (parseInt(match[1] || '0') * 3600) + (parseInt(match[2] || '0') * 60) + parseInt(match[3] || '0')
}

// ===== 초 -> 표시 형식 ("5:32", "1:23:45") =====
export function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = seconds % 60
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
  return `${m}:${String(s).padStart(2, '0')}`
}

// ===== YouTube URL 유효성 검증 =====
export function isValidYoutubeUrl(url: string): boolean {
  return YOUTUBE_REGEX.test(url)
}
```

**유틸리티 함수 위치**: `shared/youtube-utils.ts` 신규 파일 생성 → `sync-to-projects.sh`에 sync 대상 추가. 중앙 관리로 앱/웹 코드 중복 방지.

---

## 4. YouTube API 활용

### 4.1 YouTube Data API v3

**비용:** 무료 (일 10,000유닛 쿼타)

| 엔드포인트 | 유닛 비용 | 용도 | 사용 시점 |
|-----------|----------|------|----------|
| `videos.list` | 1 | 영상 메타데이터 (title, duration, thumbnail, description) | 관리자 영상 등록 시 |
| `search.list` | 100 | 키워드로 영상 검색 | 관리자 영상 찾기 (선택) |
| `playlistItems.list` | 1 | 플레이리스트에서 영상 목록 | 관리자 일괄 임포트 |
| `captions.list` | 50 | 자막 유무 확인 | 접근성 표시용 (선택) |

**쿼타 최적화 전략:**
- 사용자 요청은 항상 DB 캐시에서 서빙 → API 호출 0
- `videos.list`는 관리자 등록 시에만 1회 호출 (1유닛)
- `search.list`는 관리자 전용 → 일 100회 검색 가능
- 플레이리스트 일괄 임포트: 50개 영상 = ~51유닛
- 10,000 DAU 기준으로도 쿼타 초과 위험 없음

**환경변수:** `YOUTUBE_API_KEY` → Supabase Secrets에 저장

### 4.2 YouTube oEmbed API (폴백)

```
GET https://www.youtube.com/oembed?url={youtube_url}&format=json
```

| 항목 | 내용 |
|------|------|
| 반환 데이터 | title, author_name(채널명), thumbnail_url, html(임베드 코드) |
| 장점 | API 키 불필요, rate limit 관대 |
| 단점 | duration, viewCount, description 미포함 |
| 용도 | Data API 키 없을 때 폴백, 게시글 임베드 시 간단 메타데이터 |

### 4.3 썸네일 URL — API 호출 불필요

YouTube 썸네일은 `youtube_id`에서 결정적으로 생성 가능 → `thumbnail_url` 컬럼에 저장하되, 없으면 `getYoutubeThumbnail(youtube_id)` 호출로 동적 생성.

---

## 5. 데이터 모델

### 5.1 신규 테이블: youtube_videos (관리자 큐레이션 영상)

```sql
CREATE TABLE IF NOT EXISTS public.youtube_videos (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  youtube_id TEXT NOT NULL UNIQUE,           -- 'dQw4w9WgXcQ' 형태
  youtube_url TEXT NOT NULL,                 -- 원본 전체 URL
  title TEXT NOT NULL,                       -- YouTube에서 추출 또는 관리자 편집
  description TEXT,                          -- 관리자 작성 소개 코멘트 (YouTube 설명과 별도)
  thumbnail_url TEXT,                        -- YouTube 자동 썸네일 (없으면 youtube_id로 생성)
  channel_name TEXT,                         -- 채널명
  duration_seconds INT,                      -- YouTube Data API로 추출
  emotions TEXT[] DEFAULT '{}',              -- 기존 13개 감정 태그 재사용 (관리자 수동 선택)
  view_count INT DEFAULT 0,                  -- 앱/웹 내 조회수 (YouTube 조회수가 아님)
  is_featured BOOLEAN DEFAULT false,         -- 홈 추천 여부
  sort_order INT DEFAULT 0,                  -- 관리자 정렬 (is_featured일 때 사용)
  is_available BOOLEAN DEFAULT true,         -- 영상 유효 여부 (삭제/비공개 감지)
  last_checked_at TIMESTAMPTZ,               -- 마지막 유효성 검사 시각
  created_by UUID NOT NULL REFERENCES auth.users(id), -- 등록 관리자 user_id
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ                     -- 소프트삭제
);
```

### 5.2 posts 테이블 확장 (사용자 게시글 YouTube 임베드)

```sql
ALTER TABLE posts ADD COLUMN IF NOT EXISTS youtube_url TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS youtube_id TEXT;
```

`posts_with_like_count` 뷰는 명시적 컬럼 목록을 사용하므로 뷰 재생성 필요.

### 5.3 영상 리액션 (기존 reactions/user_reactions 패턴 재사용)

```sql
-- 별도 테이블을 사용하는 이유:
-- 기존 reactions 테이블은 post_id에 강결합되어 있고 (UNIQUE(post_id, reaction_type)),
-- toggle_reaction() RPC도 post_id 기반으로 작성됨.
-- 기존 테이블을 확장하면 모든 RPC + RLS + 인덱스 수정 필요 -> 리스크 높음.
-- 별도 테이블로 격리하되, 동일 패턴을 재사용하는 것이 안전.

CREATE TABLE IF NOT EXISTS public.video_reactions (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  video_id BIGINT NOT NULL REFERENCES youtube_videos(id) ON DELETE CASCADE,
  reaction_type TEXT NOT NULL CHECK (reaction_type IN ('like','heart','laugh','sad','surprise')),
  count INT DEFAULT 0 CHECK (count >= 0),
  UNIQUE(video_id, reaction_type)
);

CREATE TABLE IF NOT EXISTS public.user_video_reactions (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL DEFAULT auth.uid(),
  video_id BIGINT NOT NULL REFERENCES youtube_videos(id) ON DELETE CASCADE,
  reaction_type TEXT NOT NULL CHECK (reaction_type IN ('like','heart','laugh','sad','surprise')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, video_id, reaction_type)
);
```

### 5.4 북마크 (영상 저장)

```sql
CREATE TABLE IF NOT EXISTS public.video_bookmarks (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL DEFAULT auth.uid(),
  video_id BIGINT NOT NULL REFERENCES youtube_videos(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, video_id)
);
```

### 5.5 시청 기록 (Phase 2)

```sql
-- Phase 2에서 추가. 사용자 프라이버시를 고려해 삭제 기능 포함.
CREATE TABLE IF NOT EXISTS public.video_watch_history (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL DEFAULT auth.uid(),
  video_id BIGINT NOT NULL REFERENCES youtube_videos(id) ON DELETE CASCADE,
  watched_at TIMESTAMPTZ DEFAULT now(),
  watch_duration_seconds INT DEFAULT 0,
  UNIQUE(user_id, video_id)  -- 영상당 최근 시청 1건만 유지 (UPSERT)
);
```

### 5.6 인덱스

```sql
-- youtube_videos
CREATE INDEX IF NOT EXISTS idx_youtube_videos_emotions
  ON youtube_videos USING GIN(emotions) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_youtube_videos_featured
  ON youtube_videos(is_featured, sort_order) WHERE deleted_at IS NULL AND is_featured = true;
CREATE INDEX IF NOT EXISTS idx_youtube_videos_created_at
  ON youtube_videos(created_at DESC) WHERE deleted_at IS NULL;

-- posts youtube 임베드
CREATE INDEX IF NOT EXISTS idx_posts_youtube_id
  ON posts(youtube_id) WHERE youtube_id IS NOT NULL AND deleted_at IS NULL;

-- 북마크/시청기록 사용자 조회
CREATE INDEX IF NOT EXISTS idx_video_bookmarks_user
  ON video_bookmarks(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_video_watch_history_user
  ON video_watch_history(user_id, watched_at DESC);

-- 리액션 조회
CREATE INDEX IF NOT EXISTS idx_video_reactions_video
  ON video_reactions(video_id);
```

---

## 6. RLS 정책

```sql
-- ===== youtube_videos: 모든 사용자 조회 가능, 관리자만 CUD =====
ALTER TABLE youtube_videos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "youtube_videos_select" ON youtube_videos
  FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "youtube_videos_admin_insert" ON youtube_videos
  FOR INSERT WITH CHECK ((SELECT auth.uid()) IN (SELECT user_id FROM app_admin));
CREATE POLICY "youtube_videos_admin_update" ON youtube_videos
  FOR UPDATE USING ((SELECT auth.uid()) IN (SELECT user_id FROM app_admin));
CREATE POLICY "youtube_videos_admin_delete" ON youtube_videos
  FOR DELETE USING ((SELECT auth.uid()) IN (SELECT user_id FROM app_admin));

-- ===== video_reactions / user_video_reactions: 조회만 허용, 쓰기는 RPC =====
ALTER TABLE video_reactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "video_reactions_select" ON video_reactions FOR SELECT USING (true);

ALTER TABLE user_video_reactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_video_reactions_select" ON user_video_reactions FOR SELECT USING (true);

-- ===== video_bookmarks: 본인 것만 CRUD =====
ALTER TABLE video_bookmarks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "video_bookmarks_own_select" ON video_bookmarks
  FOR SELECT USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "video_bookmarks_own_insert" ON video_bookmarks
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "video_bookmarks_own_delete" ON video_bookmarks
  FOR DELETE USING ((SELECT auth.uid()) = user_id);

-- ===== video_watch_history (Phase 2): 본인 것만 =====
ALTER TABLE video_watch_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "video_watch_history_own_select" ON video_watch_history
  FOR SELECT USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "video_watch_history_own_insert" ON video_watch_history
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "video_watch_history_own_update" ON video_watch_history
  FOR UPDATE USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "video_watch_history_own_delete" ON video_watch_history
  FOR DELETE USING ((SELECT auth.uid()) = user_id);
```

---

## 7. RPC 함수

### 7.1 영상 목록 조회

```sql
CREATE OR REPLACE FUNCTION get_youtube_videos(
  p_emotion TEXT DEFAULT NULL,
  p_featured_only BOOLEAN DEFAULT false,
  p_sort TEXT DEFAULT 'recent',       -- 'recent' | 'popular'
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0
)
RETURNS TABLE(
  id BIGINT, youtube_id TEXT, youtube_url TEXT, title TEXT,
  description TEXT, thumbnail_url TEXT, channel_name TEXT,
  duration_seconds INT, emotions TEXT[], view_count INT,
  is_featured BOOLEAN, created_at TIMESTAMPTZ,
  total_reactions BIGINT, user_bookmarked BOOLEAN
)
```

### 7.2 영상 리액션 토글

```sql
CREATE OR REPLACE FUNCTION toggle_video_reaction(p_video_id BIGINT, p_type TEXT)
RETURNS JSONB  -- { action: 'added' | 'removed' }
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
-- advisory lock: hashtext(user_id || ':video:' || video_id)
-- ':video:' 네임스페이스로 기존 post 리액션과 해시 충돌 방지
-- 기존 toggle_reaction()과 동일한 구조 (post_id -> video_id로 변경)
```

### 7.3 영상 리액션 조회

```sql
CREATE OR REPLACE FUNCTION get_video_reactions(p_video_id BIGINT)
RETURNS TABLE(reaction_type TEXT, count INT, user_reacted BOOLEAN)
-- 기존 get_post_reactions()과 동일 패턴
```

### 7.4 조회수 기록

```sql
CREATE OR REPLACE FUNCTION record_video_view(p_video_id BIGINT)
RETURNS void
-- view_count 증가 (advisory lock 불필요, 근사치 허용)
-- Phase 2: video_watch_history UPSERT 추가
```

### 7.5 북마크 토글

```sql
CREATE OR REPLACE FUNCTION toggle_video_bookmark(p_video_id BIGINT)
RETURNS JSONB  -- { bookmarked: boolean }
-- DELETE 시도 -> FOUND 체크 -> INSERT or 완료
```

### 7.6 내 북마크 목록

```sql
CREATE OR REPLACE FUNCTION get_my_video_bookmarks(p_limit INT DEFAULT 20, p_offset INT DEFAULT 0)
RETURNS TABLE(...)  -- 영상 정보 + bookmarked_at
```

### 7.7 영상 비가용 표시 (관리자 전용)

```sql
CREATE OR REPLACE FUNCTION mark_video_unavailable(p_video_id BIGINT)
RETURNS void
-- 관리자 체크 후 is_available = false, last_checked_at = now()
```

---

## 8. Edge Function: fetch-youtube-metadata

관리자가 영상 등록 시 YouTube 메타데이터를 자동 추출하는 Edge Function.

```
[관리자] YouTube URL 입력
    |
    v
[Edge Function: fetch-youtube-metadata]  (JWT 필요 -- 관리자만)
    |
    +-- 1. YouTube URL에서 video ID 추출 (정규식)
    |
    +-- 2. YouTube Data API v3 호출 (1유닛):
    |     GET https://www.googleapis.com/youtube/v3/videos
    |       ?id={videoId}&part=snippet,contentDetails,statistics
    |       &key={YOUTUBE_API_KEY}
    |
    +-- 3. 메타데이터 추출:
    |     - snippet.title -> title
    |     - snippet.channelTitle -> channel_name
    |     - snippet.thumbnails.high.url -> thumbnail_url
    |     - contentDetails.duration -> parseDuration() -> duration_seconds
    |     - contentDetails.caption -> has_captions (true/false)
    |
    +-- 4. oEmbed 폴백 (API 키 없을 때):
    |     GET https://www.youtube.com/oembed?url={url}&format=json
    |     -> title, author_name만 추출 (duration 없음)
    |
    +-- 5. 응답 반환 -> 관리자가 감정 태그 선택 + 설명 작성 후 DB INSERT
```

**에러 처리:**
- 영상 없음 (삭제/비공개): 404 → "이 영상을 찾을 수 없어요. URL을 확인해주세요."
- 연령 제한 영상: `embeddable=false` → "이 영상은 임베드할 수 없어요."
- API 쿼타 초과: 429 → oEmbed 폴백으로 자동 전환

---

## 9. UI/UX 설계

### 9.1 앱 홈 화면 (RecommendedVideos 섹션 추가)

```
+--------------------------------------------------+
| ScreenHeader (은둔마을 + 검색 + 정렬)               |
+--------------------------------------------------+
| FlashList (스크롤 가능)                             |
|   [ListHeader]                                    |
|    GreetingBanner (compact)                       |
|    EmotionTrend (compact)                         |
|    * RecommendedVideos (가로 스크롤, 최대 5개)     |  <-- 신규 섹션
|       "추천 영상" 헤더 + [더보기 >]                  |
|       [썸네일1][썸네일2][썸네일3]                     |
|    TrendingPosts (compact)                        |
|   [PostCard 1]                                    |
|   [PostCard 2]                                    |
+--------------------------------------------------+
| Tab Bar                                           |
+--------------------------------------------------+
```

RecommendedVideos는 기존 TrendingPosts와 동일 패턴 (가로 스크롤 카드). '더보기' → `/videos` 전체 목록.

### 9.2 홈 추천 영상 카드 (가로 스크롤 -- 컴팩트)

```
+--------------------+
| [썸네일]    >      |  w-40, 16:9 비율
|            5:32    |  우하단 duration 배지
+--------------------+
| 영상 제목 (1줄)    |  text-sm, numberOfLines={1}
| 채널명             |  text-xs, text-gray
+--------------------+
```

### 9.3 영상 전용 페이지 (/videos)

- 앱: `src/app/videos/index.tsx`
- 웹: `src/app/videos/page.tsx`

```
+--------------------------------------------------+
| [<- 뒤로] 추천 영상                                 |
| EmotionFilterBar (기존 컴포넌트 재사용)               |
| 정렬: 최신순 | 인기순                                |
+--------------------------------------------------+
| VideoCard 목록 (앱: FlashList 1열 / 웹: 2열 grid)  |
|   +-------------------------------+               |
|   | [썸네일]              >       | 16:9           |
|   |                      5:32     |               |
|   +-------------------------------+               |
|   | 영상 제목 (max 2줄)           |               |
|   | 채널명 . 조회 42회            |               |
|   | [무기력] [불안]               | 감정 태그      |
|   | heart 5  bookmark             | 리액션+북마크  |
|   +-------------------------------+               |
|                                                   |
| 빈 상태: "아직 추천 영상이 없어요"                    |
+--------------------------------------------------+
```

### 9.4 영상 상세/재생 화면

- 앱: `src/app/videos/[id].tsx`
- 웹: `src/app/videos/[id]/page.tsx`

```
+--------------------------------------------------+
| [YouTube Player -- 인앱 재생]                       |
| 16:9 비율, 전체화면 버튼                              |
+--------------------------------------------------+
| 영상 제목 (text-lg bold)                            |
| 채널명 . 5:32 . 조회 42회                            |
| [무기력] [불안] [슬픔]                                |
+--------------------------------------------------+
| 리액션 바 (기존 ReactionBar 패턴 재사용)               |
| [heart 5] [laugh 2] [sad 1]    [bookmark 저장]     |
+--------------------------------------------------+
| 설명                                               |
| "이 영상은 은둔 생활을 극복한 한 청년의..."              |
+--------------------------------------------------+
| 비슷한 영상 (get_recommended_videos_by_emotion)     |
| [VideoCard] [VideoCard]                            |
+--------------------------------------------------+
```

### 9.5 게시글 YouTube 임베드

**글쓰기 화면:**
- YouTube URL 입력 필드 추가 (선택)
- URL 입력 → 클라이언트에서 `extractYoutubeId()` → 미리보기 썸네일 표시
- 잘못된 URL → "올바른 YouTube URL을 입력해주세요" 안내

**PostCard (목록) -- youtube_id가 있으면:**
```
+-------------------------------+
| 닉네임 . 3시간 전              |
| 게시글 제목                    |
| 본문 미리보기...                |
| +---------------------------+ |
| | [YouTube 미니 썸네일] >    | |  높이 ~160px, 16:9
| +---------------------------+ |
| [무기력] heart 5 comment 3    |
+-------------------------------+
```

**PostDetailView (상세):** youtube_id 있으면 본문 위에 인라인 플레이어 표시.

### 9.6 마이페이지 확장

`/my` 페이지에 섹션 추가:
```
[활동 요약] [감정 캘린더] [* 저장한 영상] [* 시청 기록]
```

- 저장한 영상: VideoCard 목록 + "저장 해제" 스와이프/버튼
- 시청 기록: VideoCard 목록 + 시청일 + "기록 삭제" 옵션

### 9.7 관리자 영상 관리 화면

`/admin/videos` 페이지 (관리자 전용):

```
+--------------------------------------------------+
| [YouTube URL 입력]  [메타데이터 가져오기]              |
+--------------------------------------------------+
| 제목: [자동 채워짐, 편집 가능]                        |
| 채널: [자동 채워짐]  길이: [자동 채워짐]               |
| 관리자 코멘트: [직접 작성]                            |
| 감정 태그: [무기력] [불안] [+추가]                     |
| [v] 홈 추천 영상   정렬 순서: [0]                    |
| [등록]                                              |
+--------------------------------------------------+
| 등록된 영상 목록 (드래그 정렬, 편집, 삭제)               |
+--------------------------------------------------+
```

---

## 10. 에러 처리 및 엣지 케이스

| 상황 | 처리 |
|------|------|
| YouTube 영상 삭제/비공개 전환 | 재생 시 YouTube 플레이어가 에러 표시 → onError 콜백에서 "이 영상을 더 이상 볼 수 없어요" 안내 |
| 썸네일 로드 실패 | onError에서 `getYoutubeThumbnail()` 폴백 → 기본 플레이스홀더 이미지 |
| 연령 제한 영상 | 등록 시 Edge Function에서 embeddable 체크 → 차단 |
| 네트워크 오프라인 | 캐시된 영상 목록 표시 (React Query staleTime), 플레이어 숨김 |
| 중복 URL 등록 | youtube_id UNIQUE 제약 → "이미 등록된 영상이에요" 안내 |
| 잘못된 YouTube URL | 클라이언트 `extractYoutubeId()` 실패 → "올바른 YouTube URL을 입력해주세요" |

---

## 11. 공유 코드 변경 요약

### shared/types.ts 추가

```typescript
export interface YoutubeVideo { ... }     // 유튜브 영상
export interface VideoBookmark { ... }    // 북마크
export interface VideoReaction { ... }    // 영상 리액션 집계
export interface UserVideoReaction { ... } // 사용자별 영상 리액션

// Post 인터페이스에 youtube_url?, youtube_id? 추가
// CreatePostRequest, UpdatePostRequest에 youtube_url? 추가
```

### shared/constants.ts 추가

```typescript
// EMPTY_STATE_MESSAGES에 추가:
videos: { title: '아직 추천 영상이 없어요', description: '곧 은둔·고립에 도움이 되는\n영상을 소개해드릴게요.' }
bookmarks: { title: '저장한 영상이 없어요', description: '마음에 드는 영상을 저장해보세요.\n언제든 다시 볼 수 있어요.' }
```

---

## 12. 구현 단계 (Phase 분리)

### Phase 1: MVP -- DB + 기본 UI

**supabase-hermit:**
- 마이그레이션: `youtube_videos`, `video_reactions`, `user_video_reactions`, `video_bookmarks` 테이블
- posts 테이블에 `youtube_url`, `youtube_id` 컬럼 추가
- RPC: `get_youtube_videos`, `toggle_video_reaction`, `get_video_reactions`, `record_video_view`, `toggle_video_bookmark`, `get_my_video_bookmarks`, `mark_video_unavailable`
- 공유 타입/상수 업데이트

**앱/웹:**
- `react-native-youtube-iframe` / `react-lite-youtube-embed` 설치
- 영상 전용 페이지 (`/videos`, `/videos/[id]`)
- 홈 RecommendedVideos 가로 스크롤 섹션
- 영상 카드 + 인앱 재생 + 리액션 + 북마크
- 유틸리티 함수 (URL 파싱, 썸네일, duration)

### Phase 2: 게시글 임베드 + 시청 기록

**supabase-hermit:**
- `video_watch_history` 테이블
- `get_my_watch_history` RPC
- `clear_my_watch_history` RPC

**앱/웹:**
- 글쓰기 화면 YouTube URL 입력 필드
- PostCard/PostDetailView YouTube 임베드
- 마이페이지 시청 기록 탭

### Phase 3: 고급 기능

- Edge Function `fetch-youtube-metadata` (YouTube Data API v3)
- 관리자 영상 관리 UI (`/admin/videos`)
- 감정 기반 영상 추천 RPC (`get_recommended_videos_by_emotion`)
- 플레이리스트 일괄 임포트
- 시간대별 추천 (밤=힐링, 아침=동기부여)
- 영상 제목/설명 기반 AI 감정 자동 태깅 (기존 Gemini 분석 파이프라인 재사용)
- 영상 댓글 기능

---

## 13. 앱/웹 파일 구조 (참고)

### 앱 (gns-hermit-comm)

```
src/features/videos/
+-- components/
|   +-- VideoCard.tsx          -- 영상 카드
|   +-- VideoPlayer.tsx        -- react-native-youtube-iframe 래퍼
|   +-- RecommendedVideos.tsx  -- 홈 가로 스크롤 섹션
|   +-- VideoList.tsx          -- FlashList 전체 목록
+-- hooks/
|   +-- useVideos.ts           -- React Query 훅
+-- api/
|   +-- videosApi.ts           -- Supabase RPC 호출
+-- utils/
    +-- youtube.ts             -- URL 파싱, 썸네일, duration

src/app/videos/
+-- index.tsx                  -- 전체 목록 페이지
+-- [id].tsx                   -- 영상 상세 + 인앱 재생
```

### 웹 (web-hermit-comm)

```
src/features/videos/
+-- components/
|   +-- VideoCard.tsx          -- 영상 카드
|   +-- VideoPlayer.tsx        -- react-lite-youtube-embed 래퍼
|   +-- RecommendedVideos.tsx  -- 홈 섹션
|   +-- VideoGrid.tsx          -- 2열 그리드
+-- hooks/
|   +-- useVideos.ts           -- React Query 훅
+-- api/
|   +-- videosApi.ts           -- Supabase RPC 호출
+-- utils/
    +-- youtube.ts             -- URL 파싱, 썸네일, duration

src/app/videos/
+-- page.tsx                   -- 전체 목록
+-- [id]/page.tsx              -- 영상 상세
```

---

## 14. 리팩토링 고려사항

### 14.1 리액션 시스템 통합 (향후 리팩토링 후보)

현재 설계는 `video_reactions`/`user_video_reactions`를 별도 테이블로 분리했다. 향후 리액션이 더 많은 콘텐츠 타입에 확장된다면 다형성(polymorphic) 리액션 테이블로 통합 가능:

```sql
-- 현재 (콘텐츠별 분리)
reactions (post_id, reaction_type, count)
video_reactions (video_id, reaction_type, count)

-- 향후 리팩토링 (다형성 통합)
content_reactions (target_type TEXT, target_id BIGINT, reaction_type, count)
-- target_type: 'post' | 'video' | 'comment' | ...
```

**지금 통합하지 않는 이유:**
- 기존 앱/웹 코드의 `toggle_reaction(post_id, type)` 호출부 전부 수정 필요
- RLS 정책이 target_type에 따라 다른 권한 체크 필요 → 복잡도 증가
- 인덱스 효율이 떨어짐 (composite key에 text 타입 추가)
- 현재 콘텐츠 타입이 2개(게시글, 영상)뿐이라 분리 유지가 합리적

### 14.2 기존 컴포넌트 재사용

| 기존 컴포넌트 | 재사용처 | 수정 필요 |
|-------------|---------|----------|
| EmotionFilterBar | 영상 목록 감정 필터 | 없음 (그대로 사용) |
| EmotionTags | 영상 카드/상세 감정 태그 표시 | 없음 |
| ReactionBar | 영상 상세 리액션 | `targetType` prop 추가 |
| SortTabs | 영상 목록 정렬 (최신/인기) | 없음 |
| ScreenHeader | 영상 목록 페이지 헤더 | 없음 |
| TrendingPosts (패턴) | RecommendedVideos 설계 참고 | 새 컴포넌트이나 구조 동일 |

### 14.3 API 레이어 패턴 통일

```typescript
export const videosApi = {
  getVideos: async (params) => supabase.rpc('get_youtube_videos', ...),
  getVideo: async (id) => supabase.from('youtube_videos').select('*').eq('id', id).single(),
  toggleReaction: async (videoId, type) => supabase.rpc('toggle_video_reaction', ...),
  toggleBookmark: async (videoId) => supabase.rpc('toggle_video_bookmark', ...),
  recordView: async (videoId) => supabase.rpc('record_video_view', ...),
}
```

---

## 15. 디자인 시스템

### 15.1 색상 -- 기존 SHARED_PALETTE 활용

| 용도 | 색상 | 이유 |
|------|------|------|
| 영상 카드 배경 | cream-50 (#FFFEF5) | 기존 PostCard와 동일 |
| 재생 버튼 오버레이 | coral-500 (#FF7366) + 반투명 | 눈에 띄는 CTA |
| Duration 배지 배경 | rgba(0,0,0,0.7) + white 텍스트 | YouTube 기본 패턴 |
| 북마크 아이콘 (활성) | happy-500 (#FFC300) | like 리액션 색상 계열 |
| 북마크 아이콘 (비활성) | text-gray-400 | 기존 비활성 아이콘 |
| 감정 태그 | EMOTION_COLOR_MAP 그대로 | 동일 시각화 |

### 15.2 타이포그래피

| 요소 | 앱 (NativeWind) | 웹 (Tailwind) |
|------|----------------|---------------|
| 영상 제목 (카드) | text-sm font-medium | text-sm font-medium |
| 영상 제목 (상세) | text-lg font-bold | text-lg font-bold |
| 채널명 | text-xs text-gray-500 | text-xs text-muted-foreground |
| Duration 배지 | text-xs font-medium text-white | text-xs font-medium text-white |
| 조회수 | text-xs text-gray-400 | text-xs text-muted-foreground |
| 섹션 헤더 | text-base font-bold | text-base font-bold |

### 15.3 모션/애니메이션 -- 기존 MOTION 프리셋 활용

| 인터랙션 | 모션 | 기존 프리셋 |
|---------|------|-----------|
| 썸네일 -> 재생 전환 | fade in (250ms) | MOTION.timing.medium |
| 북마크 토글 | scale bounce | MOTION.spring.bouncy |
| 리액션 애니메이션 | 기존 ReactionBar 그대로 | MOTION.spring.gentle |
| 카드 탭 | scale 0.98 -> 1.0 | MOTION.spring.quick |

### 15.4 반응형 레이아웃 (웹)

```
Mobile (< 640px):   1열 VideoCard 목록
Tablet (640-1024px): 2열 grid (gap-4)
Desktop (> 1024px):  2열 grid + 사이드바 (max-w-2xl 유지)
```

앱은 항상 1열 (FlashList).

### 15.5 접근성

| 요소 | 접근성 처리 |
|------|-----------|
| 썸네일 이미지 | `alt="{영상 제목} 썸네일"` |
| 재생 버튼 | `aria-label="영상 재생"` |
| 북마크 버튼 | `aria-label="영상 저장"` / `"저장 해제"` (상태 반영) |
| Duration 배지 | `aria-label="영상 길이 5분 32초"` |
| YouTube 플레이어 | `title` prop으로 iframe title 설정 |

---

## 16. 성능 최적화

### 16.1 썸네일 로딩 전략: 프로그레시브 로딩

```
1단계: BlurHash 플레이스홀더 즉시 표시 (~50바이트)
2단계: 저품질 썸네일 로드 (~30KB) -> mqdefault.jpg (320x180)
3단계: 고품질 썸네일 로드 (~120KB) -> hqdefault.jpg (480x360) (탭/호버 시)
4단계: 인앱 재생 시에만 플레이어 로드 (~500KB+)
```

### 16.2 플레이어 Lazy Loading

- **앱**: FlashList에서 썸네일만 표시 (WebView 미로드). VideoPlayer는 영상 상세 화면에서만 마운트.
- **웹**: `react-lite-youtube-embed`가 자체 처리 (썸네일 먼저 → 클릭 시 iframe).

### 16.3 React Query 캐싱 전략

```typescript
// 영상 목록: staleTime 5분, gcTime 30분
// 영상 상세: staleTime 10분
// 북마크/리액션 토글: 옵티미스틱 업데이트 + 롤백
```

### 16.4 앱 FlashList 최적화

```typescript
<FlashList
  data={videos}
  renderItem={({ item }) => <VideoCard video={item} />}
  estimatedItemSize={280}
  drawDistance={500}
/>
```

**주의:** FlashList에 WebView(YouTube 플레이어)를 넣지 않음. 목록에서는 썸네일만 표시.

### 16.5 웹 번들 사이즈

| 패키지 | 번들 크기 (gzipped) | 영향 |
|--------|-------------------|------|
| react-lite-youtube-embed | ~5KB | 무시할 수준 |
| 일반 YouTube iframe | 1.3MB/embed | 사용 안 함 |

VideoPlayer는 `dynamic(() => import(...), { ssr: false })`로 분리.

### 16.6 DB 쿼리 최적화

- `get_youtube_videos` RPC는 SECURITY DEFINER로 RLS 오버헤드 회피
- emotions GIN 인덱스로 감정 필터 빠른 검색
- is_featured partial 인덱스로 홈 추천 영상만 빠르게 조회
- view_count 업데이트는 advisory lock 불필요 (근사치 허용)
- 페이지네이션은 LIMIT + OFFSET (데이터 규모가 작으므로 cursor 불필요)

---

## 17. 보안 고려사항

| 항목 | 대응 |
|------|------|
| YouTube API 키 노출 | Supabase Secrets에 저장, Edge Function에서만 사용 |
| XSS (YouTube URL) | `extractYoutubeId()`로 파싱 후 youtube_id만 저장, iframe src에 직접 URL 삽입하지 않음 |
| RLS 우회 | 영상 쓰기는 RPC + SECURITY DEFINER, 관리자 체크는 app_admin 테이블 조회 |
| 부적절 콘텐츠 | 관리자 큐레이션으로 품질 통제 |
| 프라이버시 | youtube-nocookie.com 사용, 시청 기록은 본인만 조회/삭제 가능 |

---

## 18. 주의사항 및 해결 설계

### 18.1 react-native-youtube-iframe 유지보수 리스크

마지막 업데이트 8개월 전. `VideoPlayer.tsx`를 얇은 래퍼(thin wrapper)로 설계하여 내부 구현을 교체해도 외부 API가 변하지 않도록 격리.

**대안:**
- `react-native-youtube-bridge` (백업 옵션)
- `react-native-webview`에 직접 YouTube iframe HTML 삽입 (최후 수단)

### 18.2 WebView 메모리 누수 및 크래시

1. 목록 화면(FlashList)에서는 절대 WebView를 마운트하지 않음 → 썸네일 Image만 표시
2. 영상 상세 화면에서도 플레이어는 1개만
3. 화면 떠날 때(unfocus) 플레이어 정리: `useFocusEffect`에서 `setPlaying(false)`
4. `useRef`로 onMessage 콜백 참조 관리 → BatchedBridge 누수 방지

### 18.3 YouTube 영상 가용성 변경

**방안 1 + 2 병행 (권장):**
- 주기적 유효성 검사: Supabase Cron으로 일 1회 oEmbed 확인 → `is_available` 업데이트
- 실시간 감지: YouTube 플레이어 onError 콜백에서 감지 → `mark_video_unavailable` RPC 호출

### 18.4 YouTube API 쿼타 초과

자동 폴백 체인:
```
YouTube Data API v3 (실패 또는 쿼타 초과)
  -> YouTube oEmbed API (API 키 불필요, duration 없음)
  -> 기본값 사용 (title만 관리자 수동 입력)
```

### 18.5 오프라인/저속 네트워크

- 오프라인: React Query 캐시에서 영상 목록 표시, 플레이어 숨김
- 저속: 썸네일 품질 자동 다운그레이드 (hq → mq → default)
- React Query gcTime 30분 → 오프라인에서도 이전 목록 표시

### 18.6 view_count 정확도 vs 성능

- advisory lock 사용하지 않음 (조회수는 정확도보다 성능 우선)
- Phase 2에서 `video_watch_history` UNIQUE(user_id, video_id)로 중복 방지
- Phase 1에서는 단순 증가 허용

### 18.7 GDPR/프라이버시

- `youtube-nocookie.com` 기본 사용
- 시청 기록 본인만 조회 가능 (RLS)
- "시청 기록 전체 삭제" 기능 제공 (`clear_my_watch_history` RPC)
- 계정 삭제 시 CASCADE로 자동 삭제

### 18.8 홈 화면 과밀

- 조건부 노출: `is_featured` 영상이 1개 이상일 때만 섹션 표시
- 컴팩트 디자인: w-36, 섹션 높이 ~100px 이하
- ListHeader 내 위치로 스크롤 시 자연스럽게 올라감
- 홈에서는 최대 3개만 표시