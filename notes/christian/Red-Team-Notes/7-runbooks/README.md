# Runbooks

Practical "when I'm stuck, run this" playbooks by phase. Each file is a topical checklist — not a curriculum. Every item is something to actually **do**, in order of highest expected value.

The main notes (`1-` through `5-`) explain *how* each technique works. **This section is the reflex layer** — read a runbook, work top-to-bottom, tick items as you go.

## General Reminders

- **`nxc` for Windows, `medusa` for everything else.** [Password Attacks](../2-pre-exploitation/03-password-attacks.md).
- **Never rabbit-hole.** If a technique isn't working after 45 minutes, tick it off and move to the next item.
- **Every credential goes in a `creds.txt`** with the format `<user>:<pass>` — it feeds directly into `nxc smb <ip> -u users.txt -p passwords.txt --continue-on-success`.
- **Every host goes in `hosts.txt`.** Every subdomain in `subdomains.txt`. Every URL in `urls.txt`.

## Index

| # | File | Trigger |
|---|------|---------|
| 00 | [Methodology & Setup](./00-methodology.md) | Before the op starts |
| 01 | [Recon](./01-recon.md) | New host on the scope |
| 02 | [Web](./02-web.md) | Any HTTP(S) port |
| 03 | [Active Directory](./03-active-directory.md) | Port 88 / 389 / 445 / 464 |
| 04 | [Linux Privesc](./04-linux-privesc.md) | Shell on Linux |
| 05 | [Windows Privesc](./05-windows-privesc.md) | Shell on Windows |
| 06 | [Password Attacks](./06-password-attacks.md) | Any hash, or a login you can spray |
| 07 | [Pivoting](./07-pivoting.md) | Second subnet visible from a foothold |

## Quick decision tree

```
New host?              → 01-recon.md
HTTP alive?            → 02-web.md
SMB / LDAP / Kerberos? → 03-active-directory.md
Got a shell?           → 04-linux-privesc.md  or  05-windows-privesc.md
Got a hash?            → 06-password-attacks.md
New subnet visible?    → 07-pivoting.md
```
