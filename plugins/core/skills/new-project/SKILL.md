---
name: new-project
description: Bootstrap a new project with the standard setup - CHANGELOG.md, CLAUDE.md, .claude settings, and .gitignore.
disable-model-invocation: true
argument-hint: "[project name or short description]"
---

Set up the current directory as a new project ("$ARGUMENTS"). Templates live in `${CLAUDE_SKILL_DIR}/templates/`.

1. If this directory is not a git repository, run `git init`.
2. Copy each template below into the project, but never overwrite a file that already exists:
   - `templates/CHANGELOG.md` -> `./CHANGELOG.md`
   - `templates/AGENTS.md` -> `./AGENTS.md` (shared, tool-agnostic context)
   - `templates/CLAUDE.md` -> `./CLAUDE.md` (thin layer that imports `AGENTS.md`)
   - `templates/README.md` -> `./README.md`
   - `templates/settings.json` -> `./.claude/settings.json`
   - `templates/editorconfig` -> `./.editorconfig`
   - `templates/gitattributes` -> `./.gitattributes`
   - `templates/env.example` -> `./.env.example`
   - `templates/gitignore` -> `./.gitignore` (if one exists, merge missing lines instead)
   - `templates/nvmrc` -> `./.nvmrc` (only if this is a Node project, i.e. `package.json` exists)
   - `templates/python-version` -> `./.python-version` (only if this is a Python project: `pyproject.toml`, `setup.py`, `setup.cfg`, or `requirements.txt` exists)
3. Fill in the `{{PLACEHOLDERS}}` (they live in `AGENTS.md`, and the title/first line of `CLAUDE.md` and `README.md`): ask me for the project name, a one-line description, the tech stack, and the dev/test/lint/build commands, then write them in. Remove placeholder lines that do not apply.
4. Ask which language(s) the project uses and remind me to install the matching code-intelligence plugin from `claude-plugins-official` (for example `typescript-lsp` or `pyright-lsp`) if I have not already.
5. Make the initial commit: `chore: bootstrap project from dev-kit`.
