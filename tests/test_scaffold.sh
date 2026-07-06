#!/usr/bin/env sh
# Behavior tests for hooks/scaffold.sh, run in throwaway git repos.
# This automates the manual check AGENTS.md used to prescribe:
# create-if-missing, never-overwrite, stack gating, plugin-repo skip.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOOK="$ROOT/plugins/core/hooks/scaffold.sh"
export CLAUDE_PLUGIN_ROOT="$ROOT/plugins/core"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
HOME="$TMP/home" # sandbox the user-scope statusline side effect
export HOME
mkdir -p "$HOME"

new_repo() {
  mkdir -p "$TMP/$1"
  git -C "$TMP/$1" init -q
  echo "$TMP/$1"
}

# 1. Fresh git repo: every always-required file is created WITH its template's
#    exact content (existence alone would pass even for 0-byte files); no
#    stack files.
d=$(new_repo fresh)
(cd "$d" && sh "$HOOK")
TPL="$CLAUDE_PLUGIN_ROOT/skills/new-project/templates"
while read -r tpl dest; do
  [ -f "$d/$dest" ] || { echo "missing $dest in fresh repo"; exit 1; }
  cmp -s "$d/$dest" "$TPL/$tpl" || { echo "$dest does not match template $tpl"; exit 1; }
done <<EOF
CHANGELOG.md CHANGELOG.md
AGENTS.md AGENTS.md
CLAUDE.md CLAUDE.md
README.md README.md
gitignore .gitignore
gitattributes .gitattributes
editorconfig .editorconfig
env.example .env.example
settings.json .claude/settings.json
EOF
[ ! -f "$d/.nvmrc" ] || { echo ".nvmrc created without package.json"; exit 1; }
[ ! -f "$d/.python-version" ] || { echo ".python-version created without python markers"; exit 1; }
[ -f "$HOME/.claude/statusline.py" ] || { echo "hook did not install user-scope statusline"; exit 1; }

# 2. Never overwrites an existing file.
d=$(new_repo keep)
printf 'KEEP\n' >"$d/CHANGELOG.md"
(cd "$d" && sh "$HOOK")
[ "$(cat "$d/CHANGELOG.md")" = "KEEP" ] || { echo "overwrote existing CHANGELOG.md"; exit 1; }

# 3. Stack gating: Node repo gets .nvmrc — and never the Python pin (the
#    pyenv footgun the hook exists to avoid).
d=$(new_repo node)
printf '{}\n' >"$d/package.json"
(cd "$d" && sh "$HOOK")
[ -f "$d/.nvmrc" ] || { echo ".nvmrc not created for Node repo"; exit 1; }
[ ! -f "$d/.python-version" ] || { echo ".python-version leaked into a Node repo"; exit 1; }

# 4. Stack gating: Python repo gets .python-version — and never .nvmrc.
d=$(new_repo py)
touch "$d/pyproject.toml"
(cd "$d" && sh "$HOOK")
[ -f "$d/.python-version" ] || { echo ".python-version not created for Python repo"; exit 1; }
[ ! -f "$d/.nvmrc" ] || { echo ".nvmrc leaked into a Python repo"; exit 1; }

# 5. Plugin/marketplace repos are skipped entirely — but the user-scope
#    statusline must still be installed (it runs before that gate).
for marker in marketplace.json plugin.json; do
  d=$(new_repo "plugin-$marker")
  mkdir -p "$d/.claude-plugin"
  printf '{}\n' >"$d/.claude-plugin/$marker"
  (cd "$d" && HOME="$TMP/home-$marker" sh "$HOOK")
  [ ! -f "$d/CHANGELOG.md" ] || { echo "scaffolded inside a repo with $marker"; exit 1; }
  [ -f "$TMP/home-$marker/.claude/statusline.py" ] ||
    { echo "statusline not installed from a plugin repo ($marker)"; exit 1; }
done

# 6. Outside a git work tree: exits 0 and creates nothing — except the
#    user-scope statusline, which runs before the git gate.
mkdir -p "$TMP/norepo"
(cd "$TMP/norepo" && HOME="$TMP/home-norepo" sh "$HOOK")
[ ! -f "$TMP/norepo/CHANGELOG.md" ] || { echo "scaffolded outside a git repo"; exit 1; }
[ -f "$TMP/home-norepo/.claude/statusline.py" ] ||
  { echo "statusline not installed outside a git repo"; exit 1; }

echo OK
