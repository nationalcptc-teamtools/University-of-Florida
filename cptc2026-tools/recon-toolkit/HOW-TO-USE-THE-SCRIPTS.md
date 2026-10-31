# How to Use These Scripts — a plain-English guide (print me)

You do not need to be "a scripts person." These scripts just automate the boring, repetitive *looking around* so your brain is free for the interesting part: chaining bugs together and writing the report. Each one answers a simple question. Here's exactly when to reach for each.

## The one idea that makes it click
**Scripts are for the ENUMERATION step — "I can reach / I'm now on X. What's here, and what looks weak?"** They never break in for you. They hand you a **to-do list** of things to go try. You do the actual exploiting. So the trigger is always: *"I just got access to something new — what does the matching script tell me to look at?"*

## The whole comp, in order (just follow this)
1. **Fresh attack box?** → `setup.sh` (installs all the tools). Once, at the start.
2. **Told the in-scope IP ranges?** → `cptc-triage.sh` (what's on the network, what to hit first).
3. **Triage shows a website?** → `cptc-web.sh` on that URL (quick web wins), then Burp for the logic bugs.
4. **Got a Linux shell?** → `cptc-enum.sh` (how do I become root / escape the container).
5. **Got a Windows shell** (or your Windows teammate does)? → `cptc-winenum.ps1`.
Then: chase the `[!! HIT]` lines, and write up each finding as you confirm it.

---

## The scripts, one card each

### `setup.sh` — "set up my attack box"
- **When:** once, at the very start, on a fresh Kali/attack box.
- **Run:** `./setup.sh`  (or `./setup.sh --list` to see what it'll install first)
- **You get:** nmap, netexec, impacket, hashcat, BloodHound, o365spray, seclists, etc.
- **Next:** run triage.

### `cptc-triage.sh` — "what's on the network and what do I hit first?"
- **When:** right after you're given the in-scope ranges.
- **Run:** `bash cptc-triage.sh 10.0.1.0/24 10.0.2.0/24`
- **You see:** a list grouped by service (SMB, web, DNS, AD, databases, *weird ports*). Each line has a `->` telling you the move, and a `[PAST: ...]` tag naming the past finding it matches.
- **Next:** split the list with your team and go service by service. The weird-ports section is gold — custom services are where command-injection RCEs hide.

### `cptc-web.sh` — "quick wins on a website before I open Burp"
- **When:** whenever triage shows a web port (80 / 443 / 3000 / 8080 ...). Point it at that site.
- **Run:** `bash cptc-web.sh http://10.0.1.5`
- **You see:** missing security headers, exposed files (`.git`, `.env`, swagger/API docs, `/admin`), default-login hints, TLS problems.
- **Next:** it ends by listing the **manual** bugs to do in Burp — IDOR (change an ID), broken authz (admin action as a normal user), SSRF. Those are the real points; the script just clears the easy stuff first so you don't miss it.

### `cptc-enum.sh` — "I have a Linux shell, how do I level up?"
- **When:** the **moment** you land any shell on a Linux box. First thing you run, every time.
- **Run:** `bash cptc-enum.sh | tee enum-<host>.txt`  (the `tee` saves a copy for your report)
- **You see:** `[!! HIT]` lines = chase these: passwordless sudo, SUID binaries, credentials in files/env/history, writable SSH keys or cron, and — if you're in a container — the **escape routes** (docker.sock / privileged / host mount / old kernel).
- **Next:** work the hits top-down. Container hits → the escape one-liner from the CHEATSHEET. Found creds → log in somewhere else with them.

### `cptc-winenum.ps1` — the Windows version (for whoever runs Windows)
- **When:** after someone has a shell on a Windows box. You may never run this yourself — it's for the AD/Windows folks — but now the team *has* it.
- **Run:** `powershell -ep bypass -f cptc-winenum.ps1`  (or paste it into a session)
- **You see:** privesc quick wins (SeImpersonate → Potato = SYSTEM, AlwaysInstallElevated, weak services), stored creds, and AD pointers.
- **Honest note:** I wrote this carefully but could **not** test it on a real Windows box, so have the Windows person run it on the practice range once before trusting it in the comp.

---

## When NOT to use a script
- **To exploit.** Scripts enumerate; *you* exploit. They give you the to-do list, not the win.
- **When you already know what's there.** Don't re-scan for no reason — it's slow and noisy.
- **Out of scope or outside the window.** The active ones (triage, web) send traffic. Only run them in scope, in the window.

## Two safety facts (so you can relax)
- **`enum` and `winenum` only LOOK** — they read the box and change nothing.
- **`triage` and `web` send requests/scan** — that's their job, so keep them in scope + in the window.
- If you see a red error line, it almost always just means a tool isn't installed — the scripts are built to fail quietly and keep going. You didn't break anything. Paste it to me and I'll fix it.

## You don't have to memorize any of this
Print it, keep it next to you, and just match **"what did I just get access to?"** to the right script. That's the whole skill.
