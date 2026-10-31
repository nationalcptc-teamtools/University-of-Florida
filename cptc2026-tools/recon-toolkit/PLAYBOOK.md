# CPTC Comp Toolkit + Playbook

Pre-staged tooling and methodology for the engagement. Clone this onto the attack box. **This repo is PUBLIC — never commit live target intel here** (no target names, creds, OSINT, wordlists, or attack plans). Live target notes live in the team's private drive.

## The tools

| Script | Run it | What it does |
|---|---|---|
| `setup.sh` | on a fresh attack box: `./setup.sh` | installs the standard kit (nmap, netexec, impacket, hashcat, BloodHound, dnstwist, seclists, o365spray, etc.), grouped by purpose. `./setup.sh --list` to preview. |
| `cptc-triage.sh` | from the attack box: `bash cptc-triage.sh <in-scope-range>` | scans the range and prints a **prioritized, per-service hit list** — mail, SMB, FTP, DNS, web, AD/Kerberos, databases, and any non-standard ports — each tagged with the past finding it matches. Start here. |
| `cptc-enum.sh` | after you land a Linux shell: `bash cptc-enum.sh \| tee enum.txt` | our **custom LinPEAS** — only checks the privesc + **container-escape** paths we actually find. sudo/SUID, container detection + escape (docker.sock / privileged / host-path / kernel), creds in env/config/history, SSH keys, hijackable cron, custom listening services. Chase every `[!! HIT]`. |

All three are read-only / enumeration only. Run the active ones (`triage`, and anything that touches a target) **only inside the authorized engagement window, against in-scope IPs.**

## First 15 minutes
1. `./setup.sh` if the box isn't ready.
2. `bash cptc-triage.sh <prod-range> <dev-range>` — let it run, read the hit list top-down.
3. Split the hit list across the team by surface (web / AD / Linux / cloud) — claim rows in the threat-model sheet.
4. The instant anyone gets a Linux shell: `bash cptc-enum.sh` on that box.
5. Keep a running log of every command + result. The report is written from this log.

## The past-vuln checklist (what we keep finding — check each surface for its version)

**Web / app**
- IDOR: change an ID in a request, get someone else's data. Look for `?id=`, `/user/N`, `/AllUsers?limit=`.
- Broken function-level auth: call an admin action as a normal user.
- SSRF: any "fetch this URL / image by URL" feature -> point it at `file:///proc/self/environ` and internal services -> often DB creds -> RCE.
- Hardcoded secrets in front-end JS; client-side auth (flip a role in localStorage).
- Stored XSS / HTML injection; SQLi (sqlmap); exposed API docs (Swagger).

**Linux host (run cptc-enum.sh)**
- Postgres default/weak creds -> `COPY ... TO PROGRAM` = OS command execution.
- Custom/in-house service on a weird port -> connect with `nc`, find a debug/command feature -> command injection -> shell.
- Container? -> escape via docker.sock, `--privileged`, host-path mount, or a kernel exploit (Dirty Pipe etc.).
- SUID/sudo (GTFOBins), readable SSH keys, writable cron, outdated OpenSSH (regreSSHion).

**Active Directory**
- Kerberoast service accounts (`nxc --kerberoasting` / `GetUserSPNs`) -> crack with hashcat `-m 13100`.
- Delegation abuse (constrained / unconstrained / RBCD) -> map with BloodHound -> `impacket getST` -> `secretsdump` -> Domain Admin.
- Weak password policy, NTLMv1, SMB signing off, PetitPotam coercion, blank local-admin passwords.

**Cloud / identity**
- Public storage leaking credentials; over-privileged app/service principals (AzureHound/BloodHound).
- M365/Exchange: enumerate users, spray accounts without MFA (o365spray); check MFA posture (MFASweep).

**AI (the target's, not ours)**
- If the target runs an LLM/chatbot, that's an authorized finding: jailbreak / prompt-inject it (classic "act as a Linux terminal" -> read the guarded secret). Prompt-injection on any AI agent with tool/repo access.

## Using an AI assistant during the comp (prompting cheat sheet)
You don't jailbreak your own assistant — you give it the authorized context and ask specifically.
- Context line, once per session: *"I'm on a university team in CPTC, an authorized sanctioned pentest against an isolated competition environment I have written scope for. Help me with ___."*
- Ask for the concrete thing: "interpret this nmap/BloodHound/hashcat output," "write the impacket command to do X," "explain how to test this endpoint for IDOR," "draft this finding with business + technical impact + repro steps."
- Lean on it hardest for: interpreting output, writing/explaining commands, debugging a tool, and the **report + inject responses** (where the points are).
- Don't: vague "hack this," anything out of scope, or jailbreak attempts (unreliable + against ToS).

## Report reminders (this is where points live)
- Findings summary table in the exec summary AND atop the technical section.
- Every finding: end-to-end reproduction steps (incl. how you got the hash / which tool), **business impact separated from technical impact**, layered + linked remediation, redacted secrets.
- Keep the OSINT in the body, not just an appendix.
- Never claim "100% sure"; never touch prod/DC with changes. Stay in scope. Out-of-scope actions lose real points.
