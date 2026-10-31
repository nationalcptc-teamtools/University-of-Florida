# =============================================================================
#  cptc-winenum.ps1  --  Windows "WinPEAS-lite": read-only local-privesc + AD
#                        quick enum, the common local-privesc paths. Run AFTER
#                        you have a shell/session on a Windows host.
#
#  READ ONLY. It enumerates, it changes nothing.
#
#  USAGE (from a PowerShell prompt on the target):
#     powershell -ep bypass -f cptc-winenum.ps1
#     # or paste the contents into a session. Pipe to a file:  ... | Tee-Object win-enum.txt
#
#  [!! HIT] = chase it. 
# =============================================================================
$ErrorActionPreference = "SilentlyContinue"
function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Hit($t){ Write-Host "  [!! HIT] $t" -ForegroundColor Red }

Write-Host "#### cptc-winenum.ps1 | $env:USERNAME@$env:COMPUTERNAME | $(Get-Date) ####" -ForegroundColor Cyan

Sec "Who am I + privileges (the quick wins)"
whoami /user
$priv = whoami /priv
$priv
if($priv -match "SeImpersonatePrivilege.*Enabled" -or $priv -match "SeAssignPrimaryTokenPrivilege.*Enabled"){
  Hit "SeImpersonate / SeAssignPrimaryToken is ENABLED -> Potato attack (PrintSpoofer / GodPotato / JuicyPotato) = SYSTEM."
}
whoami /groups | Select-String "Admin","Backup Operators","Server Operators"

Sec "AlwaysInstallElevated (if both = 1, trivial SYSTEM via a crafted .msi)"
$a = (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer -Name AlwaysInstallElevated).AlwaysInstallElevated
$b = (Get-ItemProperty HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer -Name AlwaysInstallElevated).AlwaysInstallElevated
if($a -eq 1 -and $b -eq 1){ Hit "AlwaysInstallElevated = 1 (HKLM+HKCU) -> msfvenom .msi = SYSTEM." }

Sec "Services: unquoted paths + writable binaries/dirs (classic privesc)"
Get-WmiObject win32_service | Where-Object { $_.PathName -and $_.PathName -notmatch '^"' -and $_.PathName -match ' ' -and $_.PathName -notmatch 'C:\\Windows' } |
  ForEach-Object { Hit ("unquoted service path: {0}  [{1}]" -f $_.PathName, $_.Name) }
Get-WmiObject win32_service | ForEach-Object {
  $p = ($_.PathName -replace '"','') -replace '(\.exe).*','$1'
  if($p -and (Test-Path $p)){
    try { $acl = Get-Acl $p; foreach($ace in $acl.Access){ if($ace.FileSystemRights -match "Write|FullControl|Modify" -and $ace.IdentityReference -match "Users|Everyone|Authenticated"){ Hit ("writable service binary: {0}  [{1}]" -f $p, $_.Name); break } } } catch {}
  }
}

Sec "Scheduled tasks running as SYSTEM/admin (check if you can edit the action)"
Get-ScheduledTask | Where-Object { $_.Principal.UserId -match "SYSTEM|Administrator" -and $_.State -ne "Disabled" } |
  Select-Object TaskName, @{n="Run";e={$_.Principal.UserId}} | Format-Table -Auto

Sec "Stored credentials / secrets"
cmdkey /list | Select-String "Target"
# WinLogon autologon
$w = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
if($w.DefaultPassword){ Hit "autologon password in registry (DefaultUserName=$($w.DefaultUserName))" }
# Unattend / sysprep leftovers
"C:\Windows\Panther\Unattend.xml","C:\Windows\Panther\Unattended.xml","C:\unattend.xml","C:\sysprep.inf" | ForEach-Object { if(Test-Path $_){ Hit "unattend file present: $_ (may hold a password)" } }
# Files with 'password' in them (bounded)
Get-ChildItem C:\Users,C:\inetpub,C:\xampp,C:\wamp -Recurse -Include *.config,*.ini,*.xml,*.txt,*.ps1,*.bat 2>$null |
  Select-String -Pattern "password=|pwd=|secret=|apikey" 2>$null | Select-Object -First 15 |
  ForEach-Object { Hit ("possible cred: {0}:{1}" -f $_.Path, $_.LineNumber) }

Sec "Patch level (old = kernel/privesc exploit)"
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5 HotFixID, InstalledOn | Format-Table -Auto
Write-Host "   (few/old hotfixes -> check Watson/Sherlock or 'systeminfo' against known exploits)"

# -------- AD side (only if domain-joined) ------------------------------------
if($env:USERDNSDOMAIN){
  Sec "Active Directory quick checks (domain: $env:USERDNSDOMAIN)"
  Hit "Domain-joined -> the big wins are AD, not local. From the attack box:"
  Write-Host "     nxc ldap <dc> -u <user> -p <pass> --kerberoasting kerb.txt   # then hashcat -m 13100"
  Write-Host "     bloodhound-python -u <user> -p <pass> -d $env:USERDNSDOMAIN -ns <dc> -c all   # find delegation paths"
  # MachineAccountQuota (RBCD prereq)
  try { $maq = (Get-ADObject (Get-ADDomain).DistinguishedName -Properties ms-DS-MachineAccountQuota)."ms-DS-MachineAccountQuota"; if($maq -gt 0){ Hit "MachineAccountQuota = $maq (>0) -> you can add a machine account (RBCD path)." } } catch {}
  # SMB signing / NTLMv1 are checked from the attack box with nxc
  Write-Host "     nxc smb <range> --gen-relay-list targets.txt   # hosts without SMB signing -> relay"
}

Write-Host "`n=== done. Chase every [!! HIT]. For AD, the real work is from the Linux attack box (nxc/impacket/BloodHound). Log everything for the report. ===" -ForegroundColor Cyan
