# 01 — Recon

**Jump to:** [Network sweep (once, at the start)](#network-sweep-once-at-the-start) · [Full port scan (every host, always)](#full-port-scan-every-host-always) · [Service-specific enumeration (per open port)](#service-specific-enumeration-per-open-port) · [OSINT (only when in scope — most CPTS exams limit this)](#osint-only-when-in-scope--most-cpts-exams-limit-this) · [Output you should have after recon](#output-you-should-have-after-recon)

Trigger: any new host, or the start of the engagement.
Reference: [Information Gathering](../1-information-gathering/).

## Network sweep (once, at the start)

- [ ] Live host discovery: `sudo nmap -sn <scope>` → `hosts.txt`.
- [ ] ARP scan on same-subnet targets: `sudo arp-scan -l`.
- [ ] Ping sweep as fallback: `for i in {1..254}; do ping -c1 -W1 10.10.10.$i >/dev/null && echo 10.10.10.$i; done`.

## Full port scan (every host, always)

- [ ] Fast all-ports TCP: `sudo nmap -p- --min-rate=5000 -oA scans/<ip>-fast <ip>`.
- [ ] Full service/version + default scripts on found ports:

```bash
PORTS=$(grep '^[0-9]' scans/<ip>-fast.nmap | cut -d/ -f1 | paste -sd,)
sudo nmap -sV -sC -p$PORTS -oA scans/<ip>-deep <ip>
```

- [ ] UDP top-100 (SNMP / IKE / DNS / TFTP hide here): `sudo nmap -sU --top-ports=100 -oA scans/<ip>-udp <ip>`.
- [ ] Note the OS guess and TTL — `TTL=64` Linux, `TTL=128` Windows, `TTL=255` network gear.

## Service-specific enumeration (per open port)

Tick every one that applies:

- [ ] **21 FTP** — `nmap --script ftp-anon,ftp-syst,ftp-vsftpd-backdoor -p21 <ip>`. Try `anonymous:anonymous`.
- [ ] **22 SSH** — banner-grab, note version for CVEs (`nmap -sV -p22 <ip>`). No brute yet — wait for a userlist.
- [ ] **25/465/587 SMTP** — `smtp-user-enum -M VRFY -U users.txt -t <ip>`. Note the banner.
- [ ] **53 DNS** — zone transfer: `dig axfr @<ip> <domain>`. If it dumps, `subdomains.txt` is free.
- [ ] **80/443/8080/8443 HTTP** — jump to [02-web.md](./02-web.md).
- [ ] **88 Kerberos / 389 LDAP / 445 SMB** — jump to [03-active-directory.md](./03-active-directory.md).
- [ ] **110/143/993/995 IMAP/POP3** — try known creds with `nxc pop3` / `medusa -M imap`.
- [ ] **111 rpcbind** — `rpcinfo -p <ip>`. NFS shares often piggyback here.
- [ ] **135/139/445 SMB** — see AD checklist; also `nxc smb <ip>` for share/OS/signing info. If `-u '' -p ''` (anonymous) comes back empty, always also try `-u guest -p ''` — guest is a separate authenticator and often left enabled after anon is locked down.
- [ ] **161 SNMP** — `snmpwalk -c public -v2c <ip>`; try `snmp-check <ip>`. Community strings: `public`, `private`, `manager`.
- [ ] **1433 MSSQL** — `nxc mssql <ip> -u sa -p sa`.
- [ ] **2049 NFS** — `showmount -e <ip>`; `mount -t nfs <ip>:/share /mnt/nfs`.
- [ ] **3306 MySQL / 5432 PostgreSQL** — try default creds, then `medusa -M mysql`.
- [ ] **3389 RDP** — `nxc rdp <ip>`; grab the login banner for the domain name.
- [ ] **5985/5986 WinRM** — `nxc winrm <ip>`; `evil-winrm` with any cred you already have.
- [ ] **6379 Redis** — `redis-cli -h <ip>`, then `INFO` and `CONFIG GET *`.
- [ ] **8080/9090** — Tomcat / Jenkins / Splunk — try default creds and manager URLs.

## OSINT (only when in scope — most CPTS exams limit this)

- [ ] Client-provided domain → `theHarvester -d <domain> -b all`.
- [ ] Look for public creds: `<domain>` + "site:pastebin.com" via search engine.
- [ ] LinkedIn → build `users.txt` from the format the client uses (`first.last`, `flast`, `firstlast`).

## Output you should have after recon

- [ ] `hosts.txt` — every live IP.
- [ ] `scans/` — one nmap output triple per host.
- [ ] `subdomains.txt` — from zone transfers, HTTP recon.
- [ ] `users.txt` — from SMTP enum, SMB null sessions, LDAP, OSINT.
- [ ] A one-line note per host in `notes.md`: `10.10.10.5 — Windows Server 2019, DC, SMB signing off, SMB1 enabled`.
