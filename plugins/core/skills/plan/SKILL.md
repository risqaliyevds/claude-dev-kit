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
5. End by asking me to confirm the plan. Implementation happens after confirmation (typically on the faster execution model).

Keep the plan tight enough that a mid-level engineer — or a smaller model — could execute it without asking questions.
