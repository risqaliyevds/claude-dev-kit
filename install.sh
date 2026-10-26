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

# ECC is used for its rules only: the ecc@ecc plugin's 387 skills + 68 agent
# descriptions cost ~45k tokens every session and crowd the kit's own skills
# out of the listing budget.
echo ">> Installing ECC rule packs (security, git, python, dart) to ~/.claude/rules/ecc"
sh "$(dirname "$0")/plugins/core/scripts/ecc-rules.sh"

echo ">> Installing Python code intelligence: pyright-lsp (live type errors, go-to-definition)"
npm install -g pyright || echo "   WARNING: pyright not installed - pyright-lsp needs pyright-langserver on PATH"
claude plugin install pyright-lsp@claude-plugins-official --scope user ||
  echo "   WARNING: pyright-lsp not installed (is the claude-plugins-official marketplace added?)"

echo ">> Pinning model routing (Opus 5.5 everywhere, Sonnet 5.5 for coding) in ~/.claude/settings.json"
sh "$(dirname "$0")/plugins/core/scripts/model-routing.sh" || echo "   WARNING: model routing not set (needs jq)"

echo ">> Setting up the status line (user scope: ~/.claude; needs jq to wire settings.json)"
command -v jq >/dev/null 2>&1 || echo "   WARNING: jq not found - script installed, statusLine not wired"
sh "$(dirname "$0")/plugins/core/statusline/setup.sh"

echo ">> Done. Open any project, run 'claude', then try: /core:new-project"
