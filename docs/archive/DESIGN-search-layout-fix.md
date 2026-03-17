# 검색 페이지 레이아웃 개선 설계

## 문제

### 앱 (search.tsx)
1. **감정 칩 가로 ScrollView가 항상 표시됨** (line 201-236) — `showInitial` 상태에서도 보임
2. **초기 화면에 "감정으로 찾기" 그리드가 별도 존재** (line 352-373) — 기능 중복
3. **검색바 → 감정칩(항상 표시) → 빈 공간 → 최근 검색어** 순서로 과도한 빈 공간 발생
4. 감정 칩이 초기 화면 중앙부에 떠있는 비정상 배치

### 웹 (SearchView.tsx)
1. 동일한 구조적 문제 — 감정 칩이 항상 표시 + 초기 화면에 감정 그리드 중복
2. 웹은 공간 여유가 있어 시각적 문제가 덜하지만, 동일한 UX 개선 적용 필요

## 해결 방안

### 핵심 원칙
- **초기 화면(showInitial)**: 감정 칩 가로 ScrollView 숨김 → 최근 검색어 + 감정 그리드만 표시
- **활성 필터 상태**: 감정 칩 가로 ScrollView 표시 + 정렬/필터 바 표시

### 앱 변경 (src/app/search.tsx)

**Before:**
```
View flex-1
├── Header (검색바) — 항상 표시
├── 감정 칩 가로 ScrollView — 항상 표시 ← 문제
├── 정렬/필터 바 (hasActiveFilter)
└── 콘텐츠
    ├── [초기] ScrollView: 최근 검색어 + 감정으로 찾기 ← 중복
    └── [활성] 검색 결과/감정 결과/로딩/에러/빈 상태
```

**After:**
```
View flex-1
├── Header (검색바) — 항상 표시
├── [hasActiveFilter만] 감정 칩 가로 ScrollView ← 조건부
├── [hasActiveFilter만] 정렬/필터 바
└── 콘텐츠
    ├── [초기] ScrollView: 최근 검색어 + 감정으로 찾기
    └── [활성] 검색 결과/감정 결과/로딩/에러/빈 상태
```

**구체적 변경:**
1. 감정 칩 ScrollView를 `{hasActiveFilter && (...)}` 조건으로 감싸기
2. 초기 화면의 "감정으로 찾기" 그리드는 유지 (진입점 역할)
3. 감정 칩 ScrollView에 `style={{ flexGrow: 0, flexShrink: 0 }}` 추가 (활성 시 공간 안정성)

### 웹 변경 (src/features/posts/components/SearchView.tsx)

동일한 패턴 적용:
1. 감정 칩 `<div className="flex gap-1.5 overflow-x-auto ...">` 를 `hasActiveFilter` 조건으로 감싸기
2. 초기 화면의 "감정으로 찾기" 그리드 유지

## 영향 범위

| 파일 | 변경 내용 |
|---|---|
| 앱 `src/app/search.tsx` | 감정 칩 ScrollView 조건부 렌더링 |
| 웹 `SearchView.tsx` | 감정 칩 div 조건부 렌더링 |

- 중앙 레포 변경: 없음 (순수 UI 레이아웃 변경)
- shared/ 변경: 없음
- DB 변경: 없음

## 검증 체크리스트

- [ ] 앱: 초기 화면에서 검색바 바로 아래 최근 검색어 표시 (빈 공간 없음)
- [ ] 앱: 감정 칩 선택 시 가로 ScrollView 나타남 (선택된 칩 하이라이트)
- [ ] 앱: 텍스트 검색 시 감정 칩 + 정렬 바 표시
- [ ] 앱: 필터 해제 시 초기 화면으로 복귀 (감정 칩 숨김)
- [ ] 웹: 동일한 동작 검증
- [ ] 앱/웹: 초기 화면 "감정으로 찾기" 클릭 → 감정 필터 활성 + 가로 칩 표시
