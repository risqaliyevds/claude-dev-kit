# Changelog

All notable changes to this project are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This repo has no
`version` field on purpose — every commit to `main` is the current version.

## [Unreleased]

### Added
- `announcement`, `report-verify`, `nlp`, and `evals` skills (`report-verify`
  bundles `scripts/extract_links.py`).
- `AGENTS.md` template and scaffold entry — shared tool-agnostic context, with
  `CLAUDE.md` reduced to a thin layer that imports it (`@AGENTS.md`). The kit's
  own repo was migrated to this pattern too.
- `/core:plan` now persists the plan to `PLAN.md` and a checklist to `TASKS.md`
  so planning survives `/clear` and new sessions.
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

### Changed
- Personalized marketplace/plugin metadata and install references
  (`risqaliyevds` / `Murod`).
- Marketplace description and README command table now list the new skills.
