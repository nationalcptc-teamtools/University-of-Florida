# AI Red Team Notes

A clean, sectioned reference for attacking AI-enabled targets — scoped to what's actually exploitable in a timed engagement like CPTC. This repo deliberately skips training-time/white-box attacks (data poisoning, adversarial evasion math, model internals) that need access you will never have against a deployed client app in an 8-hour window. See [Scope](#scope) below.

Each stage folder holds a set of `.md` files covering one focused topic; sections mirror an engagement against an AI-enabled target from recon through exploitation to defense-aware reporting.

---

## Master Directory

| # | Stage | What lives here |
|---|-------|-----------------|
| 1 | [Recon & Frameworks](./1-recon-and-fingerprinting/) | LLM app fingerprinting, OWASP ML/LLM Top 10, Google SAIF cheat sheets |
| 2 | [Prompt Injection](./2-prompt-injection/) | Direct & indirect injection, jailbreaking, tooling, mitigations |
| 3 | [LLM Output Attacks](./3-llm-output-attacks/) | Insecure output handling (SQLi/XSS/code injection via LLM), function calling, exfiltration, abuse |
| 4 | [Application & System Attacks](./4-application-system-attacks/) | DoS, model reverse engineering, rogue actions, insecure storage, deployment tampering, CVEs |
| 5 | [MCP Attacks](./5-mcp-attacks/) | MCP protocol basics, malicious servers (tool poisoning, rug pulls, tool shadowing), vulnerable servers |
| 6 | [Guardrails & Defense](./6-guardrails-and-defense/) | How guardrails work and how to identify/bypass them |
| 7 | [Runbooks](./7-runbooks/) | "Found an AI thing in scope — now what" checklist |

---

## Full Section Index

### 1. Recon & Frameworks
- [01 - LLM Recon & Fingerprinting](./1-recon-and-fingerprinting/01-llm-recon-and-fingerprinting.md)
- [02 - OWASP ML/LLM Top 10 & Google SAIF](./1-recon-and-fingerprinting/02-owasp-and-saif-frameworks.md)

### 2. Prompt Injection
- [01 - Direct Prompt Injection](./2-prompt-injection/01-direct-prompt-injection.md)
- [02 - Indirect Prompt Injection](./2-prompt-injection/02-indirect-prompt-injection.md)
- [03 - Jailbreaking](./2-prompt-injection/03-jailbreaking.md)
- [04 - Tools of the Trade & Mitigations](./2-prompt-injection/04-tools-and-mitigations.md)

### 3. LLM Output Attacks
- [01 - Insecure Output Handling (SQLi/XSS/Code Injection)](./3-llm-output-attacks/01-insecure-output-handling.md)
- [02 - Function Calling & Excessive Agency](./3-llm-output-attacks/02-function-calling-and-excessive-agency.md)
- [03 - Exfiltration Attacks](./3-llm-output-attacks/03-exfiltration-attacks.md)
- [04 - Abuse Attacks & Hallucinations](./3-llm-output-attacks/04-abuse-and-hallucinations.md)

### 4. Application & System Attacks
- [01 - Application-Layer Attacks](./4-application-system-attacks/01-application-layer-attacks.md)
- [02 - System-Layer Attacks & CVEs](./4-application-system-attacks/02-system-layer-attacks.md)

### 5. MCP Attacks
- [01 - MCP Fundamentals](./5-mcp-attacks/01-mcp-fundamentals.md)
- [02 - Malicious MCP Servers](./5-mcp-attacks/02-malicious-mcp-servers.md)
- [03 - Vulnerable MCP Servers](./5-mcp-attacks/03-vulnerable-mcp-servers.md)

### 6. Guardrails & Defense
- [01 - Guardrail Types & Bypasses](./6-guardrails-and-defense/01-guardrail-types-and-bypasses.md)

### 7. Runbooks
- [00 - AI Red Team Checklist](./7-runbooks/00-ai-redteam-checklist.md)

---

## Scope

This repo intentionally excludes attack categories that need training-time, white-box, or heavy-API-budget access an attacker won't have in a CPTC-style engagement:

- **Data attacks** (trojan/backdoor attacks, label flipping, clean-label attacks, pickle/tensor steganography) — require write access to the training pipeline/dataset.
- **Evasion attacks** (FGSM, DeepFool, JSMA, ElasticNet) — require white-box gradient access to a classifier's weights.
- **AI fundamentals / model-building** (deep learning theory, supervised/unsupervised algorithms, building classifiers) — background knowledge, not an attack playbook.
- **Membership inference / shadow models / DP-SGD / PATE** — low priority for a time-boxed engagement; condensed into [`_appendix-privacy-attacks.md`](./_appendix-privacy-attacks.md) in case an AI component surfaces heavy API access.

If a target exposes model internals or a training pipeline directly, that's valuable — but for a network pentest competition, assume black-box access to a deployed LLM-powered app or service.

## Layout

```
ai-redteam-notes/
├── README.md                          ← this file (master directory)
├── 1-recon-and-fingerprinting/
├── 2-prompt-injection/
├── 3-llm-output-attacks/
├── 4-application-system-attacks/
├── 5-mcp-attacks/
├── 6-guardrails-and-defense/
├── 7-runbooks/
└── _appendix-privacy-attacks.md       ← low-priority reference, not core playbook
```

