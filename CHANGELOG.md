# Changelog

All notable changes to this project are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This repo has no
`version` field on purpose — every commit to `main` is the current version.

## [Unreleased]

### Added
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
- `scaffold.sh` now skips plugin/marketplace repos (those with
  `.claude-plugin/marketplace.json` or `.claude-plugin/plugin.json`), so the
  kit no longer scaffolds app-project files into itself.
- Dogfooding: the kit's own repo now has the `.editorconfig` it ships as a
  required file (previously missing).

### Changed
- Personalized marketplace/plugin metadata and install references
  (`risqaliyevds` / `Murod`).
- Marketplace description and README command table now list the new skills.
