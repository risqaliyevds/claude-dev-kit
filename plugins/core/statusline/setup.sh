#!/usr/bin/env sh
# Install the kit status line at user scope (~/.claude), idempotently — and
# CHECK that it actually renders, because a statusLine that is wired but
# broken shows nothing and also hides Claude Code's footer hints.
# Called from two places so one run of either fully fixes the status bar:
#   - install.sh (one-time machine setup, from the repo checkout)
#   - hooks/scaffold.sh (SessionStart, from the installed plugin — this also
#     re-syncs the script and re-verifies the wiring every session)
# Usage: setup.sh            install/repair; silent when healthy
#        setup.sh --check    read-only health report; exit 1 when broken
# Safe by design: syncs the script only when content differs, rewrites the
# statusLine setting only when it is missing or ours (a user's custom
# statusLine is never touched), and never installs output it cannot parse.
set -u

SRC="$(dirname "$0")/statusline.py"
DST_DIR="$HOME/.claude"
DST="$DST_DIR/statusline.py"
SETTINGS="$DST_DIR/settings.json"
# Absolute, forward-slash script path. NOT `~`: Claude Code may run the
# command through PowerShell or cmd.exe on Windows, and neither expands `~`
# for a native executable's argument (python then fails with "can't open
# file '~/.claude/statusline.py'" and the bar goes blank). C:/Users/... works
# in Git Bash, PowerShell and cmd alike.
if command -v cygpath >/dev/null 2>&1; then
  SCRIPT="$(cygpath -m "$DST")"
else
  SCRIPT="$DST"
fi

# Does a statusLine command really draw the bar? `{}` is the worst-case
# payload the renderer must survive.
renders() { printf '{}' | sh -c "$1" 2>/dev/null | grep -q 'Model:'; }

# Find an interpreter that RUNS. `command -v python3` is not enough: on
# Windows it happily returns the Microsoft Store stub, which prints to stderr
# and exits 49 — the #1 reason the bar is missing on some machines.
find_python() {
  for c in python3 python 'py -3' "$(uv python find 2>/dev/null)"; do
    [ -n "$c" ] || continue
    # shellcheck disable=SC2086 # word-splitting `py -3` is the point
    exe=$($c -c 'import sys; print(sys.executable)' 2>/dev/null) || continue
    [ -n "$exe" ] || continue
    printf '%s\n' "$exe" | tr '\134' '/'   # backslash → /: Git Bash eats unquoted ones
    return 0
  done
  return 1
}

if [ "${1:-}" = "--check" ]; then
  [ -f "$DST" ] || { echo "status line: $DST missing — run setup.sh"; exit 1; }
  cur=$(jq -r '.statusLine.command? // ""' "$SETTINGS" 2>/dev/null) || cur=""
  [ -n "$cur" ] || { echo "status line: statusLine not wired in $SETTINGS"; exit 1; }
  if renders "$cur"; then echo "status line: OK ($cur)"; exit 0; fi
  echo "status line: BROKEN — '$cur' renders nothing"; exit 1
fi

[ -f "$SRC" ] || exit 0
mkdir -p "$DST_DIR" 2>/dev/null || exit 0
# The plugin copy is the source of truth — customize it in the kit repo,
# not by editing ~/.claude/statusline.py (edits there get overwritten).
if ! cmp -s "$SRC" "$DST" 2>/dev/null; then
  cp "$SRC" "$DST" 2>/dev/null || exit 0
fi

command -v jq >/dev/null 2>&1 || exit 0
# Missing or 0-byte settings both mean "no settings yet" — seed {} (jq treats
# an empty file as zero documents and would silently produce empty output).
[ -s "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"

# Wire only when statusLine is absent or ours (any command that runs
# statusline.py — legacy `python3 ~/...`, a hand-edited absolute path, ...).
# A user's own statusLine is never touched, whatever its shape (with a
# command, command-less, even a bare string).
if jq -e '.statusLine' "$SETTINGS" >/dev/null 2>&1; then
  cur=$(jq -r '.statusLine.command? // ""' "$SETTINGS" 2>/dev/null) || cur=""
  case "$cur" in *statusline.py*) ;; *) exit 0 ;; esac
fi

PY=$(find_python) ||
  { echo "status line: no working python3 found — install Python 3 (or uv) and open a new session"; exit 1; }
CMD="\"$PY\" \"$SCRIPT\""
renders "$CMD" ||
  { echo "status line: '$CMD' renders nothing — not wiring a broken statusLine"; exit 1; }
# refreshInterval keeps the ↻ reset countdowns live between events.
WANT=$(jq -n --arg c "$CMD" '{type: "command", command: $c, refreshInterval: 60}')

jq -e --argjson want "$WANT" '.statusLine == $want' "$SETTINGS" >/dev/null 2>&1 && exit 0
TMP="$SETTINGS.tmp.$$"
if jq --argjson want "$WANT" '.statusLine = $want' "$SETTINGS" >"$TMP" 2>/dev/null && [ -s "$TMP" ]; then
  mv "$TMP" "$SETTINGS"
else
  rm -f "$TMP" # unparseable settings — leave them untouched
fi
exit 0
