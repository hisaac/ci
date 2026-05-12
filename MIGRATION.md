# Migration: templates/ → Ansible roles + scripts/

The `templates/` directory contains bash scripts originally written for Packer-based macOS VM image baking. This document tracks their migration into Ansible roles for provisioning live agents/VMs.

Scripts are **not deleted** — they move to a top-level `scripts/` directory organized by role and serve as a readable, runnable reference implementation alongside the Ansible roles.

A script only moves to `scripts/` once its equivalent Ansible role/task is complete. The presence of a script in `scripts/` (and its absence from `templates/`) indicates that phase is done. `templates/` is deleted when it's empty.

---

## Target directory layout

```
scripts/
  rosetta/
    install-rosetta-2.bash
  ssh_config/
    configure-ssh-known-hosts.bash
  system_config/
    configure-system.bash
    configure-shell.bash
    cleanup-spotlight-index.bash
    disable-protected-services.bash
    disable-spctl.bash
    update-safari.bash
    wait-for-finder.bash
  auth_config/
    disable-screen-lock.bash
    enable-auto-login.bash
    enable-passwordless-sudo.bash
  homebrew/
    install-homebrew.bash
    install-homebrew-formulae.bash
    install-homebrew-casks.bash
  xcode_clt/
    install-xcode-command-line-tools.bash
  xcode/
    configure-xcode.bash
    install-cached-xcode-versions.bash
    install-developer-certificates.bash
    lib/
      xcode-utils.bash
    tests/
      test_xcode-utils.bash
  macos_updates/
    update-macos.bash
  shell_profile/
    .profile
    .bash_profile
    .bashrc
```

---

## Phase 1 — `rosetta` role

Converts `install-rosetta-2.bash`. Single command; pure YAML in Ansible.

**Script:** `scripts/rosetta/install-rosetta-2.bash`
**Role:** `ansible/roles/rosetta/`

- [ ] Create `ansible/roles/rosetta/tasks/main.yml`
  - `ansible.builtin.command: softwareupdate --install-rosetta --agree-to-license`
  - Guard with `when: ansible_facts['architecture'] == 'arm64'`
  - Idempotency: skip if already installed
- [ ] Add play to `ansible/playbooks/provision.yml`
- [ ] Move `templates/scripts/install-rosetta-2.bash` → `scripts/rosetta/`
- [ ] Verify: `hk check --all` passes

---

## Phase 2 — `ssh_config` role

Converts `configure-ssh-known-hosts.bash` (adds GitHub SSH host keys to `~/.ssh/known_hosts`).

**Script:** `scripts/ssh_config/configure-ssh-known-hosts.bash`
**Role:** `ansible/roles/ssh_config/`

- [ ] Create `ansible/roles/ssh_config/tasks/main.yml`
  - `ansible.builtin.known_hosts` for each key (ed25519, ECDSA, RSA)
- [ ] Add play to `ansible/playbooks/provision.yml`
- [ ] Move `templates/scripts/configure-ssh-known-hosts.bash` → `scripts/ssh_config/`
- [ ] Verify: `hk check --all` passes

---

## Phase 3 — `system_config` role

Largest migration. Covers: `configure-system.bash`, `disable-protected-services.bash`,
`disable-spctl.bash`, `configure-shell.bash`, `cleanup-spotlight-index.bash`,
`update-safari.bash`, `wait-for-finder.bash`.

**Scripts:** `scripts/system_config/`
**Role:** `ansible/roles/system_config/`

**Note:** `configure-system.bash` has ~80 `defaults write` calls. Audit each for CI VM relevance before migrating — flag uncertain settings for review rather than silently dropping.

- [ ] Audit `configure-system.bash` — mark each setting keep/drop/query
- [ ] Create `ansible/roles/system_config/tasks/main.yml` (orchestrator)
- [ ] Create `ansible/roles/system_config/tasks/preferences.yml`
  - `community.general.osx_defaults` tasks from `configure-system.bash`
- [ ] Create `ansible/roles/system_config/tasks/services.yml`
  - `launchctl` tasks from `disable-protected-services.bash`
  - `spctl` task from `disable-spctl.bash`
- [ ] Create `ansible/roles/system_config/tasks/shell.yml`
  - `ansible.builtin.user: shell: /bin/bash` from `configure-shell.bash`
- [ ] Create `ansible/roles/system_config/tasks/spotlight.yml`
  - `mdutil` + async wait from `cleanup-spotlight-index.bash`
- [ ] Add Safari update task (`softwareupdate`) and Finder wait task
- [ ] Create `ansible/roles/system_config/vars/main.yml` for key lists
- [ ] Add play to `ansible/playbooks/provision.yml`
- [ ] Move scripts to `scripts/system_config/`:
  - `templates/scripts/configure-system.bash`
  - `templates/scripts/configure-shell.bash`
  - `templates/scripts/cleanup-spotlight-index.bash`
  - `templates/scripts/disable-protected-services.bash`
  - `templates/scripts/disable-spctl.bash`
  - `templates/scripts/update-safari.bash`
  - `templates/scripts/wait-for-finder.bash`
- [ ] Verify: `hk check --all` passes

---

## Phase 4 — `auth_config` role

Covers `enable-passwordless-sudo.bash`, `enable-auto-login.bash`, `disable-screen-lock.bash`.
Uses existing `macos_admin_user` / `macos_admin_password` group vars.

**Scripts:** `scripts/auth_config/`
**Role:** `ansible/roles/auth_config/`

- [ ] Create `ansible/roles/auth_config/tasks/main.yml` (orchestrator)
- [ ] Create `ansible/roles/auth_config/tasks/sudo.yml`
  - `ansible.builtin.template` → `/etc/sudoers.d/{{ macos_admin_user }}`
  - `validate: /usr/sbin/visudo -cf %s`
- [ ] Create `ansible/roles/auth_config/tasks/auto_login.yml`
  - XOR password logic is complex — keep as `ansible.builtin.script`
- [ ] Create `ansible/roles/auth_config/tasks/screen_lock.yml`
  - `ansible.builtin.command: sysadminctl -screenLock off -password ...`
- [ ] Add play to `ansible/playbooks/provision.yml`
- [ ] Move scripts to `scripts/auth_config/`:
  - `templates/scripts/enable-passwordless-sudo.bash`
  - `templates/scripts/enable-auto-login.bash`
  - `templates/scripts/disable-screen-lock.bash`
- [ ] Verify: `hk check --all` passes

---

## Phase 5 — `homebrew` role

Wraps `geerlingguy.mac.homebrew` (already in `requirements.yml`).
`group_vars/macos_agents.yml` already has `homebrew_installed_packages` and `homebrew_taps`.

**Scripts:** `scripts/homebrew/` (reference only — Ansible uses the galaxy role)
**Role:** `ansible/roles/homebrew/`

- [ ] Create `ansible/roles/homebrew/tasks/main.yml`
  - `ansible.builtin.import_role: name: geerlingguy.mac.homebrew`
- [ ] Add `homebrew_cask_apps` to `group_vars/macos_agents.yml` if casks are needed
- [ ] Add play to `ansible/playbooks/provision.yml` (after `auth_config`)
- [ ] Move scripts to `scripts/homebrew/`:
  - `templates/scripts/install-homebrew.bash`
  - `templates/scripts/install-homebrew-formulae.bash`
  - `templates/scripts/install-homebrew-casks.bash`
- [ ] Verify: `hk check --all` passes

---

## Phase 6 — `xcode` role

Covers `configure-xcode.bash`, `install-developer-certificates.bash`,
`install-cached-xcode-versions.bash` + `lib/xcode-utils.bash`.

`install-cached-xcode-versions.bash` and `xcode-utils.bash` are complex enough to keep as scripts;
Ansible copies and runs them via `ansible.builtin.script`.

**Scripts:** `scripts/xcode/`
**Role:** `ansible/roles/xcode/`

- [ ] Create `ansible/roles/xcode/tasks/main.yml` (orchestrator)
- [ ] Create `ansible/roles/xcode/tasks/configure.yml`
  - `community.general.osx_defaults` tasks from `configure-xcode.bash`
- [ ] Create `ansible/roles/xcode/tasks/certificates.yml`
  - `ansible.builtin.get_url` for Apple WWDR + Developer ID certs
  - `ansible.builtin.command: security import ...`
- [ ] Create `ansible/roles/xcode/tasks/install.yml`
  - `ansible.builtin.script` calling `install-cached-xcode-versions.bash`
- [ ] Add play to `ansible/playbooks/provision.yml`
- [ ] Move scripts to `scripts/xcode/`:
  - `templates/scripts/configure-xcode.bash`
  - `templates/scripts/install-developer-certificates.bash`
  - `templates/scripts/install-cached-xcode-versions.bash`
  - `templates/scripts/lib/xcode-utils.bash` → `scripts/xcode/lib/`
  - `templates/scripts/tests/test_xcode-utils.bash` → `scripts/xcode/tests/`
- [ ] Verify: `hk check --all` passes

---

## Phase 7 — Finalize

Wire everything together and verify end-to-end.

Final play order in `provision.yml`:
```
xcode_clt → rosetta → ssh_config → system_config → auth_config → homebrew → macos_updates → xcode
```

- [ ] Confirm `provision.yml` play order is correct
- [ ] Move remaining scripts not yet migrated:
  - `templates/scripts/install-xcode-command-line-tools.bash` → `scripts/xcode_clt/`
  - `templates/scripts/update-macos.bash` → `scripts/macos_updates/`
  - `templates/data/` → `scripts/shell_profile/`
- [ ] Delete `templates/` (should now be empty)
- [ ] Update `.shellcheckrc` source paths if needed after moves
- [ ] Run `mise run provision` against a fresh Tart VM
- [ ] Spot-check each role's effect on the VM
