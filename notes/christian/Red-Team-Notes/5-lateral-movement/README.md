# 5. Lateral Movement

You're in. Now spread. This stage focuses on Windows / Active Directory lateral movement — protocols, ticket forging, ACL abuse, and movement between Windows hosts.

## Sections
1. [Active Directory Overview](./01-active-directory-overview.md) — forest/domain/OU structure, trusts.
2. [AD Protocols](./02-ad-protocols.md) — LDAP, Kerberos, NTLM, SMB.
3. [Kerberos Attacks](./03-kerberos-attacks.md) — TGT/ST request, constrained delegation, S4U2Self.
4. [ACL Abuse with bloodyAD](./04-acl-abuse-bloodyad.md) — abusing writeable AD ACLs.
5. [Windows Pivoting](./05-windows-pivoting.md) — RDP file sharing, WinRM, evil-winrm with hashes.
6. [MSSQL Abuse](./06-mssql-abuse.md) — xp_cmdshell, EXECUTE AS impersonation, linked servers, hash capture, SQL account → SYSTEM.
