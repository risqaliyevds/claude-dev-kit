---
name: nlp
description: NLP engineering conventions - text processing, datasets, multilingual (Uzbek/Russian/English) handling, and model evaluation. Use when working on NLP tasks like classification, NER, summarization, translation, embeddings, tokenization, or text datasets.
user-invocable: false
---

When working on NLP tasks, follow these conventions.

**Data first**
- Look at raw data before modeling: print 20 random samples, check encoding, length distribution, label balance, and junk (HTML fragments, boilerplate, duplicates).
- Split train/val/test BEFORE preprocessing decisions; deduplicate across splits (exact and near-duplicate) to prevent leakage. Stratify by label for classification.
- Version datasets (HF datasets, DVC, or dated files); never overwrite a dataset in place.

**Multilingual reality (uz / ru / en)**
- Uzbek exists in Latin AND Cyrillic scripts: detect the script, normalize consistently, unify apostrophe variants (o', oʻ, o`), and test both scripts.
- Never assume a tokenizer handles Uzbek well — measure tokens-per-word; high fertility means worse quality and higher cost. Prefer models with verified uz/ru coverage, and spot-check LLM generation quality per language separately.
- Track language as metadata on every example; never silently mix languages inside one label class.

**Evaluation before iteration**
- Define the metric before training or prompting: macro-F1 for classification and NER, exact-match + token-F1 for extraction, chrF/COMET for translation, and a rubric-based LLM-judge (pairwise where possible) for open generation.
- Keep a frozen test set and a dumb baseline (majority class, keyword rules, or the previous model). Report deltas against the baseline, not absolute scores alone.
- Error analysis beats metric chasing: bucket 30-50 failures by cause before changing anything.

**LLM-for-NLP specifics**
- Prefer structured outputs (JSON schema) for extraction and classification; validate every response and count parse failures as errors, not exceptions to ignore.
- Batch and cache API calls; temperature 0 for deterministic tasks; log model + prompt version alongside every stored result.
- For long documents, measure whether chunking beats long-context on YOUR data instead of assuming either way.
