---
name: init-dev-kit
description: Bring the current project fully up to the dev-kit standard - pull the latest kit, scaffold every standard file, triage and reorganize the whole tree (docs, scratch, secrets, artifacts) into the convention layout, and format. For onboarding an existing/messy repo, not just fresh ones.
disable-model-invocation: true
argument-hint: ""
---

Bring this repository fully up to the current dev-kit standard. Do ALL analysis
first, present ONE consolidated plan, and **confirm before any move, delete,
untrack, or bulk reformat** — this can touch many files. Work in order.

0. Preflight:
   - If this is not a git repository, run `git init`.
   - Run `git status`. If the tree is dirty, warn me and let me commit/stash
     first — triaging on top of uncommitted changes is hard to review.

1. Pull the latest kit:
   - `claude plugin marketplace update dev-kit` (fetches the newest commit).
   - Tell me to run `/reload-plugins` (or restart) so new skills/hooks/templates
     load. These commands update the *installed plugin*, never this repo's files.

2. Scaffold missing standard files (create-if-missing, never overwrite), from the
   `new-project` skill's `templates/` — same set the SessionStart hook uses:
   - Always: `CHANGELOG.md`, `AGENTS.md`, `CLAUDE.md`, `README.md`, `.gitignore`,
     `.gitattributes`, `.editorconfig`, `.env.example`, `.claude/settings.json`.
   - Node (`package.json`): `.nvmrc`.  Python
     (`pyproject.toml`/`setup.py`/`setup.cfg`/`requirements.txt`): `.python-version`.
   - Fill the `{{PLACEHOLDERS}}` in `AGENTS.md` (and the title lines of
     `CLAUDE.md`/`README.md`) by asking me for project name, description, stack,
     and dev/test/lint/build commands.
   - **Skip this whole step for a plugin/marketplace repo**
     (`.claude-plugin/marketplace.json` or `.claude-plugin/plugin.json`).

3. Root triage — classify EVERY loose file/dir in the repo root (tracked **and**
   untracked), assign one action each, and show me the full table
   `path → category → action` BEFORE doing anything. Goal: a clean root that
   never breaks the app. Categories and their actions:

   a. **Keep at root — never touch:** `README/AGENTS/CLAUDE/CHANGELOG.md`;
      dotfiles/config (`.editorconfig`, `.gitignore`, `.gitattributes`, `.nvmrc`,
      `.python-version`, `.env.example`, `*.template`); tool-mandated config that
      must live at root (`docker-compose*.yml`, `Dockerfile`, `Makefile`,
      `package.json`, `pyproject.toml`, `tsconfig*`, framework configs); and
      source/asset directories.

   b. **Secrets** (`.env`, `.env.*` except `.env.example`, `*.pem`, `*.key`,
      credential/cookie files): they stay on disk (the app reads them) but MUST be
      gitignored.
      - Already gitignored → leave in place.
      - **Tracked in git → flag loudly** and offer `git rm --cached <f>` (untrack,
        keep the file) plus a `.gitignore` entry. NEVER print, move, or delete a
        real secret.
      - Obvious secret backups (e.g. `.env.dev.bak`) → offer to delete.

   c. **Local tooling artifacts** (`*.db`, `*.rvf`, `*.rvf.lock`, `agentdb.*`,
      `ruvector.db`): ensure gitignored; **leave in place** (the tools recreate
      and expect them at root). Do not move.

   d. **Generated reports / scratch** (ad-hoc root `*_report*`, `dup_*`, `*.tmp`,
      stray `*.log`, one-off `*.txt`/`*.json` that aren't config): propose moving
      to `tmp/` (gitignored) or deleting — ask me which.

   e. **Loose docs** (`*.md` other than the four) → `docs/`.
   f. `PLAN.md` / `TASKS.md` → `docs/plans/`.
   g. Screenshots/images → `screenshots/`; datasets/data → `datasets/`; loose
      one-off scripts → `scripts/`.

   Execute only after I approve: `git mv` for tracked moves, plain `mv` for
   untracked, `git rm --cached` for tracked secrets, `rm` for confirmed deletes;
   append any missing ignore patterns to `.gitignore`. **NEVER move source code,
   entry points, or tool-mandated config.**

4. Format (confirm first — this can rewrite many files; skip a tool silently if
   it isn't installed):
   - Web / Markdown / JSON / YAML: `npx --no-install prettier --write --ignore-unknown .`
   - Python (if this is a Python project): `ruff format .` when ruff is available,
     otherwise `black .`.

5. Wrap up:
   - Add a `CHANGELOG.md` entry under `[Unreleased]` noting the dev-kit init.
   - Summarize what you created, moved, untracked, deleted, and formatted.
   - Do NOT commit — leave everything staged for my review.
