#!/usr/bin/env bash
# =============================================================================
#  cptc-triage.sh  --  fast network triage from the attack box. Point it at the
#                      IN-SCOPE range(s) and it tells you, per host, what's worth
#                      hitting first, tagged with the past CPTC finding it matches.
#
#  ONLY run this during the authorized engagement window, against in-scope IPs.
#  It is ACTIVE (it scans). Nothing here changes a target; it just enumerates.
#
#  USAGE:   bash cptc-triage.sh 10.0.1.0/24 10.0.2.0/24
#           bash cptc-triage.sh 10.0.1.5 10.0.1.6
#
#  Needs nmap. Uses netexec/nxc, dig, smbclient, curl if present (degrades if not).
#  Writes raw nmap to ./triage-out/.
# =============================================================================

[ $# -lt 1 ] && { echo "usage: $0 <range-or-host> [more...]"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
C_SEC='\033[1;36m'; C_HIT='\033[1;31m'; C_PAST='\033[0;33m'; C_0='\033[0m'
[ -t 1 ] || { C_SEC=; C_HIT=; C_PAST=; C_0=; }
sec(){ printf "\n${C_SEC}=== %s ===${C_0}\n" "$1"; }
hit(){ printf "${C_HIT}  -> %s${C_0}\n" "$1"; }
past(){ printf "     ${C_PAST}[PAST: %s]${C_0}\n" "$1"; }

have nmap || { echo "nmap is required. Install it (see setup.sh) and retry."; exit 1; }
mkdir -p triage-out
TARGETS="$*"

sec "1) Who is alive"
nmap -sn $TARGETS -oG triage-out/alive.gnmap >/dev/null 2>&1
HOSTS=$(grep "Up" triage-out/alive.gnmap 2>/dev/null | awk '{print $2}')
[ -z "$HOSTS" ] && HOSTS="$TARGETS"   # some ranges block ping; scan anyway
echo "$HOSTS" | tr ' ' '\n'

sec "2) Service scan (this takes a few minutes)"
echo "running: nmap -sV -sC --open -oA triage-out/scan $TARGETS"
nmap -sV -sC --open -oA triage-out/scan $TARGETS >/dev/null 2>&1
echo "saved -> triage-out/scan.nmap"

sec "3) Prioritized hits (what to chase, per service)"
GN=triage-out/scan.gnmap
portline(){ grep -h "$1" "$GN" 2>/dev/null | awk '{print $2}'; }   # hosts with a port open

# --- Mail / M365 -----------------------------------------------------------
for h in $(portline "25/open\|587/open\|993/open"); do hit "$h: mail server -> if Exchange on-prem check ProxyNotShell; if M365 do o365spray user-enum + spray"; past "a past CPTC Exchange / M365"; done
# --- SMB -------------------------------------------------------------------
for h in $(portline "445/open"); do
  hit "$h: SMB(445) -> null session + shares + signing"
  past "a past CPTC creds/files in SMB shares; NTLMv1"
  have nxc && nxc smb "$h" -u '' -p '' --shares 2>/dev/null | sed 's/^/        /'
  have smbclient && smbclient -L "//$h" -N 2>/dev/null | sed 's/^/        /'
done
# --- FTP -------------------------------------------------------------------
for h in $(portline "21/open"); do hit "$h: FTP(21) -> try anonymous login"; have curl && curl -s --max-time 8 "ftp://$h/" --user anonymous: 2>/dev/null | sed 's/^/        /'; done
# --- DNS -------------------------------------------------------------------
for h in $(portline "53/open"); do hit "$h: DNS(53) -> try a zone transfer (AXFR)"; past "a past CPTC DNS zone transfer"; have dig && { for z in oui.local yyy.chat local; do dig +short axfr @"$h" "$z" 2>/dev/null | head -3 | sed "s/^/        $z: /"; done; }; done
# --- Web -------------------------------------------------------------------
for h in $(portline "80/open\|443/open\|8080/open\|3000/open\|5000/open\|7000/open"); do
  hit "$h: web -> dir-brute (gobuster/ffuf), check login for weak/default creds, proxy the API through Burp for IDOR + broken-authz + hardcoded JS secrets, test image/URL fields for SSRF"
  past "a past CPTC: IDOR, SSRF->RCE, client-side auth bypass, hardcoded creds in JS"
done
# --- AD / Kerberos / LDAP --------------------------------------------------
for h in $(portline "88/open\|389/open"); do hit "$h: looks like a Domain Controller -> BloodHound, then Kerberoast (nxc --kerberoasting) and hunt delegation"; past "a past CPTC a kerberoastable svc acct Kerberoast + constrained/RBCD delegation -> DA"; done
# --- Databases -------------------------------------------------------------
for h in $(portline "3306/open"); do hit "$h: MySQL(3306) -> try root:'' and defaults"; done
for h in $(portline "5432/open"); do hit "$h: Postgres(5432) -> try postgres:postgres, then COPY ... TO PROGRAM for RCE"; past "a past CPTC Postgres default creds -> host RCE"; done
# --- RDP / WinRM -----------------------------------------------------------
for h in $(portline "3389/open"); do hit "$h: RDP(3389) -> spray once you have creds"; done
for h in $(portline "5985/open"); do hit "$h: WinRM(5985) -> evil-winrm once you have creds"; done

# --- Non-standard / custom services (the gold) -----------------------------
sec "4) Non-standard open ports (custom in-house tools -> poke for command injection)"
grep -h "open" "$GN" 2>/dev/null | tr ',' '\n' | grep -oE '[0-9]+/open' | sort -u | \
  grep -vE '^(21|22|25|53|80|88|110|111|135|139|143|389|443|445|587|993|995|1433|3306|3389|5432|5985|8080)/' | \
  while read -r p; do hit "unusual port $p open somewhere -> nc to it, read the banner/menu, try command injection"; done
past "a past CPTC 'Golash' + a past CPTC 'Lido Deck' = custom services with command injection"

printf "\n${C_SEC}=== done. Full detail in triage-out/scan.nmap. Chase the hits top-down. Log everything for the report. ===${C_0}\n"
