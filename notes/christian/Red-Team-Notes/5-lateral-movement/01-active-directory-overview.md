# 01 — Active Directory Overview

**Jump to:** [Structure](#structure) · [Identifiers](#identifiers) · [Well-Known RIDs Worth Remembering](#well-known-rids-worth-remembering) · [Default High-Value Groups](#default-high-value-groups) · [Trusts](#trusts) · [Access Control Building Blocks](#access-control-building-blocks) · [Group Policy (quick mental model)](#group-policy-quick-mental-model) · [See Also](#see-also)

A grounding section before the protocol- and attack-specific chapters. If the words *forest*, *domain*, *OU*, *trust*, *SID*, *RID* aren't muscle memory, this is the place to start.

---

### Structure

```text
Forest
└── Domain (root)
    ├── Domain (child)
    └── Domain (tree root)
        ├── OU (Organizational Unit)
        │   ├── User
        │   ├── Group
        │   └── Computer
        └── OU
```

| Term | What it is |
|------|-----------|
| **Forest** | Top-level security boundary — collection of one or more trees that share a schema and global catalog. |
| **Domain** | Logical grouping (e.g. `corp.inlanefreight.com`) with its own DCs, users, computers. |
| **Tree** | Domains that share a contiguous namespace (`a.contoso.com` + `b.contoso.com`). |
| **Domain Controller (DC)** | Server that holds AD database and authenticates users. |
| **Organizational Unit (OU)** | Container for objects; the unit GPOs are linked to. |
| **Object** | User, computer, group, GPO, etc. |
| **Trust** | Relationship between domains/forests that lets users authenticate across them. |

### Identifiers

| Identifier | Format | Example |
|------------|--------|---------|
| **SID** | `S-1-5-21-<domain>-<rid>` | `S-1-5-21-3623811015-3361044348-30300820-500` |
| **RID** | Last part of SID — relative within the domain | `500` (built-in Admin), `513` (Domain Users), `512` (Domain Admins) |
| **GUID** | 128-bit globally unique ID | `4B6C72A1-EC8D-4F1F-9C7E-...` |
| **UPN** | `<user>@<domain>` | `jdoe@corp.local` |
| **sAMAccountName** | Legacy NT-style login name | `CORP\jdoe` |

### Well-Known RIDs Worth Remembering

| RID | Object |
|-----|--------|
| 500 | Built-in Administrator |
| 501 | Guest |
| 502 | krbtgt (TGT-signing service account) |
| 512 | Domain Admins |
| 513 | Domain Users |
| 514 | Domain Guests |
| 516 | Domain Controllers |
| 519 | Enterprise Admins |
| 525 | Protected Users (post 2012 R2) |

### Default High-Value Groups

| Group | Why it matters |
|-------|----------------|
| **Domain Admins** | Full control over the domain. |
| **Enterprise Admins** | Full control over every domain in the forest. |
| **Schema Admins** | Modify AD schema — rare in practice but devastating if abused. |
| **Account Operators** | Reset passwords for most user accounts. |
| **Backup Operators** | Read/write any file (often → DC SYSTEM). |
| **DnsAdmins** | Load a DLL into the DNS service running as SYSTEM. |
| **Server Operators** | Service control on DCs → SYSTEM. |
| **Print Operators** | Driver install → SYSTEM (rare in modern envs). |
| **Cert Publishers** | Manage AD CS — high-value as cert abuse grows (Certifried, ESC1-ESC8). |

### Trusts

| Direction | Meaning |
|-----------|---------|
| **One-way trust (A → B)** | B trusts A's principals; A doesn't trust B's. |
| **Two-way trust** | Both sides accept each other's authentication. |
| **Transitive** | Trust extends through chains (A trusts B, B trusts C → A trusts C). |
| **External** | Trust to a domain outside the forest (non-transitive by default). |
| **Forest trust** | Between two entire forests. |

### Access Control Building Blocks

| Construct | What it does |
|-----------|--------------|
| **ACE (Access Control Entry)** | A single permission grant on an object. |
| **DACL** | Discretionary ACL — list of ACEs that govern access. |
| **SACL** | System ACL — controls auditing (who gets logged). |
| **AdminSDHolder** | Template ACL re-applied to protected groups every 60 min (kills your privesc if you don't change AdminSDHolder itself). |

Useful ACE rights for attackers:

| Right | Why |
|-------|-----|
| `GenericAll` | Total control of the object. |
| `WriteOwner` | Make yourself the owner → grant yourself any right. |
| `WriteDACL` | Modify the ACL → grant yourself rights. |
| `ForceChangePassword` | Reset the user's password. |
| `AddSelf` | Add yourself to the group. |
| `DCSync` (Replicating Directory Changes + All + Changes In Filtered Set) | Pull all NTLM hashes from DC. |

BloodHound surfaces all of these as attack edges.

### Group Policy (quick mental model)

GPOs are policies linked to **sites, domains, or OUs**. Order of application: Local → Site → Domain → OU. Inheritance can be blocked; enforcement overrides blocks.

Attacker uses for GPO:
- Add a startup/logon script (run on every machine an OU targets).
- Push a scheduled task / installed MSI to every machine.
- Modify Group Policy Preferences (`Groups.xml` historically stored AES-encrypted passwords — known key → recoverable).

### See Also
- [Active Directory Enumeration](../1-information-gathering/06-active-directory-enumeration.md) — for mapping objects, ACLs, and trusts with BloodHound / netexec.
- [AD Protocols](./02-ad-protocols.md) — the wire-level details (Kerberos, NTLM, LDAP).
- [Kerberos Attacks](./03-kerberos-attacks.md) — for ticket-based lateral movement.
