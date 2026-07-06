---
name: docs-sync
description: Audit every doc against the current code and fix the drift - update stale claims, delete dead ones, archive finished plans. Use when docs mention removed features, wrong paths/commands, or old behavior.
disable-model-invocation: true
argument-hint: "[optional: a specific doc or folder to audit]"
---

Bring the documentation in sync with the code. Audit "$ARGUMENTS" if given,
otherwise everything: `README.md`, `AGENTS.md`, `CLAUDE.md`, all of `docs/`,
and (in a plugin repo) every skill/agent description.

1. Build ground truth FIRST, from the code only — never from other docs:
   the repo's real commands, entry points, file layout, config keys, flags,
   and behaviors. Run `--help`s and read the source where cheap.

2. Read every target doc and classify EVERY checkable claim:
   - **CURRENT** — matches the code. Leave it.
   - **STALE** — behavior/path/command changed. Rewrite to match reality.
   - **DEAD** — the feature, file, or flow no longer exists. Delete the
     passage (or the whole doc). Never leave "deprecated, see below" residue —
     dead text misleads faster than missing text.
   - **UNVERIFIABLE** — can't be checked against code (business context,
     history). Leave, but flag it to me if it smells wrong.

3. Plans get lifecycle treatment, not editing:
   - `docs/plans/PLAN.md` / `TASKS.md` for finished work → move to
     `docs/plans/archive/<date>-<slug>.md` (`git mv`), so the active plan
     files only ever describe live work.
   - Plans superseded by a newer decision → archive with a one-line header
     saying what replaced them.

4. Show me ONE consolidated table — `doc → claim → verdict → proposed fix` —
   before editing anything. Apply only after I approve. Then:
   - Update `CHANGELOG.md` `[Unreleased]` if any user-facing doc changed
     meaningfully.
   - If the repo has a docs test (this kit ships `tests/test_docs.py`),
     run the test suite to confirm no reference went dangling.

5. Wrap up by stating how many claims were checked, and the counts per
   verdict — including zero counts, so "nothing was stale" is a real finding.
