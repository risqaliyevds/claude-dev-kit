---
name: commit
description: Stage and commit current changes with a Conventional Commits message, updating the changelog first when appropriate.
disable-model-invocation: true
allowed-tools: Bash(git status *), Bash(git diff *), Bash(git add *), Bash(git commit *), Bash(git log *)
---

## Current changes

!`git status --short`

## Task

1. Review the changes above; use `git diff` for details.
2. If this is a user-visible feature, fix, or behavior change and `CHANGELOG.md` has not been updated for it, update the `[Unreleased]` section first (same conventions as the changelog skill).
3. Stage the relevant files. Never stage `.env` files, credentials, or other secrets.
4. Commit using Conventional Commits: `type(scope): summary`, where type is one of feat, fix, docs, style, refactor, perf, test, build, ci, chore. Imperative mood, summary <= 72 characters. Add a body only when the "why" is not obvious from the summary.
5. One logical change per commit. If the diff mixes unrelated changes, propose a split into multiple commits and ask me.
6. Do not push unless I explicitly ask.
