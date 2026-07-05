#!/usr/bin/env sh
# SessionStart: force the standard project files into existence.
# Only runs inside a git work tree; only creates files that are missing
# (never overwrites). Templates are shared with the /core:new-project skill.
set -u

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Skip plugin/marketplace repos (like this kit itself) — they are not app
# projects and don't want a scaffolded .env.example / .claude/settings.json.
[ -f .claude-plugin/marketplace.json ] && exit 0
[ -f .claude-plugin/plugin.json ] && exit 0

TPL="${CLAUDE_PLUGIN_ROOT:-}/skills/new-project/templates"
[ -d "$TPL" ] || exit 0

# ensure <template-name> <destination-path> — copy only if dest is missing.
ensure() {
  [ -f "$2" ] && return 0
  dir=$(dirname "$2")
  [ "$dir" = "." ] || mkdir -p "$dir" 2>/dev/null || true
  cp "$TPL/$1" "$2" 2>/dev/null || true
}

# Always required — universal and safe in any repo.
ensure CHANGELOG.md   CHANGELOG.md
ensure CLAUDE.md      CLAUDE.md
ensure README.md      README.md
ensure gitignore      .gitignore
ensure gitattributes  .gitattributes
ensure editorconfig   .editorconfig
ensure env.example    .env.example
ensure settings.json  .claude/settings.json

# Stack-specific — only where the toolchain applies, so we don't force
# pyenv/nvm to resolve a version in unrelated repos (a real footgun).
if [ -f package.json ]; then
  ensure nvmrc .nvmrc
fi
if [ -f pyproject.toml ] || [ -f setup.py ] || [ -f setup.cfg ] || [ -f requirements.txt ]; then
  ensure python-version .python-version
fi

exit 0
