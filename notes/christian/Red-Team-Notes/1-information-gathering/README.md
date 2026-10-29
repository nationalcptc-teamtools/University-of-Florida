# 1. Information Gathering

Everything that happens before you send a single exploit. The point of this stage is to understand the target's external footprint, internal services, and (where in scope) Active Directory layout so later stages have something concrete to attack.

## Sections
1. [OSINT](./01-osint.md) — Google dorking, Shodan, breach data, ExifTool, Recon-ng, OPSEC.
2. [DNS Reconnaissance](./02-dns-recon.md) — dig, dnsenum, fierce, crt.sh, subdomain & vhost enumeration.
3. [Nmap](./03-nmap.md) — host discovery, version & script scans, firewall / IPS evasion.
4. [Service Enumeration](./04-service-enumeration.md) — FTP, SMB, NFS, DNS, SMTP, IMAP/POP3, SNMP, MySQL, MSSQL, TNS, IPMI, SSH, Rsync, R-services, RDP, WinRM, WMI.
5. [Web Reconnaissance](./05-web-recon.md) — vhost & directory fuzzing, whatweb / wafw00f / nikto, FinalRecon, ReconSpider.
6. [Active Directory Enumeration](./06-active-directory-enumeration.md) — LDAP, kerbrute, BloodHound, netexec.

> "Recon is 80% of the engagement." Don't shortcut it — most exploitation paths fall out of clean enumeration.
