# NmapCluster

Do you want to use Nmap on multiple devices in parallel? Well, you're in luck!

Introducing NmapCluster. This tool will distribute Nmap scans to a cluster of
devices automatically, but is flexible enough to work as an Nmap automator
script for a single machine as well.

Unlike other solutions on the market, we strive to make our code as well-
documented as possible. We believe that, if we give to the community, the
community can give back in terms of extending our code in unexpected ways
or spotting issues that we never noticed.

## Quick Start
You'll need to run this app as root. Here's how to run the server on Linux
```
sudo python nmapcluster.py <HOST OR NETWORK TO SCAN>
```
If you want to configure a client, you'll need to change some things in
`nmapclusterconfig.ini`. Change `Mode` to `client` and change `RemoteIP`
to the IP address of the server. You should also probably add a value for
`SharedSecret` unless you're fine with anyone on the network potentially
running arbitrary code on your system.

## Features
 - [x] Written in pure Python.
 - [x] Well-documented, extensible code.
 - [x] Full TCP/UDP scan of any host or network.
 - [x] Supports inputting single hosts or entire networks in CIDR notation.
 - [x] Outputs scans to a SQLite database, which can be consumed by other tools.
 - [x] No dependencies besides Nmap and the Python standard library.
 - [x] Tested on both Windows and Linux.

## License
```
    Copyright (C) 2024  Yuliang Huang <https://gitlab.com/yhuang885/>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation; version 3.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
```
