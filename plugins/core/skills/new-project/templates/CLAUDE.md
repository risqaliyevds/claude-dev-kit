# {{PROJECT_NAME}} — Claude Code

Shared, tool-agnostic project context lives in `AGENTS.md` (imported below) so
every agent tool reads one source of truth. Keep stack, commands, and
conventions there; keep only Claude-specific guidance in this file.

@AGENTS.md

## Notes for Claude

- Use `/core:commit` for commits and the changelog skill to keep `CHANGELOG.md`
  current after user-visible changes.
- Use `/core:plan` for non-trivial work; it persists the plan to
  `docs/plans/PLAN.md` and a checklist to `docs/plans/TASKS.md`.
- Keep the repo root clean — generated files go in their folders per the
  "Project structure" section of `AGENTS.md`, never the root.
- If a request is ambiguous, ask before writing large amounts of code.
- When finishing a task, state what changed and what you did NOT do.
