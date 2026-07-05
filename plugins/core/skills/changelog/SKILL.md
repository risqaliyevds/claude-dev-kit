---
name: changelog
description: Update CHANGELOG.md with recent changes in Keep a Changelog format. Use after completing a feature, fix, or refactor, when the user asks to update the changelog, or before committing significant work.
allowed-tools: Read, Edit, Write, Bash(git status *), Bash(git diff *), Bash(git log *)
---

## Current repository state

Status: !`git status --short 2>/dev/null || echo "not a git repo"`

Recent commits: !`git log --oneline -8 2>/dev/null || echo "no commits yet"`

Change summary: !`git diff --stat HEAD 2>/dev/null | tail -6`

## Task

Update `CHANGELOG.md` in the project root:

1. If `CHANGELOG.md` does not exist, create it in [Keep a Changelog](https://keepachangelog.com) format with an `[Unreleased]` section.
2. Add entries for the recent work under `[Unreleased]`, grouped as `### Added`, `### Changed`, `### Fixed`, `### Removed`, `### Security` — create only the groups you need.
3. Write for humans reading release notes: one line per entry, imperative mood, user-visible impact rather than file names. Good: "Add dark-mode toggle to the settings page". Bad: "modified settings.tsx".
4. Never delete or rewrite entries under already-released version headings.
5. Only describe changes actually visible in the diff/commits or done in this conversation — never invent work.

If nothing has changed since the last changelog update, say so and stop.
