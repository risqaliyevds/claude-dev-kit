# claude-dev-kit

Personal Claude Code plugin marketplace. The `core` plugin ships skills,
agents, hooks, and project templates, installed at user scope so it is
available in every project.

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest (owner: Murod).
- `plugins/core/` — the plugin:
  - `skills/` — skills (changelog, release, commit, plan, new-project, plus
    background standards: senior-engineer, ai-engineer, fastapi, flutter, nlp,
    evals, announcement, report-verify).
  - `agents/` — code-reviewer, researcher.
  - `hooks/hooks.json` — prettier auto-format (PostToolUse) and the
    `scaffold.sh` auto-bootstrap (SessionStart).
  - `skills/new-project/templates/` — templates shared by the `new-project`
    skill **and** the `scaffold.sh` hook. Edit them in one place.
- `install.sh` — one-time machine setup (adds marketplace, installs `core` +
  Ponytail + UI/UX Pro Max companions).

## Conventions

- No `version` field: every commit to `main` is the new version, so keep
  `main` releasable.
- Keep `CHANGELOG.md` current under `[Unreleased]` after any user-visible
  change (the `changelog` skill knows the format).
- Conventional Commits (`feat:`, `fix:`, `chore:`); use `/core:commit`.
- Shell scripts stay LF (`.gitattributes`). After editing a template or the
  hook, verify `scaffold.sh` still copies it: point `CLAUDE_PLUGIN_ROOT` at
  `plugins/core` and run it inside a throwaway git repo, checking
  create-if-missing and stack gating.
- Run `claude plugin validate .` before pushing (the "no version" warning is
  expected).
- Personalization (`risqaliyevds` / `Murod`) must survive edits — never
  reintroduce the template placeholders into the functional files (`install.sh`,
  `marketplace.json`, `plugin.json`, `new-project/templates/settings.json`).

## Project structure — keep the root clean

Only `README.md`, `AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md`, `install.sh`, and
config/dotfiles belong at the repo root. Put any new working docs or notes in
`docs/`, plans in `docs/plans/`, and throwaway output in `tmp/` (gitignored) —
never scatter generated files across the root. This is the same convention the
kit ships to every project (see the `AGENTS.md` template).
