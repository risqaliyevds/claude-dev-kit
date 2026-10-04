#!/usr/bin/env sh
# Pin the kit's model routing at user scope: Opus 5.5 for everything except
# coding, which runs on Sonnet 5.5.
#   model opusplan              Plan Mode on Opus, execution (coding) on Sonnet
#   advisorModel                Sonnet consults Opus 5.5 mid-task
#   ANTHROPIC_DEFAULT_*_MODEL   opus/sonnet aliases → 5.5; haiku alias → Opus
#   CLAUDE_CODE_SUBAGENT_MODEL  every subagent on Opus 5.5
#   effortLevel high            also inside modelSettings entries, where a
#                               per-model value would beat the top-level one
# Merges only these keys into settings.json; everything else is kept. Run by
# install.sh and /core:init-dev-kit only — never every session (that would
# undo /model and /effort choices).
# Usage: model-routing.sh   (honors CLAUDE_CONFIG_DIR; needs jq)
set -eu

OPUS="claude-opus-5-5"
SONNET="claude-sonnet-5-5"
SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"

command -v jq >/dev/null 2>&1 || { echo "model-routing: jq not found — settings unchanged" >&2; exit 1; }
mkdir -p "$(dirname "$SETTINGS")"
# Missing or 0-byte settings = no settings yet (jq emits nothing for an empty file).
[ -s "$SETTINGS" ] || printf '{}\n' >"$SETTINGS"

TMP="$SETTINGS.tmp.$$"
if jq --arg o "$OPUS" --arg s "$SONNET" '
  .model = "opusplan" | .advisorModel = $o | .effortLevel = "high" |
  (if .modelSettings then .modelSettings[] |= (
    if type == "object" and has("effortLevel") then .effortLevel = "high" else . end
  ) else . end) |
  .env = ((.env // {}) + {
    ANTHROPIC_DEFAULT_OPUS_MODEL: $o,
    ANTHROPIC_DEFAULT_SONNET_MODEL: $s,
    ANTHROPIC_DEFAULT_HAIKU_MODEL: $o,
    CLAUDE_CODE_SUBAGENT_MODEL: $o
  })' "$SETTINGS" >"$TMP" 2>/dev/null && [ -s "$TMP" ]; then
  mv "$TMP" "$SETTINGS"
else
  rm -f "$TMP"
  echo "model-routing: $SETTINGS is not valid JSON — left untouched" >&2
  exit 1
fi
echo "model-routing: Opus 5.5 everywhere, Sonnet 5.5 for coding, effort high → $SETTINGS"
