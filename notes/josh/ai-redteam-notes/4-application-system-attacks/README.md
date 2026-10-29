# 4. Application & System Attacks

Real-world AI deployments have four components: `model`, `data`, `application`, `system`. This section covers the **application** layer (the interface tying users to the model — web apps, APIs, plugins) and the **system** layer (infra: deployment platforms, storage, serving frameworks). These are where most *actually exploitable* findings live in a client engagement — often via completely conventional web/infra vulns that just happen to be reached through an AI component.

## Sections
1. [Application-Layer Attacks](./01-application-layer-attacks.md) — DoS/sponge examples, insecure integrated components (IDOR/SQLi via chatbot), model reverse engineering, rogue actions.
2. [System-Layer Attacks & CVEs](./02-system-layer-attacks.md) — insecure data storage, model deployment tampering, real CVEs in ML serving frameworks (TorchServe, MLflow, Ollama).

> Most findings here are just normal web/infra pentesting — the only thing AI-specific is that the vulnerable component happens to sit next to or behind a model.
