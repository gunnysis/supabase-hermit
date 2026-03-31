# GEMINI.md — Shared Logic & Types

## Shared Mandates
- **Sync Priority:** Any changes here MUST be followed by `npm run sync` (or `bash ../scripts/sync-to-projects.sh`) to update the App and Web repos.
- **Pure Functions:** `utils.ts` MUST only contain pure functions without external imports.
- **Type Safety:** Business types in `types.ts` should align with `database.gen.ts` but reflect high-level application needs.
- **Single Location for Constants:** All enums, colors, and configuration values used across multiple platforms MUST live in `shared/constants.ts`.

## Rules for Synchronization
- **DO NOT** modify the generated files in the App or Web repos (`*.generated.ts`, `database.types.ts`). Change the source here.
- **Verification:** Always run `bash ../scripts/verify.sh` after a sync to ensure all repositories are in a consistent state.
- **TypeScript Compliance:** Ensure all changes are compatible with the TypeScript version and strictness level of both the App and Web projects.
