# 글 작성 경험 개선 설계

> 작성일: 2026-03-28 | 상태: Phase 1~3 구현 완료

---

## 연구 방법

3개 레포(중앙/앱/웹) 30개+ 파일을 분석하여 사용자가 글을 쓰는 전체 여정을 추적:
- **진입 전**: FAB/헤더/하단바 → 글쓰기 화면 진입 경로
- **작성 중**: 에디터 기능, 임시저장, 유효성 검증, UX 피드백
- **제출 시**: API 호출, 로딩 상태, 에러 처리, 이중 제출 방지
- **제출 후**: 이동 경로, 감정 분석 타이밍, 내 글 확인

외부 연구:
- Tiptap/TenTap 확장 생태계
- 블라인드/에브리타임 등 한국 커뮤니티 앱 UX 패턴
- beforeunload 모바일 제약사항
- Progressive disclosure, friction reduction 패턴

---

## 구현 완료

### Phase 1 — 임시저장 + 저장 상태 (C+D)
- 웹 useDraft 훅 (localStorage, 1초 debounce)
- 앱/웹 저장 상태 표시 ("☁️ 저장됨" / "✏️ 저장 중...")

### Phase 2 — 에디터 기능
- 웹: 밑줄(Underline), 링크(Link), 텍스트 정렬(TextAlign) 3개 Tiptap 확장
- 웹: 정렬 SVG 아이콘, 링크 SVG + 인라인 URL 입력 바
- 웹: 읽기 시간 표시 ("약 N분 읽기")
- 앱: 글자수 카운트 HTML→텍스트 기반 수정
- 앱: maxHeight 400→600px, 프로그레스 바, 읽기 시간
- 앱/웹: 제목 글자 수 카운터 (00/100, 90자 경고)

### Phase 3 — 여정 전반 개선
- 웹: 모바일 create 페이지 pb-24 (제출 버튼 BottomNav 가림 수정)
- 웹: beforeunload 경고 (작성+수정 폼, 내용 있을 때만)
- 앱: 작성 후 홈 대신 게시글 상세로 이동 (내 글 바로 확인)
- 앱/웹: 에러 메시지 네트워크 vs 서버 구분

---

## 제거된 안
- A안 (감정 먼저 선택 + initial_emotions) — 사용자 요청으로 제거
- B안 (글감 프롬프트 65개) — A안 의존으로 함께 제거

---

## 향후 고려 (미구현)

| 항목 | 설명 | 비용 |
|------|------|------|
| 앱 커스텀 도구 모음 | TenTap에 Link/Underline/TextAlign 커스텀 버튼 추가 | 중 |
| 미리보기 | 게시 전 PostCard 형태로 최종 모습 확인 | 중 |
| AI 글감 프롬프트 | Gemini Flash로 개인화 글감 생성 | 중 |
| 앱 이탈 경고 | BackHandler로 뒤로가기 시 확인 대화상자 | 소 |
| 도구 모음 축소 모드 | 모바일에서 도구 모음을 접기/펼치기 | 소 |

---

## 참고 자료
- beforeunload MDN: https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeunload_event
- Tiptap Link Extension: https://tiptap.dev/docs/editor/extensions/marks/link
- Tiptap TextAlign: https://tiptap.dev/docs/editor/extensions/functionality/textalign
- Progressive Disclosure (NNGroup): https://www.nngroup.com/articles/progressive-disclosure/
