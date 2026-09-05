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
for f in coding-style security testing hooks agents; do printf '# %s\n' "$f" >"$ECC/rules/common/$f.md"; done
printf '# fastapi\n' >"$ECC/rules/python/fastapi.md"
printf '# dart\n' >"$ECC/rules/dart/coding-style.md"
printf '# web\n' >"$ECC/rules/web/coding-style.md"

# 1. Copies the selected packs, skips the two install-mode-specific files, and
#    leaves packs that are not selected alone.
sh "$SCRIPT" "$ECC" >/dev/null
for want in common/coding-style.md common/security.md common/testing.md python/fastapi.md dart/coding-style.md 00-precedence.md; do
  [ -f "$DST/$want" ] || { echo "missing $want"; exit 1; }
done
for skip in common/hooks.md common/agents.md web/coding-style.md; do
  [ ! -f "$DST/$skip" ] || { echo "should not have copied $skip"; exit 1; }
done
grep -q "Ponytail" "$DST/00-precedence.md" || { echo "precedence rule lacks Ponytail clause"; exit 1; }

# 2. Idempotent and refreshing: a changed upstream file is re-copied, and the
#    tree is otherwise identical after a second run.
printf '# coding-style v2\n' >"$ECC/rules/common/coding-style.md"
before=$(find "$DST" -name '*.md' | sort)
sh "$SCRIPT" "$ECC" >/dev/null
[ "$before" = "$(find "$DST" -name '*.md' | sort)" ] || { echo "second run changed the file set"; exit 1; }
grep -q "v2" "$DST/common/coding-style.md" || { echo "did not refresh a changed rule"; exit 1; }

# 3. A checkout without rules/common is rejected, and nothing is written.
rm -rf "$CLAUDE_CONFIG_DIR"
if sh "$SCRIPT" "$TMP" >/dev/null 2>&1; then echo "accepted a non-ECC dir"; exit 1; fi
[ ! -d "$DST" ] || { echo "wrote rules from a non-ECC dir"; exit 1; }

echo OK
