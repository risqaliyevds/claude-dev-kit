# Changelog

All notable changes to this project are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This repo has no
`version` field on purpose — every commit to `main` is the current version.

## [Unreleased]

### Added
- `announcement`, `report-verify`, `nlp`, and `evals` skills (`report-verify`
  bundles `scripts/extract_links.py`).
- `SessionStart` hook (`plugins/core/hooks/scaffold.sh`) that force-creates the
  standard project files in any git repo — create-if-missing, idempotent, and
  gated to a git work tree.
- Scaffold/`new-project` templates: `README.md`, `.editorconfig`,
  `.gitattributes`, `.env.example`, plus stack-gated `.nvmrc` (Node) and
  `.python-version` (Python).
- Root `.gitattributes` pinning `*.sh` to LF so hook scripts stay runnable on
  Windows/autocrlf checkouts.

### Changed
- Personalized marketplace/plugin metadata and install references
  (`risqaliyevds` / `Murod`).
- Marketplace description and README command table now list the new skills.
