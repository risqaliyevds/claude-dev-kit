---
name: ship
description: Take finished work all the way to a verified PR (or a push to main where the repo says so) - intent, rebase, fresh-context review with auto-fixes, tests plus end-to-end evidence, docs and changelog, push, CI babysitting, risk level. Use only when the user, or the prompt that started this session, asks to ship, raise a PR, or run the pipeline.
argument-hint: "[intent: what this change should do]"
---

Ship the current work: $ARGUMENTS

You are the pipeline between "the agent says it is done" and "a human decides".
The result must be trustworthy from its summary and risk level alone, so the
user only reads diffs that deserve it. Never merge: the user merges.

**0. Guard and preflight.**
- Continue only if the user, or the prompt that started this session, asked to
  ship, raise a PR or run the pipeline. Otherwise stop and ask.
- Mode: push to the default branch only if `AGENTS.md` or `CLAUDE.md` has a
  line that is exactly `Ship: main`, nothing else on it
  (`grep -qxF 'Ship: main' AGENTS.md CLAUDE.md`). Otherwise, and whenever in
  doubt, branch + PR.
- Check `git status`, `git remote -v`, the default branch
  (`git symbolic-ref --short refs/remotes/origin/HEAD`) and, in PR mode,
  `gh auth status`. If something is missing, stop with the exact fix.

**1. Intent.** In 2-4 lines: what the change does, why, and the acceptance
checks that prove it works. Take it from `$ARGUMENTS`, else from this session
and the diff. If you cannot state it without guessing, ask once. Every later
step is judged against this intent.

**2. Branch and commit.** In PR mode on the default branch, create
`<type>/<short-slug>` (feat, fix, chore...). Commit the work with a
Conventional Commits message so later steps have a fixed base. Check
`git diff --cached --stat` first: never commit `.env` files or secrets.

**3. Sync.** `git fetch origin`, then rebase onto `origin/<default>`. Resolve
conflicts keeping both sides' intent. A conflict that is a product decision
(two behaviors that cannot both hold) goes to the user.

**4. Review in a fresh context.** Launch the `core:code-reviewer` agent with
the intent and the base `origin/<default>`. It returns findings tagged
`auto-fix` or `ask-user` and a risk level.
- Apply every `auto-fix`, commit, and send only the new delta back for review.
  At most 3 rounds; anything still open after that becomes `ask-user`.
- Collect the `ask-user` findings; never decide them yourself.

**5. Verify against the intent.**
- Run the project's test, lint and type-check commands (from `AGENTS.md` or
  the package files). Fix failures this change caused. A failure that was
  already there gets reported, never hidden.
- Prove each acceptance check end to end, the way a user meets the change:
  run the CLI, call the endpoint, drive the UI (browser tool or screenshots
  for visual changes). Unit tests alone are not evidence of the intent.
- Save evidence under `tmp/ship/<slug>/` (gitignored): each command with the
  output lines that matter, and screenshots for visual changes. `gh` cannot
  attach images, so the PR carries the text evidence and says where the
  screenshots are.

**6. Docs.** Update every doc that describes behavior this change touched
(the `/core:docs-sync` rules) and add a `CHANGELOG.md` `[Unreleased]` entry
for user-visible changes (the `/core:changelog` format). Commit.

**7. Decisions.** If any `ask-user` findings exist, stop and ask them all at
once (AskUserQuestion, your recommendation first). Apply the answers, then
repeat steps 4-6 on the delta.

**8. Publish.**
- PR mode: `git push -u origin <branch>`, then `gh pr create` with the body:

  ```
  ## Intent
  ## What changed
  ## How it was verified      (commands + key output; where screenshots are)
  ## What the pipeline caught (fixed findings, one line each)
  ## Risk: low|medium|high    (why; what a reviewer should look at)
  ```

- `Ship: main` mode: fetch again, rebase if main moved, rerun the tests, then
  `git push origin HEAD:<default>`.

**9. Babysit CI.**
- PR mode: `gh pr checks <pr> --watch`.
- `Ship: main` mode: `gh run list --branch <default> --limit 1`, then
  `gh run watch <id> --exit-status`.
- On a failure: `gh run view <id> --log-failed`, fix the cause, commit, push,
  watch again. At most 3 attempts, then report.
- If the PR gets merge conflicts: rebase and `git push --force-with-lease` on
  the PR branch. Never force-push the default branch.

**10. Report** in five lines: link (PR or commit), risk with its reason, what
the pipeline fixed, the evidence, and what still needs the user. Then say how
much attention it deserves:
- **low**: read this summary and merge.
- **medium**: read the PR body and the files the risk line names.
- **high**: review the full diff before merging.

Never merge. Never get a gate green by deleting, skipping or weakening a test.
