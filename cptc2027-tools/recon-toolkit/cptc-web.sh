#!/usr/bin/env bash
# =============================================================================
#  cptc-web.sh  --  low-hanging-fruit sweep of ONE web target. Point it at a URL
#                   and it does the boring automatable checks so you can spend
#                   your time in Burp on the logic bugs (IDOR, authz, SSRF).
#
#  ACTIVE (it sends requests). In scope + in the window only.
#
#  USAGE:   bash cptc-web.sh http://10.0.1.5
#           bash cptc-web.sh https://10.0.1.5:8443
#  (no scheme -> http:// assumed)
# =============================================================================

[ -z "${1:-}" ] && { echo "usage: $0 <url>   e.g. $0 http://10.0.1.5"; exit 1; }
U="$1"; case "$U" in http*://*) ;; *) U="http://$U";; esac
BASE=$(echo "$U" | sed -E 's#(https?://[^/]+).*#\1#')
have(){ command -v "$1" >/dev/null 2>&1; }
C_SEC='\033[1;36m'; C_HIT='\033[1;31m'; C_PAST='\033[0;33m'; C_0='\033[0m'
[ -t 1 ] || { C_SEC=; C_HIT=; C_PAST=; C_0=; }
sec(){ printf "\n${C_SEC}=== %s ===${C_0}\n" "$1"; }
hit(){ printf "${C_HIT}  [!! HIT] %s${C_0}\n" "$1"; }
CURL="curl -sk --max-time 10"

printf "${C_SEC}#### cptc-web.sh  |  %s  |  %s ####${C_0}\n" "$BASE" "$(date 2>/dev/null)"
have curl || { echo "curl is required."; exit 1; }

sec "1) Server + response headers (missing security headers = note it)"
HDR=$($CURL -D - -o /dev/null "$BASE/")
echo "$HDR" | grep -iE '^(server|x-powered-by|set-cookie|www-authenticate|location):' | sed 's/^/   /'
for h in "Content-Security-Policy" "Strict-Transport-Security" "X-Frame-Options" "X-Content-Type-Options"; do
  echo "$HDR" | grep -qi "^$h:" || echo "   missing header: $h"
done
echo "$HDR" | grep -qiE 'set-cookie:.*(httponly)' || hit "cookies without HttpOnly -> stealable via XSS"
echo "$HDR" | grep -qi 'x-powered-by' && hit "X-Powered-By leaks the stack -> version-match a CVE"

sec "2) Interesting files/paths (the quick wins)"
for p in /.git/HEAD /.git/config /.env /.svn/entries /robots.txt /sitemap.xml \
         /swagger /swagger.json /swagger-ui.html /api-docs /openapi.json \
         /.DS_Store /backup.zip /backup.sql /db.sql /config.php.bak \
         /phpinfo.php /info.php /server-status /server-info /actuator /actuator/env \
         /admin /login /adminer.php /.well-known/security.txt ; do
  CODE=$($CURL -o /dev/null -w "%{http_code}" "$BASE$p")
  case "$CODE" in
    200|301|302|401|403)
      if [ "$CODE" = "200" ]; then hit "$p -> 200 OK (open!)"; else printf "   %s -> %s\n" "$p" "$CODE"; fi
      ;;
  esac
done

sec "3) Default / weak login (manual, but check these first)"
echo "   try admin:admin, admin:password, admin:<company>, and any creds from OSINT on: $BASE/login"
echo "   view-source + grep the JS bundle for secrets:"
echo "      curl -sk $BASE/ | grep -oE 'src=\"[^\"]+\\.js\"' ; then curl the .js and grep -iE 'api|key|token|secret|password'"

sec "4) TLS (if https)"
case "$BASE" in https://*) have sslscan && sslscan --no-colour "$(echo "$BASE"|sed 's#https://##')" 2>/dev/null | grep -iE 'self.signed|expired|SSLv|TLSv1\.0|weak' | sed 's/^/   /' || echo "   (sslscan not installed; check cert manually)";; *) echo "   (http, no TLS)";; esac

sec "5) Deeper scans (run if you have the tools)"
if have gobuster; then echo "   gobuster dir -u $BASE -w /usr/share/seclists/Discovery/Web-Content/common.txt -q"; fi
if have ffuf; then echo "   ffuf -u $BASE/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-small-words.txt"; fi
if have nikto; then echo "   nikto -h $BASE   (noisy but catches known issues)"; fi

printf "\n${C_SEC}=== done. Now do the MANUAL logic bugs in Burp: IDOR (change an ID), broken authz (admin action as a user), SSRF (url=file:///proc/self/environ), SQLi, client-side auth (flip a role in localStorage). ===${C_0}\n"
