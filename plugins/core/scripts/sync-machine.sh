#!/usr/bin/env sh
# Bring this machine's Claude Code setup up to the dev-kit: marketplaces, kit
# plugins (installed, enabled, updated), companion tools, ECC rules, model
# routing, status line. Idempotent — a second run changes nothing. Run by
# install.sh and /core:init-dev-kit (from the fresh marketplace clone).
#
# Usage: sync-machine.sh [--check]
#   --check   report drift only, change nothing; exit 1 if anything is off
# Never removes anything: the retired ecc@ecc plugin and project-scope copies
# of kit plugins are printed as REMOVE lines for the caller to confirm.
# Env: KIT_REPO (default risqaliyevds/claude-dev-kit), ECC_SRC (local ECC
# checkout for ecc-rules.sh; default: shallow clone), CLAUDE_CONFIG_DIR.
# Needs jq and the claude CLI; npm for the companion tools.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CHECK=0
[ "${1:-}" = --check ] && CHECK=1
DRIFT=0 FAILED=0

MARKETPLACES="dev-kit=${KIT_REPO:-risqaliyevds/claude-dev-kit} ponytail=DietrichGebert/ponytail claude-plugins-official=anthropics/claude-plugins-official"
PLUGINS="core@dev-kit ponytail@ponytail pyright-lsp@claude-plugins-official"
RETIRED="ecc@ecc"

note() { printf '%s\n' "$*"; }
ok() { note "OK      $*"; }
fail() { note "FAILED  $*"; FAILED=1; }
# fix <what> <command...> — drift: --check reports it, apply runs the command.
fix() {
  what=$1
  shift
  DRIFT=1
  note "DRIFT   $what"
  [ "$CHECK" -eq 1 ] && return 0
  if "$@" >/dev/null 2>&1; then note "  fixed"; else fail "$*"; fi
}
# refresh <command...> — keep-current step that is not drift; apply mode only.
refresh() {
  [ "$CHECK" -eq 1 ] && return 0
  "$@" >/dev/null 2>&1 || fail "$*"
}

command -v jq >/dev/null 2>&1 || { echo "sync-machine: jq not found — install jq and re-run" >&2; exit 2; }
command -v claude >/dev/null 2>&1 || { echo "sync-machine: claude CLI not on PATH" >&2; exit 2; }

# --- marketplaces ---------------------------------------------------------
MK=$(claude plugin marketplace list --json 2>/dev/null) || MK='[]'
for m in $MARKETPLACES; do
  name=${m%%=*} repo=${m#*=}
  if printf '%s' "$MK" | jq -e --arg n "$name" 'any(.[]; .name == $n)' >/dev/null 2>&1; then
    ok "marketplace $name"
    refresh claude plugin marketplace update "$name"
  else
    fix "marketplace $name missing" claude plugin marketplace add "$repo"
  fi
done

# --- plugins: kit set at user scope, retired ones and duplicates reported --
PL=$(claude plugin list --json 2>/dev/null) || PL='[]'
user_state() { # prints enabled|disabled|missing for a user-scope plugin
  printf '%s' "$PL" | jq -r --arg id "$1" \
    '[.[] | select(.id == $id and .scope == "user")][0] | if . == null then "missing" elif .enabled then "enabled" else "disabled" end'
}
for id in $PLUGINS; do
  case $(user_state "$id") in
    enabled) ok "plugin $id"; refresh claude plugin update "$id" --scope user ;;
    disabled) fix "plugin $id is disabled" claude plugin enable "$id" --scope user ;;
    *) fix "plugin $id not installed" claude plugin install "$id" --scope user ;;
  esac
done
for id in $RETIRED; do
  if [ "$(user_state "$id")" != missing ]; then
    DRIFT=1
    note "REMOVE  $id is retired by the kit (~45k always-on tokens) — confirm, then: claude plugin uninstall $id --scope user"
  fi
done
dups=$(printf '%s' "$PL" | jq -r --arg kit "$PLUGINS $RETIRED" \
  '.[] | select(.scope != "user" and (.id as $i | $kit | split(" ") | index($i))) | "\(.id) \(.scope) \(.projectPath // "?")"')
if [ -n "$dups" ]; then
  DRIFT=1
  printf '%s\n' "$dups" | while read -r id scope path; do
    note "REMOVE  $id has a $scope-scope copy in $path (one plugin, one scope) — confirm, then from that project: claude plugin uninstall $id --scope $scope --keep-data"
  done
fi
others=$(printf '%s' "$PL" | jq -r --arg kit "$PLUGINS $RETIRED" \
  '[.[] | select(.scope == "user" and .enabled and (.id as $i | $kit | split(" ") | index($i) | not)) | .id] | join(" ")')
[ -z "$others" ] || note "INFO    other enabled plugins (not the kit's; check their cost with claude plugin details <id>): $others"

# --- companion tools -------------------------------------------------------
if command -v pyright-langserver >/dev/null 2>&1; then
  ok "pyright-langserver"
  refresh npm update -g pyright
else
  fix "pyright-langserver not on PATH (pyright-lsp needs it)" npm install -g pyright
fi
if command -v uipro >/dev/null 2>&1; then
  ok "uipro"
  refresh npm update -g ui-ux-pro-max-cli
else
  fix "uipro (UI/UX Pro Max) not installed" npm install -g ui-ux-pro-max-cli
fi
if [ -d "$CFG/skills/ui-ux-pro-max" ]; then
  ok "UI/UX Pro Max skill"
elif [ "$CHECK" -eq 1 ] || command -v uipro >/dev/null 2>&1; then
  fix "UI/UX Pro Max skill not initialized" uipro init --ai claude --global
else
  fail "UI/UX Pro Max skill: uipro unavailable"
fi

# --- ECC rules ------------------------------------------------------------
RULES="$CFG/rules/ecc"
keep=$(sed -n 's/^COMMON_KEEP="\(.*\)"$/\1/p' "$HERE/ecc-rules.sh")
stale=""
for f in "$RULES"/common/*.md; do
  [ -e "$f" ] || continue
  b=$(basename "$f")
  case " $keep " in *" $b "*) ;; *) stale="$stale $b" ;; esac
done
why=""
if [ ! -f "$RULES/00-precedence.md" ]; then
  why="not installed"
elif [ -n "$stale" ]; then
  why="out of date — still loading:$stale"
elif ! grep -q 'core:code-reviewer' "$RULES/00-precedence.md"; then
  why="out of date — precedence rule predates the lean kit"
fi
if [ -n "$why" ]; then
  fix "ECC rules $why" sh "$HERE/ecc-rules.sh" ${ECC_SRC:+"$ECC_SRC"}
else
  ok "ECC rules"
  refresh sh "$HERE/ecc-rules.sh" ${ECC_SRC:+"$ECC_SRC"}
fi

# --- model routing: diff the settings against a routed copy ----------------
SETTINGS="$CFG/settings.json"
T=$(mktemp -d)
if [ -s "$SETTINGS" ]; then cp "$SETTINGS" "$T/settings.json"; else printf '{}\n' >"$T/settings.json"; fi
if CLAUDE_CONFIG_DIR="$T" sh "$HERE/model-routing.sh" >/dev/null 2>&1; then
  if [ "$(jq -S . "$T/settings.json")" = "$(jq -S . "$SETTINGS" 2>/dev/null)" ]; then
    ok "model routing"
  else
    cur=$(jq -r '.model // "default"' "$SETTINGS" 2>/dev/null)
    want=$(jq -r .model "$T/settings.json")
    fix "model routing differs (model: $cur → $want; applying resets a /model or /effort choice)" sh "$HERE/model-routing.sh"
  fi
else
  fail "model routing: $SETTINGS is not valid JSON"
fi
rm -rf "$T"

# --- status line ----------------------------------------------------------
STATUS="$HERE/../statusline/setup.sh"
if msg=$(sh "$STATUS" --check 2>&1); then
  ok "status line"
else
  fix "$msg" sh "$STATUS"
fi

# --- summary ----------------------------------------------------------------
if [ "$CHECK" -eq 1 ]; then
  [ "$DRIFT" -eq 0 ] && note "UP TO DATE"
  exit "$DRIFT"
fi
if [ "$FAILED" -eq 0 ]; then note "SYNCED — restart Claude Code to load plugin changes"; fi
exit "$FAILED"
