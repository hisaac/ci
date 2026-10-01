# hisaac-ci

Build the macOS 27 VM in two stages on a Mac with macOS 27 and Tart installed:

```sh
mise run build:base
mise run build:boot
```

`build:base` installs macOS from the IPSW into `macos-27-01-base`, creates the
admin account, enables automatic login and SSH, and waits for SSH to become
available. It then waits for Spotlight metadata power assertions to remain
absent for 60 seconds, failing if they do not settle within 15 minutes. This is
an indexing-idle heuristic, not proof that every item is indexed. It does not
run the UI boot commands.

`build:boot` clones `macos-27-01-base` into `macos-27-02-ci-gui`, runs the boot commands
from `src/templates/macos-27-02-ci-gui.pkr.hcl`, and checks keyboard navigation,
Gatekeeper, and Screen Sharing. The base VM is preserved for future attempts.

To troubleshoot, edit the boot template and rerun only `mise run build:boot`.
If the previous attempt left a `macos-27-02-ci-gui` VM, stop it if it is running
and delete that clone before retrying:

```sh
tart stop macos-27-02-ci-gui
tart delete macos-27-02-ci-gui
mise run build:boot
```

All build tasks use Packer's `-on-error=ask` to allow inspection after a failure.
Packer debug logging is enabled for all commands in these tasks, writing to
`.logs/packer-base.log`, `.logs/packer-boot.log`, `.logs/packer-recovery.log`,
and `.logs/packer-ssh.log`. Each task creates `.logs/` before running Packer.
Each Packer invocation replaces its task's log, so the build log remains after
a normal task run. The `.logs/` directory is ignored by Git.
The default username and password are both `admin`. When invoking Packer
directly, build each template file separately. For a differently named base VM,
set `vm_base_name` on the boot build to match the base build's `vm_name`.
