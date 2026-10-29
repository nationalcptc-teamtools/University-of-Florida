# 1. Recon & Frameworks

Before attacking an AI-enabled target, build a mental model of what you're dealing with: what model, what access it has, what's guarding it. This stage also captures the two reference frameworks (OWASP's ML/LLM Top 10, Google's SAIF) worth knowing cold for report-writing and for not missing a category of attack.

## Sections
1. [LLM Recon & Fingerprinting](./01-llm-recon-and-fingerprinting.md) — info gathering, model identity, app architecture, `LLMmap`.
2. [OWASP ML/LLM Top 10 & Google SAIF](./02-owasp-and-saif-frameworks.md) — the two frameworks to map findings against in a report.

> Before touching payloads: identify the model family, the app architecture (single/multi-component, RAG, plugins), input/output constraints, and existing guardrails. Most exploitation paths fall out of good recon.
