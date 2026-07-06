# claude-dev-kit

Personal Claude Code plugin marketplace. The `core` plugin ships skills,
agents, hooks, and project templates, installed at user scope so it is
available in every project.

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest (owner: Murod).
- `plugins/core/` — the plugin:
  - `skills/` — skills (init-dev-kit, new-project, plan, changelog, release,
    commit, announcement, report-verify, docs-sync, plus background standards:
    senior-engineer, ai-engineer, fastapi, flutter, nlp, evals). This list is
    inventory-checked by `tests/test_docs.py` — adding a skill without
    updating it fails the suite.
  - `agents/` — code-reviewer, researcher.
  - `hooks/hooks.json` — prettier auto-format (PostToolUse) and the
    `scaffold.sh` auto-bootstrap (SessionStart).
  - `statusline/` — `statusline.py` (rate-limit/context status line) and
    `setup.sh`, which installs it at user scope (`~/.claude`). Called by both
    `install.sh` and the SessionStart hook, so it self-heals every session.
  - `skills/new-project/templates/` — templates shared by the `new-project`
    skill **and** the `scaffold.sh` hook. Edit them in one place.
- `install.sh` — one-time machine setup (adds marketplace, installs `core` +
  Ponytail + UI/UX Pro Max companions, sets up the status line).
- `tests/` — dependency-free test suite (`sh tests/run.sh`); CI runs it on
  Ubuntu **and** macOS on every push (`.github/workflows/test.yml`), plus a
  weekly `tests/mutants.sh` mutation audit that proves the suite still kills
  known regressions. `tests/test_docs.py` fails the suite when a root doc
  references a repo path that no longer exists.

## Conventions

- No `version` field: every commit to `main` is the new version, so keep
  `main` releasable.
- Keep `CHANGELOG.md` current under `[Unreleased]` after any user-visible
  change (the `changelog` skill knows the format).
- Conventional Commits (`feat:`, `fix:`, `chore:`); use `/core:commit`.
- Shell scripts stay LF (`.gitattributes`).
- Every behavior the kit ships must be covered by `tests/` — scaffold hook,
  statusline setup, bundled scripts. Run `sh tests/run.sh` before pushing; it
  also syntax-checks every shell script, parses every JSON file, and guards
  the personalization. After editing a template, hook, or script, extend or
  fix the matching test in the same commit.
- **Tests are the spec — the code adapts to the tests, never the reverse.**
  Assertions pin desired behavior (the contract), not whatever the code
  happens to do today. When behavior changes intentionally, update the test
  to state the new contract first, then change code until it passes. A red
  test means fix the code; never weaken, delete, or skip a test to get green
  — the only valid reason to change a test is that the requirement itself
  changed. Bug protocol: reproduce with a failing test that asserts the
  CORRECT behavior → fix the code → the now-green test stays forever as the
  regression guard.
- **Docs are code.** A change that renames, removes, or alters behavior
  updates every doc that mentions it in the same commit — or deletes the
  passage. A stale doc is a bug, and deleting outdated text beats keeping it.
  `tests/test_docs.py` catches dead path references mechanically;
  `/core:docs-sync` does the semantic sweep (claims vs. actual behavior).
- Run `claude plugin validate .` before pushing (the "no version" warning is
  expected; CI also runs it headlessly).
- Personalization (`risqaliyevds` / `Murod`) must survive edits — never
  reintroduce the template placeholders into the functional files (`install.sh`,
  `marketplace.json`, `plugin.json`, `new-project/templates/settings.json`).

## Project structure — keep the root clean

Only `README.md`, `AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md`, `install.sh`, and
config/dotfiles belong at the repo root. Put any new working docs or notes in
`docs/`, plans in `docs/plans/`, and throwaway output in `tmp/` (gitignored) —
never scatter generated files across the root. This is the same convention the
kit ships to every project (see the `AGENTS.md` template).
