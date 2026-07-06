#!/usr/bin/env sh
# Meta-test: the suite must KILL every mutant in this catalog (suite exits
# nonzero on the mutated tree). A SURVIVED result means an assertion decayed
# into a code-mirror — strengthen the TEST, never delete the mutant. A STALE
# result means the mutation no longer matches the code — update the sed.
# Slow (one full suite run per mutant), so CI runs it weekly, not per push:
#   sh tests/mutants.sh
# shellcheck disable=SC2016  # mutant sed scripts quote literal $vars on purpose
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FAIL=0

mutant() { # mutant <description> <file> <sed-script>
  desc=$1 file=$2 script=$3
  T=$(mktemp -d)
  git -C "$ROOT" checkout-index -a --prefix="$T/"
  git -C "$T" init -q && git -C "$T" add -A
  # Portable in-place edit (BSD sed's -i differs): write aside, then move.
  sed "$script" "$T/$file" >"$T/mutated" || { echo "BROKEN sed for: $desc"; FAIL=1; rm -rf "$T"; return; }
  if cmp -s "$T/$file" "$T/mutated"; then
    printf 'STALE    %s (mutation no longer applies)\n' "$desc"
    FAIL=1
    rm -rf "$T"
    return
  fi
  mv "$T/mutated" "$T/$file"
  if (cd "$T" && sh tests/run.sh) >/dev/null 2>&1; then
    printf 'SURVIVED %s\n' "$desc"
    FAIL=1
  else
    printf 'KILLED   %s\n' "$desc"
  fi
  rm -rf "$T"
}

mutant "scaffold creates 0-byte files instead of copying templates" \
  plugins/core/hooks/scaffold.sh \
  's|cp "$TPL/$1" "$2" 2>/dev/null|: >"$2" 2>/dev/null|'

mutant "scaffold overwrites files that already exist" \
  plugins/core/hooks/scaffold.sh \
  's|\[ -f "$2" \] && return 0||'

mutant ".python-version leaks into Node-only repos" \
  plugins/core/hooks/scaffold.sh \
  's|if \[ -f pyproject.toml \]|if [ -f pyproject.toml ] \|\| [ -f package.json ]|'

mutant "setup.sh clobbers a user's custom statusLine" \
  plugins/core/statusline/setup.sh \
  's@\[ "$cur" = "$OURS" \] || exit 0@true@'

mutant "status bar loses proportionality (over-filled bar)" \
  plugins/core/statusline/statusline.py \
  's|fill = int(round(pct / 100.0 \* BARS))|fill = min(BARS, int(round(pct / 100.0 * BARS)) + 2)|'

mutant "gauge width changes from the 10-cell contract" \
  plugins/core/statusline/statusline.py \
  's|^BARS = 10|BARS = 20|'

mutant "healthy usage renders blue instead of green" \
  plugins/core/statusline/statusline.py \
  's|\\033\[32m|\\033[34m|'

mutant "BY DOMAIN counts occurrences instead of unique links" \
  plugins/core/skills/report-verify/scripts/extract_links.py \
  's|for u in unique$|for u in urls|'

if [ "$FAIL" -eq 0 ]; then echo "ALL MUTANTS KILLED"; else echo "SUITE TOO WEAK (or catalog stale)"; fi
exit "$FAIL"
