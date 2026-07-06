#!/usr/bin/env python3
"""Docs freshness: repo paths referenced in the root docs must exist.

This is the mechanical half of the "docs are code" convention — renaming or
deleting a file without updating every doc that mentions it turns the suite
red. (The semantic half — stale claims about behavior — is /core:docs-sync.)

Checked: backtick-quoted tokens under the prefixes below, resolved against
the repo root and against plugins/core/ (docs often reference plugin files
relative to the plugin). `docs/...` is deliberately NOT checked: those
references describe the convention layout for scaffolded projects, not this
repo.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
DOCS = ["README.md", "AGENTS.md", "CLAUDE.md"]
PREFIXES = (
    "plugins/",
    "tests/",
    ".claude-plugin/",
    ".github/",
    "hooks/",
    "skills/",
    "agents/",
    "statusline/",
)
TOKEN = re.compile(r"`([A-Za-z0-9_.\-/]+)`")

bad = []
for doc in DOCS:
    for match in TOKEN.finditer((ROOT / doc).read_text(encoding="utf-8")):
        path = match.group(1)
        if not path.startswith(PREFIXES):
            continue
        if not ((ROOT / path).exists() or (ROOT / "plugins/core" / path).exists()):
            bad.append(f"{doc} references a path that does not exist: `{path}`")

# Inventory completeness: every shipped skill must be named in AGENTS.md's
# Layout section (path checks can't catch a skill that exists but was never
# added to the list — that omission is how doc rot starts).
agents_md = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
for skill_dir in sorted((ROOT / "plugins/core/skills").iterdir()):
    if skill_dir.is_dir() and skill_dir.name not in agents_md:
        bad.append(f"AGENTS.md does not mention shipped skill: {skill_dir.name}")

if bad:
    print("\n".join(bad))
    print("\nUpdate or delete the stale doc reference (docs are code).")
sys.exit(1 if bad else 0)
