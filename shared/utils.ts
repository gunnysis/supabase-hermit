// 은둔마을 공유 순수 유틸 함수 — 중앙 프로젝트에서 생성, sync-to-projects.sh로 앱/웹에 배포
// 수정 시 반드시 이 파일에서만 수정하고 sync 실행할 것
// 주의: 외부 import 없는 순수 함수만 추가할 것 (sync 후 빌드 안전성)

/** 게시글 입력 검증 — 유효하면 null, 에러 시 메시지 반환 */
export function validatePostInput(input: {
  title?: string
  content: string
}): string | null {
  const content = input.content.trim()
  if (!content) return '내용을 입력해주세요.'
  if (content.length > 5_000) return '내용은 5,000자 이내로 입력해주세요.'

  if (input.title !== undefined) {
    const title = input.title.trim()
    if (title.length > 100) return '제목은 100자 이내로 입력해주세요.'
  }

  return null
}

/** 오늘의 하루 입력 검증 — 유효하면 null, 에러 시 메시지 반환 */
export function validateDailyPostInput(input: {
  emotions: string[]
  activities?: string[]
  content?: string
}): string | null {
  if (!input.emotions.length) return '감정을 하나 이상 선택해주세요.'
  if (input.emotions.length > 3) return '감정은 최대 3개까지 선택할 수 있어요.'
  if (input.activities && input.activities.length > 5) return '활동은 최대 5개까지 선택할 수 있어요.'
  if (input.content && input.content.length > 200) return '한마디는 200자 이내로 입력해주세요.'
  return null
}

/** 댓글 입력 검증 — 유효하면 null, 에러 시 메시지 반환 */
export function validateCommentInput(content: string): string | null {
  const trimmed = content.trim()
  if (!trimmed) return '댓글을 입력해주세요.'
  if (trimmed.length > 1_000) return '댓글은 1,000자 이내로 입력해주세요.'
  return null
}

/** 감정 타임라인 바 데이터 가공 (단일 패스) */
export interface TimelineBarSegment {
  emotion: string
  count: number
  pct: number
}

export interface TimelineBar {
  day: string
  weekday: string
  isToday: boolean
  segments: TimelineBarSegment[]
  total: number
}

export interface ProcessedTimeline {
  bars: TimelineBar[]
  topEmotions: string[]
  maxTotal: number
  topEmotion: string | null
}

const KO_WEEKDAYS = ['일', '월', '화', '수', '목', '금', '토'] as const

export function processEmotionTimeline(
  entries: { day: string; emotion: string; cnt: number }[],
): ProcessedTimeline {
  if (!entries.length) return { bars: [], topEmotions: [], maxTotal: 0, topEmotion: null }

  // Single pass: group by day + accumulate emotion totals
  const byDay = new Map<string, Map<string, number>>()
  const emotionTotals = new Map<string, number>()

  for (const entry of entries) {
    const cnt = Number(entry.cnt)
    if (!byDay.has(entry.day)) byDay.set(entry.day, new Map())
    byDay.get(entry.day)!.set(entry.emotion, cnt)
    emotionTotals.set(entry.emotion, (emotionTotals.get(entry.emotion) ?? 0) + cnt)
  }

  // Top 5 emotions by total
  const topEmotions = [...emotionTotals.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([e]) => e)

  // Today (KST)
  const now = new Date()
  const kstMs = now.getTime() + 9 * 60 * 60 * 1000
  const todayStr = new Date(kstMs).toISOString().slice(0, 10)

  // Build bars sorted by date
  const sortedDays = [...byDay.keys()].sort()
  let maxTotal = 0

  const bars: TimelineBar[] = sortedDays.map((day) => {
    const dayMap = byDay.get(day)!
    const segments: TimelineBarSegment[] = []
    let total = 0

    for (const emotion of topEmotions) {
      const count = dayMap.get(emotion) ?? 0
      if (count > 0) {
        segments.push({ emotion, count, pct: 0 })
        total += count
      }
    }

    // Calculate percentages
    for (const seg of segments) {
      seg.pct = total > 0 ? Math.round((seg.count / total) * 100) : 0
    }

    if (total > maxTotal) maxTotal = total

    const date = new Date(day + 'T00:00:00')
    return {
      day,
      weekday: KO_WEEKDAYS[date.getDay()],
      isToday: day === todayStr,
      segments,
      total,
    }
  })

  return {
    bars,
    topEmotions,
    maxTotal: Math.max(maxTotal, 1),
    topEmotion: topEmotions[0] ?? null,
  }
}

/** 현재 KST 날짜 (year, month) 반환 — 서버 KST 로직과 동일 기준 */
export function getCurrentKST(): { year: number; month: number; date: number } {
  const now = new Date()
  const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000)
  return { year: kst.getUTCFullYear(), month: kst.getUTCMonth() + 1, date: kst.getUTCDate() }
}

/** 활동 ID → 아이콘 + 이름 라벨 변환 (외부 import 없는 순수 함수) */
export function getActivityLabel(
  id: string,
  presets: readonly { id: string; icon: string; name: string }[]
): string {
  const preset = presets.find((p) => p.id === id)
  return preset ? `${preset.icon} ${preset.name}` : id
}

