#!/usr/bin/env sh
# Test runner for the dev-kit: static checks + every tests/test_* file.
# Zero dependencies beyond git, sh, python3 (jq recommended). Usage: sh tests/run.sh
set -u
cd "$(dirname "$0")/.." || exit 1

FAIL=0
check() { # check <description> <command...>
  desc=$1
  shift
  if out=$("$@" 2>&1); then
    printf 'PASS %s\n' "$desc"
  else
    printf 'FAIL %s\n%s\n' "$desc" "$out"
    FAIL=1
  fi
}

# Static checks cover tracked AND new (untracked, unignored) files.
files() { git ls-files -c -o --exclude-standard "$1"; }

# Split ls-files output on newlines only, and don't re-glob it — filenames
# with spaces or wildcards must survive the for-loops below.
OLDIFS=$IFS
IFS='
'
set -f

# Static: every JSON file parses.
for f in $(files '*.json'); do
  check "json parses: $f" python3 -m json.tool "$f"
done

# Static: every shell script has valid syntax.
for f in $(files '*.sh'); do
  check "sh syntax:   $f" sh -n "$f"
done

# Static: shellcheck when available (CI runners always have it; locally it is
# optional, so its absence is reported but not fatal).
if command -v shellcheck >/dev/null 2>&1; then
  for f in $(files '*.sh'); do
    check "shellcheck:  $f" shellcheck "$f"
  done
else
  printf 'SKIP shellcheck (not installed)\n'
fi

set +f
IFS=$OLDIFS

# Static: personalization survives; no {{PLACEHOLDERS}} in functional files.
check "personalization intact" sh -c '
  grep -q risqaliyevds install.sh &&
  grep -q risqaliyevds plugins/core/skills/new-project/templates/settings.json &&
  grep -q Murod .claude-plugin/marketplace.json &&
  ! grep -q "{{" install.sh .claude-plugin/marketplace.json \
    plugins/core/.claude-plugin/plugin.json \
    plugins/core/skills/new-project/templates/settings.json'

# Behavior suites.
for t in tests/test_*.sh; do check "$t" sh "$t"; done
for t in tests/test_*.py; do check "$t" python3 "$t"; done

if [ "$FAIL" -eq 0 ]; then echo "ALL PASS"; else echo "FAILURES"; fi
exit "$FAIL"
