# 02 — Engagement Types & Compliance

**Jump to:** [Engagement Types](#engagement-types) · [Pentest vs. Red Team — Where the Lines Are](#pentest-vs-red-team--where-the-lines-are) · [Compliance Frameworks](#compliance-frameworks) · [Authorization — The Single Most Important Document](#authorization--the-single-most-important-document) · [When You Find Something Out-of-Scope](#when-you-find-something-out-of-scope)

The same technical work can be wrapped in very different engagement shapes. The shape determines who reads the report, how much detection-and-response gets tested, and which compliance language goes in the cover letter.

---

### Engagement Types

| Type | Description | Goal |
|------|-------------|------|
| **Vulnerability Assessment** | Identify and categorize weaknesses, almost no exploitation. | Inventory + prioritize. |
| **Penetration Test** | Authorized exploitation that demonstrates impact via chained findings. | Validate risk; show the "so what." |
| **Red Team Assessment** | Evasive, objective-driven, often unannounced to the blue team. | Test detection, response, and people, not just tech. |
| **Bug Bounty** | Public/private invitation to find bugs with restrictions. | Crowdsource testing at scale. |
| **Security Audit** | Compliance-driven, often mandated by a government / regulator. | Prove conformance to a standard. |
| **Purple Team** | Pentesters + defenders working together in real time. | Tune detections directly off real attacks. |

#### Black / Grey / White Box

| Box | What the tester knows |
|-----|----------------------|
| **Black box** | Nothing — external IP / domain only. Simulates an outside attacker. |
| **Grey box** | Some — a user account, partial network diagram. Simulates an insider or compromised contractor. |
| **White box** | Everything — source code, architecture docs, admin creds. Maximizes finding density per hour. |

### Pentest vs. Red Team — Where the Lines Are

| Dimension | Pentest | Red Team |
|-----------|---------|----------|
| Scope | Specific systems/applications | Business objective (e.g. "reach the crown jewels") |
| Time | Days/weeks | Weeks/months |
| Blue team awareness | Knows it's happening | Usually doesn't |
| Goal | Find as many findings as possible | Achieve the objective stealthily |
| Tooling | Standard pentest stack | Custom C2, evasion, social engineering |
| Report focus | Findings + remediation | Attack narrative + detection gaps |

### Compliance Frameworks

| Framework | Sector | Headline requirements relevant to a pentester |
|-----------|--------|------------------------------------------------|
| **PCI DSS** (Payment Card Industry Data Security Standards) | Anyone storing/processing/transmitting cardholder data | Annual penetration tests (Req 11.4.x), segmentation testing, retests after material change. |
| **HIPAA** (Health Insurance Portability and Accountability Act) | U.S. healthcare; protects PHI (Protected Health Information) | Regular technical risk assessments; not prescriptive on pentest cadence but expects one as part of due diligence. |
| **FISMA** (Federal Information Security Modernization Act) | U.S. federal agencies & contractors | Continuous monitoring, NIST SP 800-53 controls, system authorization. |
| **ISO 27001** | International — any sector | ISMS (Information Security Management System); requires "technical compliance review" (clause A.18.2.3) which pentesting satisfies. |
| **SOC 2** | Service organizations | Trust services criteria (security, availability, confidentiality, processing integrity, privacy). Type II audits typically demand annual penetration testing. |
| **NIST SP 800-115** | Reference, not regulation | Technical Guide to Information Security Testing — every framework above references it. |
| **CMMC** | U.S. DoD supply chain | Maturity levels; Level 3+ requires red-team-style assessment. |

#### What the auditor wants in the report

- A statement of scope mapped to the framework's control IDs.
- Methodology aligned to NIST SP 800-115 / PTES / OSSTMM.
- Findings tagged with the affected control(s).
- A retest after remediation, with a signed statement.
- The tester's certifications (where they matter — OSCP, OSCE, CRTO, GIAC family).

### Authorization — The Single Most Important Document

Before any active testing starts, you need:
- A **Rules of Engagement (RoE)** document signed by an executive with authority over the assets.
- Scope (IPs, domains, applications) + out-of-scope assets.
- Permitted test windows (avoid black-out periods, peak business hours).
- Escalation contacts on both sides (24/7 phone).
- Data-handling agreement — what you store, where, and for how long.

Without signed authorization, **everything you do is illegal** under CFAA / equivalents. Save the RoE PDF to the engagement folder before launching `nmap`.

### When You Find Something Out-of-Scope

Stop. Notify the client. Document the discovery (where, when, how) but do not exploit. Out-of-scope discoveries often signal scope was undersized — a good opportunity to expand the engagement.
