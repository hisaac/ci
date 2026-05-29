# hisaac-ci

Ansible-first automation for provisioning macOS CI agents, with Tart VM support for local iteration.

## Overview

This repository provisions macOS hosts (VMs or physical machines) using Ansible roles and playbooks.

The current active stack is:

- Root-level Ansible project (`ansible.cfg`, `inventory/`, `playbooks/`, `roles/`)
- Dynamic Tart inventory (`inventory/tart_inventory.py`) for VM IP discovery at runtime
- Role-scoped reference scripts in `scripts/` used as implementation references and helpers
- Toolchain and workflow orchestration via `mise`

## Repository Structure

```text
.
├── ansible.cfg
├── requirements.yml
├── inventory/
│   ├── tart_inventory.py
│   └── group_vars/
│       ├── macos_agents.yml
│       ├── macos_15_agents.yml
│       ├── macos_26_agents.yml
│       ├── tart_agents.yml
│       └── orka_agents.yml
├── playbooks/
│   └── provision.yml
├── roles/
│   ├── xcode_clt/
│   ├── macos_updates/
│   ├── rosetta/
│   ├── ssh_config/
│   ├── system_config/
│   ├── auth_config/
│   ├── homebrew/
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
- Tart VMs prepared locally (if using dynamic Tart inventory)
- Pre-staged Xcode `.xip` and Simulator Runtime `.dmg` assets for the target OS version(s)

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

`ansible.cfg` points to `inventory/tart_inventory.py` as the default inventory.

- `inventory/tart_inventory.py` discovers VM IPs via `tart ip <vm_name>`
- Hosts are grouped into:
  - `macos_agents` (parent)
  - `tart_agents` (runtime Tart VM group)
  - version-specific groups like `macos_15_agents` and `macos_26_agents`

Primary variable files:

- `inventory/group_vars/macos_agents.yml`: shared settings (admin credentials, Homebrew base packages, Dock config)
- `inventory/group_vars/tart_agents.yml`: Tart-specific packages (`tart-guest-agent`)
- `inventory/group_vars/macos_15_agents.yml` and `inventory/group_vars/macos_26_agents.yml`: Xcode/runtime/simulator presets

## Xcode Cache Inputs

The `xcode` role installs all `*.xip` files found in the admin user's Downloads folder on the remote host. Stage the desired Xcode `.xip` files there before running provisioning — they will be deleted after installation.

## Provisioning

Run the full playbook:

```bash
ansible-playbook playbooks/provision.yml
```

Or run common role slices with tags:

```bash
ansible-playbook playbooks/provision.yml --tags xcode
ansible-playbook playbooks/provision.yml --tags homebrew
ansible-playbook playbooks/provision.yml --tags system_config
```

Playbook role order in `playbooks/provision.yml` is intentional:

1. `xcode_clt`
2. `macos_updates`
3. `rosetta`
4. `ssh_config`
5. `system_config`
6. `auth_config`
7. `homebrew`
8. `geerlingguy.mac.dock`
9. `xcode`
10. Spotlight re-index task
11. Reboot task

## Tart VM Workflow (Local)

`mise` includes helper tasks for local Tart loops:

- `mise run run-tart-vms`: starts configured VMs and waits for SSH readiness
- `mise run provision`: verifies Xcode/simruntime cache inputs, starts VMs, then runs `ansible-playbook playbooks/provision.yml`
- `mise run shutdown-tart-vms`: shuts down hosts in `tart_agents`
- `mise run refresh-tart-vms`: recreates local Tart VM clones from frozen images

Adjust VM names in:

- `inventory/tart_inventory.py` (`VMS` list)
- `mise.toml` (`tasks.run-tart-vms` and `tasks.refresh-tart-vms`)

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
