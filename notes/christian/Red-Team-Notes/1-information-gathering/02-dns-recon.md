# 02 — DNS Reconnaissance

**Jump to:** [Tool Comparison](#tool-comparison) · [dig Quick Reference](#dig-quick-reference) · [Zone Transfer (AXFR)](#zone-transfer-axfr) · [DNS Server Config to Look For](#dns-server-config-to-look-for) · [dnsenum](#dnsenum) · [Fierce](#fierce) · [Subdomain Enumeration (mix and match)](#subdomain-enumeration-mix-and-match) · [vhost Fuzzing (find virtual hosts behind one IP)](#vhost-fuzzing-find-virtual-hosts-behind-one-ip) · [Always Add Hostnames to /etc/hosts](#always-add-hostnames-to-etchosts)

DNS is one of the highest-signal recon sources you have: subdomains map directly to additional attack surface, and a misconfigured zone transfer can hand you the entire internal name space.

---

### Tool Comparison

| Tool | Strength | Typical use |
|------|----------|-------------|
| `dig` | Versatile, all record types | Manual queries, zone transfers, deep troubleshooting |
| `nslookup` | Simple, ubiquitous | Quick A/AAAA/MX lookups |
| `host` | Concise output | Fast A/AAAA/MX checks |
| `dnsenum` | Automated brute + zone transfer | Subdomain discovery |
| `fierce` | Recursive search, wildcard detection | User-friendly subdomain hunting |
| `dnsrecon` | Multi-technique, multiple output formats | Broad enumeration sweep |
| `theHarvester` | Pulls from many OSINT sources | Email + DNS combined recon |
| `ffuf` | Generic fuzzer | Brute subdomains / vhosts via Host header |

---

### dig Quick Reference

```bash
dig domain.com                          # default A lookup
dig domain.com A                        # IPv4
dig domain.com AAAA                     # IPv6
dig domain.com MX                       # mail servers
dig domain.com NS                       # authoritative name servers
dig domain.com TXT                      # TXT records (SPF, DKIM, verification tokens)
dig domain.com CNAME                    # canonical name
dig domain.com SOA                      # start of authority
dig @1.1.1.1 domain.com                 # use a specific resolver
dig +trace domain.com                   # show the full resolution path
dig -x 192.168.1.1                      # reverse lookup (PTR)
dig +short domain.com                   # short answer
dig +noall +answer domain.com           # answer section only
dig any domain.com @<ns-server>         # everything
```

### Zone Transfer (AXFR)

If the server allows `allow-transfer`, you act as a secondary and pull the entire zone:

```bash
dig axfr inlanefreight.htb @10.129.14.128
dig axfr internal.inlanefreight.htb @10.129.14.128   # may reveal internal IPs
```

A successful AXFR is one of the best single moves you can make against a misconfigured DNS server.

### DNS Server Config to Look For

| File | What's interesting |
|------|--------------------|
| `/etc/bind/named.conf.local` | Local zone declarations |
| `/etc/bind/db.<domain>` | Zone files |
| `/etc/bind/db.<ip>` | Reverse name resolution |

| Setting | Meaning |
|---------|---------|
| `allow-query` | Which hosts can query |
| `allow-recursion` | Which hosts can issue recursive queries |
| `allow-transfer` | Who can pull a zone — **the big one** |
| `zone-statistics` | Stats collection |

### dnsenum

```bash
dnsenum --dnsserver 10.129.86.142 --enum -p 0 -s 0 \
    -o subdomains.txt \
    -f /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt \
    inlanefreight.htb
```

### Fierce

```bash
fierce --domain <domain>
fierce --domain <domain> --subdomain-file <wordlist>
```

### Subdomain Enumeration (mix and match)

```bash
subfinder -d <domain> -all
./subfinder -d inlanefreight.com -v
amass enum -d <domain>
assetfinder --subs-only <domain>
```

#### Subbrute (DNS brute force with custom resolvers)

```bash
git clone https://github.com/TheRook/subbrute.git
cd subbrute
echo "<dns_server_ip>" > ./resolvers.txt
./subbrute.py <domain_name> -s ./names.txt -r ./resolvers.txt
```

#### Certificate Transparency via crt.sh

Find subdomains issued an SSL cert (which catches many that brute-force misses):

```bash
curl -s "https://crt.sh/?q=%25.<domain>&output=json" \
  | jq -r .[].name_value \
  | sort -u
```

Pipeline: subdomains → IPs → Shodan ports:

```bash
for s in $(cat subdomainlist); do
  host "$s" | grep "has address" | grep <domain> | cut -d" " -f4 >> ip-addresses.txt
done

for ip in $(cat ip-addresses.txt); do shodan host "$ip"; done
```

### vhost Fuzzing (find virtual hosts behind one IP)

```bash
ffuf -u http://<ip> -H "Host: FUZZ.<domain>" \
     -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -ac
## Then filter once you have a baseline:
ffuf -u http://<ip> -H "Host: FUZZ.<domain>" -w <wordlist> -fs 157 -ac -t 100
```

Don't forget: **vhosts can have vhosts** — re-run the fuzz once you discover the new domain.

### Always Add Hostnames to /etc/hosts

HTB-style boxes and many real engagements use name-based virtual hosts. If you don't add the host, vhosts won't resolve:

```bash
echo "10.129.93.57 app.inlanefreight.local" | sudo tee -a /etc/hosts
```
