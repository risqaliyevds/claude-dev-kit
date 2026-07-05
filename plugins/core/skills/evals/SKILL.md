---
name: evals
description: Create or run a small evaluation harness for an LLM feature, prompt, or pipeline. Use when building or changing prompts, RAG, agents, or any LLM-powered behavior, or when asked to eval, benchmark, or compare prompt or model versions.
argument-hint: "[what to evaluate]"
---

Set up or run evals for: $ARGUMENTS

Rules:

1. **No eval set → create one FIRST.** 15-30 real or realistic inputs covering normal cases, edge cases, and known failure modes. Store as `evals/<feature>/cases.jsonl` with fields: `id`, `input`, `expected` (exact value or a list of required properties), `notes`.

2. **Choose scoring to match the task.** Exact or normalized match for deterministic outputs; schema-validity plus per-field accuracy for extraction; a 3-5 point rubric judged by a strong model for open generation — put the rubric inside the judge prompt, and use a different model as judge than as generator whenever possible.

3. **Write a tiny runner** (`evals/<feature>/run.py`) that loads the cases, calls the real pipeline, scores each case, and prints a table (case id, pass/fail, score) plus totals. Log the model id, prompt version, temperature, and token cost of every run.

4. **Baseline before change.** Run the current version and save its results as the baseline, THEN modify the prompt/pipeline and report the delta. Numbers, not vibes.

5. **Ship rule:** a change ships only if it does not regress the eval set. Every production failure you encounter becomes a new case in `cases.jsonl` the same day.
