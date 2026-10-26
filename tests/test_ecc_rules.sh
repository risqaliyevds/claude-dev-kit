#!/usr/bin/env sh
# Behavior tests for scripts/ecc-rules.sh against a fixture ECC tree and a
# sandboxed config dir (no network, no real ~/.claude).
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/plugins/core/scripts/ecc-rules.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
CLAUDE_CONFIG_DIR="$TMP/cfg"
export CLAUDE_CONFIG_DIR
DST="$CLAUDE_CONFIG_DIR/rules/ecc"

# Fixture: the parts of an ECC checkout the script reads.
ECC="$TMP/ecc"
for d in common python dart web; do mkdir -p "$ECC/rules/$d"; done
for f in coding-style security testing hooks agents git-workflow performance development-workflow code-review patterns; do
  printf '# %s\n' "$f" >"$ECC/rules/common/$f.md"
done
printf '# fastapi\n' >"$ECC/rules/python/fastapi.md"
printf '# hooks\n' >"$ECC/rules/python/hooks.md"
printf '# dart\n' >"$ECC/rules/dart/coding-style.md"
printf '# web\n' >"$ECC/rules/web/coding-style.md"

# A previous run's copy of a common rule the kit no longer ships (it loads
# every session, so it must be removed, not just left un-refreshed).
mkdir -p "$DST/common"
printf '# stale
' >"$DST/common/performance.md"

# 1. common: only security + git-workflow (the rest is always-loaded cost that
#    restates defaults or contradicts Ponytail/the kit). Language packs are
#    path-scoped, so they are copied whole. Unselected packs are left alone.
sh "$SCRIPT" "$ECC" >/dev/null
for want in common/security.md common/git-workflow.md python/fastapi.md dart/coding-style.md 00-precedence.md; do
  [ -f "$DST/$want" ] || { echo "missing $want"; exit 1; }
done
for skip in coding-style testing hooks agents performance development-workflow code-review patterns; do
  [ ! -f "$DST/common/$skip.md" ] || { echo "should not have common/$skip.md"; exit 1; }
done
[ ! -f "$DST/web/coding-style.md" ] || { echo "copied an unselected pack"; exit 1; }
# hooks.md/agents.md describe ECC's manual install, in every pack.
[ ! -f "$DST/python/hooks.md" ] || { echo "copied python/hooks.md"; exit 1; }
# The ECC plugin is not installed, so rules naming its agents/skills must be
# mapped to what the kit ships, or the model goes looking for them.
grep -q "core:code-reviewer" "$DST/00-precedence.md" || { echo "precedence rule lacks the ECC-agent mapping"; exit 1; }
grep -q "Ponytail" "$DST/00-precedence.md" || { echo "precedence rule lacks Ponytail clause"; exit 1; }
# Model policy: Opus 5.5 everywhere except coding (Sonnet 5.5), never Haiku.
# It must live in the generated file, or every re-run of the script erases it.
for want in "Model policy" "claude-opus-5-5" "claude-sonnet-5-5" "Never pick Haiku"; do
  grep -q "$want" "$DST/00-precedence.md" || { echo "precedence rule lacks model policy: $want"; exit 1; }
done

# 2. Idempotent and refreshing: a changed upstream file is re-copied, and the
#    tree is otherwise identical after a second run.
printf '# security v2\n' >"$ECC/rules/common/security.md"
before=$(find "$DST" -name '*.md' | sort)
sh "$SCRIPT" "$ECC" >/dev/null
[ "$before" = "$(find "$DST" -name '*.md' | sort)" ] || { echo "second run changed the file set"; exit 1; }
grep -q "v2" "$DST/common/security.md" || { echo "did not refresh a changed rule"; exit 1; }

# 3. A checkout without rules/common is rejected, and nothing is written.
rm -rf "$CLAUDE_CONFIG_DIR"
if sh "$SCRIPT" "$TMP" >/dev/null 2>&1; then echo "accepted a non-ECC dir"; exit 1; fi
[ ! -d "$DST" ] || { echo "wrote rules from a non-ECC dir"; exit 1; }

# 4. install.sh: ECC ships as rules only (its plugin cost ~45k tokens every
#    session), and Python gets the official LSP plugin for real diagnostics.
if grep -qE '^[^#]*plugin install ecc@ecc' "$ROOT/install.sh"; then echo "install.sh still installs the ECC plugin"; exit 1; fi
grep -qE '^[^#]*plugin install pyright-lsp@claude-plugins-official' "$ROOT/install.sh" || { echo "install.sh does not install pyright-lsp"; exit 1; }
grep -q 'ecc-rules.sh' "$ROOT/install.sh" || { echo "install.sh no longer installs the ECC rules"; exit 1; }

echo OK
