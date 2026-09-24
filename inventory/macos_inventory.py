#!/usr/bin/env python3
"""
Dynamic inventory script for Tart VMs.

Set VM_NAME to the VM name.

Usage (Ansible calls these automatically):
        VM_NAME=macos:26 ./macos_inventory.py --list
        ./macos_inventory.py --host macos:26
"""

import json
import os
import subprocess
import sys


def get_tart_hostvars(vm_name: str) -> dict | None:
    result = subprocess.run(
        ["tart", "ip", vm_name],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return None
    ip = result.stdout.strip()
    return {"ansible_host": ip} if ip else None


def list_inventory() -> dict:
    vm_name = os.environ.get("VM_NAME", "").strip()

    if not vm_name:
        print("Error: VM_NAME environment variable is not set", file=sys.stderr)
        sys.exit(1)

    hostvars = get_tart_hostvars(vm_name)
    if not hostvars:
        print(f"Error: could not find running VM '{vm_name}'", file=sys.stderr)
        sys.exit(1)

    return {
        "macos_agents": {"hosts": [vm_name]},
        "_meta": {"hostvars": {vm_name: hostvars}},
    }


def host_vars(vm_name: str) -> dict:
    return get_tart_hostvars(vm_name) or {}


if __name__ == "__main__":
    if "--list" in sys.argv:
        print(json.dumps(list_inventory(), indent=2))
    elif "--host" in sys.argv:
        idx = sys.argv.index("--host")
        print(json.dumps(host_vars(sys.argv[idx + 1])))
    else:
        print(
            "Usage: VM_NAME=<name> macos_inventory.py [--list | --host <name>]",
            file=sys.stderr,
        )
        sys.exit(1)
