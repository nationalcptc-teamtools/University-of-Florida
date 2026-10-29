# 3. LLM Output Attacks

The second highest-yield category. Core principle: **LLM output is untrusted data, just like user input.** If the app doesn't treat it that way — feeding it straight into SQL, a shell, HTML, or a function call — classic injection vulns appear, just reached through the model instead of a form field.

Maps to OWASP `LLM05: Improper Output Handling` and Google SAIF's `Insecure Model Output`.

## Sections
1. [Insecure Output Handling](./01-insecure-output-handling.md) — SQLi, code injection, XSS via LLM-generated output.
2. [Function Calling & Excessive Agency](./02-function-calling-and-excessive-agency.md) — abusing tool/function calls the LLM can trigger.
3. [Exfiltration Attacks](./03-exfiltration-attacks.md) — markdown-image and link-based data theft, usually chained with indirect injection.
4. [Abuse Attacks & Hallucinations](./04-abuse-and-hallucinations.md) — weaponizing generation itself, plus hallucination-driven supply-chain risk (slopsquatting).
