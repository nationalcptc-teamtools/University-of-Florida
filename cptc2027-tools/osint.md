# OSINT of Butter Family Farms (BFF)

## Credentials

| Credential | Source |
| ---------- | ------ |
| otpauth://totp/securethepark?secret=securethepark&algorithm=SHA1&digits=6&period=120 | LinkedIn picture from Kevin Ellis' desk |

## People/Accounts

| Name | Position | Email  | Source |
| ---- | -------- | -----  | ------ |
| Karen Ellis | IT Security Analyst |  | https://butterfamilyfarms.com/news/bff-security-investment-2025.html |
| Jasmine Blunt | Network Administrator |  | https://butterfamilyfarms.com/news/bff-security-investment-2025.html
| Lucas Bigheart | Director of Finance and Investor Relations |  | https://butterfamilyfarms.com/news/bigger-butter-project-announcement.html
| Kathleen Fairweather | Social Media Specialist | kathleen.fairweather@butterfamilyfarms.com | https://butterfamilyfarms.com/news/bbc-big-butter-coaster-opening.html
| Robin McGrass | Head of Security |  | https://butterfamilyfarms.com/news/bff-mfa-park-security-platform.html
| Buttercup Butters | Chief operating officer |  | https://butterfamilyfarms.com/news/bigger-butter-contractor-bid-process.html
| Darius Butters | CEO |  | https://www.linkedin.com/in/darius-butters-7b5455432/
| Nancy Norwood | Groundskeeper |  | https://butterfamilyfarms.com/news/bff-20th-anniversary.html
| Anthony Zamora | Ride Operator |  | 
| AI Agent | Comitted to github (Claude) | ai-agent@butterfamilyfarms.com | https://github.com/jblunt-bff/park-website
Kevin Ellis | IT Security Analyst |  | https://lnkd.in/p/gFgS9bwF

## Infrastructure

| Tool | Purpose | Source |
| ---- | ------- | ------ |
| PSP | Internally developed security tool containerized architecture using Docker and written in Golang | https://butterfamilyfarms.com/news/bff-mfa-park-security-platform.html |
| Microsoft 365 / Exchange Online (email) | BFF email on Microsoft 365. MX: butterfamilyfarms-com.mail.protection.outlook.com; autodiscover subdomain configured. -> O365 user-enum + password spray (only exec email has MFA per news), OWA/Autodiscover, conditional-access gaps. | DNS/MX lookup (dig) 2026-10-09 |

## Websites

| URL | Description |
| --- | ----------- |
| https://butterfamilyfarms.com/ | Butter Family Farms Main Website |
| https://github.com/jblunt-bff/park-website | Github repo hosting the Butter Family Farms website |
| https://www.instagram.com/p/Dd4orbBgDrT/ | Party Butter (mascot) Instagram account |
| https://www.linkedin.com/company/butter-family-farms/home/ | BFF Linkedin |

## Partners

| Company | Purpose | Source |
| ------- | ------- | ------ |
| Likely: Prarie Build Group | Bigger & Butter Project Construction | https://butterfamilyfarms.com/news/bigger-butter-contractor-bid-process.html |

## Locations

* Sandwhich, IL
* Future: Orlando, FL
* Future: Zubda

## Extra Info
* pentest in q1 2025 (may have reports found in files) https://butterfamilyfarms.com/news/bff-security-investment-2025.html
  * remediation tracked through internal ticketing process and suppossedly remediated by summer 2025
* mobile app, ticketing, point-of-sale  https://butterfamilyfarms.com/news/bff-security-investment-2025.html
* previous vuln scans in spreadsheets and now in psp https://butterfamilyfarms.com/news/bff-mfa-park-security-platform.html
