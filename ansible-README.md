# ansible-macos-ci

Ansible playbook for provisioning macOS CI build agents.

## Structure

```
.
├── ansible.cfg                         # Ansible configuration
├── requirements.yml                    # External role dependencies
├── inventory/
│   ├── hosts.yml                       # Agent host definitions
│   └── group_vars/
│       └── macos_agents.yml            # Shared variables for all agents
├── playbooks/
│   └── provision.yml                   # Main playbook
├── roles/
│   ├── bootstrap/                      # Raw/script tasks — no Python needed
│   │   ├── tasks/main.yml
│   │   └── scripts/
│   │       ├── install-clt.sh          # Installs Xcode Command Line Tools
│   │       └── install-homebrew.sh     # Installs Homebrew
│   ├── xcode/                          # Installs and configures Xcode
│   │   ├── tasks/main.yml
│   │   └── defaults/main.yml
│   └── ci_agent/                       # CI agent user, config, and service
│       ├── tasks/main.yml
│       ├── defaults/main.yml
│       ├── handlers/main.yml
│       ├── templates/
│       │   └── agent-config.yml.j2
│       └── files/
└── galaxy_roles/                       # External roles (gitignored)
```

## Setup

1. Install external roles:
   ```bash
   ansible-galaxy install --roles-path ./galaxy_roles --role-file requirements.yml
   ```

2. Update `inventory/hosts.yml` with your agent IPs.

3. Update `inventory/group_vars/macos_agents.yml` with your config.

4. Set your Xcode installer path in `roles/xcode/defaults/main.yml`.

5. Run the playbook:
   ```bash
   ansible-playbook playbooks/provision.yml --ask-become-pass
   ```

## Notes

- `bootstrap` role uses `raw` and `script` modules only — safe to run on a
  fresh macOS VM with no Python installed.
- All subsequent roles require Python, which is available after bootstrap
  via Xcode CLT.
- Xcode must be pre-staged (network share, S3, etc.) — it can't be
  downloaded non-interactively from Apple.
- Sensitive values (tokens, passwords) should be stored in Ansible Vault,
  not in plaintext in group_vars.
