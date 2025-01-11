"""
Parser for Nmap scan XML output.

Example:
The following gets whether the first host is up
```
>>> result = ScanOutput(xml)
>>> result.hosts[0].up
True
```

```
Copyright (C) 2024  Yuliang Huang

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
"""

import collections
import xml.etree.ElementTree as XmlElementTree

# import scanresults


NmapPort = collections.namedtuple("NmapPort", ("number", "protocol", "service", "conf"))
"""
Represents a port as seen by Nmap

conf is the confidence in the service associated with this port.
"""

NmapHost = collections.namedtuple("NmapHost", ("up", "ip", "hostname", "open_ports"))
"""
Represents a host as seen by Nmap.

open_ports is a list of NmapPort objects.
"""

class ScanOutput:
    """
    Represents Nmap scan output.
    """
    
    def __init__(self, nmap_xml: str):
        """
        Parse Nmap scan output
        
        :param nmap_xml: XML output from Nmap
        """
        host_scan_list: list = []
    
        xml_root = XmlElementTree.fromstring(nmap_xml)
        
        self.hosts: list[NmapHost] = []
        """A list of hosts found in this scan."""
        
        for host_xml in xml_root.findall("host"):
            host_up: bool = host_xml.find("status").attrib["state"].lower() == "up"
            host_ip: str = host_xml.find("address").attrib["addr"]
            hostname: typing.Optional[str] = None
            if host_xml.find("hostnames") is not None:
                for hostname_xml in host_xml.find("hostnames").findall("hostname"):
                    hostname = hostname_xml.attrib["name"]
            open_ports: list[NmapPort] = []
            if host_xml.find("ports") is not None:
                # If any ports were found in this scan, fetch the associated information.
                for port_xml in host_xml.find("ports").findall("port"):
                    port_number: int = int(port_xml.attrib["portid"])
                    port_protocol: str = port_xml.attrib["protocol"]
                    port_state: str = port_xml.find("state").attrib["state"]
                    if port_xml.find("service") is not None:
                        # If there is an associated service, get the information associated with it
                        port_service: str = port_xml.find("service").attrib["name"]
                        port_service_conf: str = port_xml.find("service").attrib["conf"]
                    
                    if port_state == "open":
                        open_ports.append(NmapPort(port_number, port_protocol, port_service, port_service_conf))
                    
            self.hosts.append(NmapHost(host_up, host_ip, hostname, open_ports))


if __name__ == "__main__":
    print("Starting unit test for nmapxmlparser.py...")
    with open("test.xml", 'r') as inputfile:
        scan_output: ScanOutput = ScanOutput(inputfile.read())
        print(scan_output.hosts)
