# claude-dev-kit

My personal Claude Code setup, packaged as a **plugin marketplace**. Install it once per machine and every skill, agent, and hook is available in every project — no copying files around.

## What's inside (plugin: `core`)

| Component | Type | What it does |
|---|---|---|
| `/core:changelog` | skill (auto + manual) | Updates `CHANGELOG.md` in Keep a Changelog format from your actual git changes |
| `/core:release <version>` | skill (manual only) | Moves `[Unreleased]` under a version heading, bumps version, commits, tags |
| `/core:commit` | skill (manual only) | Conventional Commits workflow; checks the changelog first |
| `/core:new-project` | skill (manual only) | Bootstraps CHANGELOG.md, CLAUDE.md, `.claude/settings.json`, `.gitignore` in a fresh repo |
| `/core:plan <task>` | skill (manual, runs on `best` alias) | Deep research + implementation plan on the strong model; code gets written only after you confirm |
| `senior-engineer` | skill (background) | Engineering discipline applied to all code changes |
| `ai-engineer` | skill (background) | Conventions for LLM/agent code (keys, retries, structured output, evals) |
| `fastapi` | skill (background) | FastAPI/Python backend rules: async SQLAlchemy 2.x, Pydantic v2, layered architecture |
| `flutter` | skill (background) | Flutter/Dart rules: Material 3, one state-management approach, go_router, widget/golden tests |
| `code-reviewer` | subagent | Reviews diffs for bugs, security, and maintainability |
| `researcher` | subagent (`best` alias) | Heavy investigation in an isolated context; returns a concise brief instead of flooding your session |
| auto-format | hook | Runs project-local Prettier on every file Claude writes/edits (no-op if absent) |

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

## Updating the kit

Edit skills, commit, push. No `version` field is set on purpose: every commit counts as a new version, so machines with marketplace auto-update enabled pick changes up automatically. Otherwise run `/plugin marketplace update dev-kit`.

## Developing / testing changes locally

```bash
claude --plugin-dir ./plugins/core   # load without installing
claude plugin validate .             # check marketplace + plugin schemas
```

Inside a session, `/reload-plugins` picks up edits without restarting.
