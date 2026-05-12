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
    # "macos:15",
    "macos:26",
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
    os_major_groups = {}

    for vm in VMS:
        ip = get_ip(vm)
        if ip:
            reachable_hosts.append(vm)
            hostvars[vm] = {"ansible_host": ip}

            # Group hosts by macOS major version (e.g. macos_15_agents).
            # This allows version-specific presets via group_vars.
            vm_parts = vm.split(":", 1)
            if len(vm_parts) == 2:
                major = vm_parts[1].split(".", 1)[0]
                group_name = f"macos_{major}_agents"
                os_major_groups.setdefault(group_name, []).append(vm)
        else:
            print(f"Warning: could not get IP for VM '{vm}' — skipping", file=sys.stderr)

    inventory = {
        PARENT_GROUP: {
            "children": [GROUP, *sorted(os_major_groups.keys())],
        },
        GROUP: {
            "hosts": reachable_hosts,
        },
        "_meta": {
            "hostvars": hostvars,
        },
    }

    for group_name, hosts in os_major_groups.items():
        inventory[group_name] = {"hosts": hosts}

    return inventory


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
