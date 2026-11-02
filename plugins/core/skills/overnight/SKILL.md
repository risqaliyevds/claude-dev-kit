---
name: overnight
description: Run a long unattended agent loop (gnhf) toward a verifiable objective, with hard caps on iterations and tokens, in its own worktree - for overnight work such as raising test coverage, cutting load time, or fixing usability problems one by one. "review" summarizes a finished run.
disable-model-invocation: true
argument-hint: "[objective] | review"
---

$ARGUMENTS

Overnight runs use gnhf, which the kit's machine sync installs. Each iteration
is a fresh `claude -p` that takes the smallest verifiable step, commits it on
a `gnhf/` branch when it works, rolls it back when it fails, and leaves notes
for the next iteration. It stops at the caps, at the stop condition, or after
3 failures in a row.

## `review`

Find the latest run (`git branch --list 'gnhf/*' --sort=-committerdate`; its
`notes.md` and `end-state.json` are under `.gnhf/runs/` in that checkout).
List each commit in one line, run the tests on the branch, read the notes, and
recommend which commits to keep. Keeping means cherry-picking them onto a
fresh branch and running `/core:ship`; never merge a gnhf branch wholesale.

## Start a run

1. **Make the objective checkable.** Restate it with a stop condition: a
   metric threshold, a test suite going green, or "no new problem of kind X
   after N tries". If mine is vague, propose a measurable version and ask
   once. Good fits: performance targets, coverage, a lint or type error count,
   a usability sweep with a persona and a task ("as a 7-year-old, use the app
   end to end, fix the first thing that confuses you, repeat").
2. **Preflight.** `gnhf --version` works (if not, tell me to run the kit's
   machine sync); the working tree is clean; the current branch is not a
   `gnhf/` branch (`--worktree` needs that).
3. **Permissions.** gnhf gives `claude` `--dangerously-skip-permissions` unless
   a permission flag is configured. Make sure `~/.gnhf/config.yml` contains:

   ```yaml
   agentArgsOverride:
     claude:
       - --permission-mode
       - auto
   ```

   Show me the change before writing it. Auto mode lets routine edits and
   commands through and blocks risky actions, which an unattended run needs.
   If auto mode is unavailable on my plan, stop and tell me; never fall back
   to skipping permissions silently.
4. **Caps.** Always pass `--max-iterations` and `--max-tokens` (defaults: 30
   iterations, 5000000 tokens; lower them when the status line shows little
   weekly quota left), `--max-rate-limit-wait 2h` and `--stop-when "<condition>"`.
5. **Launch** in its own terminal tab so it outlives this session, with
   telemetry off. Write the command to `tmp/overnight/<slug>.sh`:

   ```sh
   export GNHF_TELEMETRY=0
   cd "<repo>"
   gnhf --worktree --max-iterations 30 --max-tokens 5000000 \
     --max-rate-limit-wait 2h --stop-when "<condition>" "<objective>"
   ```

   - Windows: `wt.exe -w 0 new-tab --title overnight "<git-bash.exe>" -l "<script>"`,
     where `<git-bash.exe>` is `cygpath -w "$(command -v bash)"` (Git Bash,
     not WSL's `bash.exe`).
   - macOS / Linux: `tmux new-session -d -s overnight "sh <script>"`.
   - Otherwise print the command for me to run.
6. **Hand over.** Tell me where to watch (the gnhf screen in that tab,
   `git log gnhf/<slug>`) and to run `/core:overnight review` when it ends.
