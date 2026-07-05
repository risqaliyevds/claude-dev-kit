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
   - `templates/CLAUDE.md` -> `./CLAUDE.md`
   - `templates/settings.json` -> `./.claude/settings.json`
   - `templates/gitignore` -> `./.gitignore` (if one exists, merge missing lines instead)
3. Fill in the `{{PLACEHOLDERS}}` in `CLAUDE.md`: ask me for the project name, a one-line description, the tech stack, and the dev/test/lint/build commands, then write them in. Remove placeholder lines that do not apply.
4. Ask which language(s) the project uses and remind me to install the matching code-intelligence plugin from `claude-plugins-official` (for example `typescript-lsp` or `pyright-lsp`) if I have not already.
5. Make the initial commit: `chore: bootstrap project from dev-kit`.
