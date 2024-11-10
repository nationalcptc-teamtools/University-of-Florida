"""
Manages ports, scans, and hosts in Planka.
"""

import configparser
import sqlite3

import plankapy  # type: ignore[import-untyped]

class PlankaPortManager:
    """
    A manager that will automatically perform tasks to assist in
    port scans.
    """
    
    def __init__(self) -> None:
        """
        Initialize and connect to the Planka service
        """
        
        config_file: configparser.ConfigParser = configparser.ConfigParser()
        config_file.read("plankaconfig.ini")
        
        self.planka_project_name: str = "CPTC"
        """The name of the project that will be created"""
        
        users_to_create: list[str] = [username.strip().lower() for username in config_file["Planka"]["Users"].split(",")]
        
        self.planka_instance: plankapy.Planka = plankapy.Planka(config_file["Planka"]["URL"], 
                config_file["Planka"]["Username"], config_file["Planka"]["Password"])
        """The Planka instance object that holds the session token."""
        
        self.planka_project = plankapy.Project(self.planka_instance, name="CPTC")
        """The Planka project that contains all the information"""
        try:
            self.planka_project.create()
        except plankapy.plankapy.InvalidToken:
            # The project probably already exists
            pass
        
        planka_board_lister: plankapy.Board = plankapy.Board(self.planka_instance)
        planka_board_list: dict = planka_board_lister.get(project_name=self.planka_project_name)
        
        self.open_ports_board: plankapy.Board = plankapy.Board(self.planka_instance, 
                    name="Open Ports", position=10)
        """The Kanban board containing open ports"""
        self.compromised_machines_board: plankapy.Board = plankapy.Board(self.planka_instance, 
                name="Compromised Machines", position=20)
        """The Kanban board containing compromised machines"""
        
        # Create the boards
        create_open_ports_board: bool = True
        create_compromised_machines_board: bool = True
        
        for board in planka_board_list:
            print(board)
            if board["name"] == "Open Ports":
                self.open_ports_board = plankapy.Board(instance=self.planka_instance, **board)
                create_open_ports_board = False
            elif board["name"] == "Compromised Machines":
                self.compromised_machines_board = plankapy.Board(instance=self.planka_instance, **board)
                create_compromised_machines_board = False
        
        if create_open_ports_board:
            self.open_ports_board.create(project_name=self.planka_project_name)
        if create_compromised_machines_board:
            self.compromised_machines_board.create(project_name=self.planka_project_name)
        
        # Create the users if they don't exist
        planka_user_lister: plankapy.User = plankapy.User(self.planka_instance)
        for user_to_create in users_to_create:
            user_exists: bool = False
            for existing_user in planka_user_lister.get():
                # Look for the user in the lis of existing users
                if existing_user["username"] == user_to_create:
                    user_exists = True
                    break
            if not user_exists:
                planka_user: plankapy.User = plankapy.User(instance=self.planka_instance, 
                        username=user_to_create, name=user_to_create, password="ChangeMe123!", email="invalid@invalid.invalid")
                try:
                    planka_user.create()
                except TypeError:
                    # Ignore the buggy module code
                    # TODO Make a pull request or fork `plankapy`
                    pass
    
    def create_list_if_not_exists(self, instance: plankapy.Planka, project: plankapy.Project,
            board: plankapy.Board, name: str, position: int) -> plankapy.List:
        """
        Create a list with the given name in the given Planka instance if it doesn't exist. 
        If the list does exist, returns the list.
        
        :param name: The name of the list to return
        :param position: The position of the list, if it doesn't exist. Will be ignored
        if a list named `name` already exists.
        """
        planka_list_lister: plankapy.List = plankapy.List(self.planka_instance)
        list_exists: bool = False
        for planka_list in planka_list_lister.get(project_name=project.data["name"], board_name=board.data["name"]):
            if planka_list["name"] == name:
                return plankapy.List(self.planka_instance, **planka_list)
        if not list_exists:
            planka_list = plankapy.List(instance=instance, name=name, position=position)
            planka_list.create(project_name=project.data["name"], board_name=board.data["name"])
            return planka_list
    
    def create_card_if_not_exists(self, instance: plankapy.Planka, project: plankapy.Project,
            board: plankapy.Board, planka_list: plankapy.List, name: str, position: int) -> plankapy.Card:
        """
        Create a card with the given name in the given Planka instance if it doesn't exist. 
        If the card does exist, returns the card.
        
        :param name: The name of the card to return
        :param position: The position of the card, if it doesn't exist. Will be ignored
        if a card named `name` already exists.
        """
        planka_card_lister: plankapy.Card = plankapy.Card(self.planka_instance)
        card_exists: bool = False
        
        for planka_card in planka_card_lister.get(project_name=project.data["name"], 
                board_name=board.data["name"], list_name=planka_list.data["name"]):
            if planka_card["item"]["name"] == name:
                return plankapy.Card(self.planka_instance, **(planka_card["item"]))
        if not card_exists:
            planka_card = plankapy.Card(instance=instance, name=name, position=position)
            planka_card.create(project_name=project.data["name"], board_name=board.data["name"], 
                    list_name=planka_list.data["name"])
            return planka_card
        
        
    def upload_ports_from_sqlite(self, sqlite_file: str = "openports.db") -> None:
        """
        Upload ports to Planka from a SQLite file.
        
        :param sqlite_file: The name of the SQLite file to read ports from
        """
        open_ports_database: sqlite3.Connection = sqlite3.connect(sqlite_file)
        scanned_hosts: list[str] = []
        for row in open_ports_database.execute("SELECT name FROM sqlite_master WHERE type='table';"):
            scanned_hosts.append(row[0])
        open_ports: dict[str, list[tuple[str, str]]] = {}
        """Maps each host to a list of tuples of (port/protocol, service)"""
        for hostname in scanned_hosts:
            for row in open_ports_database.execute("SELECT port, protocol, service FROM '" + hostname + "';"):
                try:
                    open_ports[hostname].append((str(row[0]) + '/' + row[1], row[2]))
                except KeyError:
                    open_ports[hostname] = [(str(row[0]) + '/' + row[1], row[2])]
        
        current_host_position: int = 10
        for hostname in open_ports:
            host_list: plankapy.List = self.create_list_if_not_exists(self.planka_instance, project=self.planka_project, 
                    board=self.open_ports_board, name=hostname, position=current_host_position)
            current_port_position = 10
            for port, protocol in open_ports[hostname]:
                port_card = self.create_card_if_not_exists(self.planka_instance, self.planka_project, 
                        self.open_ports_board, host_list, name=port + " - " + protocol, position=current_port_position)
                current_port_position += 10
            current_host_position += 10
