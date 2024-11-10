"""
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
"""

import argparse
import configparser
import ctypes
import datetime
import ipaddress
import multiprocessing
import multiprocessing.connection
import multiprocessing.managers
import pathlib
import pickle
import queue
import random
import socket
import sqlite3
import subprocess
import sys
import time
import typing

import nmapxmlparser

shared_secret: bytes = b'2\x9bAU5\xafT#\x809\x89\xf6\x02\x19\xd3\xef\x0e\xc6cY\xdc\xac\xf2\x94'

# TODO Either figure out why authkey is not working or accept the fact that someone
# can RCE into your machine


class NmapManager(multiprocessing.managers.BaseManager):
    """
    A multiprocessing manager to manage nmap scans.
    """
    pass


class NmapScan:
    """
    Represents an Nmap scan task.
    """
    
    scan_types: tuple[str, ...] = ("ARP", "ICMP", "IGMP", "TCP", "SCTP", "UDP")
    """The valid scan types, roughly sorted from fastest to slowest."""
    
    def __init__(self, ip: typing.Union[ipaddress.IPv4Address, ipaddress.IPv6Address, \
            ipaddress.IPv4Network, ipaddress.IPv6Network], scanflags: typing.Sequence[str],
            scan_type: str, scan_purpose: int):
        """
        :param ip: The IP address or network to scan.
        :param scanflags: The flags that will be passed to Nmap immediately after "nmap".
        :param scan_type: The type of scan.
        :param scan_purpose: The purpose of the scan. See also the documentation for `scan_purpose`
        """
        self.__ip: typing.Union[ipaddress.IPv4Address, ipaddress.IPv6Address, \
                ipaddress.IPv4Network, ipaddress.IPv6Network] = ip
        self.__scanflags: tuple[str, ...] = tuple(scanflags)
        self.__scan_type: str = scan_type.upper()
        if self.__scan_type not in self.scan_types:
            # Sanity check
            raise ValueError("Invalid value \"" + self.__scan_type + "\" for scan_type, must be one of: " + 
                    ", ".join(self.scan_types))
        self.__scan_purpose: int = scan_purpose
        self.__scan_output: typing.Optional[str] = None
        self.__xml_file: typing.Optional[pathlib.Path] = None
        self.failed_attempts: int = 0
        """The number of failed attempts at scanning. If this becomes greater than 7, we'll give up."""
    
    @property
    def ip(self) -> typing.Union[ipaddress.IPv4Address, ipaddress.IPv6Address, \
            ipaddress.IPv4Network, ipaddress.IPv6Network]:
        """
        The IP address or network to scan
        """
        return self.__ip
    
    @property
    def scan_purpose(self) -> int:
        """
        The purpose of the scan.
         - 1 = Port discovery
         - 2 = Host discovery
        """
        return self.__scan_purpose
    
    @property
    def scan_output(self) -> typing.Optional[str]:
        """
        Returns the scan output, as a string.
        """
        return self.__scan_output
    
    @property
    def scan_type(self) -> str:
        """
        The type of Nmap scan we will be running. This has no effect on the actual scan 
        and is purely for identification purposes.
        """
        return self.__scan_type
    
    @property
    def xml_file(self) -> typing.Optional[pathlib.Path]:
        """
        The path to the XML file containing the Nmap XML output.
        
        Only applies to the machine that `scan()` was called on. If
        this object was picked and sent from a remote machine, the
        file will almost definitely not exist.
        """
        return self.__xml_file
    
    def scanflags(self) -> tuple[str, ...]:
        """
        The flags that will be passed to Nmap.
        """
        return self.__scanflags
    
    def scan(self) -> int:
        """
        Runs the Nmap scan. The standard output of the scan is returned. An XML
        file is written into `./nmapscan-xml/starttime.xml`
        
        :return: The exit code of the nmap process
        """
        # Create the output folder if it doesn't exist
        pathlib.Path("nmapscan-xml").mkdir(parents=True, exist_ok=True)
        
        # First, generate the file path of the output XML file.
        output_file_path: pathlib.Path = pathlib.Path("nmapscan-xml/" + 
                str(datetime.datetime.now(datetime.timezone.utc).timestamp()) + ".xml")
        
        # Run the scan with the given flags
        nmap_process = subprocess.run(["nmap"] + list(self.__scanflags) + ["-oX", 
                str(output_file_path), str(self.__ip)], capture_output=True)
        
        # Set the variables with the output.
        self.__scan_output = nmap_process.stdout.decode("utf-8")
        self.__xml_file = output_file_path
        
        return nmap_process.returncode
    
    def update_str(self) -> str:
        return "Scanning " + str(self.__ip) + " with options \"" + " ".join(self.__scanflags) + "\"..."
    
    def __str__(self) -> str:
        return "<" + str(self.__scan_type) + " Nmap scan of " + str(self.__ip) + ">"
    
    def __repr__(self) -> str:
        return "NmapScan(ip=" + repr(self.__ip) + ", scanflags=" + repr(self.__scanflags) + \
                ", scan_type=" + repr(self.__scan_type) + ", scan_purpose=" + repr(self.__scan_purpose) + ")"


def client(local_ip: typing.Union[ipaddress.IPv4Address, ipaddress.IPv6Address], server_address: str, 
        manager_port: int, shared_secret: bytes):
    """
    A single worker that can perform nmap scans.
    
    :param local_ip: The local IP address of the client
    :param server_address: The IP address of the server
    :param manager_port: The port of the manager server
    :param shared_secret: 
    """
    
    time.sleep(0.1)
    
    # TODO Set some sort of timeout here.
    # Initialize a manager client.
    manager = NmapManager(address=(server_address, manager_port))
    manager.register("host_discovery_queue")
    manager.register("fast_scan_queue")
    manager.register("medium_scan_queue")
    manager.register("slow_scan_queue")
    manager.register("scan_results_queue")
    manager.connect()
    
    # Fetch all queues from the manager.
    host_discovery_queue = manager.host_discovery_queue()
    fast_scan_queue = manager.fast_scan_queue()
    medium_scan_queue = manager.medium_scan_queue()
    slow_scan_queue = manager.slow_scan_queue()
    scan_results_queue = manager.scan_results_queue()
    
    queues_empty_get_counter: int = 0
    """
    The number of times we tried to get something from the queue
    but found it to be empty.
    """
    
    while True:
        # Get something from the queue.
        scan_type: str = ""
        nmap_scan: typing.Optional[NmapScan] = None
        try:
            nmap_scan = host_discovery_queue.get(block=False)
            scan_type = "discovery"
        except queue.Empty:
            try:
                nmap_scan = fast_scan_queue.get(block=False)
                scan_type = "fast"
            except queue.Empty:
                try:
                    nmap_scan = medium_scan_queue.get(block=False)
                    scan_type = "medium"
                except queue.Empty:
                    try:
                        nmap_scan = slow_scan_queue.get(block=False)
                        scan_type = "slow"
                    except queue.Empty:
                        pass
        
        if nmap_scan is None:
            if queues_empty_get_counter > 5:
                # We are probably done. So we gracefully exit the loop.
                break
            else:
                # Wait some number of seconds, doubling the wait time every loop.
                queues_empty_get_counter += 1
                time.sleep(random.uniform(0, 0.5 * 2**queues_empty_get_counter))
                continue
        else:
            # The queues were not empty when we checked
            queues_empty_get_counter = 0
        
        assert nmap_scan is not None
        assert scan_type != ""
        
        if nmap_scan.failed_attempts > 7:
            # Too many failed attempts.
            # Print a warning and silently ignore this scan without sending
            # it back to the server.
            print("WARNING: " + str(nmap_scan) + " failed after 7 attempts!")
            print(repr(nmap_scan) + " failed.\n")
            continue
        
        print(nmap_scan.update_str())
        scan_exit_code: int = nmap_scan.scan()
        if scan_exit_code == 0:
            # Send successful output to server
            print("Scan complete. Sending results to server...")
            nmap_xml: str = ""
            xml_file_path: typing.Optional[pathlib.Path] = nmap_scan.xml_file
            assert xml_file_path is not None
            with open(xml_file_path, 'r') as nmapxmlfile:
                nmap_xml = nmapxmlfile.read()
            scan_results_queue.put((nmap_scan, nmap_xml, local_ip))
        else:
            # Scan failed. Return the scan back to the server.
            print("Scan failed. Notifying server...")
            nmap_scan.failed_attempts += 1
            if scan_type == "discovery":
                host_discovery_queue.put(nmap_scan)
            elif scan_type == "fast":
                fast_scan_queue.put(nmap_scan)
            elif scan_type == "medium":
                medium_scan_queue.put(nmap_scan)
            elif scan_type == "slow":
                slow_scan_queue.put(nmap_scan)


def server_loop(raw_ip_list: list[typing.Union[ipaddress.IPv4Address, ipaddress.IPv6Address, \
        ipaddress.IPv4Network, ipaddress.IPv6Network]], manager_port: int, shared_secret: bytes):
    """
    The tasks that need to be run in a loop on the server.
    
    :param raw_ip_list: A list of IP addresses to scan.
    """
    
    # Initialize a manager client.
    manager = NmapManager(address=("127.0.0.1", manager_port))
    manager.register("host_discovery_queue")
    manager.register("fast_scan_queue")
    manager.register("medium_scan_queue")
    manager.register("slow_scan_queue")
    manager.register("scan_results_queue")
    manager.connect()
    
    # Fetch all queues from the manager.
    host_discovery_queue = manager.host_discovery_queue()
    fast_scan_queue = manager.fast_scan_queue()
    medium_scan_queue = manager.medium_scan_queue()
    slow_scan_queue = manager.slow_scan_queue()
    scan_results_queue = manager.scan_results_queue()
    
    host_discovery_scans: list[NmapScan] = []
    """
    The Nmap scans for host discovery purposes.
    """
    
    ips_to_scan: list[typing.Union[ipaddress.IPv4Address, ipaddress.IPv6Address, \
            ipaddress.IPv4Network, ipaddress.IPv6Network]] = []
    
    for raw_ip in raw_ip_list:
        # Split the IP addresses into more manageable chunks
        if isinstance(raw_ip, ipaddress.IPv4Network) or isinstance(raw_ip, ipaddress.IPv6Network):
            if raw_ip.prefixlen < 23:
                for ip_subnet in raw_ip.subnets(new_prefix=24):
                    ips_to_scan.append(ip_subnet)
            elif raw_ip.prefixlen < 26:
                for ip_subnet in raw_ip.subnets(prefixlen_diff=2):
                    ips_to_scan.append(ip_subnet)
            else:
                # Just append the network. It's not worth splitting it up
                ips_to_scan.append(raw_ip)
        else:
            # This is a single IP address, so we can just scan it to see.
            ips_to_scan.append(raw_ip)
        
    
    for ip_address in ips_to_scan:
        # ARP, ICMP, and TCP SYN/ACK scans for host discovery
        # They will all be combined into one command
        host_discovery_scans.append(NmapScan(ip_address, ("-PR", "-PE", "-PP", "-PM", "-PO2", 
                "-PS21,22,23,25,80,110,113,135,137,143,443,445,691,993,995," + 
                "1433,1521,2483,2484,3306,8008,8080,8443,7680,31339", 
                "-PA80,113,443,10042", "-sn"), "ICMP", 2))
    
    # Populate the queue for host discovery
    for nmap_scan in host_discovery_scans:
        host_discovery_queue.put(nmap_scan)
    
    discovered_hosts: set[typing.Union[ipaddress.IPv4Address, ipaddress.IPv6Address]] = set()
    """Set to keep track of hosts that we've discovered"""
    
    while True:
        time.sleep(0.5)
        
        # Consume all the scan results
        # The second element is the XML output of the Nmap scan
        # The third element is the IP address of the scanning server
        scan_results_list: list[tuple[NmapScan, str, \
                typing.Union[ipaddress.IPv4Address, ipaddress.IPv6Address]]] = []
        try:
            scan_results_list.append(scan_results_queue.get(block=False))
        except queue.Empty:
            pass
        
        for scan_result in scan_results_list:
            scan_output: nmapxmlparser.ScanOutput = nmapxmlparser.ScanOutput(scan_result[1])
            if scan_result[0].scan_purpose == 2:
                # This is a host discovery scan.
                for scanned_host in scan_output.hosts:
                    if scanned_host.up:
                        # Add the other scans for this host to the list.
                        host_ip: typing.Union[ipaddress.IPv4Address, ipaddress.IPv6Address] = \
                                ipaddress.ip_address(scanned_host.ip)
                        if host_ip not in discovered_hosts:
                            # Add this host to the list of discovered hosts
                            discovered_hosts.add(host_ip)
                            
                            # Sort the scans in order of speed, with faster scans going first.
                            fast_scan_queue.put(NmapScan(host_ip, ("-sS", "-sV"), "TCP", 1))  # TCP top 1000 scan
                            medium_scan_queue.put(NmapScan(host_ip, ("-p-", "-sS", "-sC", "-sV"), "TCP", 1))  # TCP full scan
                            medium_scan_queue.put(NmapScan(host_ip, ("-p-", "-sY", "-sC", "-sV"), "SCTP", 1))  # SCTP full scan
                            slow_scan_queue.put(NmapScan(host_ip, ("-sU", "-sC", "-sV", "--top-ports", "96"), "UDP", 1))  # UDP top 96 scan
            elif scan_result[0].scan_purpose == 1:
                # This is a scan of a single host.
                database: sqlite3.Connection = sqlite3.connect("openports.db")
                for scanned_host in scan_output.hosts:
                    database.execute("CREATE TABLE IF NOT EXISTS \"" + str(scanned_host.ip) + 
                            "\" ( \"port\" INTEGER NOT NULL, \"protocol\" TEXT NOT NULL, \"service\" TEXT, PRIMARY KEY(\"port\",\"protocol\"));")
                    for port in scanned_host.open_ports:
                        database.execute("INSERT OR IGNORE INTO \"" + scanned_host.ip + 
                                "\" (port, protocol, service) VALUES (?, ?, ?)", (port.number, port.protocol, port.service))
                database.commit()


def server(local_ip: typing.Union[ipaddress.IPv4Address, ipaddress.IPv6Address],
            ip_list: list[typing.Union[ipaddress.IPv4Address, ipaddress.IPv6Address,
            ipaddress.IPv4Network, ipaddress.IPv6Network]], 
            manager_listen_address: str, manager_port: int, shared_secret: bytes):
    """
    Starts a server that manages the Nmap scans.
    
    :param local_ip: The IP address of the server.
    :param ip_list: A list of IP addresses.
    :param manager_listen_address: The address that the manager will listen on.
    :param manager_port: The port to listen on for the manager
    """
    
    # Create a manager and start it
    manager = NmapManager(address=(manager_listen_address, manager_port))
    
    host_discovery_queue: queue.Queue = queue.Queue()
    fast_scan_queue: queue.Queue = queue.Queue()
    medium_scan_queue: queue.Queue = queue.Queue()
    slow_scan_queue: queue.Queue = queue.Queue()
    scan_results_queue: queue.Queue = queue.Queue()
    
    manager.register("host_discovery_queue", callable=lambda: host_discovery_queue)
    manager.register("fast_scan_queue", callable=lambda: fast_scan_queue)
    manager.register("medium_scan_queue", callable=lambda: medium_scan_queue)
    manager.register("slow_scan_queue", callable=lambda: slow_scan_queue)
    manager.register("scan_results_queue", callable=lambda: scan_results_queue)
    
    server_loop_process: multiprocessing.Process = multiprocessing.Process(target=server_loop, args=(ip_list, manager_port, shared_secret))
    server_loop_process.start()
    
    # Start the client process
    print("Starting client...")
    scan_client_process: multiprocessing.Process = multiprocessing.Process(target=client, 
            args=(local_ip, "127.0.0.1", manager_port, shared_secret))
    scan_client_process.start()
    
    manager_server = manager.get_server()
    
    print("Initializing manager...")
    try:
        manager_server.serve_forever()
    except KeyboardInterrupt:
        # Interrupted, let's exit.
        pass
    finally:
        scan_client_process.terminate()
        server_loop_process.terminate()


def main(argv: list[str]) -> int:
    # Read the configuration from the file
    config: configparser.ConfigParser = configparser.ConfigParser()
    config.read("nmapclusterconfig.ini")
    
    # Parse command-line arguments
    argparser = argparse.ArgumentParser()
    argparser.add_argument("--force-superuser", action="store_true", 
            help="Don't perform the check for whether the user is a superuser or not. This " + 
            "can be useful if the script is unable to accurately detect if you are superuser " + 
            "on your operating system. WARNING: Things will break if you do not actually have " + 
            "superuser privileges.")
    argparser.add_argument("-l", "--localip", nargs=1, 
            help="The IP address of this server. If omitted, will read from config file. If " + 
            "LocalIP is not specified in the config file, then will attempt to autodetect the IP.")
    argparser.add_argument("target", nargs='*', 
            help="An IP address or subnet to scan. Multiple can be passed in.")
    arguments_dict: dict = vars(argparser.parse_args(argv[1:]))
    
    # Initialize the authentication key
    multiprocessing.current_process().authkey = shared_secret
    
    # Get the local IP address
    local_ip_address: typing.Optional[typing.Union[ipaddress.IPv4Address, ipaddress.IPv6Address]] = None
    if "localip" in arguments_dict and arguments_dict["localip"] is not None:
        try:
            local_ip_address = ipaddress.ip_address(arguments_dict["localip"])
        except ValueError:
            pass
    else:
        try:
            local_ip_address = ipaddress.ip_address(config["General"]["LocalIP"])
        except ValueError:
            print("WARNING: Invalid IP address \"" + str(config["Server"]["LocalIP"]) + 
                    "\" specified in config.")
        except KeyError:
            pass
    if local_ip_address is None:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.connect(("1.1.1.1", 53))
            local_ip_address = ipaddress.ip_address(sock.getsockname()[0])
            sock.close()
        except OSError:
            print("ERROR: IP detection failed - you do not appear to have Internet access from your machine. " +
                    "Please provide your machine's IP address using the --localip argument.")
            return 1
    
    assert local_ip_address is not None
    
    is_server: typing.Optional[bool] = None
    """Whether we are a server (True) or a client (False)"""
    try:
        is_server = config["General"]["Mode"].lower() == "server"
    except KeyError:
        print("ERROR: Must specify server or client with directive Mode under section [General]")
        return 1
    
    assert is_server is not None
    
    manager_port: int = 9001
    try:
        manager_port = int(config["General"]["ManagerPort"])
    except ValueError:
        print("ERROR: Invalid value for ManagerPort \"" + str(config["General"]["ManagerPort"]) + 
                "\", must be an integer")
        return 1
    except KeyError:
        print("No value specified for ManagerPort, defaulting to 9001.")
    
    if is_server:
        # This is a server
        # Check the validity of the arguments \"targets\"
        if arguments_dict["target"] is None or arguments_dict["target"] == []:
            print("ERROR: Argument \"target\" required in server mode")
            return 1
        
        target_ip_addresses: list[typing.Union[ipaddress.IPv4Address, ipaddress.IPv6Address,\
                ipaddress.IPv4Network, ipaddress.IPv6Network]] = []
        for ip_address_str in arguments_dict["target"]:
            try:
                # Try to parse as address
                target_ip_addresses.append(ipaddress.ip_address(ip_address_str))
            except ValueError:
                try:
                    # Okay, so the IP address won't parse as an address. Maybe it's a network
                    target_ip_addresses.append(ipaddress.ip_network(ip_address_str))
                except ValueError as e:
                    print("ERROR: Failed to parse IP address/network \"" + ip_address_str + "\" - " + str(e))
                    return 1
        
        manager_listen_address: str = "0.0.0.0"
        try:
            manager_listen_address = config["Server"]["ListenIP"]
        except KeyError:
            print("No value specified for ListenIP, defaulting to 0.0.0.0")
        server(local_ip_address, target_ip_addresses, manager_listen_address, manager_port, shared_secret)
    else:
        if arguments_dict["target"] is not None and arguments_dict["target"] != []:
            print("WARNING: Ignoring argument \"target\" in client mode")
        # This is a client
        server_address: str = ""
        try:
            server_address = config["Client"]["RemoteIP"]
        except KeyError:
            print("ERROR: No value specified for RemoteIP.")
            return 1
        client(local_ip_address, server_address, manager_port, shared_secret)
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
