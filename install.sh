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

echo ">> Done. Open any project, run 'claude', then try: /core:new-project"
