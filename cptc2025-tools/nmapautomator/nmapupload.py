"""
Uploads scanned Nmap ports to Planka.

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

import sys

import plankaportmanager

def main(argv: list[str]) -> int:
    
    planka_manager: plankaportmanager.PlankaPortManager = plankaportmanager.PlankaPortManager()
    planka_manager.upload_ports_from_sqlite()
    
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
