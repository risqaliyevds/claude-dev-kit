---
name: plan
description: Deep planning and research before implementation - produce an implementation plan without writing code.
disable-model-invocation: true
argument-hint: "[what to plan]"
model: opus
---

Plan this task: $ARGUMENTS

You are in planning mode — research and design only. Do NOT write implementation code yet.

1. Research first: read every file this change would touch, trace the real data/control flow, and note existing patterns worth reusing. If external libraries or APIs are involved and their current behavior matters, verify against up-to-date docs rather than memory.
2. Consider 2-3 viable approaches. For each: a one-paragraph sketch and its main tradeoff.
3. Recommend one approach and justify the choice in 2-4 sentences.
4. Write the implementation plan for the chosen approach:
   - Ordered steps, each naming the exact files to create or change and what changes in them
   - Data model / API changes, if any
   - Risks and edge cases that must be handled
   - Test plan: what proves this works
   - What is explicitly OUT of scope
5. Persist the plan so it survives `/clear` and new sessions (create `docs/plans/` if needed — never write these to the repo root):
   - Write the full plan to `docs/plans/PLAN.md` (overwrite it — it holds the *current* plan; if an unfinished `PLAN.md` already exists, tell me before replacing it).
   - Write a `docs/plans/TASKS.md` checklist derived from the ordered steps, one `- [ ]` item per step, grouped under a `## <task title>` heading. This is the durable to-do list — you tick items off (`- [x]`) as you implement, so progress is visible in git and recoverable after a context reset.
   - Do NOT commit these automatically; leave them in the working tree for me to review.
6. Show me the plan as an interactive page instead of a wall of text, so I can point at the exact part I disagree with:
   - With the Artifact tool available, publish a private page (follow the Artifact tool's own instructions for its design skill). It shows the recommended approach next to the alternatives; mockups of any UI change in the project's own look (read its theme, CSS or components first); the ordered steps; the risks; and a **Decisions** section with one card per open question, options listed and your recommendation marked.
   - Ask me to comment on any part of the page or pick an option on a card. Read my comments (ArtifactComments), update `PLAN.md`, republish, and repeat until I approve. `PLAN.md` stays the source of truth; the page is its view.
   - The page is private, but its text is uploaded to claude.ai. If the plan names secrets or confidential customer details, keep it in the terminal.
   - Without the Artifact tool, write the same page to `tmp/plans/<slug>.html`, open it (`start` / `open` / `xdg-open`), and take my feedback in chat.
7. End by asking me to confirm the plan. Implementation then runs without interruptions (on Sonnet 5.5 under the kit's `opusplan` routing): ask me again only for a product decision the plan did not settle. Keep `TASKS.md` current: check off each item as it lands. When it is done, offer `/core:ship` instead of asking me to review the diff.

Keep the plan tight enough that a mid-level engineer — or a smaller model — could execute it without asking questions.

Note: `docs/plans/PLAN.md`/`TASKS.md` hold one active task at a time. For parallel workstreams, archive the finished pair (e.g. into `docs/plans/archive/`) before starting the next.
