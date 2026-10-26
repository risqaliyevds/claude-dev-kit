#!/usr/bin/env sh
# Install ECC's rule packs at user scope (~/.claude/rules/ecc). The kit uses
# ECC for its rules only — not the ecc@ecc plugin, whose 387 skills and 68
# agent descriptions cost ~45k tokens every session. Rules are copied from a
# checkout (https://github.com/affaan-m/ECC#claude-code-details).
#
# Usage: ecc-rules.sh [ecc-checkout-dir]   (no arg = shallow-clone to a temp dir)
# Idempotent: each pack dir is managed — re-running replaces it, so files a
# previous run or an older upstream left behind are removed. Edit PACKS to add
# a stack (one dir name under ECC's rules/, e.g. typescript, web, golang).
set -eu

PACKS="common python dart"
# Language packs are path-scoped (they load only for matching files), so they
# are copied whole. common/ loads in EVERY session, and most of it restates
# model defaults or contradicts this kit (Haiku workers, mandatory subagent
# review/planning, 80% coverage + E2E everywhere, many-small-files, the
# manual-install hooks.md/agents.md). Only these common files are kept:
COMMON_KEEP="security.md git-workflow.md"
# Every pack's hooks.md/agents.md describes ECC's manual-copy install (hook
# setup to configure, agents in ~/.claude/agents), not how to write code.
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
  rm -rf "${DST:?}/$pack"
  mkdir -p "$DST/$pack"
  for f in "$SRC/rules/$pack"/*.md; do
    [ -e "$f" ] || continue   # empty pack: the glob stays literal
    base=$(basename "$f")
    case " $SKIP " in *" $base "*) continue ;; esac
    if [ "$pack" = common ]; then
      case " $COMMON_KEEP " in *" $base "*) ;; *) continue ;; esac
    fi
    cp "$f" "$DST/$pack/$base"
  done
done

# Ponytail and ECC's language rules disagree on breadth, and the kept rules
# name ECC agents/skills the kit does not install. Settle both once.
cat > "$DST/00-precedence.md" <<'EOF'
# Rule precedence (dev-kit)

When Ponytail is active, its ladder wins over ECC rules on file count,
abstraction breadth, error-handling breadth, and immutability: write the
shortest working diff. ECC rules on security and git workflow stand as written.

The ECC plugin is not installed — only its rules. Where a rule names an ECC
agent or skill (`security-reviewer`, `code-reviewer`, `python-reviewer`,
`tdd-guide`, `planner`, "See skill: ..."), use what the kit ships instead:
`core:code-reviewer` for any review (security included), `/core:plan` for
planning, and the `core:fastapi` / `core:flutter` / `core:senior-engineer`
standards for stack patterns.

## Model policy (overrides any model-tier hint from a rule, skill or plugin)

Opus 5.5 (`claude-opus-5-5`) for everything except coding: Plan Mode,
research, review, the advisor, every subagent and every workflow `agent()`
call. Coding — the main thread outside Plan Mode under `opusplan` — runs on
Sonnet 5.5 (`claude-sonnet-5-5`). Never pick Haiku or Fable for a worker, even
when a rule, skill or `[INTELLIGENCE]`/routing hint suggests another tier; pass
`model: "opus"` where a call takes a model. Enforced in
`~/.claude/settings.json` by the kit's `model-routing.sh` (`model`,
`advisorModel`, `CLAUDE_CODE_SUBAGENT_MODEL`, `ANTHROPIC_DEFAULT_*_MODEL`);
`CLAUDE_CODE_SUBAGENT_MODEL` overrides an agent file's `model: sonnet`. For a
session that is mostly non-coding, `/model opus` keeps the main thread on Opus.
EOF

echo "ecc-rules: installed $(find "$DST" -name '*.md' | wc -l | tr -d ' ') rule files to $DST"
