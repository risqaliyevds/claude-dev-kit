---
name: release
description: Cut a new release - move Unreleased changelog entries under a version heading, bump the version, commit, and tag.
disable-model-invocation: true
argument-hint: "[version, e.g. 1.4.0]"
allowed-tools: Read, Edit, Bash(git status *), Bash(git diff *), Bash(git log *), Bash(git add *), Bash(git commit *), Bash(git tag *)
---

Cut release $ARGUMENTS. If no version was given, propose one (semver, judged from the `[Unreleased]` entries: breaking = major, features = minor, fixes only = patch) and confirm with me before continuing.

Steps:

1. Verify the working tree is clean with `git status`. If it is not, stop and list what is uncommitted.
2. In `CHANGELOG.md`, rename `[Unreleased]` to `[<version>] - <today's date YYYY-MM-DD>` and insert a fresh empty `[Unreleased]` section above it.
3. If the project has a version field (`package.json`, `pyproject.toml`, `Cargo.toml`, ...), update it to match.
4. Commit with message `chore(release): v<version>`.
5. Create an annotated tag `v<version>` using this version's changelog entries as the tag message.
6. Show me the result. Ask before pushing; push with `git push --follow-tags` only after I confirm.
