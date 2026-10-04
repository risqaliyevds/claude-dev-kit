#!/usr/bin/env sh
# Model routing contract: Opus 5.5 for everything except coding, which runs on
# Sonnet 5.5. Covers scripts/model-routing.sh (user-scope settings, sandboxed
# via CLAUDE_CONFIG_DIR) and the routing the kit ships in its own files.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/plugins/core/scripts/model-routing.sh"

# 1. Shipped files: the project template routes via aliases (they resolve
#    through the user-scope pins), and every kit agent/skill that pins a model
#    pins Opus — a reviewer on `inherit` would drop to Sonnet while coding.
grep -q '"model": "opusplan"' "$ROOT/plugins/core/skills/new-project/templates/settings.json" ||
  { echo "template lost model: opusplan"; exit 1; }
grep -q '"advisorModel": "opus"' "$ROOT/plugins/core/skills/new-project/templates/settings.json" ||
  { echo "template lost advisorModel: opus"; exit 1; }
for f in agents/researcher.md agents/code-reviewer.md skills/plan/SKILL.md; do
  grep -qx 'model: opus' "$ROOT/plugins/core/$f" || { echo "$f is not pinned to model: opus"; exit 1; }
done

# 1b. /core:init-dev-kit brings the machine up to date too: it updates the
#     installed plugin (a marketplace refresh alone leaves the old version
#     installed) and applies the routing via a path that really resolves.
INIT="$ROOT/plugins/core/skills/init-dev-kit/SKILL.md"
grep -q 'claude plugin update core@dev-kit' "$INIT" || { echo "init-dev-kit does not update the installed plugin"; exit 1; }
# shellcheck disable=SC2016 # ${CLAUDE_SKILL_DIR} is the literal text in the skill
ref=$(grep -o '\${CLAUDE_SKILL_DIR}/[^ `"]*model-routing\.sh' "$INIT" | head -1)
[ -n "$ref" ] || { echo "init-dev-kit does not run model-routing.sh"; exit 1; }
SKILL_DIR="$ROOT/plugins/core/skills/init-dev-kit"
[ -f "$(printf '%s' "$ref" | sed "s|\${CLAUDE_SKILL_DIR}|$SKILL_DIR|")" ] ||
  { echo "init-dev-kit references a missing script: $ref"; exit 1; }

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed"; exit 0; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
CLAUDE_CONFIG_DIR="$TMP/cfg"
export CLAUDE_CONFIG_DIR
SETTINGS="$CLAUDE_CONFIG_DIR/settings.json"
get() { jq -r "$1" "$SETTINGS"; }

routed() {
  [ "$(get .model)" = "opusplan" ] || { echo "model is $(get .model)"; return 1; }
  [ "$(get .advisorModel)" = "claude-opus-5-5" ] || { echo "advisorModel is $(get .advisorModel)"; return 1; }
  [ "$(get .env.ANTHROPIC_DEFAULT_OPUS_MODEL)" = "claude-opus-5-5" ] || { echo "opus alias not pinned"; return 1; }
  [ "$(get .env.ANTHROPIC_DEFAULT_SONNET_MODEL)" = "claude-sonnet-5-5" ] || { echo "coding is not on Sonnet 5.5"; return 1; }
  [ "$(get .env.ANTHROPIC_DEFAULT_HAIKU_MODEL)" = "claude-opus-5-5" ] || { echo "haiku alias not mapped to Opus"; return 1; }
  [ "$(get .env.CLAUDE_CODE_SUBAGENT_MODEL)" = "claude-opus-5-5" ] || { echo "subagents not on Opus"; return 1; }
  [ "$(get .effortLevel)" = "high" ] || { echo "effortLevel is $(get .effortLevel), want high"; return 1; }
}

# 2. Fresh machine (no config dir, no settings): creates them, fully routed,
#    without inventing keys it has nothing to put in.
sh "$SCRIPT" >/dev/null
routed
[ "$(get 'has("modelSettings")')" = "false" ] || { echo "created a modelSettings key"; exit 1; }

# 3. Existing settings: routing keys are overwritten (an old all-Opus remap of
#    the sonnet alias is fixed; xhigh effort — top-level or per-model, which
#    would silently beat the top-level value — drops to high), every unrelated
#    key and env var survives.
cat >"$SETTINGS" <<'EOF'
{"model": "claude-opus-5-5", "effortLevel": "xhigh",
 "modelSettings": {"claude-opus-5-5": {"effortLevel": "xhigh", "keep": 1}},
 "statusLine": {"type": "command", "command": "my-own"},
 "env": {"FOO": "bar", "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-opus-5-5"}}
EOF
sh "$SCRIPT" >/dev/null
routed
[ "$(get .env.FOO)" = "bar" ] || { echo "lost unrelated env var"; exit 1; }
[ "$(get .statusLine.command)" = "my-own" ] || { echo "lost statusLine"; exit 1; }
[ "$(get '.modelSettings["claude-opus-5-5"].effortLevel')" = "high" ] || { echo "per-model effort not set to high"; exit 1; }
[ "$(get '.modelSettings["claude-opus-5-5"].keep')" = "1" ] || { echo "lost other modelSettings keys"; exit 1; }

# 4. Idempotent: a second run changes nothing.
cp "$SETTINGS" "$TMP/before.json"
sh "$SCRIPT" >/dev/null
cmp -s "$SETTINGS" "$TMP/before.json" || { echo "second run changed settings"; exit 1; }

# 5. Unparseable settings: fails loudly and leaves the file untouched.
printf '{ not json' >"$SETTINGS"
if sh "$SCRIPT" >/dev/null 2>&1; then echo "accepted unparseable settings"; exit 1; fi
[ "$(cat "$SETTINGS")" = "{ not json" ] || { echo "rewrote unparseable settings"; exit 1; }

echo OK
