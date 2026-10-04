# claude-dev-kit

My personal Claude Code setup, packaged as a **plugin marketplace**. Install it
once per machine and every skill, agent, hook, rule pack and the status line
is available in every project — no copying files around.

The kit is one `core` plugin plus three curated companions (ECC, Ponytail,
UI/UX Pro Max), a rate-limit status line, and a test suite that keeps all of
it honest.

## Contents

- [What you get](#what-you-get)
- [How it fits together](#how-it-fits-together)
- [One-time setup (per machine)](#one-time-setup-per-machine)
- [Daily workflow](#daily-workflow)
- [The `core` plugin](#the-core-plugin)
- [Companions](#companions)
- [Model routing](#model-routing)
- [Status line](#status-line)
- [Updating the kit](#updating-the-kit)
- [Developing / testing changes locally](#developing--testing-changes-locally)
- [Troubleshooting](#troubleshooting)

## What you get

Inventory of everything enabled on a machine after `./install.sh`
(measured with `claude plugin list` + a file count on this machine):

| Plugin | Skills | Agents | Commands | Hooks | Role |
|---|---|---|---|---|---|
| `ecc@ecc` | 293 | 68 | 94 | 24 | Agent harness: planners, reviewers, TDD, session memory, lifecycle hooks |
| `core@dev-kit` | 15 | 2 | 0 | 2 | This kit: house conventions, scaffolding, changelog/commit/release flow |
| `ponytail@ponytail` | 6 | 0 | 0 | 0 | Anti-over-engineering discipline (YAGNI ladder) |
| `figma@claude-plugins-official` | 14 | 0 | 0 | 0 | Figma design-to-code (optional, not installed by `install.sh`) |
| ruflo (33 plugins) | 126 | 55 | 47 | 8 | Swarm/memory/observability tooling (optional, not installed by `install.sh`) |
| **Total** | **454** | **125** | **141** | **34** | |

Outside plugins, the kit also lays down: 18 ECC rule files in
`~/.claude/rules/ecc/` (always loaded), the status line script in
`~/.claude/statusline.py`, and UI/UX Pro Max as a global skill.

Context cost, measured with `claude -p "reply ok" --output-format json`:
`core` + Ponytail alone put the system prompt at ~43k tokens; ECC plus its
rule packs add ~16k (→ ~59k). The ruflo family adds more still — trim it
first if context gets tight.

## How it fits together

```
install.sh (once per machine)
├─ marketplace dev-kit  → plugin core@dev-kit      (user scope)
├─ marketplace ponytail → plugin ponytail@ponytail (user scope)
├─ marketplace ecc      → plugin ecc@ecc           (user scope, hook_profile=standard)
├─ ecc-rules.sh         → ~/.claude/rules/ecc/     (common + python + dart, + precedence rule)
├─ model-routing.sh     → ~/.claude/settings.json  (Opus 5.5 everywhere, Sonnet 5.5 codes)
├─ uipro init --global  → UI/UX Pro Max skill
└─ statusline/setup.sh  → ~/.claude/statusline.py + settings.statusLine

every session (SessionStart hook, core plugin)
├─ scaffold.sh   creates missing standard files in any git repo
└─ setup.sh      re-syncs the status line and verifies it renders

every project
└─ .claude/settings.json (from template): marketplace + model routing only.
   Plugins are NEVER enabled per project — one plugin, one scope.
```

Layering of instructions inside a session, highest priority first:

1. Project `AGENTS.md` / `CLAUDE.md` (scaffolded by the kit, edited by you)
2. `~/.claude/rules/ecc/00-precedence.md` — Ponytail's ladder wins over ECC
   coding-style on file count, abstraction and error-handling breadth; the
   model policy wins over ECC/ruflo model-tier hints
3. ECC rule packs (security, testing, git workflow, patterns, performance)
4. Background skills from `core` (`senior-engineer`, `ai-engineer`, `fastapi`,
   `flutter`, `nlp`, `evals`) — loaded when relevant

## One-time setup (per machine)

Requirements: git, Node.js 18+ (Ponytail, ECC hooks), Python 3 (status line,
UI/UX Pro Max), `jq` (hooks and settings wiring), Claude Code 2.1+.

1. Push this repo to GitHub. (If you forked it, replace `risqaliyevds` in
   `install.sh` and `plugins/core/skills/new-project/templates/settings.json`
   with your own username.)
2. Run:

```bash
git clone https://github.com/risqaliyevds/claude-dev-kit.git
cd claude-dev-kit
./install.sh
```

or manually, inside Claude Code:

```
/plugin marketplace add risqaliyevds/claude-dev-kit
/plugin install core@dev-kit
```

Installing at **user scope** (the default) makes it available in all your
projects. Keep it there and nowhere else: the project `settings.json`
template only declares the marketplace on purpose. A second, project-scope
copy pins its own version and its stale SessionStart hook fights the
user-scope one (that is how the status line kept vanishing).
`claude plugin list` should show `core@dev-kit` and `ecc@ecc` exactly once
each.

Verify:

```bash
claude plugin list                                   # core@dev-kit, ecc@ecc, ponytail — user scope, once each
sh plugins/core/statusline/setup.sh --check          # status line: OK (...)
ls ~/.claude/rules/ecc                               # 00-precedence.md common/ python/ dart/
```

## Daily workflow

```bash
mkdir my-app && cd my-app
claude
> /core:new-project my-app        # optional: full interactive bootstrap
> /core:plan add user login       # research + plan on the strong model; persists docs/plans/
> ...code...
> /ponytail-review                # final pass: what can be deleted
> /core:changelog                 # keep [Unreleased] current
> /core:commit                    # Conventional Commit, changelog checked first
> /core:release 1.2.0             # when it is time to cut a version
```

You rarely need `/core:new-project` by hand: the `SessionStart` hook
(`hooks/scaffold.sh`) **auto-creates any missing standard files** the first
time you open Claude Code in a git repo:

- Always: `CHANGELOG.md`, `AGENTS.md`, `CLAUDE.md`, `README.md`,
  `.gitignore`, `.gitattributes`, `.editorconfig`, `.env.example`,
  `.claude/settings.json`
- Node projects only (`package.json` present): `.nvmrc`
- Python projects only (`pyproject.toml`/`setup.py`/`setup.cfg`/`requirements.txt`):
  `.python-version`

`.nvmrc` and `.python-version` are stack-gated on purpose — an unconditional
`.python-version` makes pyenv switch versions in every directory that has it,
so forcing it into unrelated repos would break their toolchains. To make them
unconditional anyway, drop the `if [ -f ... ]` guards in `hooks/scaffold.sh`.

The hook only runs inside a git work tree and never overwrites an existing
file, so it is safe in established projects and idempotent across sessions.
Don't want it in a particular repo? Delete the files after they appear and
they will be recreated next session — to opt a repo out permanently, disable
the `core` plugin there or remove the `SessionStart` hook.

Onboarding an existing repo: `/core:init-dev-kit` pulls and installs the
latest kit, re-applies the model routing (`plugins/core/scripts/model-routing.sh`),
scaffolds every missing standard file, triages loose root files into the
convention folders (`docs/`, `docs/plans/`, `scripts/`, `tmp/`), and
formats — one consolidated plan, confirmed before anything moves.

## The `core` plugin

| Component | Type | What it does |
|---|---|---|
| `/core:init-dev-kit` | skill (manual only) | Onboards an existing repo: pulls and installs the latest kit, re-applies model routing + effort, scaffolds every standard file, reorganizes the tree into the convention folders, and formats |
| `/core:changelog` | skill (auto + manual) | Updates `CHANGELOG.md` in Keep a Changelog format from your actual git changes |
| `/core:release <version>` | skill (manual only) | Moves `[Unreleased]` under a version heading, bumps version, commits, tags |
| `/core:commit` | skill (manual only) | Conventional Commits workflow; checks the changelog first |
| `/core:new-project` | skill (manual only) | Bootstraps CHANGELOG.md, CLAUDE.md, `.claude/settings.json`, `.gitignore` in a fresh repo |
| `/core:plan <task>` | skill (manual, runs on Opus 5.5) | Deep research + implementation plan on the strong model; code gets written only after you confirm |
| `/core:announcement` | skill (manual only) | Drafts internal Telegram announcements in Uzbek in the house style — deadline explicit, clear action, purposeful emojis |
| `/core:report-verify <file>` | skill (manual, + bundled script) | Extracts every hyperlink from a report (.docx/.html/.md/.txt), groups by domain, cross-checks against declared figures |
| `/core:docs-sync` | skill (manual only) | Audits every doc against the current code: updates stale claims, deletes dead ones, archives finished plans |
| `nlp` | skill (background) | NLP conventions: leakage-safe splits, uz/ru script handling, tokenizer fertility checks, metric-first evaluation |
| `evals` | skill (background) | Eval-first harness for any LLM feature: cases.jsonl → runner → baseline → delta reporting |
| `senior-engineer` | skill (background) | Engineering discipline applied to all code changes |
| `ai-engineer` | skill (background) | Conventions for LLM/agent code (keys, retries, structured output, evals) |
| `fastapi` | skill (background) | FastAPI/Python backend rules: async SQLAlchemy 2.x, Pydantic v2, layered architecture |
| `flutter` | skill (background) | Flutter/Dart rules: Material 3, one state-management approach, go_router, widget/golden tests |
| `code-reviewer` | subagent (Opus 5.5) | Reviews diffs for bugs, security, and maintainability |
| `researcher` | subagent (Opus 5.5) | Heavy investigation in an isolated context; returns a concise brief instead of flooding your session |
| auto-format | hook | Runs project-local Prettier on every file Claude writes/edits (no-op if absent) |
| scaffold | hook | SessionStart: creates any missing standard project file in every git repo (create-if-missing; plugin repos skipped) |
| status line | script + hook | Rate-limit status line (model, live effort level, context %, 5-hour 📊, weekly 📅 and weekly-Fable 🔮 usage % with reset countdowns; plain numbers, no gauges); installed at user scope by `install.sh` and self-healed every session by the SessionStart hook |
| ECC rules installer | script | `plugins/core/scripts/ecc-rules.sh` copies ECC's always-loaded rule packs to `~/.claude/rules/ecc/` and writes the precedence rule (Ponytail ladder + model policy) |
| model routing | script | `plugins/core/scripts/model-routing.sh` pins Opus 5.5 for everything except coding (Sonnet 5.5) in `~/.claude/settings.json`; run by `install.sh` |

Conventions the kit ships to every project (see the `AGENTS.md` template):
`AGENTS.md` holds the shared, tool-agnostic context and `CLAUDE.md` only
imports it; only `README`/`AGENTS`/`CLAUDE`/`CHANGELOG` + configs live at
the repo root (docs → `docs/`, plans → `docs/plans/`, scratch → `tmp/`);
tests are the spec; docs are code.

## Companions

### ECC — the agent harness

[ECC](https://github.com/affaan-m/ECC) (`ecc@ecc`, MIT) is the agent-harness
layer: 68 agents (planner, architect, security-reviewer, tdd-guide, language
reviewers), 293 on-demand skills, `/ecc:*` commands (`/ecc:plan`,
`/ecc:code-review`, `/ecc:harness-audit`, plus the `tdd-workflow` skill), and
lifecycle hooks (session memory under `~/.claude/sessions/`, pre-compact
state saving, pattern extraction, config protection, a fact-forcing gate on
the first edit of each file).

- `install.sh` installs it at **user scope only** with
  `hook_profile=standard`. ECC refuses a second scope, and two scopes would
  run its hooks twice — never add `ecc@ecc` to a project `settings.json`.
- Plugins cannot ship `rules`, so `plugins/core/scripts/ecc-rules.sh` copies
  ECC's always-loaded rule packs to `~/.claude/rules/ecc/`: `common` plus the
  packs matching this kit's stack skills, `python` (includes `fastapi.md`) and
  `dart`. Add a stack by adding its dir name to `PACKS` in that script.
- Two common files are skipped on purpose because they describe ECC's
  manual-copy install and contradict this setup: `hooks.md` (forbids
  bypass-permissions mode) and `agents.md` (claims agents live in
  `~/.claude/agents/` and tells Claude to spawn the planner unprompted).
- A generated `00-precedence.md` settles the one real conflict: Ponytail's
  ladder wins over ECC coding-style on file count, abstraction and
  error-handling breadth; ECC's security/testing/git rules stand.
- Cost: about 16k extra system-prompt tokens per session for plugin plus rule
  packs combined (measured 43k → 59k).
- Knobs: the plugin options stored at `pluginConfigs["ecc@ecc"].options` in
  `~/.claude/settings.json` (`hook_profile`: `minimal`/`standard`/`strict`;
  `hooks_enabled`: false keeps skills without hooks; `/plugin` → configure
  edits the same values), the env overrides `ECC_HOOK_PROFILE` and
  `ECC_HOOKS_ENABLED=0`, and the per-hook
  `ECC_DISABLED_HOOKS=pre:edit-write:gateguard-fact-force` or
  `ECC_GATEGUARD=off`.
- ECC's own statusline is not installed — the kit's stays. On Windows its
  tmux/dev-server and desktop-notify hooks are no-ops by design.

### Ponytail — anti-over-engineering

[Ponytail](https://github.com/DietrichGebert/ponytail) (`ponytail@ponytail`,
requires Node.js) enforces the laziest solution that works: YAGNI first,
stdlib before dependencies, one line before fifty. `/ponytail-review` makes a
good final pass on any diff; `/ponytail-audit` scans a whole repo. The
`senior-engineer` skill deliberately leaves YAGNI/minimalism to Ponytail.

### UI/UX Pro Max — design intelligence

[UI/UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) is
installed globally via `uipro init --ai claude --global` (requires Python 3):
67 UI styles, 161 industry reasoning rules, 161 palettes, 57 font pairings,
22 stacks incl. React Native and Flutter. It generates a full design system
before writing UI code, so this kit no longer ships a `ui-ux` skill.

## Model routing

**Opus 5.5 for everything except coding, which runs on Sonnet 5.5 — all at
effort `high`.** `install.sh` and `/core:init-dev-kit` pin it at user scope
with `plugins/core/scripts/model-routing.sh` (merges into
`~/.claude/settings.json`, keeps every other key); the project template
carries the same routing as aliases (`opusplan` / `opus`).

| Who | Model | Set by |
|---|---|---|
| Main thread in Plan Mode | **Opus 5.5** | `"model": "opusplan"` |
| Main thread executing — coding | **Sonnet 5.5** | `"model": "opusplan"` |
| Advisor (Sonnet consults it mid-task) | **Opus 5.5** | `advisorModel` |
| `/core:plan`, `researcher`, `code-reviewer` | **Opus 5.5** | `model: opus` frontmatter |
| Every other subagent (ECC, ruflo, workflows) — even one whose frontmatter says `sonnet` | **Opus 5.5** | `CLAUDE_CODE_SUBAGENT_MODEL` |
| Anything asking for the `haiku` alias | **Opus 5.5** | `ANTHROPIC_DEFAULT_HAIKU_MODEL` |

`ANTHROPIC_DEFAULT_OPUS_MODEL` / `_SONNET_MODEL` pin the aliases to
`claude-opus-5-5` / `claude-sonnet-5-5`, so the template's aliases and any
`model: opus` agent resolve to 5.5. The same policy is stated to the model in
`~/.claude/rules/ecc/00-precedence.md`, so ECC/ruflo tier hints never pick a
cheaper model.

`opusplan` uses Opus only while the session is in Plan Mode — every other
main-thread turn (questions, reviews, git) runs on Sonnet. For a mostly
non-coding session, `/model opus`; `/model opusplan` returns to the hybrid.
`/model fable` puts one hard, long-running task on **Fable 5.1** (Claude Code
re-runs a classifier-flagged request on Opus and continues there — so never
remap `ANTHROPIC_DEFAULT_OPUS_MODEL` to Fable).

Effort is pinned to `high` (top-level `effortLevel`, and inside any
`modelSettings` entry, where a per-model value would beat it): the
quality/token sweet spot, and thinking still scales per request — easy turns
stay short. `/effort xhigh` raises one session for a hard task; `ultrathink`
in a prompt requests one-off deeper reasoning.

## Status line

```
🧠 Model: Opus 5.5 • 💭 Effort: high • CTX: 53% (1M) • 📊 HL: 12% ↻ 2h 10m • 📅 WL: 85% ↻ 2d 3h • 🔮 WLF: 7% ↻ 2d 3h
```

| Segment | Meaning | Source |
|---|---|---|
| `💭 Effort` | live reasoning effort (`low`…`max`), follows `/effort` mid-session; omitted when the model has no effort parameter | stdin `effort.level` |
| `CTX` | context used %, window size in parentheses | stdin `context_window` |
| `📊 HL` | 5-hour rolling limit, resets in | stdin `rate_limits.five_hour` |
| `📅 WL` | weekly limit, all models | stdin `rate_limits.seven_day` |
| `🔮 WLF` | weekly **Fable** limit | fetched from `api.anthropic.com/api/oauth/usage` |

Percentages are green/yellow/red at 50/80 %. `plugins/core/statusline/statusline.py`
renders the line from the rate-limit JSON Claude Code passes on stdin
(v2.1.80+, Pro/Max). Claude Code shows the per-model Fable window in
`/usage` but does not pass it to status lines, so the script fetches it
itself with the OAuth token from `~/.claude/.credentials.json`, caches it
for 2 minutes in `~/.claude/statusline-cache/fable.json`, and renders `—`
when there is no token (API-key login, or macOS Keychain-only storage). The
token is sent to api.anthropic.com only; the cache never contains it.

`plugins/core/statusline/setup.sh` installs the script to
`~/.claude/statusline.py` and wires `statusLine` into `~/.claude/settings.json`
with `refreshInterval: 60`, so the reset countdowns tick even while the
session is idle. It never touches a `statusLine` you configured yourself, but
repairs one it recognizes as its own (any command running `statusline.py`) —
kit updates reach already-wired machines automatically.

It is also a checker:

- picks an interpreter by actually running `python3`, `python`, `py -3`,
  then `uv python find` (on Windows the first two are often Microsoft Store
  stubs that exit without output);
- wires both interpreter and script as **absolute forward-slash paths** —
  never `~`, because Claude Code may run the status line through PowerShell
  or cmd.exe on Windows and neither expands `~` for a native executable's
  argument;
- verifies the final command really renders before writing it, and prints
  one diagnostic line into the session when no interpreter works instead of
  wiring a broken status line (a broken custom status line also hides the
  footer hints).

Run `sh plugins/core/statusline/setup.sh --check` for a read-only health
report. Wiring the settings requires `jq`; without it the script is copied
but `settings.json` is left alone — install jq and open one more session.
It runs from `install.sh` **and** from the SessionStart hook, so opening any
session installs it and re-syncs it after kit updates. To customize it, edit
the copy in this repo (edits to `~/.claude/statusline.py` are overwritten).

## Updating the kit

Edit skills, commit, push. No `version` field is set on purpose: every commit
counts as a new version. On each machine:

```bash
claude plugin marketplace update dev-kit
claude plugin update core@dev-kit        # restart Claude Code to apply
```

Machines with marketplace auto-update enabled pick changes up on their own.
Companions update the same way (`claude plugin update ecc@ecc`,
`claude plugin update ponytail@ponytail`); ECC rule packs are refreshed by
re-running `sh plugins/core/scripts/ecc-rules.sh`.

## Developing / testing changes locally

```bash
sh tests/run.sh                      # full test suite (sh + python3, no deps)
sh tests/mutants.sh                  # mutation audit: suite must kill each mutant
claude --plugin-dir ./plugins/core   # load without installing
claude plugin validate .             # check marketplace + plugin schemas
```

The suite covers the scaffold hook (throwaway git repos), statusline setup
(sandboxed `$HOME`, Store-stub and no-interpreter cases), the statusline
renderer (including a golden test against the documented example payload and
the WLF fetch/cache path), the ECC rules installer (fixture tree, no
network), `extract_links.py`, plus JSON validity, shell syntax, shellcheck
(when installed), docs-path freshness, and personalization guards. CI runs it
on Ubuntu **and** macOS on every push, validates the plugin schemas
headlessly, and re-runs the mutation catalog weekly. Inside a session,
`/reload-plugins` picks up edits without restarting.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Status line blank on Windows | `python3` is the Microsoft Store stub, or the wired command uses `~`/backslashes, or the renderer hit a cp125x code page | Run `sh plugins/core/statusline/setup.sh` (or open a new session); `--check` shows what is wired |
| Status line keeps coming back broken | A second, project-scope copy of `core@dev-kit` pinned at an old version runs its stale hook | `claude plugin list`; inside that project `claude plugin uninstall core@dev-kit --scope project` and remove `enabledPlugins` from its `.claude/settings.json` |
| `WLF: —` | No OAuth token in `~/.claude/.credentials.json` (API-key login, macOS Keychain) | Expected; the other segments still render |
| ECC blocks the first edit of a file | The standard-profile fact-forcing gate | State importers/schemas as asked, or `ECC_GATEGUARD=off` / `hook_profile=minimal` |
| `/plugin install core@dev-kit` says already installed globally | It is — user scope covers every project | Nothing to do |
| Context window feels small | 454 skills across plugins each cost description tokens | Disable plugin families you do not use (ruflo first); `claude plugin details <plugin>` shows projected cost |
