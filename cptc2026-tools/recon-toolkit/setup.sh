#!/usr/bin/env bash
#
# setup.sh  --  CPTC attack-box setup (the "Setup Script" from The Notes > Tool List)
#
# WHAT IT DOES:
#   Installs the standard pentest toolkit the team needs, grouped by the
#   attack surface it maps to. Built for a Debian/Kali/Ubuntu box (apt + pipx).
#   Run it on a FRESH engagement VM, not your daily laptop.
#
# USAGE:
#   chmod +x setup.sh && ./setup.sh            # install everything
#   ./setup.sh --list                          # just print what it WOULD install
#
# WHY pipx: it installs each Python tool in its own isolated environment so they
#   don't fight over dependencies (a classic reason "impacket broke my box").
#
set -uo pipefail

LIST_ONLY=false
[[ "${1:-}" == "--list" ]] && LIST_ONLY=true

say()  { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
run()  { if $LIST_ONLY; then echo "    $*"; else echo "+ $*"; eval "$*"; fi; }

# --- apt packages: core network / web / cracking / AD tooling ---------------
APT_PKGS=(
  nmap            # port + service scanning (map the attack surface)
  masscan         # fast port sweeps across the /24 ranges
  netexec         # (aka nxc / crackmapexec) spray + enumerate SMB/WinRM/MSSQL/LDAP
  smbclient       # browse SMB shares (creds/files are often left here)
  ldap-utils      # ldapsearch for AD enumeration
  gobuster        # directory/vhost brute forcing on web apps
  ffuf            # fast web fuzzer (params, dirs, subdomains)
  nikto           # quick web server vuln sniff
  sqlmap          # automated SQL injection
  hashcat         # GPU password cracking (Kerberoast/NTLM hashes)
  john            # CPU password cracking + hash format help
  hydra           # network login brute/spray (non-M365 services)
  seclists        # THE wordlist collection (/usr/share/seclists)
  dnsutils        # dig / host for DNS + MX recon
  jq              # parse JSON from APIs
  git curl wget   # basics
)

# --- pipx (Python) tools: cloud / AD / M365 / secrets -----------------------
PIPX_TOOLS=(
  "impacket"                                   # secretsdump, getST, psexec, GetUserSPNs...
  "git+https://github.com/0xZDH/o365spray"     # M365 user-enum + password spray (our M365 find)
  "dnstwist"                                   # look-alike domain discovery
  "bloodhound-ce"                              # AD attack-path analysis (ingestor side)
  "certipy-ad"                                 # AD CS (certificate) abuse
  "coercer"                                    # PetitPotam-style auth coercion
  "trufflehog3"                                # scan git history for leaked secrets
)

# --- things to grab by hand (printed as reminders) --------------------------
MANUAL_NOTES=(
  "BloodHound CE GUI + Neo4j: https://github.com/SpecterOps/BloodHound (docker compose up)"
  "MFASweep (PowerShell, M365 MFA posture): https://github.com/dafthack/MFASweep"
  "Kerbrute (AD user enum/spray): https://github.com/ropnop/kerbrute/releases"
  "gitleaks (secret scanning, Go binary): https://github.com/gitleaks/gitleaks/releases"
  "Burp Suite Community (web proxy): preinstalled on Kali, else portswigger.net"
  "Nessus Essentials (vuln scanning, matches an in-house Nessus stack): tenable.com"
)

say "CPTC attack-box setup  ($([[ $LIST_ONLY == true ]] && echo 'LIST ONLY' || echo 'INSTALLING'))"

if ! $LIST_ONLY; then
  if ! command -v apt-get >/dev/null; then
    echo "This installer targets Debian/Kali/Ubuntu (apt). On macOS, use the --list"
    echo "output as a shopping list and install via brew/pipx instead."
    exit 1
  fi
  run "sudo apt-get update -y"
fi

say "apt packages (network / web / cracking / AD)"
run "sudo apt-get install -y ${APT_PKGS[*]}"

say "pipx bootstrap"
run "sudo apt-get install -y pipx || python3 -m pip install --user pipx"
run "pipx ensurepath"

say "Python tools (cloud / AD / M365 / secrets)"
for t in "${PIPX_TOOLS[@]}"; do run "pipx install \"$t\""; done

say "Install these by hand (printed for your checklist):"
for n in "${MANUAL_NOTES[@]}"; do echo "   - $n"; done

say "Done. Sanity check:"
for c in nmap netexec impacket-secretsdump o365spray dnstwist hashcat; do
  if command -v "$c" >/dev/null; then echo "   ok   $c"; else echo "   MISSING  $c"; fi
done

cat <<'EOF'

Next: point the recon tools at the target only when you're in scope. Suggested first moves
once the engagement opens (see the study guide for the why behind each):
   nmap -sC -sV -oA scans/target <in-scope-range>
   o365spray --enum -U users.txt --domain <target-domain>
   nxc smb <range> -u users.txt -p spray.txt --continue-on-success
Stay in scope. Never touch a domain controller with changes. Log everything.
EOF
