# 2. Prompt Injection

The highest-yield category against any LLM-powered app in scope. LLMs have no structural separation between "instructions" and "data" — everything is one blob of text — which is the root cause of every technique below.

## Sections
1. [Direct Prompt Injection](./01-direct-prompt-injection.md) — manipulating the LLM through your own input.
2. [Indirect Prompt Injection](./02-indirect-prompt-injection.md) — payload delivered via a resource the LLM ingests (email, website, document).
3. [Jailbreaking](./03-jailbreaking.md) — bypassing trained-in content restrictions.
4. [Tools of the Trade & Mitigations](./04-tools-and-mitigations.md) — `garak`, and what actually stops this stuff.

> Randomness matters: the same prompt can produce different results across attempts. Don't give up on a technique after one try — and don't be surprised if it works, then stops working.
