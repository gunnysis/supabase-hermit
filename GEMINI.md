# GEMINI.md — Operational Directives

This document defines the operational mandates and workflows for Gemini CLI within the `supabase-hermit` workspace. These instructions take absolute precedence over general defaults.

## Core Mandates
- **Single Source of Truth:** This repository is the authoritative source for the Supabase schema. All DB changes MUST happen here via migrations in `supabase/migrations/`.
- **Validation is Finality:** No task is complete without verification. Use `scripts/db.sh lint`, `scripts/verify.sh`, and project-specific tests.
- **Surgical Execution:** Apply precise changes. Avoid unrelated refactoring.
- **Documentation Parity:** Update `CLAUDE.md`, `SCHEMA.md`, and relevant audit files (`docs/audit/`) immediately after any structural or functional change.

## Development Workflow: Research -> Strategy -> Execution
For every directive, follow this lifecycle:

1.  **Research:** Use `grep_search` and `glob` to map dependencies. Read `CLAUDE.md` and `docs/audit/` to understand the current state.
2.  **Strategy:** Present a concise implementation plan.
3.  **Execution (Iterative Plan -> Act -> Validate):**
    - **Plan:** Define the specific change and verification steps.
    - **Act:** Apply changes (e.g., create migration, update shared constants).
    - **Validate:** Run `npm run push` (which triggers `lint` -> `gen-types` -> `sync` -> `verify`) to ensure cross-repo consistency.

## Project-Specific Rules
- **Migrations:** Use `YYYYMMDDHHMMSS_description.sql` format. Ensure idempotency (`IF NOT EXISTS`, `OR REPLACE`).
- **Shared Code:** Modifications to `shared/` must be followed by `npm run sync` to propagate changes to App and Web repositories.
- **RPC Documentation:** Every new or modified RPC MUST include a `COMMENT ON FUNCTION` for automated documentation.
- **Needs & Communication:** Use `needs.md` to request user input or credentials. Do not proceed with ambiguous tasks without clarification.
- **Tone:** Professional, direct, and concise. Minimize conversational filler.

## Tooling & Commands
- **Database:** `bash scripts/db.sh [push|pull|lint|status|gen-types]`
- **Sync:** `bash scripts/sync-to-projects.sh`
- **Verification:** `bash scripts/verify.sh`
- **Full Cycle:** `npm run push` (Recommended after migrations)

## Reference Context
- **Project Ref:** `qwrjebpsjjdxhhhllqcw`
- **App Path:** `/mnt/c/Users/Administrator/programming/apps/gns-hermit-comm`
- **Web Path:** `/home/gunny/apps/web-hermit-comm`
