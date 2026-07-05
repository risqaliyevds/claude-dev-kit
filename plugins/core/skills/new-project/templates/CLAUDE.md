# {{PROJECT_NAME}}

{{ONE_LINE_DESCRIPTION}}

## Stack

{{STACK}}

## Commands

- Dev server: `{{DEV_COMMAND}}`
- Tests: `{{TEST_COMMAND}}`
- Lint: `{{LINT_COMMAND}}`
- Build: `{{BUILD_COMMAND}}`

## Conventions

- Keep `CHANGELOG.md` current: after completing any user-visible feature, fix, or change, add an entry under `[Unreleased]` (the changelog skill knows the format).
- Commits follow Conventional Commits (`feat: ...`, `fix: ...`); use `/core:commit`.
- Never read, print, or commit `.env` files or other secrets.
- Prefer small, focused changes; run tests before declaring work done.

## Notes for Claude

- If a request is ambiguous, ask before writing large amounts of code.
- When finishing a task, state what changed and what you did NOT do.
