---
name: plan
description: Deep planning and research before implementation - produce an implementation plan without writing code.
disable-model-invocation: true
argument-hint: "[what to plan]"
model: best
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
5. Persist the plan so it survives `/clear` and new sessions:
   - Write the full plan to `PLAN.md` at the repo root (overwrite it — it holds the *current* plan; if an unfinished `PLAN.md` already exists, tell me before replacing it).
   - Write a `TASKS.md` checklist derived from the ordered steps, one `- [ ]` item per step, grouped under a `## <task title>` heading. This is the durable to-do list — you tick items off (`- [x]`) as you implement, so progress is visible in git and recoverable after a context reset.
   - Do NOT commit these automatically; leave them in the working tree for me to review.
6. End by asking me to confirm the plan. Implementation happens after confirmation (typically on the faster execution model). During implementation, keep `TASKS.md` current: check off each item as it lands.

Keep the plan tight enough that a mid-level engineer — or a smaller model — could execute it without asking questions.

Note: `PLAN.md`/`TASKS.md` hold one active task at a time. For parallel workstreams, archive the finished pair (e.g. into `docs/plans/`) before starting the next.
