# Appendix — Privacy Attacks (Membership Inference)

**Low priority for CPTC.** These attacks need either white-box access or a large, uncapped query budget against the same model — rarely realistic in a timed network pentest. Kept here in case an engagement specifically exposes heavy API access to a model trained on sensitive data.

## Membership Inference Attack (MIA)

Determines whether a specific data sample was part of a model's training set, by exploiting the gap between **memorization** (the model fits training data closely) and **generalization** (it should perform similarly on unseen data, but usually doesn't quite).

Two signals an attack model exploits from the target's output:
- **Prediction confidence** — training members tend to get higher-confidence predictions.
- **Prediction correctness** — models are more accurate on data they've seen before.

Larger models (more parameters) memorize more and are more vulnerable. Regularization (dropout, weight decay, early stopping) reduces but doesn't eliminate the effect.

**Why it matters if found:** if a model leaks membership, it likely leaks other info too (model inversion, attribute inference, verbatim training-data extraction) — MIA success is a good proxy for broader data-leakage risk, useful for a report even without running the deeper attacks.

## Related Privacy Attacks (background only)

- **Model inversion** — reconstruct features of training inputs from outputs (e.g. inferring genetic markers from a disease-risk model's predictions).
- **Attribute inference** — deduce a sensitive attribute not directly predicted by the model, from other predictions.
- **Training data extraction** — recover verbatim training examples; LLMs that memorize specific sequences are most vulnerable.

## Framework Mapping

- OWASP ML Top 10: `ML03` (Model Inversion), `ML04` (Membership Inference), `ML05` (Model Theft).
- OWASP LLM Top 10: `LLM02` (Sensitive Information Disclosure).
- Google SAIF: `Sensitive Data Disclosure`, `Inferred Sensitive Data`.

Primary defense (for context, not something you'll be testing): differential privacy during training (DP-SGD, PATE).
