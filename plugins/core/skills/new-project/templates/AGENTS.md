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

- Keep `CHANGELOG.md` current: after any user-visible feature, fix, or change,
  add an entry under `[Unreleased]`.
- Commits follow Conventional Commits (`feat: ...`, `fix: ...`).
- Never read, print, or commit `.env` files or other secrets.
- Prefer small, focused changes; run tests before declaring work done.
- Docs are code: update or delete every doc that mentions a behavior you
  change, in the same commit. A stale doc is a bug — delete outdated docs
  rather than letting them mislead. Archive finished plans out of
  `docs/plans/` so the active plan files only describe live work
  (`/core:docs-sync` audits and fixes doc drift on demand).
- Tests are the spec — the code adapts to the tests, never the reverse.
  Assert desired behavior (the contract), not what the implementation happens
  to do. If a behavior change is intentional, update the test first, then
  make the code pass; never weaken, delete, or skip a failing test to get
  green. Fix bugs test-first: add a failing test for the correct behavior,
  fix the code until it passes, and keep the test as the regression guard.
- Active plan and task list live in `docs/plans/PLAN.md` and
  `docs/plans/TASKS.md` — read them before starting and keep `TASKS.md` checked
  off as you go.

## Project structure — where generated files go

Keep the repo root clean. **Only** these belong at the root: `README.md`,
`AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md`, and tool-mandated config/dotfiles
(`package.json`, `pyproject.toml`, `.gitignore`, `.env.example`, etc.).
Everything you generate goes in a dedicated folder — create it on first use:

| Artifact | Folder |
|---|---|
| Docs, notes, design write-ups (`*.md`) | `docs/` |
| Architecture decisions | `docs/adr/` |
| Plans & task checklists | `docs/plans/` (`PLAN.md`, `TASKS.md`) |
| Screenshots / captured images | `screenshots/` |
| Datasets / sample data | `datasets/` |
| One-off / helper scripts | `scripts/` |
| Throwaway scratch output, reports | `tmp/` (gitignored) |

Never write a generated doc, screenshot, dataset, or scratch file to the repo
root. If a skill or tool would drop one in the root, redirect it to the folder
above. (Large datasets usually shouldn't be committed — gitignore `datasets/`
if so.)

Two kinds of files stay at the root but must be gitignored, never moved:
**secrets** (`.env`, `.env.*` except `.env.example`, keys, cookies — the app
reads them in place) and **local tooling artifacts** (`ruvector.db`, `*.rvf`,
`agentdb.*` — tools recreate them there). If a secret is ever committed, untrack
it with `git rm --cached` — do not delete the working file.
