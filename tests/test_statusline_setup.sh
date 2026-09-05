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
# The renderer's WLF lookup resolves ~/.claude via Path.home(), which on
# Windows reads USERPROFILE, not HOME — pin it so tests never touch the real
# credentials/cache or the network.
CLAUDE_CONFIG_DIR="$HOME/.claude"
export CLAUDE_CONFIG_DIR
mkdir -p "$HOME"
SETTINGS="$HOME/.claude/settings.json"

cmd() { jq -r '.statusLine.command' "$SETTINGS"; }
# The contract: the wired command must actually render — that is the whole
# point (a wired-but-broken statusLine shows nothing AND hides footer hints).
renders() { printf '{}' | sh -c "$(cmd)" 2>/dev/null | grep -q 'Model:'; }

# 1. Fresh machine: installs the script and wires a statusLine whose command
#    runs a VERIFIED interpreter against ~/.claude/statusline.py, with
#    refreshInterval so the ↻ reset countdowns stay live between events.
sh "$SETUP"
cmp -s "$SRC" "$HOME/.claude/statusline.py" || { echo "statusline.py not installed"; exit 1; }
[ "$(jq -r '.statusLine.type' "$SETTINGS")" = "command" ] || { echo "statusLine not wired"; exit 1; }
case "$(cmd)" in *'/.claude/statusline.py"') ;; *) echo "command does not run <home>/.claude/statusline.py: $(cmd)"; exit 1 ;; esac
# No `~` and no backslashes anywhere: PowerShell/cmd.exe do not expand `~`
# for a native exe argument, and Git Bash eats unquoted backslashes.
BS=$(printf '\134')
case "$(cmd)" in *'~'*|*"$BS"*) echo "command must be absolute forward-slash paths: $(cmd)"; exit 1 ;; esac
[ "$(jq -r '.statusLine.refreshInterval' "$SETTINGS")" = "60" ] ||
  { echo "statusLine.refreshInterval not 60"; exit 1; }
renders || { echo "wired command does not render: $(cmd)"; exit 1; }

# 2. Idempotent: a second run leaves settings byte-identical and prints nothing
#    (the SessionStart hook forwards stdout into the session — stay quiet when
#    healthy).
before=$(cat "$SETTINGS")
out=$(sh "$SETUP")
[ "$before" = "$(cat "$SETTINGS")" ] || { echo "second run changed settings"; exit 1; }
[ -z "$out" ] || { echo "healthy run was not silent: $out"; exit 1; }

# 3. Respects a user's own statusLine and preserves unrelated keys.
printf '{"model": "opusplan", "statusLine": {"type": "command", "command": "my-own"}}\n' >"$SETTINGS"
sh "$SETUP"
[ "$(cmd)" = "my-own" ] || { echo "clobbered existing statusLine"; exit 1; }
[ "$(jq -r '.model' "$SETTINGS")" = "opusplan" ] || { echo "lost unrelated settings key"; exit 1; }

# 3a. A custom statusLine WITHOUT a command key (static/other schema) is a
#     user choice too — present means never touched, whatever its shape.
printf '{"statusLine": {"type": "static", "text": "mine"}}\n' >"$SETTINGS"
sh "$SETUP"
[ "$(jq -r '.statusLine.text' "$SETTINGS")" = "mine" ] || { echo "clobbered command-less statusLine"; exit 1; }
printf '{"statusLine": "custom-string"}\n' >"$SETTINGS"
sh "$SETUP"
[ "$(jq -r '.statusLine' "$SETTINGS")" = "custom-string" ] || { echo "clobbered string statusLine"; exit 1; }

# 3b. Repairs a statusLine that is OURS (any command mentioning statusline.py:
#     the legacy `python3 ~/...` form, a hand-edited absolute path, ...) to the
#     current, verified spec — kit updates must reach already-wired machines,
#     and a stale interpreter path must self-heal.
for legacy in 'python3 ~/.claude/statusline.py' '"C:/gone/python.exe" "C:/Users/x/.claude/statusline.py"'; do
  jq -n --arg c "$legacy" '{model: "opusplan", statusLine: {type: "command", command: $c}}' >"$SETTINGS"
  sh "$SETUP"
  [ "$(jq -r '.statusLine.refreshInterval' "$SETTINGS")" = "60" ] ||
    { echo "did not upgrade our own legacy statusLine ($legacy)"; exit 1; }
  renders || { echo "repaired command does not render ($legacy -> $(cmd))"; exit 1; }
  [ "$(jq -r '.model' "$SETTINGS")" = "opusplan" ] || { echo "upgrade lost unrelated key"; exit 1; }
done

# 3c. The Windows case: `python3`/`python` on PATH are Microsoft Store stubs
#     (no stdout, exit 49). setup.sh must skip them and still wire a command
#     that renders via a real interpreter found later in the candidate list.
#     `python3` is a stub; `python` is a real interpreter (a wrapper around
#     whichever one this box has), so the candidate order is exercised.
REAL=$(python3 -c 'import sys; print(sys.executable)' 2>/dev/null ||
  py -3 -c 'import sys; print(sys.executable)' 2>/dev/null)
STUB="$TMP/stub"; mkdir -p "$STUB"
printf '#!/bin/sh\necho "Python was not found" >&2\nexit 49\n' >"$STUB/python3"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$REAL" >"$STUB/python"
chmod +x "$STUB"/*
rm -f "$SETTINGS"
PATH="$STUB:$PATH" sh "$SETUP"
case "$(cmd)" in *"$STUB"*) echo "wired a Store stub: $(cmd)"; exit 1 ;; esac
renders || { echo "Store-stub PATH: wired command does not render: $(cmd)"; exit 1; }

# 3d. No interpreter at all (every candidate is a stub): script copied,
#     statusLine NOT wired (a broken custom statusLine hides the footer hints),
#     and one diagnostic line on stdout so the SessionStart hook surfaces it.
for n in python3 python py uv; do
  printf '#!/bin/sh\necho "Python was not found" >&2\nexit 49\n' >"$STUB/$n"; chmod +x "$STUB/$n"
done
rm -f "$SETTINGS"
out=$(PATH="$STUB:$PATH" sh "$SETUP" || true)
[ "$(jq -r '.statusLine // "none"' "$SETTINGS" 2>/dev/null || echo none)" = "none" ] ||
  { echo "wired a statusLine with no interpreter"; exit 1; }
case "$out" in *"status line"*) ;; *) echo "no diagnostic when no interpreter found: '$out'"; exit 1 ;; esac

# 3e. An interpreter that RUNS but cannot render the script (broken install,
#     wrong runtime) must not be wired either — the render check is the gate.
# shellcheck disable=SC2016 # literal $1/$0 belong to the stub
printf '#!/bin/sh\ncase "$1" in -c) echo "$0" ;; *) exit 0 ;; esac\n' >"$STUB/python3"
rm -f "$SETTINGS"
out=$(PATH="$STUB:$PATH" sh "$SETUP" || true)
[ "$(jq -r '.statusLine // "none"' "$SETTINGS")" = "none" ] ||
  { echo "wired a non-rendering command: $(cmd)"; exit 1; }
case "$out" in *"renders nothing"*) ;; *) echo "no diagnostic for non-rendering command: '$out'"; exit 1 ;; esac

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

# 8. --check: read-only health report — exit 0 when the bar renders, 1 when
#    not, and never modifies settings.
rm -f "$SETTINGS"; sh "$SETUP"
sh "$SETUP" --check >/dev/null || { echo "--check failed on a healthy install"; exit 1; }
jq '.statusLine.command = "\"C:/gone/python.exe\" ~/.claude/statusline.py"' "$SETTINGS" >"$SETTINGS.n" && mv "$SETTINGS.n" "$SETTINGS"
if sh "$SETUP" --check >/dev/null; then echo "--check passed on a broken command"; exit 1; fi
[ "$(cmd)" = '"C:/gone/python.exe" ~/.claude/statusline.py' ] || { echo "--check must not modify settings"; exit 1; }

echo OK
