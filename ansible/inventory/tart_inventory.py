#!/usr/bin/env python3
"""
Dynamic inventory script for Tart VMs.

Resolves each VM's IP address at runtime via `tart ip <name>` and
emits the Ansible inventory JSON format.

Usage (Ansible calls these automatically):
  ./tart_inventory.py --list
  ./tart_inventory.py --host <vm_name>
"""

import json
import subprocess
import sys

# Names of the Tart VMs to manage
VMS = [
    "macos:15",
    # "macos:26",
]

GROUP = "tart_agents"
PARENT_GROUP = "macos_agents"


def get_ip(vm_name: str) -> str | None:
    result = subprocess.run(
        ["tart", "ip", vm_name],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def list_inventory() -> dict:
    hostvars = {}
    reachable_hosts = []

    for vm in VMS:
        ip = get_ip(vm)
        if ip:
            reachable_hosts.append(vm)
            hostvars[vm] = {"ansible_host": ip}
        else:
            print(f"Warning: could not get IP for VM '{vm}' — skipping", file=sys.stderr)

    return {
        PARENT_GROUP: {
            "children": [GROUP],
        },
        GROUP: {
            "hosts": reachable_hosts,
        },
        "_meta": {
            "hostvars": hostvars,
        },
    }


def host_vars(vm_name: str) -> dict:
    ip = get_ip(vm_name)
    return {"ansible_host": ip} if ip else {}


if __name__ == "__main__":
    if "--list" in sys.argv:
        print(json.dumps(list_inventory(), indent=2))
    elif "--host" in sys.argv:
        idx = sys.argv.index("--host")
        print(json.dumps(host_vars(sys.argv[idx + 1])))
    else:
        print("Usage: tart_inventory.py [--list | --host <name>]", file=sys.stderr)
        sys.exit(1)
