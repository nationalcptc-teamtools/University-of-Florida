# 01 — Report Fundamentals

**Jump to:** [Notetaking Strategy (start before you fire the first packet)](#notetaking-strategy-start-before-you-fire-the-first-packet) · [Automatic Terminal Logging (`script`)](#automatic-terminal-logging-script) · [Standard Report Structure](#standard-report-structure) · [1. Executive Summary](#1-executive-summary) · [2. Scope and Objectives](#2-scope-and-objectives) · [3. Methodology](#3-methodology) · [4. Findings Summary Table](#4-findings-summary-table) · [5. Detailed Findings (the template every finding follows)](#5-detailed-findings-the-template-every-finding-follows) · [6. Attack Path Narrative](#6-attack-path-narrative) · [7. Remediation Roadmap](#7-remediation-roadmap) · [8. Appendices](#8-appendices) · [Writing Hygiene](#writing-hygiene) · [Style: Don't Be Punitive](#style-dont-be-punitive) · [Client Communication (bookend every day)](#client-communication-bookend-every-day) · [Working Habits That Compound](#working-habits-that-compound) · [Lessons From Real Attack Chains](#lessons-from-real-attack-chains)

A penetration test report has **two distinct audiences** sharing one document:
- **Executives** — care about business risk, budget impact, and what they should do next quarter. Read pages 1–3.
- **Engineers** — care about reproducing the issue, fixing it, and verifying the fix. Read everything else.

Write for both, but separate the language clearly.

---

### Notetaking Strategy (start before you fire the first packet)

The report is assembled from notes taken during testing — never the other way around. Set up a note structure on day 0, keep it disciplined, and the report writes itself.

Recommended notebook layout:

| Section | Contents |
|---|---|
| **Attack Path** | Full narrative of every foothold and pivot, with commands and screenshots pasted in chronological order — this becomes the report's attack-chain section verbatim. |
| **Credentials** | Central store for every cred discovered — `user:pass`, hash type, source host, whether cracked. Also collects `.kdbx`, keys, tokens. |
| **Findings** | Subfolder per finding — narrative + evidence + reference material. |
| **Vulnerability Scan Research** | What you scanned, what came back, what you followed up on — prevents re-running the same triage twice. |
| **Service Enumeration Research** | Per-service investigation notes: what you found, what you tried, why it didn't work. |
| **Web Application Research** | Per-site notes: subdomain enum output, default cred pairs tried, interesting endpoints. Aquatone / EyeWitness screenshots go here. |
| **AD Enumeration Research** | Step-by-step of every enum tool run against the domain — BloodHound queries, PowerView pulls, Snaffler output. |
| **OSINT** | Anything you dug up externally that isn't already in another note. |
| **Administrative Info** | Client POC contacts, PMs, unique objectives from the RoE, running to-do list of "try this later" ideas. |
| **Scoping Info** | IPs / CIDRs / URLs / provided credentials in scope. Referred to constantly — don't hide it in an email. |
| **Activity Log** | High-level chronology of everything you did — supports blue-team event correlation if they ask. |
| **Payload Log** | Every payload used, target, timestamp, and file hash for anything dropped on disk. Critical for cleanup and IR support. |
| **Artifact Log** | Every account created, config changed, or file left behind. Include: host IP/name, timestamp, description, location on disk, service touched, account name + password if you had to leave one. |

Recommended tools:

- **Cloud**: OneNote (sync, tables, drag-drop screenshots, revision history).
- **Local**: Obsidian (markdown, no vendor lock-in, plays nicely with git).

---

### Automatic Terminal Logging (`script`)

Every command you run should be captured to disk without you thinking about it. `script(1)` is preinstalled on every Linux distro and handles this in three lines — no plugins, no config, no session manager to babysit:

```bash
mkdir -p ~/AEN/logs
script -f ~/AEN/logs/aen-$(date +%F-%H%M).log
# ... work ...
exit   # stops recording
```

- `-f` flushes after every write, so if your VM crashes mid-session, everything up to the last keystroke is on disk.
- Each shell gets its own timestamped file — grep across all of them at report-writing time with `grep -rn <pattern> ~/AEN/logs/`.
- Copy the whole `~/AEN/logs/` directory into your engagement's `evidence/logging/` folder at end of day.

Run it at the top of every new terminal you open, and every command + its output is captured automatically.

---

### Standard Report Structure

| # | Section | Audience | Length |
|---|---------|----------|--------|
| 1 | **Executive Summary** | Execs | 1–2 pages |
| 2 | **Scope and Objectives** | Both | <1 page |
| 3 | **Methodology** | Engineers | 1–2 pages |
| 4 | **Findings Summary Table** | Both | 1 page |
| 5 | **Detailed Findings** | Engineers | Bulk of the document |
| 6 | **Attack Path Narrative** | Both | 2–4 pages |
| 7 | **Remediation Roadmap** | Both | 1–2 pages |
| 8 | **Appendices** | Engineers | As needed |

### 1. Executive Summary

What it should answer in three paragraphs:

1. **What we did** — scope, dates, type of assessment.
2. **What we found** — high-level posture statement + risk picture.
3. **What you should do** — top 3–5 priority remediations.

Avoid jargon. The CFO should understand the page.

Example posture statement:

> *Inlanefreight's internal Active Directory environment exhibits a low overall security posture. We obtained Domain Administrator privileges within four hours of the engagement start using only network access and no prior credentials. The principal weaknesses are weak service account passwords, missing patch management on Domain Controllers, and lack of network segmentation between user and server VLANs.*

The audience test: write it as if you're explaining it to your parents while staying professional and concise. If your parents can't understand the point, try again (assuming your parents aren't CISOs). The reader:

- Does not do this every day. They don't know what Rubeus does, what password spraying means, or that a Kerberos ticket can grant other tickets.
- May be reading their first-ever penetration test report.
- Has a short attention span. Once you lose it, you don't get it back.
- Doesn't want to Google what terms mean — that's a distraction.

#### Do

| Rule | Why |
|---|---|
| **Be specific with metrics.** "Several" and "multiple" could mean 6 or 500. Use "25 occurrences" or "while there may be additional instances, we observed 25 in the time allotted." | Vagueness reads as hedging — execs stop reading. |
| **Keep it to 1.5–2 pages max.** If longer, collapse categories into higher-level themes tied to policies/procedures. | It's a *summary*. Detail lives in the findings. |
| **Describe the things you accessed in business terms.** "An account that let us access HR documents, banking systems, and customer records" beats "Domain Admin." | The audience knows what HR documents are; they don't know what DA is. |
| **Prescribe process fixes, not patch lists.** Instead of "install 3 patches," ask "what process broke down that let a 5-year-old CVE go unpatched in a quarter of the estate?" | Patches are today's symptom; process is tomorrow's root cause. |
| **Set effort expectations** if you have the sysadmin background to judge them. Low / moderate / significant. | Prevents an overzealous CEO from telling the server team to apply CIS hardening over the weekend without testing. |

#### Don't

| Anti-pattern | Why to avoid |
|---|---|
| **Naming specific vendors.** OK to say "EDR" or "log aggregation"; not OK to say "CrowdStrike" or "Splunk." Vendor recommendations belong in an out-of-band conversation. | The deliverable is a technical document, not a sales pitch. |
| **Acronyms.** IP and VPN are fine; SNMP, MitM, XSS, LDAP are not — the exec-summary audience does not speak in acronyms. | Every unexplained acronym is a distraction. |
| **Spending more space on trivia than on serious findings.** | You control what the reader remembers. Don't dilute the critical stuff. |

### 2. Scope and Objectives

- Targets (IP ranges, domains, applications).
- Out-of-scope assets and times.
- Engagement type (black box / grey box / white box).
- Authorized testers, dates, contact escalation chain.
- Stated objectives — typically "demonstrate impact" or "validate controls X, Y".

A scope section should make it impossible to claim "you tested something we never authorized."

### 3. Methodology

Describe the process at the level of "we followed PTES" or "we worked through the seven stages: recon, enum, vuln assessment, exploitation, post-ex, lateral, reporting." Reference standards:

- **PTES** — Penetration Testing Execution Standard.
- **OSSTMM** — Open-Source Security Testing Methodology Manual.
- **OWASP Testing Guide v4** — for web apps.
- **NIST SP 800-115** — Technical Guide to Information Security Testing.
- **MITRE ATT&CK** — useful as a tagging vocabulary for techniques used.

### 4. Findings Summary Table

```text
| Finding ID | Title                                  | Severity | CVSS  | Status |
| ---------- | -------------------------------------- | -------- | ----- | ------ |
| F-001      | Domain Admin via Kerberoasting         | Critical | 9.8   | Open   |
| F-002      | Unauthenticated Docker API exposed      | Critical | 9.6   | Open   |
| F-003      | LDAP signing not enforced               | High     | 7.5   | Open   |
| F-004      | Outdated OpenSSH version on jump host   | Medium   | 5.3   | Open   |
| ...        |                                        |          |       |        |
```

### 5. Detailed Findings (the template every finding follows)

```text
#### F-001 — Domain Admin via Kerberoasting

**Severity:** Critical (CVSS 9.8)
**Affected:** corp.inlanefreight.com → svc-sql (Domain Admin)
**Discovered:** 2026-05-21
**CWE:** CWE-262 Not Using Password Aging

**Summary**
A one-paragraph plain-English description.

**Technical Details**
What the issue is, why it exists, what protocols/configurations are involved.

**Reproduction Steps**
Numbered, runnable commands — engineers should be able to reproduce verbatim.

  1. Acquire any valid domain account (e.g. ASREPRoasting of `jdoe`).
  2. Request Kerberos service tickets for SPN-bearing accounts:

     ```bash
     impacket-GetUserSPNs corp.local/jdoe:Spring2026! -dc-ip 10.1.1.10 -request -outputfile spns.txt
     ```

  3. Crack offline:

     ```bash
     hashcat -m 13100 spns.txt rockyou.txt
     ```

  4. Authenticate as `svc-sql` (member of Domain Admins) and demonstrate access.

**Impact**
Domain compromise — full read/write to every system, all credentials.

**Evidence**
- Screenshot of cracked hash with timestamp.
- `nxc smb 10.1.1.10 -u svc-sql -p '<cracked>' --shares` output showing C$ access.

**Remediation**
- Set service account passwords to 25+ characters of high entropy and disable interactive logon.
- Move to gMSA (group Managed Service Accounts) where possible.
- Monitor for Event 4769 with unusual encryption types.

**References**
- MITRE ATT&CK: T1558.003
- CVE-not-applicable
- Microsoft KB article URL
```

### 6. Attack Path Narrative

A prose walkthrough of how the engagement actually unfolded, in order. This is the section non-technical readers tend to remember — it's also where you show the *chain* (low-impact bugs combined into critical compromise).

Example opening:

> *Starting from a single user credential discovered via a successful password spray (Welcome2026! → `jdoe@corp.local`), we performed AD enumeration with BloodHound and identified `svc-sql` as Kerberoastable. The service account's password (`Inlane2024!`) cracked in seconds, granting Domain Admin via group membership in `IT-DBAs`. From there we dumped NTDS.dit and demonstrated read access to all sensitive shares.*

### 7. Remediation Roadmap

Group fixes by:
- **Immediate** (≤ 7 days) — issues being actively exploitable / critical.
- **Short-term** (≤ 30 days) — high-severity hardening.
- **Strategic** (next quarter+) — architecture / process changes.

Pair each item with the finding(s) it closes.

### 8. Appendices

Appendices split into two kinds — **static** (same skeleton across engagements) and **dynamic** (populated from what you actually did on this one).

**Static appendices** — reused with minimal edits per report:

- **Scope** — URLs, network ranges, facilities, dates. Compliance auditors need to see this.
- **Methodology** — the repeatable process you follow (recon → enum → vuln assessment → exploitation → post-ex → lateral → reporting), so a reader can judge whether the assessment was thorough.
- **Severity ratings** — if your severity bands don't directly map to CVSS, define the criteria explicitly. You'll need to defend these on QA and client calls.
- **Consultant biographies** — required for PCI reports (proves consultant qualifications); nice-to-have for others, gives the client confidence.
- **Tools used** (with versions).
- **Glossary** for non-technical readers.

**Dynamic appendices** — populated per engagement:

- **Exploitation attempts & payloads** — everything you fired, including custom payloads dropped on disk, their SHA256 hashes, and their locations. If the blue team investigates a real incident later, they need to differentiate you from a real attacker. Especially critical for payloads you couldn't clean up.
- **Compromised credentials** — every account you broke into. For full-domain compromise, "all domain accounts" is enough — don't list every user; that's noise.
- **Configuration changes** — anything you modified in the environment (hopefully with permission first). List so the client can revert cleanly. Ideal: put it back yourself and get written approval for anything that stays changed.
- **Additional affected scope** — for findings with lots of affected hosts, tabulate them here rather than in the finding body. Multi-column tables keep it clean.
- **Information Gathering** (external pentests) — whois, subdomains, discovered emails, breach-data hits, SSL/TLS analysis, externally-accessible port inventory (big scopes → supplementary spreadsheet). Great for low-finding reports where you still want to convey value.
- **Domain Password Analysis** — after DA, dump NTDS, hashcat with multiple wordlists + rules, brute-force NTLM up to 8 chars if your rig is up to it. Run [DPAT](https://github.com/clr2of8/DPAT) on the results for a statistics report. Include: total hashes obtained, cracked count + %, cracked privileged accounts (DA / EA), top-N passwords, cracked count per character length. Reinforces "weak password" themes throughout the report. Optionally include the full DPAT report as supplementary data.

### Writing Hygiene

- **Use the active voice** — *"We obtained DA"*, not *"DA was obtained"*.
- **Number everything** — every finding ID, every screenshot ("Figure 3.2 — Cracked hash for svc-sql").
- **Avoid color of severity alone** — colorblind readers exist; pair color with the word ("High").
- **Redact before screenshots** — real passwords, real SIDs of the customer's domain.
- **Date stamps** — UTC in artifacts so timelines line up across writers.

### Style: Don't Be Punitive

Write to help, not to dunk. *"The team has historically had limited tooling for service-account rotation, leading to long-lived passwords"* lands better than *"Service-account passwords are negligently old."* The technical content is the same; the relationship matters.

---

### Client Communication (bookend every day)

Send a **start notification** at the beginning of the engagement:

- Tester name
- Description of the type / scope of the engagement
- Source IP address for testing — public IP for external attacks, internal IP if you're on their network
- Anticipated testing dates
- Primary and secondary contact info (email + phone) for both sides

Send a **stop notification** at the end of each testing day:

- One-line summary that testing has stopped for the day
- If you found anything critical, a high-level heads-up so the report doesn't blindside them 3 weeks later ("we ended today with Domain Admin — details in the final report")
- Reiterate expected delivery date for the report

Both emails go to the primary POC + a backup, cc'd to your own PM.

---

### Working Habits That Compound

Small habits that separate consistent reports from panicked all-nighters:

- **Write as you go.** Notes don't need to be perfect in the moment, but documenting each finding when it's fresh beats reconstructing it three days later from a screenshot with no context.
- **Stay chronological.** Notes in the order you did the work — easier to trace an attack chain back and to answer "when did you find X?" from a stakeholder.
- **Evidence should be unarguable.** Screenshotting a login prompt to prove basic auth isn't enough — pair it with a Wireshark capture showing the plaintext creds in the auth request. Leave no room for the client to argue "but that could be TLS-inside." (See [Deliverables & Remediation](./03-deliverables-remediation.md) for the evidence bar.)
- **Redact as you screenshot**, not before you submit — waiting until report-writing time means you'll miss things.
- **Autosave + off-VM backup.** Notes and the report should both live somewhere that survives the pentest VM crashing.
- **Automate anything you do on every engagement** — scoping doc generation, folder scaffolding, VPN setup script, log-rotation, etc.

---

### Lessons From Real Attack Chains

Small operational learnings that come up in real internal AD engagements — worth internalizing before you go on-site:

- **Start Responder immediately** when you land on an internal AD network. NBT-NS and LLMNR poisoning are the highest-ROI passive attack; run it in the background from minute one and check the log periodically for captured NetNTLMv2 hashes.
- **BloodHound weird?** Restart with `bloodhound-startup` — it fixes almost every "won't launch / can't connect" issue.
- **Local admin creds are a pivot, not the goal.** Dump secrets on the local box, look for a **domain** account (often a service account cached locally). If that domain account has no NTLM hash but has an AES key, request a TGT with:

  ```bash
  getTGT.py -aesKey <aes-key> 'inlanefreight.local/DEV01$'
  export KRB5CCNAME=DEV01\$.ccache
  ```

  Then run BloodHound as that account:

  ```bash
  bloodhound-python -u 'DEV01$' -k -no-pass -d inlanefreight.local \
    -ns 172.16.5.5 --dc DC01.INLANEFREIGHT.LOCAL -c all --zip
  ```

- **Bloodhound-start** is the incantation to launch the UI itself once the data is imported.
