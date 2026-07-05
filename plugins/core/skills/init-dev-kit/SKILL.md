---
name: init-dev-kit
description: Bring the current project fully up to the dev-kit standard - pull the latest kit, scaffold every standard file, reorganize the tree into the convention folder structure, and format. For onboarding an existing/messy repo, not just fresh ones.
disable-model-invocation: true
argument-hint: ""
---

Bring this repository fully up to the current dev-kit standard. Work in this
exact order and **confirm with me before any move or bulk reformat** — this can
touch a lot of files.

0. Preflight:
   - If this is not a git repository, run `git init`.
   - Run `git status`. If the tree has uncommitted changes, warn me and let me
     stash/commit first — reorganizing on top of dirty state is hard to review.

1. Pull the latest kit:
   - `claude plugin marketplace update dev-kit` (fetches the newest commit).
   - Tell me to run `/reload-plugins` (or restart Claude Code) so the new
     skills, hooks, and templates load into the session.
   - These commands update the *installed plugin*, never files in this repo.

2. Create every missing standard file (never overwrite an existing one), copying
   from the `new-project` skill's `templates/` — same set the SessionStart hook
   uses:
   - Always: `CHANGELOG.md`, `AGENTS.md`, `CLAUDE.md`, `README.md`, `.gitignore`,
     `.gitattributes`, `.editorconfig`, `.env.example`, `.claude/settings.json`.
   - Node project (`package.json` present): `.nvmrc`.
   - Python project (`pyproject.toml`/`setup.py`/`setup.cfg`/`requirements.txt`):
     `.python-version`.
   - Then fill the `{{PLACEHOLDERS}}` in `AGENTS.md` (and the title lines of
     `CLAUDE.md`/`README.md`): ask me for project name, one-line description,
     stack, and dev/test/lint/build commands. Remove placeholder lines that
     don't apply.
   - Skip this whole step if the repo is itself a plugin/marketplace
     (`.claude-plugin/marketplace.json` or `.claude-plugin/plugin.json`) — those
     don't want app-project files.

3. Reorganize to the "Project structure" convention in `AGENTS.md` — keep the
   root clean. Only `README.md`, `AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md`, and
   config/dotfiles stay at the root. For everything else currently loose in the
   root:
   - Loose docs (`*.md` other than the four above) -> `docs/`
   - Existing `PLAN.md` / `TASKS.md` -> `docs/plans/`
   - Screenshots / captured images -> `screenshots/`
   - Datasets / sample data -> `datasets/`
   - One-off / helper scripts -> `scripts/`
   Use `git mv` so history is preserved. **NEVER move source code, entry points,
   or tool-mandated config** (`package.json`, `tsconfig.json`, `pyproject.toml`,
   `Dockerfile`, framework config, etc.) — those must stay where the toolchain
   expects them. List every planned move and get my OK before running any.

4. Format the codebase with the kit's formatter (skip silently if prettier is
   not available): `npx --no-install prettier --write --ignore-unknown .`

5. Wrap up:
   - Add a `CHANGELOG.md` entry under `[Unreleased]` noting the dev-kit
     initialization.
   - Summarize what you created, moved, and formatted in a short list.
   - Do NOT commit automatically — leave everything staged for my review.
