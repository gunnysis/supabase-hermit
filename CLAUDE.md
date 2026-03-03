# CLAUDE.md — 은둔마을 Supabase 중앙 프로젝트

이 프로젝트는 은둔마을 앱/웹이 공유하는 **Supabase DB 스키마의 단일 정본(Single Source of Truth)**.

## 구조

```
supabase-hermit/
├── supabase/
│   ├── config.toml        # Supabase 프로젝트 설정
│   └── migrations/        # 모든 마이그레이션 원본
├── scripts/
│   ├── db.sh              # Supabase CLI 래퍼 (push/pull/diff/lint/status)
│   └── sync-to-projects.sh  # 앱/웹 레포로 migration 동기화
├── .env                   # SUPABASE_ACCESS_TOKEN (git 제외)
└── CLAUDE.md
```

## 워크플로

### 1. 새 마이그레이션 작성
이 디렉터리에서만 작성. 앱/웹 레포에서 직접 만들지 않음.

```bash
# 새 SQL 파일 생성
vi supabase/migrations/20260303000003_description.sql

# dry-run 확인
bash scripts/db.sh push --dry-run

# 적용
bash scripts/db.sh push

# 앱/웹 동기화
bash scripts/sync-to-projects.sh
```

### 2. Remote 변경 사항 가져오기 (Dashboard에서 수정한 경우)
```bash
bash scripts/db.sh pull
```

### 3. 상태 확인
```bash
bash scripts/db.sh status   # 로컬/remote 비교
bash scripts/db.sh lint      # RLS/스키마 린트
```

## 규칙

- **마이그레이션은 여기서만 생성** — 앱/웹 레포의 `supabase/migrations/`는 읽기 전용 복사본
- **push 후 반드시 sync** — `sync-to-projects.sh`로 양쪽 동기화
- **Edge Functions는 앱 레포** — `supabase/functions/`는 앱에서 관리/배포
- **RLS에서 자기참조 금지** — `group_members` 정책에서 `group_members` 직접 SELECT 하면 무한 재귀. `SECURITY DEFINER` 함수 사용

## 연결 정보

- Project ref: `qwrjebpsjjdxhhhllqcw`
- 앱 레포: `/mnt/c/Users/Administrator/programming/apps/gns-hermit-comm`
- 웹 레포: `/home/gunny/apps/web`
