import subprocess
import argparse
import multiprocessing
import tempfile
import json
import urllib.request
import xml.etree.ElementTree as ET

SERVER = "http://<<<CHANGEME>>>:3000/"
ADMIN_USERNAME = "admin"
ADMIN_PASSWORD = "ChangeMe123!"
PROJECT_NAME = "CPTC 2"

LABELS = {
    "scanning": "light-concrete",
    "triage": "berry-red",
    "likely": "pumpkin-orange",
    "unlikely": "light-cocoa",
    "VULN": "pink-tulip",
    "user": "sunny-grass",
    "root": "morning-sky"
}
USERS = {
    "adam": "ChangeMe123!",
    "alannis": "ChangeMe123!",
    "ayden": "ChangeMe123!",
    "dnf": "ChangeMe123!",
    "eric": "ChangeMe123!",
    "yuli": "ChangeMe123!",
}

class HTTPError(Exception):
    def __init__(self, url, code, reason, body):
        self.url = url
        self.code = code
        self.reason = reason
        self.body = body

auth = None
def request(method, endpoint, **data):
    req = urllib.request.Request(f"{SERVER}{endpoint}", method=method)
    if auth:
        req.add_header("Authorization", f"Bearer {auth}")

    if data:
        req.add_header('Content-Type', 'application/json; charset=utf-8')
        data = json.dumps(data).encode()

    try:
        response = urllib.request.urlopen(req, data=data)
    except urllib.error.HTTPError as e:
        with e as f:
            raise HTTPError(e.url, e.code, e.reason, f.read())
    with response as f:
        return json.load(response)

auth = request("POST", "api/access-tokens",
               emailOrUsername=ADMIN_USERNAME,
               password=ADMIN_PASSWORD)["item"]

projects = [project["id"] for project in request("GET", "api/projects")["items"]
            if project["name"] == PROJECT_NAME]
if projects:
    assert len(projects) == 1, PROJECT_NAME
    project_id = projects[0]
else:
    project_id = request("POST", "api/projects", name=PROJECT_NAME)["item"]["id"]
project = request("GET", f"api/projects/{project_id}")

users = {user["name"]:user["id"] for user in request("GET", "api/users")["items"]
         if user["name"] in USERS}
for username, pw in USERS.items():
    if username in users: continue
    users[username] = request("POST", "api/users", username=username, name=username,
                              email=f"{username}@cptc.global", password=pw)["item"]["id"]

nmap_services = {}
with open("/usr/share/nmap/nmap-services") as f:
    for line in f.readlines():
        if line.startswith("#"): continue
        line = line.split("\t")
        nmap_services[line[1]] = line[0]

parser = argparse.ArgumentParser()
parser.add_argument("hosts", nargs="*")
parser.add_argument("-Pn", action="store_true")
parser.add_argument("-p", type=int)
parser.add_argument("-i", type=argparse.FileType())
args = parser.parse_args()

def is_ip(ip):
    try:
        if len([int(seg) for seg in ip.split(".")]) != 4:
            return False
    except ValueError:
        return False
    return True

def is_service(service):
    service = service.split("/")
    if len(service) != 2: return False
    if service[1] not in ["tcp" or "udp"]:
        return False
    try:
        int(service[0])
    except ValueError:
        return False
    return True

labels = {}
def create_labels(board_id):
    for name, color in LABELS.items():
        if (board_id, name) in labels: continue
        label_id = request("POST", f"api/boards/{board_id}/labels",
                           name=name, color=color, position=0)["item"]["id"]
        labels[(board_id, name)] = label_id

def add_users(board_id, included_users=set()):
    for user, user_id in users.items():
        if user in included_users: continue
        request("POST", f"api/boards/{board_id}/memberships", userId=user_id, role="editor")

boards, lsts, cards = {}, {}, {}
for board in project["included"]["boards"]:
    ip = board["name"].split("/24")[0]
    if not is_ip(ip): continue
    assert ip not in boards, ip
    board_id = board["id"]
    boards[ip] = board_id

    board = request("GET", f"api/boards/{board_id}")
    for lst in board["included"]["lists"]:
        ip = lst["name"].split("-")[0].strip()
        if not is_ip(ip): continue
        assert ip not in lsts, ip
        lsts[ip] = lst["id"]

        for card in board["included"]["cards"]:
            if card["listId"] != lst["id"]: continue
            service = card["name"].split("-")[0].strip()
            if not is_service(service): continue
            assert (ip, service) not in cards, (ip, service)
            cards[(ip, service)] = card["id"]

    for label in board["included"]["labels"]:
        name = label["name"]
        if name in LABELS:
            assert (board_id, name) not in labels, ip
            labels[(board_id, name)] = label["id"]
    create_labels(board_id)

    included_users = {user["name"] for user in board["included"]["users"]}
    add_users(board_id, included_users)

print("Connected to API")
print("Boards:", ", ".join(f'"{name}"' for name in boards.keys()))
print("Hosts:", ", ".join(f'"{name}"' for name in lsts.keys()))

def get_board(ip):
    assert is_ip(ip), ip
    ip = [int(seg) for seg in ip.split(".")]
    ip = ".".join(str(c) for c in ip[0:3]) + ".0"

    if ip in boards:
        board_id = boards[ip]
    else:
        board_id = request("POST", f"api/projects/{project_id}/boards",
                           name=f"{ip}/24 - ?", position=0)["item"]["id"]
        boards[ip] = board_id
        add_users(board_id)
    create_labels(board_id)
    return board_id

def get_list(ip, name=None):
    assert is_ip(ip), ip

    if ip in lsts:
        return lsts[ip]
    else:
        lst_id = request("POST", f"api/boards/{get_board(ip)}/lists",
                         name=f"{ip} - {name or '?'}", position=0)["item"]["id"]
        lsts[ip] = lst_id
        return lst_id

def card_name(service, name=None):
    name = name or nmap_services.get(service, "unknown") + "?"
    return f"{service} - {name}"

def get_card(ip, service, name=None):
    assert is_ip(ip), ip
    assert is_service(service), service

    if (ip, service) in cards:
        return cards[(ip, service)]
    else:
        name = card_name(service, name)
        card_id = request("POST", f"api/lists/{get_list(ip)}/cards",
                          name=name, position=0)["item"]["id"]
        cards[(ip, service)] = card_id
        return card_id

def add_label(card_id, label_id):
    try:
        request("POST", f"api/cards/{card_id}/labels", labelId=label_id)
    except HTTPError as e:
        if e.code != 409:
            raise e

if args.i:
    xml = ET.parse(args.i)
    for host in xml.findall("host"):
        ip = host.find("address").attrib["addr"]
        triage_id = labels[(get_board(ip), "triage")]
        for port in host.findall("ports/port"):
            service = port.attrib["portid"] + "/" + port.attrib["protocol"]
            service_node = port.find("service")
            service_name = service_node.attrib["name"] if service_node else None

            card_id = get_card(ip, service, name=service_name)
            add_label(card_id, triage_id)

            info = [service, port.find("state").attrib["state"]]
            if "name" in service_node.attrib:
                info.append(str(service_node.attrib["name"]))
            if "product" in service_node.attrib:
                info.append(str(service_node.attrib["product"]))
            if "product" in service_node.attrib:
                info.append(f"({service_node.attrib['product']})")
            text = ["  ".join(info)]
            for script in port.findall("script"):
                output = script.attrib["output"].split("\n")
                output[0] = f"{script.attrib['id']}  {output[0]}"
                for line in output[:-1]:
                    text.append(f"| {line}")
                text.append(f"|_{output[-1]}")
            text = "\n".join(text)
            request("POST", f"api/cards/{card_id}/comment-actions", text=f"```\n{text}\n```")

    exit(0)
elif not args.hosts:
    parser.error("the following arguments are required: hosts")

if args.Pn:
    print("SKIPPING HOST DISCOVERY")
    hosts = args.hosts
else:
    print("[PHASE 1] HOST DISCOVERY")
    hosts = []
    for host in args.hosts:
        p = subprocess.Popen(["nmap", "-sn", host], stdout=subprocess.PIPE)
        for line in p.stdout:
            if line.startswith(b"Nmap scan report for "):
                ip = line[len(b"Nmap scan report for "):].decode()
                if line.endswith(b")\n"):
                    name, ip = ip[:-2].split(" (")
                else:
                    ip, name = ip[:-1], None

                board_id = get_board(ip)
                get_list(ip, name)

                print(f"Host {ip} is up")
                hosts.append(ip)

def detailed_scan(ip, service, card_id):
    board_id = get_board(ip)
    scanning_id = labels[(board_id, "scanning")]
    triage_id = labels[(board_id, "triage")]

    add_label(card_id, scanning_id)

    port = service.split("/")[0]
    p = subprocess.Popen(
        ["nmap", "-sC", "-sV", "-v0", "-o", "-", "-Pn", "-p", port, ip],
        stdout=subprocess.PIPE
    )

    lines = [line.decode() for line in p.stdout]
    if request("GET", f"api/cards/{card_id}")["item"]["name"] == card_name(service):
        header_idx = next(i for i, line in enumerate(lines) if line.startswith("PORT"))
        service_name = lines[header_idx + 1].split()[2]
        request("PATCH", f"api/cards/{card_id}", name=f"{service} - {service_name}")

    text = "".join(["```\n"] + lines + ["```"])
    request("POST", f"api/cards/{card_id}/comment-actions", text=text)

    request("DELETE", f"api/cards/{card_id}/labels/{scanning_id}")
    add_label(card_id, triage_id)

scanned = set()
def scan(*args):
    pool = multiprocessing.Pool(4)
    p = subprocess.Popen(
        ["nmap", "-Pn", "-v"] + list(args) + hosts,
        stdout=subprocess.PIPE
    )
    for line in p.stdout:
        if line.startswith(b"Discovered open port "):
            line = line[len(b"Discovered open port "):-1].split(b" ")
            assert len(line) == 3, line
            assert line[1] == b"on", line
            service, ip = line[0].decode(), line[2].decode()
            if (service, ip) in scanned:
                continue
            scanned.add((service, ip))

            card_id = get_card(ip, service)
            print(f"{service} on {ip}")

            args = (ip, service, card_id)
            pool.apply_async(detailed_scan, args, {}, None, print)

    pool.close()
    pool.join()

if args.p:
    pool = multiprocessing.Pool(4)
    for ip in hosts:
        service = f"{args.p}/tcp"
        card_id = get_card(ip, service)
        args = (ip, service, card_id)
        pool.apply_async(detailed_scan, args, {}, None, print)
    pool.close()
    pool.join()
else:
    print("[PHASE 2] TOP1000 PORT SCAN")
    scan()

    print("[PHASE 3] FULL PORT SCAN")
    scan("-p", "-")
