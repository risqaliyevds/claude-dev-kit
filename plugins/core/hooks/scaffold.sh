#!/usr/bin/env sh
# SessionStart: force the standard project files into existence.
# Only runs inside a git work tree; only creates files that are missing
# (never overwrites). Templates are shared with the /core:new-project skill.
set -u

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

TPL="${CLAUDE_PLUGIN_ROOT:-}/skills/new-project/templates"
[ -d "$TPL" ] || exit 0

[ -f CHANGELOG.md ] || cp "$TPL/CHANGELOG.md" CHANGELOG.md 2>/dev/null || true
[ -f CLAUDE.md ]    || cp "$TPL/CLAUDE.md"    CLAUDE.md    2>/dev/null || true
[ -f .gitignore ]   || cp "$TPL/gitignore"    .gitignore   2>/dev/null || true
if [ ! -f .claude/settings.json ]; then
  mkdir -p .claude 2>/dev/null || true
  cp "$TPL/settings.json" .claude/settings.json 2>/dev/null || true
fi

exit 0
