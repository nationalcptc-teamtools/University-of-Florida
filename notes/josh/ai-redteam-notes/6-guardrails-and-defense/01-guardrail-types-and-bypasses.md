# 01 — Guardrail Types & Bypasses

**Jump to:** [Input vs Output Guardrails](#input-vs-output-guardrails) · [Character-Based Validation](#character-based-validation) · [Content-Based Validation (Traditional)](#content-based-validation-traditional) · [AI-Based Guardrails (LLM-as-Judge)](#ai-based-guardrails-llm-as-judge) · [Guardrail Libraries & Services](#guardrail-libraries--services) · [Identifying What's in Front of You](#identifying-whats-in-front-of-you)

## Input vs Output Guardrails

- **Input guardrails** run on the user prompt before it reaches the model — filter/reject prompt injection, jailbreaks, out-of-domain requests.
- **Output guardrails** run on the generated response — content filtering, moderation, rule-based post-processing.

More guardrails = more latency and more false-positive friction, so real deployments balance coverage against UX — that tension is often where gaps appear.

## Character-Based Validation

Whitelist/blacklist specific characters (classic injection-filter style). Weak against prompt injection specifically, since most injection payloads are plain alphanumeric text — nothing to strip. More useful as a narrow-domain input constraint (e.g. a calculator app only accepting `0-9.+-*/()`), not as general LLM security.

## Content-Based Validation (Traditional)

Regex/blacklist/similarity-matching against known attack patterns:

```python
PROMPT_INJECTION_REGEX = r"^.*(Ignore|Disregard|Skip|Forget)\s*(prior|previous|preceding|above)?\s*(instructions?|directives?|commands?).*$"
```

Jailbreak detection via string similarity to known payloads (`SequenceMatcher` ratio above a threshold).

**Known weaknesses to exploit:**
- Regex bypassed by inserting extra words/characters: `Ignore *ALL* previous instructions`
- Similarity-based detection bypassed by rephrasing, typos, or synonym swaps to push below the threshold
- Naive substring checks produce false positives/negatives on partial word matches (e.g. a profanity blacklist containing `poon` also flags `spoon`)
- Exact-match whitelists miss case variations

## AI-Based Guardrails (LLM-as-Judge)

A second (often smaller) LLM classifies the input/output as `safe`/`violation` against a dedicated system prompt. Significantly harder to bypass than regex, but not unbreakable:

- **Fail-open vs fail-closed logic matters.** A guardrail that only blocks on an explicit `violation` keyword fails open if the judge model itself gets confused/jailbroken into an unexpected response. A guardrail checking for the literal keyword `safe` fails closed by default — worth noting whether a target's implementation does this correctly.
- To succeed end-to-end, a payload generally has to fool **both** the guardrail LLM and the main LLM — harder, but not impossible, especially if the same jailbreak technique affects both (e.g. they're the same model family).
- AI-based guardrails add real latency (seen in practice: ~0.1s traditional vs ~1.6s AI-based for input+output checks combined) — if a target's AI app feels unusually slow per-request, that's a signal multiple LLM-based guardrails may be stacked, which is useful recon.

## Guardrail Libraries & Services

Worth knowing names/behavior for recon and report-writing:
- **guardrails-ai** — `UnusualPrompt` (LLM-as-judge), `DetectJailbreak`, `ProfanityFree`, `SecretsPresent`, `WebSanitization` validators, pluggable via `on_fail` actions (`exception`, `fix`, `reask`, etc.)
- **Google Model Armor** — commercial sanitization layer on both prompt and response; detects `rai` (hate/dangerous), `sdp` (sensitive data e.g. credit cards), `pi` (prompt injection/jailbreak), malicious URIs, CSAM, viruses.
- **Google ShieldGemma** — fine-tuned LLM, binary yes/no against a stated policy.
- **last_layer / rebuff** — prompt injection detection libraries.
- **profanity-check / detoxify** — profanity/toxicity detection libraries.

## Identifying What's in Front of You

During recon, probe to classify the guardrail tier you're up against:
1. Try a blatant payload (`Ignore all previous instructions...`) — if it's blocked instantly with no apparent "thinking," you're likely facing character/regex-based filtering.
2. Try rephrasing/typo variants of the same payload — if these sail through while the blatant version was blocked, confirms traditional (non-AI) filtering.
3. Try a payload that's semantically malicious but doesn't match common injection phrasing — if it's still caught, you're likely facing an AI-based judge.
4. Measure response latency — a sudden latency jump on certain inputs (vs identical-length benign ones) suggests an AI-based guardrail kicked in.

This classification tells you which playbook from [section 2](../2-prompt-injection/) is worth spending time on.
