# Things to note
Do not attempt to clone this repository on Windows without adding an antivirus exception, the files in here will immediately set it off.

## Payloads
Here are the files in the `payloads` folder, along with an explanation:
 - `chisel` and `chisel.exe` - Cross-platform pivoting tools
 - `eicar_com.zip` - Verify whether a commercial antivirus software is installed.
 - `linpeas.sh` - Check for privilege escalation on Linux hosts. Don't use on mission-critical systems.
 - `python-linux.tar.gz` - Portable Python 3.9.17 for Linux.
 - `python-windows.tar.gz` - Portable Python 3.2.5 for Windows.
 - `python.com` - Portable Python (cross-platform)
 - `nmap-bundle.tar.gz` - Contains multiple files to scan ports on Linux devices.
 - `winpeas.exe` - Privilege escalation detector on Windows. `winpeas-ofs.exe` is an obfuscated version.

## Python Scripts
The folder `python` contains scripts written for Python 3.
 - `portscan.py` - Quick and dirty port scan for pivoting without admin/root. Works on some Windows machines.


## Setup
The folder `setup` contains setup scripts that will deploy nextcloud and/or planka
 - These will be used to make notetaking and task management during the engagement easier
