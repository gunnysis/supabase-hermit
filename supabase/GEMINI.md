# GEMINI.md — Database Operations

## Database Mandates
- **Migration Ownership:** This directory is the ONLY place where schema changes are initiated.
- **RLS by Default:** Every new table MUST have Row Level Security enabled and appropriate policies defined in a migration.
- **Idempotency:** All SQL in `migrations/` MUST be idempotent to prevent execution errors during sync.
- **Search Path Security:** Always specify `search_path` in functions to prevent security vulnerabilities.

## Workflow
1.  **Generate:** Create a new migration file: `touch migrations/$(date +%Y%m%d%H%M%S)_description.sql`.
2.  **Author:** Write SQL with `COMMENT ON FUNCTION` for all RPCs.
3.  **Lint:** Run `bash ../scripts/db.sh lint` to check for RLS and schema issues.
4.  **Dry Run:** Run `bash ../scripts/db.sh push --dry-run` to verify against the remote state.
5.  **Deploy:** Run `bash ../scripts/db.sh push` to apply changes and trigger the sync/verification cycle.

## Constraints
- **Soft Delete:** Use `deleted_at` (timestamptz) for `posts` and `comments`. DO NOT use hard `DELETE` unless in `admin_cleanup` functions.
- **Timezone:** Use `timestamptz` and ensure KST (UTC+9) considerations for daily posts and streaks as defined in `shared/constants.ts`.
- **Naming:** Follow existing snake_case convention for all DB objects.
