#!/usr/bin/env python3
"""
Dynamic inventory script for macOS VMs (Tart or Orka).

Set VM_PROVIDER to 'tart' or 'orka', and VM_NAME to the VM name.

Usage (Ansible calls these automatically):
  VM_PROVIDER=tart  VM_NAME=macos:26                   ./macos_inventory.py --list
  VM_PROVIDER=orka  VM_NAME=orka-mobile-agent-thmpm    ./macos_inventory.py --list
  VM_PROVIDER=tart  VM_NAME=macos:26                   ./macos_inventory.py --host <vm_name>
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
    )
    if result.returncode != 0:
        return None
    ip = result.stdout.strip()
    return {"ansible_host": ip} if ip else None


def get_orka_hostvars(vm_name: str) -> dict | None:
    result = subprocess.run(
        ["orka3", "vm", "list", "-o", "json"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"Error: orka3 vm list failed: {result.stderr}", file=sys.stderr)
        return None
    for vm in json.loads(result.stdout):
        if vm.get("name") == vm_name and vm.get("status") == "Running":
            return {"ansible_host": vm["ip"], "ansible_port": vm["ssh"]}
    return None


def list_inventory() -> dict:
    provider = os.environ.get("VM_PROVIDER", "").strip().lower()
    vm_name = os.environ.get("VM_NAME", "").strip()

    if not provider:
        print("Error: VM_PROVIDER environment variable is not set (tart or orka)", file=sys.stderr)
        sys.exit(1)
    if provider not in ("tart", "orka"):
        print(f"Error: VM_PROVIDER must be 'tart' or 'orka', got '{provider}'", file=sys.stderr)
        sys.exit(1)
    if not vm_name:
        print("Error: VM_NAME environment variable is not set", file=sys.stderr)
        sys.exit(1)

    get_hostvars = get_tart_hostvars if provider == "tart" else get_orka_hostvars
    hostvars = get_hostvars(vm_name)
    if not hostvars:
        print(f"Error: could not find running VM '{vm_name}'", file=sys.stderr)
        sys.exit(1)

    provider_group = f"{provider}_agents"
    return {
        "macos_agents": {"children": [provider_group]},
        provider_group: {"hosts": [vm_name]},
        "_meta": {"hostvars": {vm_name: hostvars}},
    }


def host_vars(vm_name: str) -> dict:
    provider = os.environ.get("VM_PROVIDER", "").strip().lower()
    get_hostvars = get_tart_hostvars if provider == "tart" else get_orka_hostvars
    return get_hostvars(vm_name) or {}


if __name__ == "__main__":
    if "--list" in sys.argv:
        print(json.dumps(list_inventory(), indent=2))
    elif "--host" in sys.argv:
        idx = sys.argv.index("--host")
        print(json.dumps(host_vars(sys.argv[idx + 1])))
    else:
        print(
            "Usage: VM_PROVIDER=<tart|orka> VM_NAME=<name> macos_inventory.py [--list | --host <name>]",
            file=sys.stderr,
        )
        sys.exit(1)
