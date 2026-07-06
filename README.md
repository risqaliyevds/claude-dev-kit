# claude-dev-kit

My personal Claude Code setup, packaged as a **plugin marketplace**. Install it once per machine and every skill, agent, and hook is available in every project — no copying files around.

## What's inside (plugin: `core`)

| Component | Type | What it does |
|---|---|---|
| `/core:init-dev-kit` | skill (manual only) | Onboards an existing repo: pulls the latest kit, scaffolds every standard file, reorganizes the tree into the convention folders, and formats |
| `/core:changelog` | skill (auto + manual) | Updates `CHANGELOG.md` in Keep a Changelog format from your actual git changes |
| `/core:release <version>` | skill (manual only) | Moves `[Unreleased]` under a version heading, bumps version, commits, tags |
| `/core:commit` | skill (manual only) | Conventional Commits workflow; checks the changelog first |
| `/core:new-project` | skill (manual only) | Bootstraps CHANGELOG.md, CLAUDE.md, `.claude/settings.json`, `.gitignore` in a fresh repo |
| `/core:plan <task>` | skill (manual, runs on `best` alias) | Deep research + implementation plan on the strong model; code gets written only after you confirm |
| `/core:announcement` | skill (manual only) | Drafts internal Telegram announcements in Uzbek in the house style — deadline explicit, clear action, purposeful emojis |
| `/core:report-verify <file>` | skill (manual, + bundled script) | Extracts every hyperlink from a report (.docx/.html/.md/.txt), groups by domain, cross-checks against declared figures |
| `/core:docs-sync` | skill (manual only) | Audits every doc against the current code: updates stale claims, deletes dead ones, archives finished plans |
| `nlp` | skill (background) | NLP conventions: leakage-safe splits, uz/ru script handling, tokenizer fertility checks, metric-first evaluation |
| `evals` | skill (background) | Eval-first harness for any LLM feature: cases.jsonl → runner → baseline → delta reporting |
| `senior-engineer` | skill (background) | Engineering discipline applied to all code changes |
| `ai-engineer` | skill (background) | Conventions for LLM/agent code (keys, retries, structured output, evals) |
| `fastapi` | skill (background) | FastAPI/Python backend rules: async SQLAlchemy 2.x, Pydantic v2, layered architecture |
| `flutter` | skill (background) | Flutter/Dart rules: Material 3, one state-management approach, go_router, widget/golden tests |
| `code-reviewer` | subagent | Reviews diffs for bugs, security, and maintainability |
| `researcher` | subagent (`best` alias) | Heavy investigation in an isolated context; returns a concise brief instead of flooding your session |
| auto-format | hook | Runs project-local Prettier on every file Claude writes/edits (no-op if absent) |
| scaffold | hook | SessionStart: creates any missing standard project file in every git repo (create-if-missing; plugin repos skipped) |
| status line | script + hook | Rate-limit status bar (model, context %, 5-hour 📊 and weekly 📅 usage with reset countdowns); installed at user scope by `install.sh` and self-healed every session by the SessionStart hook |

## Model routing

All four models, each in its lane (ships in the project settings template):

- `"model": "opusplan"` — **Opus 4.8 plans** (Plan Mode), **Sonnet 5 codes** (execution switches automatically; Sonnet 5 runs a native 1M-token context window)
- `"advisorModel": "opus"` — while coding, Sonnet 5 consults **Opus 4.8** mid-task when it decides it needs deeper reasoning
- `/core:plan` and the `researcher` agent run on the `best` alias — **Fable 5** where your org has access, otherwise Opus 4.8
- `/model fable` — put an entire hard, long-running task on **Fable 5**; when its safety classifiers flag a request (mostly cyber/bio content), Claude Code automatically re-runs it on **Opus 4.8** and continues there

Requires Claude Code v2.1.197+ (`claude update`). `/model opusplan` returns to the hybrid; `/effort` tunes reasoning depth; typing `ultrathink` in any prompt requests one-off deeper reasoning. Do NOT remap `ANTHROPIC_DEFAULT_OPUS_MODEL` to Fable — that breaks Fable's automatic Opus fallback.

`install.sh` also installs two external companions: [Ponytail](https://github.com/DietrichGebert/ponytail) (`ponytail@ponytail`) — anti-over-engineering discipline whose `/ponytail-review` makes a good final pass on any diff (requires Node.js) — and [UI/UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) installed globally via `uipro init --ai claude --global` — a design-intelligence engine (67 UI styles, 161 industry reasoning rules, 161 palettes, 57 font pairings, 22 stacks incl. React Native and Flutter) that generates a full design system before writing UI code (requires Python 3). The `senior-engineer` skill leaves YAGNI/minimalism to Ponytail, and this kit no longer ships a `ui-ux` skill — Pro Max replaces it entirely.

## One-time setup (per machine)

1. Push this repo to GitHub. (If you forked it, replace `risqaliyevds` in `install.sh` and `plugins/core/skills/new-project/templates/settings.json` with your own username.)
2. Run:

```bash
./install.sh
```

or manually, inside Claude Code:

```
/plugin marketplace add risqaliyevds/claude-dev-kit
/plugin install core@dev-kit
```

Installing at **user scope** (the default) makes it available in all your projects.

## Starting a new project

```bash
mkdir my-app && cd my-app
claude
> /core:new-project my-app
```

`/core:new-project` is the full interactive bootstrap (git init, fills in
`CLAUDE.md`, makes the first commit). You rarely need to run it by hand,
though: a `SessionStart` hook (`hooks/scaffold.sh`) **auto-creates any
missing standard files** the first time you open Claude Code in a git repo:

- Always: `CHANGELOG.md`, `AGENTS.md`, `CLAUDE.md`, `README.md`, `.gitignore`,
  `.gitattributes`, `.editorconfig`, `.env.example`, `.claude/settings.json`
- Node projects only (`package.json` present): `.nvmrc`
- Python projects only (`pyproject.toml`/`setup.py`/`setup.cfg`/`requirements.txt`): `.python-version`

`.nvmrc` and `.python-version` are stack-gated on purpose — an unconditional
`.python-version` makes pyenv switch versions in every directory that has it,
so forcing it into unrelated repos would break their toolchains. To make them
unconditional anyway, drop the `if [ -f ... ]` guards in `hooks/scaffold.sh`.

The hook only runs inside a git work tree and never overwrites an existing
file, so it is safe in established projects and idempotent across sessions.
Don't want it in a particular repo? Delete the files after they appear and
they will be recreated next session — to opt a repo out permanently, disable
the `core` plugin there or remove the `SessionStart` hook.

## Updating the kit

Edit skills, commit, push. No `version` field is set on purpose: every commit counts as a new version, so machines with marketplace auto-update enabled pick changes up automatically. Otherwise run `/plugin marketplace update dev-kit`.

## Status line

`plugins/core/statusline/statusline.py` renders
`🧠 Model • CTX ████░ 40% 80k/200k • 📊 HL 12% ↻ 2h 10m • 📅 WL 85% ↻ 2d 3h`
from the real rate-limit JSON Claude Code passes on stdin (v2.1.80+, Pro/Max).
`setup.sh` installs it to `~/.claude/statusline.py` and wires `statusLine`
into `~/.claude/settings.json` with `refreshInterval: 60`, so the reset
countdowns tick even while the session is idle. It never touches a
`statusLine` you configured yourself, but upgrades one it recognizes as its
own — kit updates reach already-wired machines automatically.
Wiring the settings requires `jq` (the hooks already depend on it); without
`jq` the script is copied but `settings.json` is left alone — install jq and
open one more session to finish.
It runs from `install.sh` **and** from the SessionStart hook, so opening any
session installs it and re-syncs it after kit updates. To customize it, edit
the copy in this repo (edits to `~/.claude/statusline.py` are overwritten).

## Developing / testing changes locally

```bash
sh tests/run.sh                      # full test suite (sh + python3, no deps)
sh tests/mutants.sh                  # mutation audit: suite must kill each mutant
claude --plugin-dir ./plugins/core   # load without installing
claude plugin validate .             # check marketplace + plugin schemas
```

The suite covers the scaffold hook (throwaway git repos), statusline setup
(sandboxed `$HOME`), the statusline renderer (including a golden test against
the documented example payload), `extract_links.py`, plus JSON validity,
shell syntax, shellcheck (when installed), docs-path freshness, and
personalization guards. CI runs it on Ubuntu **and** macOS on every push,
validates the plugin schemas headlessly, and re-runs the mutation catalog
weekly. Inside a session, `/reload-plugins` picks up edits without restarting.
