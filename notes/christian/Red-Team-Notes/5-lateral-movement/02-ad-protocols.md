# 02 — AD Protocols

**Jump to:** [Kerberos (88, 464)](#kerberos-88-464) · [NTLM (no fixed port — over SMB 445, HTTP, MSSQL, etc.)](#ntlm-no-fixed-port--over-smb-445-http-mssql-etc) · [LDAP (389) / LDAPS (636)](#ldap-389--ldaps-636) · [SMB (445)](#smb-445) · [DNS (53)](#dns-53) · [Global Catalog (3268 / 3268S)](#global-catalog-3268--3268s) · [WinRM (5985 / 5986)](#winrm-5985--5986) · [WMI (135 + dynamic high ports)](#wmi-135--dynamic-high-ports) · [MS-RPC over Named Pipes / TCP](#ms-rpc-over-named-pipes--tcp) · [See Also](#see-also)

The wire-level pieces of Active Directory. Knowing the protocols lets you predict which attacks apply, which logs they leave, and where to coerce / relay.

---

### Kerberos (88, 464)

Token-based authentication. No password is sent after initial auth.

```text
1. Pre-auth   : Client encrypts a timestamp with its own NT hash.
2. AS-REQ     : "Give me a TGT" → sent to KDC.
3. AS-REP     : KDC returns a TGT (encrypted with krbtgt's key) + session key.
4. TGS-REQ    : Client presents TGT to request a Service Ticket for SPN X.
5. TGS-REP    : KDC returns a Service Ticket (encrypted with the service's key).
6. AP-REQ     : Client presents Service Ticket to the service → authenticated.
```

Why it matters for attacks:

| Step | Attack |
|------|--------|
| AS-REQ (no pre-auth required) | **ASREPRoasting** — request hash without auth, crack offline |
| TGS-REP | **Kerberoasting** — request ST for any SPN, crack offline |
| TGT itself | **Golden Ticket** — forge with krbtgt hash |
| Service Ticket | **Silver Ticket** — forge for one service with that service's hash |
| S4U2Self / S4U2Proxy | **Constrained delegation** — impersonate any user to a target SPN |

Common error → action:

| Error | What |
|-------|------|
| `KRB5KRB_AP_ERR_SKEW` | Clock skew > 5 min — `ntpdate <dc-ip>` |
| `KDC_ERR_PREAUTH_REQUIRED` | Account does require pre-auth (not AS-REP-roastable) |
| `KDC_ERR_C_PRINCIPAL_UNKNOWN` | Bad username |
| `KDC_ERR_S_PRINCIPAL_UNKNOWN` | Bad SPN target |

### NTLM (no fixed port — over SMB 445, HTTP, MSSQL, etc.)

Challenge/response — server sends a nonce, client encrypts with its NT hash, server validates.

| Hash variant | Where you see it | Hashcat mode |
|--------------|------------------|--------------|
| **LM** | Old / legacy Windows | 3000 |
| **NTLM (NT hash)** | SAM / NTDS.dit, DCSync, mimikatz | 1000 |
| **NetNTLMv1** | Old captures | 5500 |
| **NetNTLMv2** | Responder / wire capture | 5600 |

Why it matters: NetNTLMv2 hashes are crackable; if you can coerce auth (file UNC, PrinterBug, PetitPotam) and the target doesn't enforce SMB signing, **you can relay** to LDAP, MSSQL, HTTP for instant access — see [AD Initial Access → NTLM Relay](../3-exploitation/05-ad-initial-access.md).

### LDAP (389) / LDAPS (636)

Read/query AD objects. Foundation of every enumeration tool (BloodHound, netexec, PowerView, etc.).

```bash
## Anonymous bind
ldapsearch -x -H ldap://<dc> -s base

## Authenticated search
ldapsearch -x -H ldap://<dc> -D 'CORP\jdoe' -w '<pass>' -b 'dc=corp,dc=local' \
    "(objectClass=user)"

## Filter for specific attributes
ldapsearch -x -H ldap://<dc> -D 'CORP\jdoe' -w '<pass>' -b 'dc=corp,dc=local' \
    "(objectClass=user)" sAMAccountName memberOf description
```

Useful LDAP filters:

| Filter | What it finds |
|--------|---------------|
| `(samAccountType=805306368)` | Users |
| `(samAccountType=805306369)` | Computers |
| `(objectClass=group)` | Groups |
| `(userAccountControl:1.2.840.113556.1.4.803:=4194304)` | DOES_NOT_REQUIRE_PREAUTH (ASREProast) |
| `(servicePrincipalName=*)` | Accounts with SPNs (Kerberoast) |
| `(adminCount=1)` | Members of protected groups |

### SMB (445)

File-sharing protocol; also carries IPC$, SAMR, LSARPC, DRSUAPI (replication / DCSync), etc. — most of what `impacket-*` tools use.

| Channel | What's there |
|---------|--------------|
| `IPC$` | Inter-process — RPC over named pipes |
| `\PIPE\samr` | Account info (RID brute, users) |
| `\PIPE\lsarpc` | LSA — SID/domain queries |
| `\PIPE\netlogon` | Used for Zerologon |
| `\PIPE\drsuapi` | Directory replication — DCSync |

Versions to flag:
- **SMBv1** — vulnerable to EternalBlue (MS17-010), should be disabled everywhere.
- **SMB signing off** — enables relay.

```bash
nxc smb <ip>                               # banner + signing
nmap -p445 --script smb-protocols <ip>
nmap -p445 --script smb-security-mode <ip>
```

### DNS (53)

In AD, DNS is usually hosted on DCs. Members register their A records dynamically. Why it matters:

- **Resolve hosts**: `dig +short <machine>.<domain> @<dc-ip>`
- **Zone transfer** (rare on AD DNS but worth trying): `dig axfr <domain> @<dc-ip>`
- **DnsAdmins privesc**: load a malicious DLL into the DNS service — runs as SYSTEM.
- **SigRed (CVE-2020-1350)**: pre-auth RCE on the DC's DNS service → Domain Admin.

### Global Catalog (3268 / 3268S)

A subset of every object in every domain of the forest, accessible from any DC. Used for cross-domain lookups — and an excellent target for LDAP queries that need forest-wide visibility.

### WinRM (5985 / 5986)

HTTP-based remote PowerShell. Default port 5985 plaintext, 5986 TLS. `evil-winrm` is the standard tool. Auth options: cleartext password, NTLM (`-H <hash>`), Kerberos (`-r <REALM>` after `kinit`).

### WMI (135 + dynamic high ports)

Older RPC-based remote management. Used by `impacket-wmiexec`. Useful when WinRM is locked down.

### MS-RPC over Named Pipes / TCP

Backbone of much of AD. Tools like `rpcclient`, `impacket-*`, and `bloodhound-python` all run RPC calls; abused by SAMR brute, LSARPC enum, DRSUAPI (DCSync), Spoolsv (PrinterBug), EFSRPC (PetitPotam).

### See Also
- [Active Directory Enumeration](../1-information-gathering/06-active-directory-enumeration.md) — LDAP / netexec / kerbrute in practice.
- [Kerberos Attacks](./03-kerberos-attacks.md) — ticket impersonation & forging.
- [Credential Dumping](../4-post-exploitation/03-credential-dumping.md) — for the hashes that feed these protocols.
