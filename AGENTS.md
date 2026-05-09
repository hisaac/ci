# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repo experiments with building macOS VM images for CI/CD pipelines. The two active components are:

- **`templates/`** — Bash scripts sourced/run inside Packer/Tart VM images to configure macOS
- **`ansible/`** — Ansible playbook for provisioning macOS CI build agents (physical hardware or VMs)

Packer `.hcl` templates and older `mise` tasks have been deleted; the current focus is Ansible-managed provisioning of agents running Tart VMs.

## Tooling

Dependencies are managed with [mise](https://mise.jdx.dev). Tools in use: `packer`, `tart`, `ansible`, `python`, `jq`, `tombi`.

```bash
mise install          # install all tools from mise.toml
mise run upd          # upgrade tools within current version constraints (mise upgrade + mise lock)
mise run upg          # bump tool versions (mise upgrade --bump + mise lock)
```

## Ansible

All commands run from the `ansible/` directory (or rely on `ansible.cfg` there).

```bash
# Install external roles/collections (required once, output to gitignored galaxy_roles/)
ansible-galaxy install --roles-path ./galaxy_roles --role-file requirements.yml

# Run the full provisioning playbook
ansible-playbook playbooks/provision.yml --ask-become-pass

# Lint
ansible-lint playbooks/provision.yml
```

**Playbook order matters:** `bootstrap` runs first using only `raw`/`script` modules (no Python required) to install Xcode CLT and Homebrew. All subsequent roles (`geerlingguy.mac.homebrew`, `xcode`, `ci_agent`) require Python, which is available after bootstrap via Xcode CLT.

**Before running:** update `inventory/hosts.yml` with agent IPs, `inventory/group_vars/macos_agents.yml` with config, and `roles/xcode/defaults/main.yml` with the path to a pre-staged Xcode installer (Xcode cannot be downloaded non-interactively from Apple).

Sensitive values (tokens, vault passwords) go in Ansible Vault — the local vault password file `.vault_pass` is gitignored.

## Shell Scripts (`templates/scripts/`)

Scripts are Bash, targeting macOS exclusively. They are designed to run inside Tart VMs during image baking.

- `lib/xcode-utils.bash` — shared Xcode utility functions (install, select, normalize version, simulator management)
- `tests/test_xcode-utils.bash` — lightweight test runner (no framework; run directly on a macOS host with Xcode installed)

Run tests:
```bash
bash templates/scripts/tests/test_xcode-utils.bash
```

ShellCheck is configured via `.shellcheckrc`:
- `external-sources=true` (suppress source warnings)
- SC2096 disabled (macOS allows multi-word shebangs)
- SC2154 disabled (variables injected by `usage`)

## Code Style

- **Indentation:** tabs for all files; 2-space indent for `.yml`/`.yaml`/`.hcl` (enforced by `.editorconfig`)
- **Bash:** `#!/bin/bash -euo pipefail` or `#!/bin/bash` depending on the script; `local -r` for readonly locals; subshells via `()` function bodies when directory isolation is needed; prefer long-form flags when available (e.g. `--verbose` over `-v`) — note that macOS BSD tools (`tail`, `cut`, `rm`, etc.) often lack long options, so short flags are acceptable there
- **Ansible:** use fully-qualified module names (e.g. `ansible.builtin.command`); `become: true` only where needed
