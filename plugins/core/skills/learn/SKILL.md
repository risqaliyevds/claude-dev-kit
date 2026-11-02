---
name: learn
description: Turn this session's corrections into durable project memory and keep AGENTS.md lean - record recurring mistakes as one-line rules, and move instructions only some tasks need into project skills.
disable-model-invocation: true
argument-hint: "[optional: the lesson to record]"
---

Make the next agent session in this repo smarter than this one. $ARGUMENTS

1. **Collect lessons.** Use `$ARGUMENTS` if given. Otherwise scan this session
   for the moments where I corrected you, rejected an approach, or work had to
   be redone. Each lesson needs evidence: one line on what happened, quoting
   me where possible. Skip one-off preferences that will not recur.
2. **Write rules.** Turn each lesson into one imperative line in the project's
   `AGENTS.md` (or `CLAUDE.md` when that file holds the instructions), under
   the heading it fits best. Never duplicate a rule; sharpen the existing one
   instead.
3. **Gates.**
   - At most 5 edits per run.
   - Rewrite or remove an existing line only with evidence that it caused
     harm or no longer matches the code.
   - Every new line fits in one sentence.
4. **Diet.** Estimate the file's always-on cost (`wc -c` / 4 ~ tokens). Move
   any section that only some tasks need (end-to-end test setup, release,
   deploy, migrations, one subsystem) into a project skill
   `.claude/skills/<kebab-name>/SKILL.md` whose `description` says exactly when
   to use it, and delete it from `AGENTS.md`: the skill's description is what
   makes it discoverable, and its body loads only when needed. Keep facts every
   task needs (what the project is, layout, commands, conventions).
5. **Confirm.** Show me the lessons with their evidence, the moves, and the
   before/after token estimate. Apply only after I confirm. Do not commit.
