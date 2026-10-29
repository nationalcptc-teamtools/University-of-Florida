# 03 — Deliverables and Remediation

**Jump to:** [Engagement Folder Structure](#engagement-folder-structure) · [Formatting & Redaction — Screenshots](#formatting--redaction--screenshots) · [Word (or LibreOffice) — Author Efficiency](#word-or-libreoffice--author-efficiency) · [QA Process](#qa-process) · [Standard Deliverables](#standard-deliverables) · [Risk Scoring](#risk-scoring) · [Writing Remediation Guidance](#writing-remediation-guidance) · [Evidence](#evidence) · [Retest Process](#retest-process) · [SLAs to Suggest](#slas-to-suggest) · [Presentation / Readout](#presentation--readout) · [Common Pitfalls](#common-pitfalls) · [Tooling](#tooling)

A report isn't finished when the PDF is signed. The full deliverable set drives the client through *fix → verify → close*, and that's what generates the next engagement.

---

### Engagement Folder Structure

Set this up on day 0 alongside your [notetaking scaffold](./01-report-fundamentals.md#notetaking-strategy-start-before-you-fire-the-first-packet). Same folder every time — muscle memory saves hours.

```
engagement/
├── admin/                    Scope of Work, kickoff notes, status reports, vuln notifications
├── deliverables/             Report + supplementary sheets, slide decks
├── evidence/
│   ├── findings/             One subfolder per finding — evidence lives with the narrative
│   └── scans/
│       ├── vuln/             Nessus / OpenVAS exports (native format)
│       ├── service_enum/     Nmap / Masscan / Rumble output
│       ├── web/              Burp / ZAP state files, EyeWitness / Aquatone screenshots
│       └── ad/               BloodHound JSON, PowerView / ADRecon CSV, Ping Castle, Snaffler,
│                              nxc logs, impacket output
├── notes/                    Your working notes (OneNote / Obsidian export goes here)
├── osint/                    Intelx, Maltego, DeHashed pulls that don't fit inline
├── wireless/                 Optional — kismet / airodump captures if wireless is in scope
├── logging/                  `script(1)` session logs, msfconsole spool files
└── misc/                     Web shells, payloads, custom scripts touched during the engagement
```

The **findings subfolder per finding** is the pattern that pays off most — when you write the report, you're just assembling narrative + evidence from a folder rather than hunting through a monolithic dump.

---

### Formatting & Redaction — Screenshots

The screenshot rules that separate a signed-off report from a "please revise" reply:

- **Redact credentials + PII in screenshots.** Solid black boxes over the sensitive region — never blur (deblurring tools are trivially good). For terminal output, use black bars printed *in the terminal* or edit the log before capture. First 4 chars of a hash is fine to show it *is* a hash.
- **Annotate on the image** (arrows, red boxes) — draw the reader's eye. Do this in Greenshot / Flameshot, not in MS Word.
- **Add a minimal border** so the image stands out against the page.
- **Crop to just the relevant region.** No full-screen captures — a login form is a login form, not a login form plus your taskbar and open Discord.
- **Show a URL bar or hostname context** so the reader knows *what* they're looking at without hunting.
- **Terminal aesthetics:** solid black background, white or green text — no transparent shells, no rainbow themes. Clients sometimes print reports; dark-on-light saves toner and is more legible on paper.
- **Keep your prompt professional.** Nothing screenshotted with `azzkicker@clientsmasher$ ` will survive QA.

#### What NOT to include in the archive

- Unredacted PII
- Anything potentially criminal
- Anything considered legally discoverable that isn't strictly necessary to prove the finding
- Individual sensitive files as screenshots — instead, screenshot the *directory listing showing you had read permission*. Same evidentiary weight, no data leakage.

#### Redacting tool output

- Replace `(Pwn3d!)`-style tags in CrackMapExec / nxc output — configurable in the tool's config file so you don't hand-edit every screenshot.
- Sanity-check `hashcat --show` output for anything crude in the cracked candidates. Rockyou is full of it — swap any offensive password for something innocuous. Yes, this counts as altering command output, but preserving the *finding* (weak password) while removing an unprofessional artifact is fine.
- Spell out acronyms on first use. `IPv4`, `VPN` — safe. `SNMP`, `MitM`, `LDAP` — expand on first mention.

---

### Word (or LibreOffice) — Author Efficiency

The reporting tool matters less than these habits — the goal is zero "direct formatting" in the document:

| Habit | Payoff |
|---|---|
| **Font styles for every text element.** Never highlight-then-bold; apply a style. | Update the style once, every instance updates. Fixing a heading in 45 places at report-review time is soul-crushing. |
| **Table styles** — same principle for tables. | Global consistency, fewer QA nits. |
| **Built-in captions** (right-click image → Insert Caption). | Captions renumber automatically when you add/remove figures. Otherwise every insertion is manual carnage. |
| **Page numbers.** | Referring to "second paragraph on page 12" during client Q&A is dramatically easier than "in the section about, uh, the Kerberos thing." |
| **Table of Contents + List of Figures/Tables** — generated from styles + captions. | One-click refresh (`Ctrl-A` then `F9` in Word). |
| **Bookmarks** — anchor targets for internal hyperlinks. | Lets appendix cross-references survive section reordering. Also useful with macros to strip sections. |
| **Custom dictionary / AutoCorrect entries** for words you always misspell (e.g., writing "pubic" instead of "public"). | Prevents career-defining typos. Doesn't travel with the template — configure per person. |
| **Language settings — mark code / terminal style as "do not spell-check."** | Spellcheck stops nagging you 400 times about `impacket-secretsdump` and `NetNTLMv2`. |
| **Custom numbering** for findings, appendices, etc. | Renumbering after insertion is automatic. |

#### Quick Access Toolbar additions

`File → Options → Quick Access Toolbar` — worth adding:

- **Back** — after clicking a hyperlink you inserted, jumps you back to where you were.
- **Undo / Redo** — if you don't reflex-hit `Ctrl-Z`.
- **Save** — same, for `Ctrl-S`.
- Then set "Choose commands from" → "Commands Not in the Ribbon" to browse the deeply-buried tools worth surfacing.

#### Word hotkeys worth muscle-memorizing

| Shortcut | What |
|---|---|
| `F4` | Repeats the last action. Highlight text → apply style → then highlight next region → `F4`. |
| `Ctrl-A` then `F9` | Update every field in the document — ToC, list of figures, cross-references. Occasionally misbehaves, so save first. |
| `Ctrl-S` | Save. Do it constantly — Word crashes. |
| `Ctrl-Alt-S` | Split the window into two panes for referencing distant sections without scrolling back and forth. |
| `Shift-F5` | Move cursor to the last edit position — useful when you tab away and lose your place, or accidentally type into Discord. |

---

### QA Process

- **Two reviewers besides yourself** — you should never review your own writing. If you're solo, at minimum sleep on it one night and re-read fresh; walking away and coming back catches things staring won't.
- **Style guide** — everyone on the team writes to the same rules (voice, capitalization, finding-title format). Consistency reads as competence.
- **Grammar/spelling tools** — Grammarly or LanguageTool are meaningfully better than Word's built-in checker. Be aware some tools ship text to the cloud for "learning" — check the ToS against your client's data-handling agreement.
- **Whitehat** — a platform worth learning post-CPTS; it stores findings so you don't retype the same three sentences for every "weak password" finding across engagements.

---

### Standard Deliverables

| Artifact | Purpose | Audience |
|----------|---------|----------|
| **Report (PDF)** | Primary deliverable. | Both |
| **Executive briefing slides** | 10-15 slides; talked through with leadership. | Execs |
| **Findings spreadsheet (XLSX)** | One row per finding, sortable / filterable / importable into ticketing. | Engineers |
| **Raw evidence pack** | Screenshots, command outputs, capture files. Often a zip. | Engineers / auditors |
| **Scanner output** | Nessus / OpenVAS / Burp scans in native format. | Engineers |
| **Retest report** | Delta report after remediation. | Both |

### Risk Scoring

#### CVSS v3.1 (the current default)

Score = base × temporal × environmental modifiers.

Severity bands:

| Range | Severity |
|-------|----------|
| 9.0 – 10.0 | Critical |
| 7.0 – 8.9 | High |
| 4.0 – 6.9 | Medium |
| 0.1 – 3.9 | Low |
| 0.0 | Informational |

Always include the **CVSS vector string** alongside the number — others should be able to recompute.

```bash
CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H   = 9.8 Critical
```

CVSS v4.0 is gaining traction; if the client requests it, use the matching calculator. Pure CVSS misses business context, so almost every mature program augments with their own **Likelihood × Impact** matrix.

#### Likelihood × Impact (the contextual fix)

| Likelihood | Impact | Risk |
|-----------|--------|------|
| Low | Low | Low |
| Low | Medium | Low |
| Low | High | Medium |
| Medium | Low | Low |
| Medium | Medium | Medium |
| Medium | High | High |
| High | Low | Medium |
| High | Medium | High |
| High | High | Critical |

Likelihood factors: required privilege, exploit availability, accessibility, detection presence.
Impact factors: data sensitivity, blast radius, regulatory exposure, recovery cost.

### Writing Remediation Guidance

Bad: *"Apply patches."*
Better: *"Apply Microsoft security update KB5005565 (released Sept 2021) to all Server 2016 Domain Controllers to address CVE-2021-36934."*
Best: *"Apply KB5005565 to all 2016 DCs by 2026-06-30; in the interim, restrict access to volume shadow copy backups by removing READ for `BUILTIN\Users` on `C:\Windows\System32\config`."*

A good remediation block answers:

1. **What to change** (specific config / patch / code).
2. **Where to change it** (file path, console, GPO).
3. **How to verify** (the command or check that proves the fix).
4. **By when** (deadline tied to severity SLAs).
5. **Compensating controls** if a fast fix isn't possible.

### Evidence

For each finding:

- **Timestamped** screenshot (full window, no cropping that hides context).
- The exact command(s) run, copy-pastable.
- Output excerpts long enough to be conclusive but redacted of unrelated noise.
- The IP/hostname of every system involved.

Store the evidence pack alongside the report — auditors and retest teams need it.

### Retest Process

1. Client signals "ready for retest" on specific findings.
2. Test only those findings (re-running adjacent tests is scope creep unless paid for).
3. Outcomes:
   - **Closed** — issue no longer reproducible.
   - **Partially mitigated** — risk reduced but exploit still possible.
   - **Open** — fix didn't take.
4. Issue a short retest report — usually 2–5 pages.

### SLAs to Suggest

Default starter SLAs (client can negotiate):

| Severity | Triage | Fix |
|----------|--------|-----|
| Critical | 24h | 7 days |
| High | 72h | 30 days |
| Medium | 7 days | 90 days |
| Low | 30 days | 180 days |
| Informational | — | next planning cycle |

### Presentation / Readout

After delivery, run a 30–60 min walkthrough:
- Slides 1–3: executive posture & top risks.
- Slides 4–8: attack narrative (the chain).
- Slides 9–12: remediation roadmap.
- Q&A.

Goals: shared understanding, clear ownership of each remediation, agreement on the retest window. Send the slides to attendees afterward — they'll be circulated up the chain.

### Common Pitfalls

| Pitfall | Cost |
|---------|------|
| Findings without reproduction steps | Engineers ignore them; "we can't verify" → no fix |
| Vague severity ("seems bad") | Triage process can't prioritize |
| No evidence of impact | Easy for stakeholders to dismiss |
| Mixed exec/engineer language | Both audiences disengage |
| Big screenshots, tiny font | Print versions illegible — use real text where you can |
| No retest plan | Findings linger for years |

### Tooling

| Tool | Use |
|------|-----|
| **SysReptor** | Open-source pentest reporting platform. |
| **Dradis** | Findings DB + report generator. |
| **PwnDoc** | Open-source pentest report tool. |
| **Markdown + Pandoc** | DIY; convert your `.md` notes into a polished PDF. |
| **LaTeX template (Eisvogel etc.)** | High-quality PDF rendering for Markdown sources. |

For a Markdown-based workflow:

```bash
pandoc report.md -o report.pdf --template=eisvogel --toc
```
