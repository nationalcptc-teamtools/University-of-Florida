# 00 — AI Red Team Checklist

**Trigger:** any chatbot, LLM-powered support widget, AI feature, or MCP server in scope.

## 1. Recon (do all of these first)

- [ ] Identify model family/provider — try direct questions, fall back to [LLMmap](../1-recon-and-fingerprinting/01-llm-recon-and-fingerprinting.md#llm-fingerprinting-tools) if it won't say.
- [ ] Map architecture — single model vs multi-component, RAG, plugins, function calling, API-based vs self-hosted.
- [ ] Attempt to leak the system prompt — see [strategies](../2-prompt-injection/01-direct-prompt-injection.md#system-prompt-leaking-strategies).
- [ ] Classify the guardrail tier in front of you — see [identification steps](../6-guardrails-and-defense/01-guardrail-types-and-bypasses.md#identifying-whats-in-front-of-you).
- [ ] Ask the model directly what tools/functions/plugins it has access to.
- [ ] Check for rate limiting (absence = model reverse engineering / DoS risk).

## 2. Prompt Injection & Jailbreaking

- [ ] Try basic direct injection (`ignore all previous instructions...`) — low expectation, cheap to test.
- [ ] Try [jailbreak families](../2-prompt-injection/03-jailbreaking.md) — roleplay/fictional scenario first (highest success rate, least suspicious), then token smuggling, then suffix-based.
- [ ] If the app ingests external content (email, URL, document, username field) anywhere the LLM reads it back → test [indirect injection](../2-prompt-injection/02-indirect-prompt-injection.md).
- [ ] Run `garak` against the target if you have API access — see [tooling](../2-prompt-injection/04-tools-and-mitigations.md#garak).

## 3. Output Handling

- [ ] Test if LLM output is HTML-encoded before rendering (bold-tag test) → [XSS](../3-llm-output-attacks/01-insecure-output-handling.md#xss-via-llm).
- [ ] If the LLM translates queries to SQL → test for [SQLi via LLM](../3-llm-output-attacks/01-insecure-output-handling.md#sql-injection-via-llm).
- [ ] If the LLM triggers shell commands → test for [code injection](../3-llm-output-attacks/01-insecure-output-handling.md#code-injection-via-llm).
- [ ] Enumerate every function/tool the LLM can call; test each for excessive agency and injection in its own right — see [function calling](../3-llm-output-attacks/02-function-calling-and-excessive-agency.md).
- [ ] If Markdown is rendered → test [exfiltration via markdown image](../3-llm-output-attacks/03-exfiltration-attacks.md).

## 4. Application & System

- [ ] Fuzz any chatbot-adjacent endpoint for IDOR/SQLi like a normal web app — see [insecure integrated components](../4-application-system-attacks/01-application-layer-attacks.md#insecure-integrated-components).
- [ ] Fingerprint the ML serving stack (TorchServe/MLflow/Ollama/BentoML/Triton/etc.) and check versions against [known CVEs](../4-application-system-attacks/02-system-layer-attacks.md).
- [ ] Directory-brute the app for exposed DB dumps / model files / training data.
- [ ] If a classifier API is exposed with no rate limit → consider a quick [model reverse engineering](../4-application-system-attacks/01-application-layer-attacks.md#model-reverse-engineering) PoC for the report.

## 5. MCP (if present)

- [ ] Enumerate all tools/resources/prompts — read every description for hidden instructions before trusting anything.
- [ ] If you control an MCP server the target connects to → test [tool poisoning / rug pull / shadowing](../5-mcp-attacks/02-malicious-mcp-servers.md).
- [ ] If connecting to a target's MCP server directly → test [injection/SSRF/auth](../5-mcp-attacks/03-vulnerable-mcp-servers.md) independent of any LLM resilience — you don't need to jailbreak anything, you have direct network access to the server.

## 6. Reporting

- [ ] Map every finding to an OWASP ML/LLM Top 10 ID and/or SAIF risk — see [framework cheat sheet](../1-recon-and-fingerprinting/02-owasp-and-saif-frameworks.md).
- [ ] Note responsible party per SAIF (model creator vs model consumer) — almost everything you'll find in a client engagement is a **model consumer** failure.
- [ ] Attach `garak` JSON/HTML reports as evidence where applicable.
