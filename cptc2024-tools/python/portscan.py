# Slow and loud cross-platform TCP port scanner written in pure Python and not requiring root/admin.
# Scans the top 100 ports using TCP CONNECT.
#
# Written by Yuliang Huang

import socket
import sys
import time

ports_to_scan = [7,9,13,21,22,23,25,26,37,53,79,80,81,88,106,110,111,113,119,135,139,143,144,179,199,389,427,443,444,445,465,513,514,515,543,544,548,554,587,631,646,873,990,993,995,1025,1026,1027,1028,1029,1110,1433,1720,1723,1755,1900,2000,2001,2049,2121,2717,3000,3128,3306,3389,3986,4899,5000,5009,5051,5060,5101,5190,5357,5432,5631,5666,5800,5900,6000,6001,6646,7070,8000,8008,8009,8080,8081,8443,8888,9100,9999,10000,32768,49152,49153,49154,49155,49156,49157]

open_ports = []
closed_ports = []
filtered_ports = []
not_scanned_ports = []

if len(sys.argv) <= 1:
    print("USAGE: " + sys.argv[0] + " <HOST TO SCAN> [TIMEOUT]")
    print()
    print("HOST TO SCAN - Hostname or IP address")
    print("TIMEOUT - If connection is not refused, how long to wait before connection is assumed dead.")
    sys.exit(1)

host = sys.argv[1]
timeout = 0.2
if len(sys.argv) >= 3:
    timeout = float(sys.argv[2])

i = 0

for port in ports_to_scan:
    i += 1
    sock = socket.socket(socket.AF_INET)
    sock.settimeout(timeout)
    if sys.version_info[0] == 3 and sys.version_info[1] < 10:
        # Python <3.10. Use exceptions built in to the socket module instead.
        try:
            sock.connect((host, port))
            open_ports.append(port)
        except socket.timeout:
            filtered_ports.append(port)
        except socket.error as e:
            if sys.platform == 'win32' and e.errno == 10013:
                # Permission denied
                not_scanned_ports.append(port)
            else:
                # Probably connection refused
                closed_ports.append(port)
    else:
        try:
            sock.connect((host, port))
            open_ports.append(port)
        except ConnectionRefusedError:
            closed_ports.append(port)
        except TimeoutError:
            filtered_ports.append(port)
        except PermissionError:
            not_scanned_ports.append(port)
    sock.close()
    if i % 10 == 0:
        print("Scanned " + str(i) + " out of " + str(len(ports_to_scan)) + " ports.")


print("\nScan results for top 100 ports on host " + host + ":")
if open_ports:
    print("The open ports are: ")
    for port in open_ports:
        print(str(port) + "/tcp")
else:
    print("There are no open TCP ports.")

if closed_ports and len(closed_ports) < 12:
    print("The closed ports are: ")
    for port in closed_ports:
        print(str(port) + "/tcp")
elif not closed_ports:
    print("There are no closed TCP ports.")
else:
    print("There are " + str(len(closed_ports)) + " closed TCP ports.")

if filtered_ports and len(filtered_ports) < 12:
    print("The filtered ports are: ")
    for port in filtered_ports:
        print(str(port) + "/tcp")
elif not filtered_ports:
    print("There were no filtered TCP ports.")
else:
    print("There are " + str(len(filtered_ports)) + " filtered TCP ports.")

if not_scanned_ports:
    print("NOTE: The following ports were not scanned (permission denied):")
    for port in not_scanned_ports:
        print(str(port) + "/tcp")
