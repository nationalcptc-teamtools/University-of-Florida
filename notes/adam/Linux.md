# Initial Access

## General

* Make sure to look up versions on searchsploit and on google/github
	* Sometimes exploits aren't on searchsploit (see PG Crane)

## Web

* IF THERE IS A BUTTON OR ANY KIND OF WEB REQUEST, CLICK IT
	Especially if you can edit the field yourself

* Fuzz with .html and .php regardless of the tech (See PG Cockpit)

# Privilege Escalation

## Services available on localhost

* ss -ntlp. pay attention to whats on localhost
	* check firewall rules if you can

## Credential Access

* Password Reuse
	If you have a password, try it everywhere
	Look in config files, especially if there is a webapp that could access mysql or smth similar
	Look in history files 

	For databases, look for files with "config" in the name and grep for strings like "host", "localhost", "username", "password", and "prefix"

* Try the username as the password
	Try defaults like admin/admin, root/password, 


## Exploits

* Kernel Exploits
	`uname -a` and go from there

* Look up binary versions, especially if:
	they're run by services or are run by cronjobs
	they're suid

* Run `lsb_release -d` to get distro
