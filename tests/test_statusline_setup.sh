#!/usr/bin/env sh
# Behavior tests for statusline/setup.sh against a sandboxed $HOME.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SETUP="$ROOT/plugins/core/statusline/setup.sh"
SRC="$ROOT/plugins/core/statusline/statusline.py"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed"; exit 0; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
HOME="$TMP/home"
export HOME
mkdir -p "$HOME"
SETTINGS="$HOME/.claude/settings.json"

# 1. Fresh machine: installs the script and wires the exact statusLine command,
#    with refreshInterval so the ↻ reset countdowns stay live between events.
sh "$SETUP"
cmp -s "$SRC" "$HOME/.claude/statusline.py" || { echo "statusline.py not installed"; exit 1; }
[ "$(jq -r '.statusLine.type' "$SETTINGS")" = "command" ] || { echo "statusLine not wired"; exit 1; }
[ "$(jq -r '.statusLine.command' "$SETTINGS")" = "python3 ~/.claude/statusline.py" ] ||
  { echo "statusLine.command wrong: $(jq -r '.statusLine.command' "$SETTINGS")"; exit 1; }
[ "$(jq -r '.statusLine.refreshInterval' "$SETTINGS")" = "60" ] ||
  { echo "statusLine.refreshInterval not 60"; exit 1; }

# 2. Idempotent: a second run leaves settings byte-identical.
before=$(cat "$SETTINGS")
sh "$SETUP"
[ "$before" = "$(cat "$SETTINGS")" ] || { echo "second run changed settings"; exit 1; }

# 3. Respects a user's own statusLine and preserves unrelated keys.
printf '{"model": "opusplan", "statusLine": {"type": "command", "command": "my-own"}}\n' >"$SETTINGS"
sh "$SETUP"
[ "$(jq -r '.statusLine.command' "$SETTINGS")" = "my-own" ] || { echo "clobbered existing statusLine"; exit 1; }
[ "$(jq -r '.model' "$SETTINGS")" = "opusplan" ] || { echo "lost unrelated settings key"; exit 1; }

# 3a. A custom statusLine WITHOUT a command key (static/other schema) is a
#     user choice too — present means never touched, whatever its shape.
printf '{"statusLine": {"type": "static", "text": "mine"}}\n' >"$SETTINGS"
sh "$SETUP"
[ "$(jq -r '.statusLine.text' "$SETTINGS")" = "mine" ] || { echo "clobbered command-less statusLine"; exit 1; }
printf '{"statusLine": "custom-string"}\n' >"$SETTINGS"
sh "$SETUP"
[ "$(jq -r '.statusLine' "$SETTINGS")" = "custom-string" ] || { echo "clobbered string statusLine"; exit 1; }

# 3b. Upgrades a statusLine that is OURS (recognized by the command) to the
#     current spec — kit updates must reach already-wired machines.
printf '{"model": "opusplan", "statusLine": {"type": "command", "command": "python3 ~/.claude/statusline.py"}}\n' >"$SETTINGS"
sh "$SETUP"
[ "$(jq -r '.statusLine.refreshInterval' "$SETTINGS")" = "60" ] ||
  { echo "did not upgrade our own legacy statusLine"; exit 1; }
[ "$(jq -r '.model' "$SETTINGS")" = "opusplan" ] || { echo "upgrade lost unrelated key"; exit 1; }

# 4. Re-syncs the script when the installed copy drifts from the plugin copy.
printf 'drifted\n' >"$HOME/.claude/statusline.py"
sh "$SETUP"
cmp -s "$SRC" "$HOME/.claude/statusline.py" || { echo "drifted script not re-synced"; exit 1; }

# 5. Unparseable settings.json is left exactly as-is (never clobbered).
printf '{broken\n' >"$SETTINGS"
sh "$SETUP"
[ "$(cat "$SETTINGS")" = "{broken" ] || { echo "rewrote unparseable settings"; exit 1; }

# 6. A 0-byte settings.json heals to {} + statusLine (jq emits empty output
#    for empty input, which must not be installed as the new settings).
: >"$SETTINGS"
sh "$SETUP"
[ "$(jq -r '.statusLine.type' "$SETTINGS")" = "command" ] || { echo "empty settings not healed"; exit 1; }

# 7. Whitespace-only settings.json is unparseable-ish: left untouched, never
#    replaced by jq's empty output.
printf '  \n' >"$SETTINGS"
sh "$SETUP"
[ "$(cat "$SETTINGS")" = "  " ] || { echo "clobbered whitespace-only settings"; exit 1; }

echo OK
