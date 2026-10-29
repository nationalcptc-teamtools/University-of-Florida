# 03 — Nmap

**Jump to:** [Default Scans](#default-scans) · [Subnet Sweep (Fast)](#subnet-sweep-fast) · [Firewall / IDS Evasion](#firewall--ids-evasion) · [IPS Evasion](#ips-evasion) · [NSE — Service-Specific Scripts](#nse--service-specific-scripts) · [Output Formats](#output-formats)

The first active step against almost every target. Goal: discover hosts, open ports, services, versions, and (where possible) preliminary CVEs via NSE.

---

### Default Scans

```bash
## Aggressive: full TCP, version + default scripts, OS guess
nmap -sV -sC -p- -A <ip>

## Polite + skip host discovery
nmap -sV -sC -Pn <target_ip>

## From a host list, write normal output
nmap -sV -sC -iL hosts.txt -oN port_scan.txt
```

> Always use `-p-` for a real engagement (and the CPTS exam) — the default top-1000 misses high-port services that are common on internal networks.

| Flag | Meaning |
|------|---------|
| `-sV` | Version detection on open ports |
| `-sC` | Default NSE scripts |
| `-Pn` | Skip host discovery (assume up) |
| `-p-` | All 65535 TCP ports |
| `-A` | Aggressive — version + scripts + OS + traceroute |
| `-iL` | Read targets from file (one per line, CIDR ok) |
| `-oN` | Normal-format output to file |
| `-O` | OS detection |
| `-sU --top-ports 50` | Top 50 UDP services |

### Subnet Sweep (Fast)

```bash
fping -agq 10.211.11.0/24
## -a alive, -g generate from netmask, -q quiet
```

### Firewall / IDS Evasion

A port that returns *rejected* indicates a firewall is present; *blocked* (filtered) is also a strong signal.

```bash
nmap -sA <ip>                   # ACK scan — bypasses many stateless firewalls
nmap -sU <ip>                   # UDP scan
nmap --disable-arp-ping <ip>    # skip ARP discovery
```

### IPS Evasion

```bash
## If your source IP gets blocked
nmap -D RND:5 <ip>              # 5 randomly generated decoy IPs

## If a destination port keeps getting blocked
nmap --source-port <port> <ip>  # spoof source port (e.g. 53)
```

### NSE — Service-Specific Scripts

```bash
nmap -p3389 --script rdp-enum-encryption <ip>
nmap -p5985,5986 --script winrm-* <ip>
nmap -p3306 --script mysql-* <ip>
nmap -p445  --script smb-enum-shares,smb-vuln-* <ip>
nmap -p1433 --script ms-sql-* --script-args mssql.instance-port=1433,mssql.username=sa,mssql.password= <ip>
nmap -p25   --script smtp-open-relay <ip>
nmap -sU -p623 --script ipmi-version <ip>
```

NSE categories worth knowing:

| Category | What it does |
|----------|--------------|
| `default` | Runs with `-sC` |
| `safe` | Read-only / non-disruptive |
| `auth` | Auth checks |
| `brute` | Credential brute-force |
| `vuln` | Known-vuln checks |
| `discovery` | Extra host / service discovery |
| `intrusive` | May crash services / get noticed |

### Output Formats

```bash
nmap -sV -sC -oA scan <ip>      # -oA writes scan.nmap, scan.xml, scan.gnmap
```

`scan.gnmap` is grep-friendly; XML pairs well with tooling like `nmap-converter` or autorecon.
