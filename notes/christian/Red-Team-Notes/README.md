# Red Team Notes

A clean, sectioned reference distilled from HTB CPTS coursework, CIS4201 material, and lab notes — now scoped toward red-team operations.

Each stage folder holds a set of `.md` files covering one focused topic; sections mirror an engagement from the first packet through post-ex and pivoting.

---

## Master Directory

| # | Stage | What lives here |
|---|-------|-----------------|
| 1 | [Information Gathering](./1-information-gathering/) | OSINT, DNS, Nmap, service & web recon, AD enumeration |
| 2 | [Pre-Exploitation](./2-pre-exploitation/) | Vulnerability assessment concepts, web proxies, password / wordlist prep |
| 3 | [Exploitation](./3-exploitation/) | Shells, payloads, Metasploit, file transfers, web exploits, AD initial access |
| 4 | [Post-Exploitation](./4-post-exploitation/) | Linux & Windows privesc, credential dumping, persistence, stealth, shell upgrades |
| 5 | [Lateral Movement](./5-lateral-movement/) | AD overview, Kerberos attacks, ACL abuse, Windows pivoting |
| 6 | [Report Writing](./6-report-writing/) | Report structure, engagement types & compliance, deliverables & remediation |
| 7 | [Runbooks](./7-runbooks/) | Actionable "when I'm stuck, run this" playbooks by phase |

---

## Full Section Index

### 1. Information Gathering
- [01 - OSINT](./1-information-gathering/01-osint.md)
- [02 - DNS Reconnaissance](./1-information-gathering/02-dns-recon.md)
- [03 - Nmap](./1-information-gathering/03-nmap.md)
- [04 - Service Enumeration](./1-information-gathering/04-service-enumeration.md)
- [05 - Web Reconnaissance](./1-information-gathering/05-web-recon.md)
- [06 - Active Directory Enumeration](./1-information-gathering/06-active-directory-enumeration.md)

### 2. Pre-Exploitation
- [01 - Vulnerability Assessment](./2-pre-exploitation/01-vulnerability-assessment.md)
- [02 - Web Proxies](./2-pre-exploitation/02-web-proxies.md)
- [03 - Password Attacks](./2-pre-exploitation/03-password-attacks.md)
- [04 - Wordlist Generation](./2-pre-exploitation/04-wordlist-generation.md)

### 3. Exploitation
- [01 - Shells and Payloads](./3-exploitation/01-shells-and-payloads.md)
- [02 - Metasploit](./3-exploitation/02-metasploit.md)
- [03 - File Transfers](./3-exploitation/03-file-transfers.md)
- [04 - Web Exploits](./3-exploitation/04-web-exploits.md)
- [05 - AD Initial Access](./3-exploitation/05-ad-initial-access.md)
- [06 - Container Escape](./3-exploitation/06-container-escape.md)
- [07 - Attacking Common Applications](./3-exploitation/07-attacking-common-applications.md)
- [08 - Sliver C2](./3-exploitation/08-sliver-c2.md)

### 4. Post-Exploitation
- [01 - Linux Privilege Escalation](./4-post-exploitation/01-linux-privilege-escalation.md)
- [02 - Windows Privilege Escalation](./4-post-exploitation/02-windows-privilege-escalation.md)
- [03 - Credential Dumping](./4-post-exploitation/03-credential-dumping.md)
- [04 - Persistence](./4-post-exploitation/04-persistence.md)
- [05 - Shell Upgrades](./4-post-exploitation/05-shell-upgrades.md)
- [06 - Stealth Persistence & OPSEC](./4-post-exploitation/06-stealth-persistence.md)

### 5. Lateral Movement
- [01 - Active Directory Overview](./5-lateral-movement/01-active-directory-overview.md)
- [02 - AD Protocols](./5-lateral-movement/02-ad-protocols.md)
- [03 - Kerberos Attacks](./5-lateral-movement/03-kerberos-attacks.md)
- [04 - ACL Abuse with bloodyAD](./5-lateral-movement/04-acl-abuse-bloodyad.md)
- [05 - Windows Pivoting](./5-lateral-movement/05-windows-pivoting.md)
- [06 - MSSQL Abuse](./5-lateral-movement/06-mssql-abuse.md)

### 6. Report Writing
- [01 - Report Fundamentals](./6-report-writing/01-report-fundamentals.md)
- [02 - Engagement Types & Compliance](./6-report-writing/02-engagement-types.md)
- [03 - Deliverables and Remediation](./6-report-writing/03-deliverables-remediation.md)

### 7. Runbooks
- [00 - Methodology & Setup](./7-runbooks/00-methodology.md)
- [01 - Recon](./7-runbooks/01-recon.md)
- [02 - Web](./7-runbooks/02-web.md)
- [03 - Active Directory](./7-runbooks/03-active-directory.md)
- [04 - Linux Privesc](./7-runbooks/04-linux-privesc.md)
- [05 - Windows Privesc](./7-runbooks/05-windows-privesc.md)
- [06 - Password Attacks](./7-runbooks/06-password-attacks.md)
- [07 - Pivoting](./7-runbooks/07-pivoting.md)

---

## Conventions

- All files are standard Markdown (`.md`) for direct rendering on GitHub.
- Each file opens with a short summary, then practical content organized by tool or technique.
- Code blocks are fenced with `bash`, `powershell`, `php`, `sql`, etc. so syntax highlighting works on GitHub.
- Placeholders use `<angle-brackets>` (e.g. `<dc-ip>`, `<domain>`, `<user>`) — replace with engagement values.

## Layout

```
notes_refurb/
├── README.md                       ← this file (master directory)
├── 1-information-gathering/
│   ├── README.md                   ← stage index
│   ├── 01-osint.md
│   ├── 02-dns-recon.md
│   └── ...
├── 2-pre-exploitation/
├── 3-exploitation/
├── 4-post-exploitation/
├── 5-lateral-movement/
├── 6-report-writing/               ← report structure, engagement types, remediation
├── 7-runbooks/                     ← actionable playbooks by phase
└── _archive/                       ← original PDF sources
```

## Acknowledgements

Structural inspiration from [sachinn403/HTB-CPTS-Notes](https://github.com/sachinn403/HTB-CPTS-Notes). Source content distilled from personal CIS4201 course notes and HTB CPTS path lab work.
