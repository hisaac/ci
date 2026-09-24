# hisaac-ci

Ansible-first automation for provisioning macOS 26 CI agents using Tart for VM management.

## Overview

This repository provisions macOS 26 (Tahoe) Tart VMs using Ansible roles and playbooks. Other macOS versions are not supported; provisioning assumes the guest already runs macOS 26.

The current active stack is:

- Root-level Ansible project (`ansible.cfg`, `inventory/`, `playbooks/`, `roles/`)
- Dynamic Tart inventory (`inventory/macos_inventory.py`) for VM IP discovery at runtime
- Role-scoped reference scripts in `scripts/` used as implementation references and helpers
- Toolchain and workflow orchestration via `mise`

## Repository Structure

```text
.
├── ansible.cfg
├── requirements.yml
├── inventory/
│   ├── macos_inventory.py
│   └── group_vars/
│       └── macos_agents.yml
├── playbooks/
│   └── provision.yml
├── roles/
│   ├── xcode_clt/
│   ├── macos_updates/
│   ├── rosetta/
│   ├── ssh_config/
│   ├── system_config/
│   ├── auth_config/
│   └── xcode/
├── scripts/
│   ├── xcode/
│   ├── xcode_clt/
│   ├── homebrew/
│   ├── system_config/
│   ├── auth_config/
│   ├── ssh_config/
│   ├── rosetta/
│   └── macos_updates/
├── mise.toml
└── pyproject.toml
```

## Prerequisites

- macOS host for Tart-based workflows
- [mise](https://mise.jdx.dev)
- macOS 26 Tart VMs prepared locally
- Pre-staged Xcode `.xip` and Simulator Runtime `.dmg` assets for the configured Xcode and iOS versions

## Setup

Run commands from the repository root.

1. Install toolchain from `mise.toml`:

	```bash
	mise install
	```

2. Bootstrap Python/Ansible dependencies and Galaxy content:

	```bash
	mise run bootstrap
	```

	This installs:

	- Python dependencies from `pyproject.toml` (`ansible-core`, `ansible-lint`, `paramiko`)
	- Roles and collections from `requirements.yml`

## Inventory and Variables

Pass `-i inventory/macos_inventory.py` and set `VM_NAME` to the Tart VM to provision.

- `inventory/macos_inventory.py` discovers the VM IP via `tart ip <vm_name>`
- The VM belongs directly to `macos_agents`
- All agents use the same macOS 26 configuration; there is no OS-version selection or per-version preset loading
- macOS updates are restricted to 26.x; provisioning does not upgrade guests to a newer major release

`inventory/group_vars/macos_agents.yml` contains all agent settings: admin credentials, Homebrew packages including `tart-guest-agent`, the `openai/tools` tap, Dock config, and Xcode/runtime/simulator presets.

## Xcode Cache Inputs

The `xcode` role installs all `*.xip` files found in the admin user's Downloads folder on the remote host. Stage the desired Xcode `.xip` files there before running provisioning — they will be deleted after installation.

## Provisioning

Run the full playbook:

```bash
VM_NAME=macos:26 ansible-playbook playbooks/provision.yml -i inventory/macos_inventory.py
```

Or run common role slices with tags:

```bash
VM_NAME=macos:26 ansible-playbook playbooks/provision.yml -i inventory/macos_inventory.py --tags xcode
VM_NAME=macos:26 ansible-playbook playbooks/provision.yml -i inventory/macos_inventory.py --tags homebrew
VM_NAME=macos:26 ansible-playbook playbooks/provision.yml -i inventory/macos_inventory.py --tags system_config
```

Playbook role order in `playbooks/provision.yml` is intentional:

1. `xcode_clt`
2. `macos_updates`
3. `rosetta`
4. `ssh_config`
5. `system_config`
6. `auth_config`
7. `geerlingguy.mac.homebrew`
8. `geerlingguy.mac.dock`
9. `xcode`
10. Spotlight re-index task
11. Reboot task

## Tart VM Workflow (Local)

`mise` includes helper tasks for local Tart loops:

- `mise run run-tart-vm macos:26`: starts the named Tart VM and waits for SSH readiness
- `mise run provision macos:26`: starts the named Tart VM, then runs the provisioning playbook

Replace `macos:26` with your local macOS 26 Tart VM name. The name identifies the VM; it does not select an OS version.

## Linting and Formatting

This repo uses `hk` and `mise` task aliases:

```bash
mise run chk   # lint/check
mise run fmt   # auto-fix formatting and supported lint issues
```

`chk` includes `ansible-lint`, `shellcheck`, `shfmt`, `ruff`, `yamlfmt`, and additional utility checks defined in `hk.pkl`.

## Shell Script Tests

Xcode utility script tests can be run directly on macOS:

```bash
bash scripts/xcode/tests/test_xcode-utils.bash
```

## References

- https://github.com/timsutton/osx-vm-templates
- https://github.com/boxcutter/macos
- https://github.com/cirruslabs/macos-image-templates
- https://github.com/actions/runner-images
- https://github.com/torarnv/tart-image-bakery
- https://gist.github.com/aessam/aa9c32af6900123277c36d4d0ac7f73d#9d-skip-setup-assistant--6-layers
