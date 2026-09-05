#!/usr/bin/env sh
# Install ECC's always-loaded rule packs at user scope (~/.claude/rules/ecc).
# Claude Code plugins cannot distribute `rules`, so the ecc@ecc plugin gives
# skills/agents/commands/hooks and this script adds the rules by copying them
# (https://github.com/affaan-m/ECC#claude-code-details).
#
# Usage: ecc-rules.sh [ecc-checkout-dir]   (no arg = shallow-clone to a temp dir)
# Idempotent: re-running refreshes the copies. Edit PACKS to add a stack
# (one dir name under ECC's rules/, e.g. typescript, web, golang).
set -eu

PACKS="common python dart"
# Two common files are written for ECC's manual-copy install and contradict
# this kit's setup: hooks.md ("never use dangerously-skip-permissions" — we run
# bypass mode) and agents.md ("agents live in ~/.claude/agents", "use the
# planner agent unprompted" — false under a plugin install, and the kit forbids
# unrequested subagents). Everything else is copied.
SKIP="hooks.md agents.md"

DST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/rules/ecc"
SRC="${1:-}"
TMP=""
if [ -z "$SRC" ]; then
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  git clone -q --depth 1 https://github.com/affaan-m/ECC.git "$TMP/ecc"
  SRC="$TMP/ecc"
fi
[ -d "$SRC/rules/common" ] || { echo "ecc-rules: $SRC has no rules/common" >&2; exit 1; }

for pack in $PACKS; do
  [ -d "$SRC/rules/$pack" ] || { echo "ecc-rules: pack '$pack' not in $SRC/rules — skipped" >&2; continue; }
  mkdir -p "$DST/$pack"
  for f in "$SRC/rules/$pack"/*.md; do
    base=$(basename "$f")
    case " $SKIP " in *" $base "*) continue ;; esac
    cp "$f" "$DST/$pack/$base"
  done
done

# Ponytail and ECC's coding-style disagree on breadth (many small files,
# comprehensive error handling, immutability everywhere). Settle it once.
cat > "$DST/00-precedence.md" <<'EOF'
# Rule precedence (dev-kit)

When Ponytail is active, its ladder wins over ECC coding-style on file count,
abstraction breadth, error-handling breadth, and immutability: write the
shortest working diff. ECC rules on security, testing, git workflow, code
review, and performance stand as written.
EOF

echo "ecc-rules: installed $(find "$DST" -name '*.md' | wc -l | tr -d ' ') rule files to $DST"
