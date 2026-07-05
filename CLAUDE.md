# claude-dev-kit — Claude Code

Shared, tool-agnostic context lives in `AGENTS.md` (imported below). This file
holds only Claude-specific notes.

@AGENTS.md

## Notes for Claude

- This repo IS the dev-kit, so dogfood it: keep `CHANGELOG.md` current under
  `[Unreleased]`, and follow the same conventions the kit ships.
- The `scaffold.sh` hook skips this repo (it has `.claude-plugin/marketplace.json`),
  so standard project files here are maintained by hand, not auto-generated.
- When finishing a task, state what changed and what you did NOT do.
