# Changelog

All notable changes to this project are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This repo has no
`version` field on purpose — every commit to `main` is the current version.

## [Unreleased]

### Added
- `/core:docs-sync` skill + "docs are code" convention (kit `AGENTS.md`,
  shipped `AGENTS.md` template, `senior-engineer` skill, and a new docs
  freshness sweep step in `/core:init-dev-kit`): stale docs are bugs — update
  or delete them in the same commit as the behavior change; finished plans get
  archived out of `docs/plans/`. `tests/test_docs.py` mechanically fails the
  suite when a root doc references a repo path that no longer exists.
- Test hardening round two: shellcheck runs in the suite when installed
  (always in CI), CI matrix now covers Ubuntu **and** macOS, `claude plugin
  validate` runs headlessly in CI, a golden contract test renders the
  documented example statusline payload into an exact expected line, and the
  mutation audit is automated as `tests/mutants.sh` (8-mutant catalog, all
  killed; CI re-runs it weekly).
- Status line polish: `refreshInterval: 60` keeps reset countdowns live while
  idle; `setup.sh` now upgrades a statusLine it recognizes as its own (kit
  updates reach wired machines) while still never touching a custom one;
  context tokens prefer the documented `total_input_tokens`/
  `total_output_tokens` fields (v2.1.132+) with `current_usage` fallback.
- Status line: `plugins/core/statusline/statusline.py` (model + context % +
  5-hour/weekly rate-limit bars with reset countdowns) and `setup.sh`, which
  installs it at user scope (`~/.claude`). Wired into `install.sh` and the
  SessionStart scaffold hook, so both install and any session fully set up the
  status bar; existing `statusLine` settings are never overwritten, and the
  script re-syncs automatically after kit updates.
- Tests-as-spec convention (kit `AGENTS.md`, the shipped `AGENTS.md` template,
  and the `senior-engineer` skill): assertions pin desired behavior, the code
  adapts to the tests — never the reverse; intentional behavior changes update
  the test first; bugs are fixed with a failing test for the correct behavior,
  never by weakening or skipping a test.
- Test suite (`tests/`, run with `sh tests/run.sh`) + GitHub Actions CI: the
  scaffold hook is exercised in throwaway git repos (create-if-missing,
  never-overwrite, stack gating, plugin-repo skip — automating the old manual
  check), statusline setup in a sandboxed `$HOME` (idempotency, respects an
  existing statusLine, never clobbers unparseable settings), unit/E2E tests
  for the statusline renderer and `extract_links.py`, plus JSON-validity,
  shell-syntax, and personalization guards. No dependencies beyond
  git/sh/python3 (jq recommended). Assertions pin exact user-visible
  contracts (template content, gauge width/proportion, ANSI palette,
  stack-gating absence, domain-count semantics) — hardened via a mutation
  audit in which every surviving mutant became a stronger assertion.
- `/core:init-dev-kit` skill — onboards an existing repo: pulls the latest kit,
  scaffolds every missing standard file, runs a full **root triage** that
  classifies every loose file (docs, scratch/reports, secrets, tooling
  artifacts) and proposes the right action per category, then formats
  (web via prettier, Python via ruff/black). Safe by design: one consolidated
  plan, confirm before any move/delete/untrack/reformat, never touches source or
  tool-mandated config, and untracks committed secrets with `git rm --cached`
  rather than deleting them.
- gitignore template now ignores local tooling artifacts (`ruvector.db`,
  `agentdb.*`, `*.rvf`, `*.rvf.lock`) and `*.bak`.
- `announcement`, `report-verify`, `nlp`, and `evals` skills (`report-verify`
  bundles `scripts/extract_links.py`).
- `AGENTS.md` template and scaffold entry — shared tool-agnostic context, with
  `CLAUDE.md` reduced to a thin layer that imports it (`@AGENTS.md`). The kit's
  own repo was migrated to this pattern too.
- `/core:plan` now persists the plan and checklist to `docs/plans/PLAN.md` and
  `docs/plans/TASKS.md` so planning survives `/clear` and new sessions.
- "Project structure" convention in the `AGENTS.md` template (and the kit's own
  `AGENTS.md`): only `README`/`AGENTS`/`CLAUDE`/`CHANGELOG` + configs stay at the
  root; docs → `docs/`, plans → `docs/plans/`, screenshots → `screenshots/`,
  datasets → `datasets/`, scripts → `scripts/`, scratch → `tmp/` (gitignored).
- `SessionStart` hook (`plugins/core/hooks/scaffold.sh`) that force-creates the
  standard project files in any git repo — create-if-missing, idempotent, and
  gated to a git work tree.
- Scaffold/`new-project` templates: `README.md`, `.editorconfig`,
  `.gitattributes`, `.env.example`, plus stack-gated `.nvmrc` (Node) and
  `.python-version` (Python).
- Root `.gitattributes` pinning `*.sh` to LF so hook scripts stay runnable on
  Windows/autocrlf checkouts.

### Fixed
- Doc-vs-code audit fallout (all four caught by the new docs-are-code sweep):
  `setup.sh` treated a present-but-command-less custom statusLine (static or
  string-shaped) as absent and overwrote it every session — now any present
  statusLine that is not ours is untouched, pinned by tests; `docs-sync` was
  documented "manual only" but missed `disable-model-invocation: true`; the
  kit `AGENTS.md` skills inventory listed 13 of 15 shipped skills (now
  inventory-checked by `tests/test_docs.py`); CI claimed shellcheck on both
  runners while macOS images don't ship it — the macOS leg now installs it
  via brew so shellcheck truly always runs in CI.
- README scaffold list was stale: it omitted `AGENTS.md`, which the hook has
  scaffolded since the AGENTS.md standard landed (caught by the new docs
  conventions; the component table also gained the missing scaffold-hook and
  docs-sync rows).
- `scaffold.sh` now skips plugin/marketplace repos (those with
  `.claude-plugin/marketplace.json` or `.claude-plugin/plugin.json`), so the
  kit no longer scaffolds app-project files into itself.
- Dogfooding: the kit's own repo now has the `.editorconfig` it ships as a
  required file (previously missing).

### Changed
- Personalized marketplace/plugin metadata and install references
  (`risqaliyevds` / `Murod`).
- Marketplace description and README command table now list the new skills.
