#!/usr/bin/env sh
# Behavior tests for scripts/sync-machine.sh: brings a machine up to the kit
# (plugins, tools, ECC rules, model routing, status line), --check changes
# nothing, removals are reported and never done, a second run is a no-op.
# Hermetic: `claude` and `npm` are stubs, HOME/CLAUDE_CONFIG_DIR are sandboxed,
# ECC rules come from a fixture tree (no network).
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/plugins/core/scripts/sync-machine.sh"

# Static contract: install.sh delegates to the sync, init-dev-kit runs it
# from the freshly fetched marketplace clone (the loaded skill dir is the
# old version), and the ECC plugin is retired, never installed.
grep -q 'sync-machine.sh' "$ROOT/install.sh" || { echo "install.sh does not run sync-machine.sh"; exit 1; }
if grep -qE '^[^#]*plugin install ecc@ecc' "$ROOT/install.sh" "$SCRIPT"; then echo "the ECC plugin is installed again"; exit 1; fi
INIT="$ROOT/plugins/core/skills/init-dev-kit/SKILL.md"
grep -q 'claude plugin marketplace update dev-kit' "$INIT" || { echo "init-dev-kit does not fetch the latest kit"; exit 1; }
grep -q 'installLocation' "$INIT" || { echo "init-dev-kit does not locate the fresh marketplace clone"; exit 1; }
grep -q 'sync-machine.sh" --check' "$INIT" || { echo "init-dev-kit does not show the drift report first"; exit 1; }
[ -f "$ROOT/plugins/core/scripts/model-routing.sh" ] && grep -q 'model-routing.sh' "$SCRIPT" ||
  { echo "sync-machine.sh does not apply model routing"; exit 1; }

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed"; exit 0; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin" STATE="$TMP/state" LOG="$TMP/log"
mkdir -p "$BIN" "$STATE"
: >"$LOG"
export STATE LOG BIN

# PATH without the real claude/npm/pyright/uipro, so only the stubs answer.
CLEAN=""
OLDIFS=$IFS
IFS=:
for d in $PATH; do
  for t in claude npm pyright-langserver uipro; do
    if [ -e "$d/$t" ] || [ -e "$d/$t.cmd" ] || [ -e "$d/$t.exe" ]; then continue 2; fi
  done
  CLEAN="$CLEAN:$d"
done
IFS=$OLDIFS
PATH="$BIN$CLEAN"
export PATH
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq shares a dir with claude/npm"; exit 0; }

# Stateful `claude` stub: logs every call, answers the two list commands from
# JSON files, and applies install/enable/marketplace add to them.
cat >"$BIN/claude" <<'EOF'
#!/usr/bin/env sh
echo "claude $*" >>"$LOG"
upd() { jq "$1" "$STATE/$2" >"$STATE/$2.tmp" && mv "$STATE/$2.tmp" "$STATE/$2"; }
case "$*" in
  "plugin list --json") cat "$STATE/plugins.json" ;;
  "plugin marketplace list --json") cat "$STATE/mk.json" ;;
  "plugin install "*) upd ". + [{\"id\":\"$3\",\"scope\":\"user\",\"enabled\":true}]" plugins.json ;;
  "plugin enable "*) upd "map(if .id==\"$3\" and .scope==\"user\" then .enabled=true else . end)" plugins.json ;;
  "plugin marketplace add "*)
    case "$4" in */claude-dev-kit) n=dev-kit ;; *) n=${4##*/} ;; esac
    upd ". + [{\"name\":\"$n\"}]" mk.json ;;
esac
exit 0
EOF
cat >"$BIN/npm" <<'EOF'
#!/usr/bin/env sh
echo "npm $*" >>"$LOG"
for a in "$@"; do
  case "$a" in
    pyright) printf '#!/bin/sh\n' >"$BIN/pyright-langserver" ;;
    ui-ux-pro-max-cli) printf '#!/bin/sh\necho "uipro $*" >>"$LOG"\nmkdir -p "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/ui-ux-pro-max"\n' >"$BIN/uipro" ;;
  esac
done
chmod +x "$BIN"/* 2>/dev/null
exit 0
EOF
chmod +x "$BIN/claude" "$BIN/npm"

HOME="$TMP/home"
CLAUDE_CONFIG_DIR="$HOME/.claude"
export HOME CLAUDE_CONFIG_DIR
mkdir -p "$CLAUDE_CONFIG_DIR/rules/ecc/common"
CFG=$CLAUDE_CONFIG_DIR

# ECC fixture checkout, passed through to ecc-rules.sh.
ECC_SRC="$TMP/ecc"
export ECC_SRC
mkdir -p "$ECC_SRC/rules/common" "$ECC_SRC/rules/python" "$ECC_SRC/rules/dart"
for f in security git-workflow performance; do printf '# %s\n' "$f" >"$ECC_SRC/rules/common/$f.md"; done
printf '# py\n' >"$ECC_SRC/rules/python/coding-style.md"

# A machine from before the lean kit: ECC plugin installed, ponytail only as a
# project-scope copy, pyright-lsp missing, ponytail marketplace missing, old
# rules still loading, /model set to opus.
cat >"$STATE/plugins.json" <<'EOF'
[{"id":"core@dev-kit","scope":"user","enabled":true},
 {"id":"ecc@ecc","scope":"user","enabled":true},
 {"id":"ponytail@ponytail","scope":"project","enabled":true,"projectPath":"/p/labelCraft"},
 {"id":"ruflo-core@ruflo","scope":"user","enabled":true}]
EOF
printf '[{"name":"dev-kit"},{"name":"claude-plugins-official"}]\n' >"$STATE/mk.json"
printf '{"model": "opus", "theme": "dark"}\n' >"$CFG/settings.json"
printf '# old performance rule\n' >"$CFG/rules/ecc/common/performance.md"
printf '# old precedence\n' >"$CFG/rules/ecc/00-precedence.md"

has() { grep -qF -- "$1" "$TMP/out" || { echo "output lacks: $1"; cat "$TMP/out"; exit 1; }; }
logged() { grep -qF -- "$1" "$LOG"; }

# 1. --check reports every drift, changes nothing, exits nonzero.
cp "$CFG/settings.json" "$TMP/settings.before"
if sh "$SCRIPT" --check >"$TMP/out" 2>&1; then echo "--check passed on a drifted machine"; cat "$TMP/out"; exit 1; fi
has "pyright-lsp@claude-plugins-official"
has "ponytail@ponytail"
has "/p/labelCraft"
has "claude plugin uninstall ecc@ecc --scope user"
has "model: opus"
has "performance.md"
has "pyright-langserver"
has "ruflo-core@ruflo"
if grep -qE '^claude plugin (install|uninstall|enable|update|marketplace (add|update))|^npm ' "$LOG"; then
  echo "--check changed something:"; cat "$LOG"; exit 1
fi
cmp -s "$CFG/settings.json" "$TMP/settings.before" || { echo "--check rewrote settings.json"; exit 1; }
[ -f "$CFG/rules/ecc/common/performance.md" ] || { echo "--check touched the rules"; exit 1; }

# 2. Apply: installs what is missing, refreshes rules, pins routing, updates
#    kit plugins, and never removes anything.
sh "$SCRIPT" >"$TMP/out" 2>&1 || { echo "apply failed"; cat "$TMP/out"; exit 1; }
logged "claude plugin marketplace add DietrichGebert/ponytail" || { echo "ponytail marketplace not added"; exit 1; }
logged "claude plugin install ponytail@ponytail --scope user" || { echo "ponytail not installed at user scope"; exit 1; }
logged "claude plugin install pyright-lsp@claude-plugins-official --scope user" || { echo "pyright-lsp not installed"; exit 1; }
logged "claude plugin update core@dev-kit" || { echo "core not updated"; exit 1; }
logged "npm install -g pyright" || { echo "pyright not installed"; exit 1; }
logged "uipro init --ai claude --global" || { echo "UI/UX Pro Max not initialized"; exit 1; }
if grep -q "uninstall" "$LOG"; then echo "apply removed something without asking"; exit 1; fi
if grep -q "install ecc@ecc" "$LOG"; then echo "apply installed the retired ECC plugin"; exit 1; fi
[ ! -f "$CFG/rules/ecc/common/performance.md" ] || { echo "stale rule still loading"; exit 1; }
[ -f "$CFG/rules/ecc/common/security.md" ] || { echo "rules not refreshed"; exit 1; }
[ "$(jq -r .model "$CFG/settings.json")" = "opusplan" ] || { echo "model routing not applied"; exit 1; }
[ "$(jq -r .theme "$CFG/settings.json")" = "dark" ] || { echo "lost an unrelated setting"; exit 1; }
has "claude plugin uninstall ecc@ecc --scope user"

# 3. Idempotent: a second apply installs nothing new.
: >"$LOG"
sh "$SCRIPT" >"$TMP/out" 2>&1 || { echo "second apply failed"; cat "$TMP/out"; exit 1; }
if grep -qE '^claude plugin (install|enable|marketplace add)|^npm install' "$LOG"; then
  echo "second apply was not a no-op:"; cat "$LOG"; exit 1
fi

# 4. Once the user has removed what the report asked about, --check is clean.
printf '[{"id":"core@dev-kit","scope":"user","enabled":true},{"id":"ponytail@ponytail","scope":"user","enabled":true},{"id":"pyright-lsp@claude-plugins-official","scope":"user","enabled":true}]\n' >"$STATE/plugins.json"
sh "$SCRIPT" --check >"$TMP/out" 2>&1 || { echo "--check not clean after removals"; cat "$TMP/out"; exit 1; }
has "UP TO DATE"

echo OK
