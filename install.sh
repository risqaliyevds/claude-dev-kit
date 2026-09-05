#!/usr/bin/env bash
# One-time machine setup for the dev-kit.
# 1) Push this repo to GitHub   2) edit REPO below   3) run ./install.sh
set -euo pipefail

REPO="risqaliyevds/claude-dev-kit"   # <-- change me

echo ">> Adding marketplace: $REPO"
claude plugin marketplace add "$REPO"

echo ">> Installing 'core' plugin at user scope (available in every project)"
claude plugin install core@dev-kit

echo ">> Installing companion: Ponytail (anti-over-engineering; needs node on PATH)"
claude plugin marketplace add DietrichGebert/ponytail
claude plugin install ponytail@ponytail

echo ">> Installing companion: UI/UX Pro Max (design intelligence; needs Python 3)"
npm install -g ui-ux-pro-max-cli
uipro init --ai claude --global

echo ">> Installing companion: ECC (agent harness: 68 agents, 286 skills, hooks; needs Node 18+)"
# marketplace add fails when the marketplace already exists; that is fine.
claude plugin marketplace add affaan-m/ECC || true
# user scope only — never also enable ecc@ecc at project scope (ECC's setup
# refuses two scopes, and both copies of its hooks would run).
claude plugin install ecc@ecc --scope user \
  --config hooks_enabled=true --config hook_profile=standard
echo ">> Installing ECC rule packs (plugins cannot ship rules) to ~/.claude/rules/ecc"
sh "$(dirname "$0")/plugins/core/scripts/ecc-rules.sh"

echo ">> Setting up the status line (user scope: ~/.claude; needs jq to wire settings.json)"
command -v jq >/dev/null 2>&1 || echo "   WARNING: jq not found - script installed, statusLine not wired"
sh "$(dirname "$0")/plugins/core/statusline/setup.sh"

echo ">> Done. Open any project, run 'claude', then try: /core:new-project"
