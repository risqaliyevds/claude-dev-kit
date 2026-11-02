---
name: grill-me
description: Interview the user relentlessly about a plan or design until you reach shared understanding, resolving each branch of the decision tree. Use when the user wants to stress-test a plan, get grilled on a design, or says "grill me". Asks in English, plus Uzbek when enabled.
---

Interview me relentlessly about every aspect of this plan until we reach a
shared understanding. Walk down each branch of the design tree, resolving
dependencies between decisions one by one. For each question, give your
recommended answer.

Ask one question at a time. If the codebase can answer a question, explore the
codebase instead of asking.

## English + Uzbek (optional)

Before the first question, run with the Bash tool:

`python3 "${CLAUDE_SKILL_DIR}/scripts/translate.py" --status`

Empty output or a non-zero exit means that interpreter does not run (on Windows
`python3` can be a Store stub): retry with `python`, then `py -3`, and use the
one that works for every call below. If none runs, say once that Uzbek mode
needs Python 3 and carry on in English.

- `on`: every question below is shown in English and Uzbek.
- `broken: <reason>`: tell me the reason once, then carry on in English only.
- Exactly `off` or `unset`: English only. Say nothing about Uzbek.

When it printed `on`, for each question:

1. Write the question and your recommended answer in English, as usual.
2. Translate exactly that text (nothing else) with the Bash tool:

   ```
   python3 "${CLAUDE_SKILL_DIR}/scripts/translate.py" <<'EOF'
   <the English question and recommended answer>
   EOF
   ```

3. Show the output under it, headed **Oʻzbekcha**, word for word. Do not edit,
   re-translate or add to it: code, technical terms and names are already
   kept in English on purpose.

If the script exits non-zero, show its one-line error once and continue in
English for the rest of the session. Grilling never waits on Gemini.
