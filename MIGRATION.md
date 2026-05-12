# Migration: templates/ → Ansible roles + scripts/

The `templates/` directory contains bash scripts originally written for Packer-based macOS VM image baking. This document tracks their migration into Ansible roles for provisioning live agents/VMs.

Scripts are **not deleted** — they move to a top-level `scripts/` directory organized by role and serve as a readable, runnable reference implementation alongside the Ansible roles.

A script only moves to `scripts/` once its equivalent Ansible role/task is complete. The presence of a script in `scripts/` (and its absence from `templates/`) indicates that phase is done. `templates/` is deleted when it's empty.

---

## Current directory layout

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

## ✅ Phase 1 — `rosetta` role

**Script:** `scripts/rosetta/install-rosetta-2.bash`
**Role:** `ansible/roles/rosetta/`

Checks if Rosetta 2 is installed via `arch -arch x86_64 /usr/bin/true`, installs via
`softwareupdate --install-rosetta --agree-to-license` if not. Skipped on non-arm64 hosts.

---

## ✅ Phase 2 — `ssh_config` role

**Script:** `scripts/ssh_config/configure-ssh-known-hosts.bash`
**Role:** `ansible/roles/ssh_config/`

Adds GitHub's three SSH host keys (ed25519, ECDSA, RSA) to `~/.ssh/known_hosts` via
`ansible.builtin.known_hosts`. Idempotent.

---

## ✅ Phase 3 — `system_config` role

**Scripts:** `scripts/system_config/`
**Role:** `ansible/roles/system_config/`

Structured as an orchestrator (`main.yml`) importing seven task files:

- `preferences.yml` — all `defaults write` settings via `community.general.osx_defaults`
- `power.yml` — individual `pmset` tasks, `systemsetup`, `tmutil`, sleep image removal
- `services.yml` — `launchctl bootout` for notification center, Tips, Time Machine, analytics, apsd
- `shell.yml` — sets `/bin/bash` as shell for admin user and root via `ansible.builtin.user`
- `spotlight.yml` — erases Spotlight indexes, polls logs for completion (up to 6 min)
- `gatekeeper.yml` — disables Gatekeeper, enables Terminal developer mode
- `safari.yml` — installs Safari update via `softwareupdate`

`services.yml` and `gatekeeper.yml` are gated behind a SIP check (`csrutil status`) and
skipped if SIP is enabled. `wait-for-finder.bash` has no Ansible equivalent (Packer-only).

---

## ✅ Phase 4 — `auth_config` role

**Scripts:** `scripts/auth_config/`
**Role:** `ansible/roles/auth_config/`

- `sudo.yml` — writes `/etc/sudoers.d/{{ macos_admin_user }}-nopasswd` via
  `ansible.builtin.template`, validated with `visudo`
- `auto_login.yml` — runs `enable-auto-login.bash` via `ansible.builtin.script`
  (XOR kcpassword cipher logic kept as script)
- `screen_lock.yml` — `sysadminctl -screenLock off`

**Open:** idempotency checks not yet implemented for auto-login and screen lock.

---

## ✅ Phase 5 — `homebrew` role

**Scripts:** `scripts/homebrew/` (reference only)
**Role:** `ansible/roles/homebrew/`

Wraps `geerlingguy.mac.homebrew`. Combines `homebrew_base_packages` (defined in
`group_vars/macos_agents.yml`) with `homebrew_platform_packages` (defined per platform
group) before calling the galaxy role. Platform groups are children of `macos_agents`:

- `tart_agents` — adds `tart-guest-agent`
- `orka_agents` (future) — will add the Orka equivalent

---

## ✅ Phase 6 — `xcode` role

**Scripts:** `scripts/xcode/`
**Role:** `ansible/roles/xcode/`

- `configure.yml` — Xcode/XCTest/Simulator preferences via `community.general.osx_defaults`
- `certificates.yml` — downloads and imports Apple WWDR CA G3 and Developer ID G2 CA certs
- `install.yml` — finds `.xip` files in `.cache/xcode/` on the control node; skips if empty,
  otherwise copies to remote, runs `install-cached-xcode-versions.bash`, cleans up
- `sdks.yml` — finds `.dmg` simulator runtime files in `.cache/simruntime/`; installs via
  `xcrun simctl runtime add`, cleans up

Populate `.cache/xcode/` and `.cache/simruntime/` on the control node before running the
playbook. Both directories are gitignored.

---

## ⏳ Phase 7 — Finalize

- [ ] Run the full playbook against a fresh Tart VM end-to-end
- [ ] Spot-check each role's effect on the VM
- [ ] Add idempotency to `auth_config` tasks (auto-login, screen lock)
- [ ] Add simulator pre-warming after Xcode install

---

## Open items

- **Simulator pre-warming** — no tasks to boot simulators after install; the first CI job on a
  freshly provisioned agent will pay a significant cold-start cost
- **Xcode/SDK version pinning** — currently installs whatever is in `.cache/`; no mechanism
  yet to specify which versions are required
