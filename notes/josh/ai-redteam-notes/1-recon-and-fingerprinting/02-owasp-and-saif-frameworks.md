# 02 — OWASP ML/LLM Top 10 & Google SAIF

**Jump to:** [OWASP ML Top 10](#owasp-top-10-for-machine-learning-security) · [OWASP LLM Top 10](#owasp-top-10-for-llm-applications) · [Google SAIF](#googles-secure-ai-framework-saif)

Reference these when writing findings — mapping an attack to a named risk ID (`LLM01`, `ML02`, etc.) makes reports look sharp and gives the client something to Google.

## OWASP Top 10 for Machine Learning Security

| ID   | Risk                                                                          | Realistic in CPTC?                                                       |
| ---- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| ML01 | Input Manipulation Attack — adversarial perturbations cause misclassification | Low (needs white-box or heavy query budget)                              |
| ML02 | Data Poisoning — malicious data injected into training set                    | Very low (needs pipeline access)                                         |
| ML03 | Model Inversion — reconstruct training inputs from outputs                    | Low                                                                      |
| ML04 | Membership Inference — determine if a sample was in training data             | Low                                                                      |
| ML05 | Model Theft — clone a model via query/response pairs                          | **Medium** — plausible if a classifier API is exposed with no rate limit |
| ML06 | AI Supply Chain Attacks — vulnerable deps/pretrained models/frameworks        | **High**                                                                 |
| ML07 | Transfer Learning Attack — poisoned baseline model                            | Very low                                                                 |
| ML08 | Model Skewing — bias injected via training data                               | Very low                                                                 |
| ML09 | Output Integrity Attack — tamper with output post-inference, pre-processing   | Medium if you can MITM the pipeline                                      |
| ML10 | Model Poisoning — direct tampering with model weights/parameters              | Low unless you get file/infra access                                     |

## OWASP Top 10 for LLM Applications

| ID    | Risk                                                              | Realistic in CPTC?        |
| ----- | ----------------------------------------------------------------- | ------------------------- |
| LLM01 | Prompt Injection                                                  | **High**                  |
| LLM02 | Sensitive Information Disclosure                                  | **High**                  |
| LLM03 | Supply Chain                                                      | **High**                  |
| LLM04 | Data and Model Poisoning                                          | Very low                  |
| LLM05 | Improper Output Handling (XSS/SQLi/code injection via LLM output) | **High**                  |
| LLM06 | Excessive Agency                                                  | **High**                  |
| LLM07 | System Prompt Leakage                                             | **High**                  |
| LLM08 | Vector and Embedding Weaknesses (RAG)                             | Medium if RAG is in scope |
| LLM09 | Misinformation / Hallucination                                    | Medium                    |
| LLM10 | Unbounded Consumption (DoS via resource exhaustion)               | Medium                    |

## Google's Secure AI Framework (SAIF)

Four areas: `Data`, `Infrastructure`, `Model`, `Application`. SAIF maps each risk to a responsible party — `model creator` (e.g. OpenAI/Anthropic/Google) vs `model consumer` (the client who deployed it). Useful framing in a report: most findings against a client's deployment are **model consumer** failures (missing input/output validation, excessive agency, insecure integration), not failures of the underlying LLM itself.

Key SAIF risks worth citing:
- `Prompt Injection`, `Insecure Model Output`, `Rogue Actions`, `Model Deployment Tampering`, `Insecure Integrated Component`, `Denial of ML Service`, `Model Reverse Engineering`, `Excessive Data Handling`.

Full risk map: https://saif.google/secure-ai-framework/saif-map
