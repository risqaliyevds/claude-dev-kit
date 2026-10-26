#!/usr/bin/env bash
# One-time machine setup for the dev-kit.
# 1) Push this repo to GitHub   2) edit REPO below   3) run ./install.sh
# Everything is done by plugins/core/scripts/sync-machine.sh — the same
# idempotent sync /core:init-dev-kit runs later to keep the machine current:
# marketplaces, core + Ponytail + pyright-lsp (user scope), pyright and
# UI/UX Pro Max (npm), ECC rule packs (rules only — the ecc@ecc plugin cost
# ~45k tokens every session), model routing, status line.
# Needs: git, jq, Node.js 18+ (npm), Python 3, the claude CLI.
set -euo pipefail

REPO="risqaliyevds/claude-dev-kit"   # <-- change me

KIT_REPO="$REPO" sh "$(dirname "$0")/plugins/core/scripts/sync-machine.sh" || {
  echo ">> Some steps failed (FAILED lines above). Fix them and re-run ./install.sh — it is idempotent."
  exit 1
}

echo ">> Done. Open any project, run 'claude', then try: /core:new-project"
