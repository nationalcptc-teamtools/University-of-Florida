"""
Uploads scanned Nmap ports to Planka.

```
Copyright (C) 2025  Yuliang Huang

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

import configparser
import datetime
import sqlite3
import sys
import typing

import plankaapi

def main(argv: list[str]) -> int:
    # Open the database and read in the scanned data
    open_ports_database: sqlite3.Connection = sqlite3.connect("openports.db")
    
    # Get the scanned hosts
    scanned_hosts: list[str] = []
    for row in open_ports_database.execute("SELECT DISTINCT host FROM scans;"):
        scanned_hosts.append(row[0])
    open_ports: dict[str, tuple[list[str], list[tuple[str, str]]]] = {}
    """Maps each host to (a list of nmap_scan_output, a list of tuples of (port/protocol, service))"""
    
    for hostname in scanned_hosts:
        for row in open_ports_database.execute("SELECT port, protocol, service FROM ports WHERE host=?", (hostname,)):
            try:
                open_ports[hostname][1].append((str(row[0]) + '/' + row[1], row[2]))
            except KeyError:
                open_ports_list: list[tuple[str, str]] = [(str(row[0]) + '/' + row[1], row[2])]
                
                nmap_scan_strings: list[str] = []
                for row in open_ports_database.execute("SELECT rawScan FROM scans WHERE host=?;", (hostname,)):
                    nmap_scan_strings.append(row[0])
                open_ports[hostname] = (nmap_scan_strings, open_ports_list)
    
    open_ports_database.close()
    
    # Read the config for the Planka settings
    config_file: configparser.ConfigParser = configparser.ConfigParser()
    config_file.read("plankaconfig.ini")
    
    # Get request timeout from config file.
    request_timeout_duration: float = 30.0
    try:
        request_timeout_duration = float(config_file["Sockets"]["TCPTimeout"].strip())
        if request_timeout_duration < 0:
            print("Invalid value \"" + config_file["Sockets"]["TCPTimeout"] + 
                    "\" for TCPTimeout - using default of 30.")
            request_timeout_duration = 30.0
    except ValueError:
        print("Invalid value \"" + config_file["Sockets"]["TCPTimeout"] + 
                "\" for TCPTimeout - using default of 30.")
    
    # Initialize the Planka API
    planka_api: plankaapi.PlankaApi = plankaapi.PlankaApi(config_file["Planka"]["URL"], 
            config_file["Planka"]["Username"], config_file["Planka"]["Password"], timeout=request_timeout_duration)
    
    intended_project_name: str = config_file["Planka"]["ProjectName"]
    """The name of the project we want to create."""
    
    # Create all the users
    usernames_to_add: set[str] = set(config_file["Planka"]["Users"].split(','))
    for user in planka_api.get_users():
        # If the user already exists, don't add them.
        usernames_to_add.discard(user.username)
    for username in usernames_to_add:
        # Now we create the users
        planka_api.create_user(username, "ChangeMe123!", username + "@email.example")
    
    # Create the project if it doesn't exist
    planka_project: typing.Optional[plankaapi.PlankaProject] = None
    for project in planka_api.get_projects():
        if project.name == intended_project_name:
            planka_project = project
    if planka_project is None:
        planka_project = planka_api.create_project(intended_project_name)
    # Now the project is stored in planka_project
    
    # Now create the board if it doesn't exist
    current_board_position: int = 100
    ports_board: typing.Optional[plankaapi.PlankaBoard] = None
    for board in planka_project.get_boards():
        if board.position >= current_board_position:
            current_board_position = board.position + 10
        if board.name == "Open Ports":
            ports_board = board
    if ports_board is None:
        ports_board = planka_project.create_board("Open Ports", current_board_position)
        current_board_position += 10
    # Now the board is stored in ports_board
    
    current_list_position: int = 100
    for hostname in open_ports:
        # Create the list if it doesn't exist.
        # Also keep track of the highest position, so we can insert after that.
        host_list: typing.Optional[plankaapi.PlankaList] = None
        for planka_list in ports_board.get_lists():
            if planka_list.position >= current_list_position:
                current_list_position = planka_list.position + 10
            if planka_list.name == hostname:
                host_list = planka_list
        if host_list is None:
            host_list = ports_board.create_list(hostname, current_list_position)
            current_list_position += 10
        
        current_card_position: int = 100
        for port, service in open_ports[hostname][1]:
            card_title: str = port + " - " + service
            
            # Create the card if it doesn't exist.
            port_card: typing.Optional[plankaapi.PlankaCard] = None
            for planka_card in host_list.get_cards():
                if planka_card.position >= current_card_position:
                    current_card_position = planka_card.position + 10
                if planka_card.name == card_title:
                    port_card = planka_card
            if port_card is None:
                port_card = host_list.create_card(card_title, current_card_position)
                current_card_position += 10
        
        # Add one last card for the scan of the host.
        scan_card: plankaapi.PlankaCard = host_list.create_card("Scan details " + 
                    datetime.datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %z"), current_card_position)
        current_card_position += 10
        # Add one comment for each scan that was performed.
        for nmap_scan_string in open_ports[hostname][0]:
            scan_card.create_comment("```\n" + nmap_scan_string + "\n```")
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
