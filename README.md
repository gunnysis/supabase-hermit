# supabase-hermit

은둔마을 앱/웹이 공유하는 **Supabase DB 스키마의 단일 정본(Single Source of Truth)**.

## 구조

```
supabase-hermit/
├── supabase/migrations/    # 모든 마이그레이션 원본 (22개)
├── shared/                 # 앱/웹 공유 코드
│   ├── constants.ts        # 공유 상수
│   ├── types.ts            # 공유 비즈니스 타입
│   └── utils.ts            # 공유 순수 함수
├── types/database.gen.ts   # 자동 생성 DB 타입
├── scripts/                # 자동화 스크립트
│   ├── db.sh               # Supabase CLI 래퍼
│   ├── gen-types.sh        # 타입 생성
│   └── sync-to-projects.sh # 앱/웹 동기화
└── docs/                   # 상세 문서
```

## 사용법

```bash
# 마이그레이션 적용 (자동: gen-types → sync → verify)
npm run push

# dry-run
npm run push:dry

# 타입 재생성 + 동기화
npm run gen-types && npm run sync

# 정합성 검증
npm run verify
```

## 동기화

`sync-to-projects.sh`가 다음 파일을 앱/웹 레포에 자동 복사합니다:

| 소스 | 앱 | 웹 |
|---|---|---|
| `supabase/migrations/` | `supabase/migrations/` | `supabase/migrations/` |
| `supabase/config.toml` | `supabase/config.toml` | `supabase/config.toml` |
| `types/database.gen.ts` | `src/types/database.gen.ts` | `src/types/database.gen.ts` |
| `shared/constants.ts` | `src/shared/lib/constants.generated.ts` | `src/lib/constants.generated.ts` |
| `shared/types.ts` | `src/types/database.types.ts` | `src/types/database.types.ts` |
| `shared/utils.ts` | `src/shared/lib/utils.generated.ts` | `src/lib/utils.generated.ts` |

## 규칙

- **마이그레이션은 여기서만 생성** — 앱/웹의 `supabase/migrations/`는 읽기 전용 복사본
- **공유 코드는 `shared/`에서만 수정** — 앱/웹의 generated 파일 직접 수정 금지
- **멱등 마이그레이션** — `IF NOT EXISTS`, `CREATE OR REPLACE`, `DROP ... IF EXISTS` 패턴

## 문서

- [DB 스키마 상세](docs/SCHEMA.md)
- [스크립트 사용법](docs/SCRIPTS.md)
- [클라이언트 아키텍처](docs/CLIENT-ARCHITECTURE.md)
