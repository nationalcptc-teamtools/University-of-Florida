# 01 — OSINT (Open-Source Intelligence)

**Jump to:** [Google Dorking ("regex for the web")](#google-dorking-regex-for-the-web) · [Pastebin / GitHub Gists](#pastebin--github-gists) · [Internet Archive / Wayback Machine](#internet-archive--wayback-machine) · [Shodan](#shodan) · [Email Enumeration](#email-enumeration) · [People & Breach Intel](#people--breach-intel) · [Recon-ng (modular OSINT framework)](#recon-ng-modular-osint-framework) · [theHarvester](#theharvester) · [ExifTool (metadata)](#exiftool-metadata) · [WHOIS / IP Allocation](#whois--ip-allocation) · [Image / Reverse Search](#image--reverse-search) · [OPSEC Reminders](#opsec-reminders)

Passive reconnaissance — collect everything the public internet already knows about a target without sending packets directly at it. The cleaner your OSINT, the smaller and stealthier your later active recon needs to be.

---

### Google Dorking ("regex for the web")

| Operator | Use case |
|----------|----------|
| `site:example.com` | Restrict results to a domain |
| `filetype:pdf "confidential"` | Find specific file types |
| `intitle:"index of" "<keyword>"` | Open directory listings |
| `inurl:admin OR inurl:login site:<target>` | Login portals |
| `-www -site:foo.com` | Exclude noise |
| `site:pastebin.com "<target>"` | Exposed creds in pastes |
| `site:github.com "<target>" password` | Leaked secrets in repos |

Reference: **Google Hacking Database (GHDB)**.

### Pastebin / GitHub Gists

- Pastebin disables native site search — pivot via Google dorks for tokens, creds, internal hostnames.
- GitHub: `"<target>" password`, `org:<target> filename:.env`
- Automate repo scraping: **TruffleHog** / **GitLeaks** against a known org or user.

### Internet Archive / Wayback Machine

- History snapshot: `https://web.archive.org/web/*/<target>/*`
- Pulls back old endpoints, deleted pages, leaked subdomains, stale `robots.txt`, `sitemap.xml`.
- Bulk URL extraction: `waybackurls <domain>` or `gau <domain>`.

### Shodan

```bash
shodan init <api-key>
shodan host <ip>
shodan search 'org:"Acme" port:22' --fields ip_str,port,product
```

Useful filters (login + API key required):

```
org:"<Company Name>"
hostname:<domain>
net:<CIDR>
product:"OpenSSH" version:"7.4"
port:445 country:"US"
http.title:"login"
http.favicon.hash:<hash>
```

### Email Enumeration

- **Hunter.io** — verified email addresses tied to a domain (great for phishing).
- **HaveIBeenPwned** — confirm an address appears in a breach (validates it exists).
- **Permutators** — build candidates from names: `fname.lname@<domain>`, `flname@<domain>`, etc.
- SMTP-side verify without sending:

```bash
smtp-user-enum -M VRFY -U users.txt -t <ip>
```

### People & Breach Intel

Chain the pieces: **name → company (LinkedIn) → email pattern → breach data → password reuse**.

Useful sources: LinkedIn, Twitter/X bios, Facebook, Instagram (geotags), public CVs, GitHub profiles.
Breach search: HaveIBeenPwned, DeHashed (paid), IntelX, leak-lookup.

### Recon-ng (modular OSINT framework)

```bash
recon-ng
workspaces create <name>
marketplace install all
modules load recon/domains-hosts/hackertarget
options set SOURCE <domain>
run
```

Other useful modules: `hackertarget`, `bing_domain_web`, `brute_hosts`, `whois_pocs`, `hibp_breach`.

### theHarvester

Aggregates emails, employee names, subdomains, and hosts from multiple OSINT sources (Bing, Baidu, certificate transparency, etc.) — fast first sweep of a domain.

### ExifTool (metadata)

```bash
exiftool <file>                 # read all metadata
exiftool -r <dir>               # recursive
exiftool -all= <file>           # strip metadata before publishing
```

What to look for: GPS coords, camera serial, internal usernames, software/version strings, document author.

### WHOIS / IP Allocation

```bash
whois <domain>                  # registrar info
whois <ip>                      # RIR allocation
amass intel -org "<Company>"    # ASN / netblock pivot
```

Also useful: `bgp.he.net` for ASN → CIDR mapping.

### Image / Reverse Search

- **Google Lens**, **Yandex Images** (best for faces/landmarks), **TinEye**.
- Hash matching / duplicate detection: `imagehash` Python lib.
- ⚠ Never attempt facial recognition against unwitting subjects — stay in scope.

### OPSEC Reminders

- Use a clean browser profile / VM for OSINT — cookies and login state leak intent.
- Stay passive when possible. Active recon (nmap, fierce brute force) is detectable and may violate scope timing rules.
