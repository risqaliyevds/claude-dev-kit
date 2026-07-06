#!/usr/bin/env sh
# Install the kit status line at user scope (~/.claude), idempotently.
# Called from two places so one run of either fully fixes the status bar:
#   - install.sh (one-time machine setup, from the repo checkout)
#   - hooks/scaffold.sh (SessionStart, from the installed plugin — this also
#     re-syncs the script and settings after every kit update)
# Safe by design: syncs the script only when content differs, rewrites the
# statusLine setting only when it is missing or already ours (a user's custom
# statusLine is never touched), and never installs output it cannot parse.
set -u

SRC="$(dirname "$0")/statusline.py"
[ -f "$SRC" ] || exit 0

DST_DIR="$HOME/.claude"
DST="$DST_DIR/statusline.py"
mkdir -p "$DST_DIR" 2>/dev/null || exit 0

# The plugin copy is the source of truth — customize it in the kit repo,
# not by editing ~/.claude/statusline.py (edits there get overwritten).
if ! cmp -s "$SRC" "$DST" 2>/dev/null; then
  cp "$SRC" "$DST" 2>/dev/null || exit 0
fi

command -v jq >/dev/null 2>&1 || exit 0
SETTINGS="$DST_DIR/settings.json"
# Missing or 0-byte settings both mean "no settings yet" — seed {} (jq treats
# an empty file as zero documents and would silently produce empty output).
[ -s "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"

OURS='python3 ~/.claude/statusline.py'
# refreshInterval keeps the ↻ reset countdowns live between events.
WANT='{"type": "command", "command": "python3 ~/.claude/statusline.py", "refreshInterval": 60}'

# Wire only when statusLine is absent or already ours — kit upgrades apply
# automatically, a user's own statusLine is never touched, whatever its
# shape (with a command, command-less, even a bare string).
if jq -e '.statusLine' "$SETTINGS" >/dev/null 2>&1; then
  cur=$(jq -r '.statusLine.command? // ""' "$SETTINGS" 2>/dev/null) || cur=""
  [ "$cur" = "$OURS" ] || exit 0
fi
jq -e --argjson want "$WANT" '.statusLine == $want' "$SETTINGS" >/dev/null 2>&1 && exit 0

TMP="$SETTINGS.tmp.$$"
if jq --argjson want "$WANT" '.statusLine = $want' "$SETTINGS" >"$TMP" 2>/dev/null && [ -s "$TMP" ]; then
  mv "$TMP" "$SETTINGS"
else
  rm -f "$TMP" # unparseable settings — leave them untouched
fi
exit 0
