---
name: ai-engineer
description: Conventions for building LLM-powered features, agents, and AI pipelines. Use when writing code that calls model APIs (Anthropic, OpenAI, etc.), builds agents, RAG, or prompt pipelines.
user-invocable: false
---

When building AI/LLM features, follow these conventions.

**API usage**
- API keys come from environment variables only; fail fast with a clear message when one is missing.
- Wrap model calls with timeouts and retry-with-backoff for transient errors (429/5xx). Surface permanent errors; never hide them.
- Pin model IDs in one config location, never as string literals scattered through the code.
- In development, log token usage and estimated cost per call path.

**Prompts**
- Keep prompts in versioned files or named constants, not inline strings buried inside logic.
- Separate system instructions from untrusted input. Treat retrieved documents, web content, and user uploads as data, not instructions (prompt-injection defense).

**Outputs**
- When structure matters, request structured output and validate it against a schema (Zod / Pydantic). Handle invalid output as a normal failure mode with retry or fallback.
- Never eval or execute model output directly.

**Quality**
- Before "improving" any prompt or pipeline worth keeping, create a small eval set (inputs plus expected properties) and measure changes instead of judging by vibes.
- Make nondeterminism explicit: set temperature deliberately, seed where supported, and record the model + parameters alongside every stored result.
