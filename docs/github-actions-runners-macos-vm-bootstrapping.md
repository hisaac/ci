# macOS VM Bootstrapping: How GitHub Actions Runner Images Work

This document explains how macOS virtual machines are bootstrapped for GitHub Actions runners. The VMs are not truly headless — they boot into a full GUI session — but are configured so that no human interaction is ever required. This enables unattended UI automation, Xcode testing, and job provisioning.

---

## Virtualization Platform: Anka by Veertu

macOS images use [Anka](https://veertu.com/anka-build/) virtualization (unlike Windows/Ubuntu which use Azure + Packer). The Packer templates use the `veertu-anka-vm-clone` plugin to clone a base VM, provision it via SSH, then save the result as a new image.

**Relevant files:**

- `images/macos/templates/macOS-15.anka.pkr.hcl` — Packer template for macOS 15 (Intel)
- `images/macos/templates/macOS-15.arm64.anka.pkr.hcl` — Packer template for macOS 15 (Apple Silicon)
- Similar files exist for macOS 14 and macOS 26.

**How it works:**

The Packer `veertu-anka-vm-clone` source block clones an existing base Anka VM (specified by `source_vm_name`), configures CPU/RAM, then provisions it through a sequence of file uploads and shell scripts executed over SSH. After provisioning, the VM is stopped and the image is saved.

```hcl
source "veertu-anka-vm-clone" "template" {
  vm_name        = "${var.build_id}"
  source_vm_name = "${var.source_vm_name}"
  source_vm_tag  = "${var.source_vm_tag}"
  vcpu_count     = "${var.vcpu_count}"
  ram_size       = "${var.ram_size}"
  stop_vm        = "true"
}
```

---

## Automatic GUI Login (No Lock Screen)

**Relevant files:**

- `images/macos/scripts/build/configure-autologin.sh`
- `images/macos/assets/bootstrap-provisioner/kcpassword.py`
- `images/macos/assets/bootstrap-provisioner/setAutoLogin.sh`

**What it does:**

Configures the VM to boot directly into a logged-in desktop session without showing a login screen.

**How it works:**

macOS supports automatic login via an XOR-encoded password file at `/etc/kcpassword`. The `kcpassword.py` script encodes the VM user's password using Apple's known 11-byte XOR cipher and writes the result to that file. Then `com.apple.loginwindow` preferences are set:

```bash
python3 $HOME/bootstrap/kcpassword.py "$PASSWORD"
/usr/bin/defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser "$USERNAME"
/usr/bin/defaults write /Library/Preferences/com.apple.loginwindow autoLoginUserScreenLocked -bool false
```

**Why:**

The VM must boot into an active GUI session because:
1. WindowServer must be running for UI tests (XCUITest, Simulator, etc.)
2. Many macOS developer tools assume a logged-in session
3. The provisioner agent needs access to the Aqua session to drive automation

---

## UI Automation Without Authentication (`automationmodetool`)

**Relevant file:**

- `images/macos/scripts/build/configure-machine.sh` (lines 55–94)

**What it does:**

Enables Apple's XCTest UI automation framework to operate without requiring user authentication prompts at runtime.

**How it works:**

The script uses `expect` (an interactive automation tool) to feed the admin password to `automationmodetool`:

```bash
/usr/bin/expect <<EOF
    spawn automationmodetool enable-automationmode-without-authentication
    expect "password"
    send "${PASSWORD}\r"
    expect {
        "succeeded." { puts "Automation mode enabled successfully"; exit 0 }
        eof
    }
EOF
```

It then verifies the mode is active:

```bash
if [[ ! "$(automationmodetool)" =~ "DOES NOT REQUIRE" ]]; then
    echo "Failed to enable enable-automationmode-without-authentication option"
    exit 1
fi
```

**Why:**

Without this, every XCUITest run would trigger a system dialog asking the user to authenticate. In an unattended CI environment, that dialog would block forever and fail the job.

---

## System Integrity Protection (SIP) Disabled

**Relevant file:**

- `images/macos/scripts/build/configure-machine.sh` (lines 26–30)

**What it does:**

The VMs run with SIP disabled. The script checks for this condition (`csrutil status: disabled|unknown`) before performing privileged operations.

**How it works:**

SIP is disabled at the Anka VM level (before image provisioning begins — it's a property of the base VM). The provisioning scripts detect this state and take advantage of it:

```bash
if csrutil status | grep -Eq "System Integrity Protection status: (disabled|unknown)"; then
    sudo bash -c 'echo -n "a" > /private/var/db/Accessibility/.VoiceOverAppleScriptEnabled'
fi
```

**Why:**

SIP must be disabled to:
- Directly write to the TCC privacy database (bypassing consent dialogs)
- Write to protected system directories (`/private/var/db/Accessibility/`)
- Unload system LaunchDaemons
- Grant accessibility permissions to arbitrary binaries

---

## Pre-populated TCC Database (Permission Pre-granting)

**Relevant files:**

- `images/macos/scripts/build/configure-tccdb-macos.sh`
- `images/macos/scripts/helpers/utils.sh` (lines 137–149)

**What it does:**

Directly injects rows into macOS's Transparency, Consent, and Control (TCC) SQLite databases, pre-granting every permission that the runner and provisioner will need — without any user-facing dialog ever appearing.

**How it works:**

The helper functions write directly to the TCC databases:

```bash
configure_system_tccdb () {
    local values=$1
    local dbPath="/Library/Application Support/com.apple.TCC/TCC.db"
    local sqlQuery="INSERT OR IGNORE INTO access VALUES($values);"
    sudo sqlite3 "$dbPath" "$sqlQuery"
}

configure_user_tccdb () {
    local values=$1
    local dbPath="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
    local sqlQuery="INSERT OR IGNORE INTO access VALUES($values);"
    sqlite3 "$dbPath" "$sqlQuery"
}
```

**Permissions granted include:**

| Service | Granted To | Purpose |
|---------|-----------|---------|
| `kTCCServiceAccessibility` | `/bin/bash`, `/usr/bin/osascript`, provisioner, Terminal | Drive UI elements programmatically |
| `kTCCServiceScreenCapture` | `/bin/bash`, provisioner, Terminal | Capture screenshots for debugging |
| `kTCCServiceAppleEvents` | bash, osascript, sshd, provisioner | Inter-process communication (AppleScript) |
| `kTCCServiceSystemPolicyAllFiles` | bash, sshd, provisioner, Terminal | Full disk access |
| `kTCCServicePostEvent` | Anka addons, provisioner | Synthetic keyboard/mouse input |
| `kTCCServiceMicrophone` | provisioner, Simulator | Audio device access for tests |
| `kTCCServiceBluetoothAlways` | provisioner | Bluetooth access for tests |

**Why:**

On a normal Mac, each of these permissions triggers a system dialog the first time an app requests access. In CI, those dialogs would block indefinitely. By pre-populating the database (only possible with SIP disabled), all permissions are silently granted.

---

## Aggressive Service/Daemon Stripping

**Relevant file:**

- `images/macos/scripts/build/configure-system.sh`

**What it does:**

Unloads and disables system services that would waste CPU, trigger unexpected UI, or interfere with test reliability.

**Services disabled:**

```bash
# Notification center — can overlay UI and interfere with tests
launchctl unload -w /System/Library/LaunchAgents/com.apple.notificationcenterui.plist

# Analytics/diagnostics — wastes CPU and network
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.SubmitDiagInfo.plist

# Time Machine — disk I/O interference
sudo tmutil disable
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.backupd.plist

# Apple Push Notification Service — unnecessary in CI
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.apsd.plist

# Performance/Power Management — CPU overhead
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.PerfPowerServices.plist
```

**Additional optimizations:**

```bash
# Disable animations and transparency (faster UI, less GPU load)
defaults write com.apple.universalaccess reduceMotion -bool true
defaults write com.apple.universalaccess reduceTransparency -bool true

# Set solid black wallpaper (avoids dynamic wallpaper CPU usage)
osascript -e 'tell application "Finder" to set desktop picture to POSIX file "/System/Library/Desktop Pictures/Solid Colors/Black.png"'

# Close all Finder windows (can interfere with UI tests)
close_finder_window
```

**Why:**

Every unnecessary service is a potential source of:
- Non-deterministic test failures (unexpected windows/dialogs)
- CPU/disk contention (slows builds and tests)
- Network traffic (unnecessary connections)

---

## Sleep and Power Management Disabled

**Relevant file:**

- `images/macos/scripts/build/configure-machine.sh` (lines 13–20)

**What it does:**

Ensures the VM never sleeps, hibernates, or dims the display.

```bash
# Disable hibernation and remove sleep image
sudo pmset -a hibernatemode 0
sudo rm -f /var/vm/sleepimage

# Disable all sleep modes
sudo pmset -a sleep 0 disksleep 0 displaysleep 0

# Disable App Nap system-wide
defaults write NSGlobalDomain NSAppSleepDisabled -bool YES
```

**Why:**

A sleeping VM would be unresponsive to SSH commands and job requests. App Nap could throttle background processes (like build tools or test runners) if macOS decides they're "inactive."

---

## Automatic Software Updates Disabled

**Relevant file:**

- `images/macos/scripts/build/configure-auto-updates.sh`

```bash
sudo softwareupdate --schedule off
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 0
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 0
defaults write com.apple.commerce AutoUpdate -bool false
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false
```

**Why:**

Automatic updates would:
- Change the installed software unexpectedly (breaking reproducibility)
- Consume bandwidth and CPU during jobs
- Potentially trigger restart prompts

---

## Provisioner Agent Installation

**Relevant files:**

- `images/macos/assets/bootstrap-provisioner/installNewProvisioner.sh`
- `images/macos/assets/bootstrap-provisioner/change_password`

**What it does:**

Installs a **provisioner agent** binary at `/usr/local/opt/<username>/provisioner/provisioner` with a wrapper script at `/usr/local/opt/<username>/runprovisioner.sh`. This is the process that receives and executes Actions runner jobs.

**How it works:**

1. Creates the provisioner directory structure
2. Downloads the provisioner binary and install script via `aria2c`
3. Runs the install script
4. Creates a `runprovisioner.sh` wrapper that sources `.bashrc` and launches the binary
5. Writes a state file (`provisionerDone`) to signal completion

```bash
PROVISIONER_ROOT=/usr/local/opt/${Username}
sudo mkdir -p ${PROVISIONER_ROOT}

tee -a ${PROVISIONER_ROOT}/runprovisioner.sh > /dev/null <<\EOF
#!/bin/bash
. ${HOME}/.bashrc
/usr/local/opt/$USER/provisioner/provisioner
EOF
```

The provisioner is pre-granted extensive TCC permissions (accessibility, screen capture, Apple Events, full disk access, microphone, Bluetooth) so it can drive the system without any consent prompts.

**Why:**

The provisioner is the orchestration layer between GitHub's infrastructure and the macOS VM. It needs deep system access to:
- Launch and monitor runner processes
- Interact with the GUI for UI testing workloads
- Manage the VM lifecycle (password rotation, etc.)

---

## Window Management at Build Time

**Relevant file:**

- `images/macos/scripts/build/configure-windows.sh`

**What it does:**

Ensures no stray windows are open in the GUI session before the image is finalized. On ARM64 machines, it also kills the Setup Assistant that auto-launches on first boot.

```bash
# Close System Preferences (opens by default on ARM64 Ventura+)
osascript -e 'tell application "System Preferences" to quit'

# Kill Setup Assistant if running
if pgrep -x "Setup Assistant" >/dev/null 2>&1; then
    osascript -e 'tell application "Setup Assistant" to quit' 2>/dev/null || true
fi

# Verify no unexpected windows remain
openwindows=$(osascript -e 'tell application "System Events" to get every window of (every process whose class of windows contains window)')
```

**Why:**

Open windows in the saved image would appear in every job run, potentially interfering with UI tests or causing non-deterministic behavior.

---

## Developer Mode and Accessibility

**Relevant file:**

- `images/macos/scripts/build/configure-machine.sh` (lines 9–31)

```bash
# Enable developer mode (allows attaching debuggers, running unsigned code, etc.)
sudo /usr/sbin/DevToolsSecurity --enable

# Suppress Keyboard Setup Assistant
sudo defaults write /Library/Preferences/com.apple.keyboardtype "keyboardtype" -dict-add "3-7582-0" -int 40

# Enable VoiceOver AppleScript control (requires SIP disabled)
sudo bash -c 'echo -n "a" > /private/var/db/Accessibility/.VoiceOverAppleScriptEnabled'
defaults write com.apple.VoiceOver4/default SCREnableAppleScript -bool YES
```

**Why:**

- Developer mode is required for Xcode debugging and running tests
- The Keyboard Setup Assistant dialog would block the session on first boot
- VoiceOver scripting support enables accessibility testing without user interaction

---

## NOPASSWD Sudo Access

**Relevant file:**

- `images/macos/scripts/build/configure-machine.sh` (lines 99–100)

```bash
sudo sed -i '' 's/%admin		ALL = (ALL) ALL/%admin		ALL = (ALL) NOPASSWD: ALL/g' /etc/sudoers
```

**Why:**

Build scripts and the provisioner frequently need root access. Without NOPASSWD, every `sudo` call would prompt for a password, blocking automation.

---

## Summary: The Full Boot Sequence

When a macOS runner VM boots:

1. **Anka** starts the VM on physical Mac hardware
2. **Auto-login** kicks in — the user session starts without a login screen
3. **WindowServer** launches the GUI (needed for simulators and UI tests)
4. **No consent dialogs** appear thanks to pre-populated TCC entries
5. **The provisioner agent** starts and connects to GitHub's infrastructure
6. **Jobs execute** with full system access — accessibility, screen capture, Apple Events, etc.
7. **Nothing sleeps**, nothing updates, nothing prompts — the VM is a fully automated, unattended workstation.

The result is not "headless" in the traditional sense (WindowServer is running, there's a full Aqua session), but it behaves like a headless system from the perspective of automation: no human interaction is ever required or expected.

---

## Additional Tricks and Techniques

### Dynamic Hostname Generation at Boot

**Relevant file:**

- `images/macos/scripts/build/configure-hostname.sh`

**What it does:**

Installs a LaunchDaemon that generates a unique hostname every time the VM boots, based on the current timestamp.

```bash
name="Mac-$(python3 -c 'from time import time; print(int(round(time() * 1000)))')"
scutil --set HostName "${name}.local"
scutil --set LocalHostName $name
scutil --set ComputerName "${name}.local"
```

**Why:**

Since many VMs are cloned from the same base image and run simultaneously, they'd all share the same hostname. This causes Bonjour/mDNS conflicts on the network. The `.local` suffix is intentional — without it, macOS can have DNS resolution issues in certain network configurations. A millisecond-precision timestamp ensures uniqueness without needing external coordination.

---

### Parallel Xcode Installation (5 at a Time)

**Relevant files:**

- `images/macos/scripts/build/Install-Xcode.ps1`
- `images/macos/scripts/helpers/Xcode.Installer.psm1`

**What it does:**

Downloads and extracts multiple Xcode versions in parallel using PowerShell's `ForEach-Object -Parallel` with a throttle limit of 5.

```powershell
$xcodeVersions | ForEach-Object -ThrottleLimit $threadCount -Parallel {
    Install-XcodeVersion -Version $_.version -LinkTo $_.link -Sha256Sum $_.sha256
    Confirm-XcodeIntegrity -Version $_.link
}
```

**Why:**

Xcode downloads are huge (10–30 GB each) and extraction is CPU-intensive. Installing them sequentially would take hours. Parallelizing with a throttle of 5 balances I/O throughput against available disk space (each XIP archive exists temporarily alongside the expanded app).

---

### `unxip` — A Faster XIP Extractor

**Relevant files:**

- `images/macos/scripts/build/install-unxip.sh`
- `images/macos/scripts/helpers/Xcode.Installer.psm1` (line 57–61)

**What it does:**

Installs [saagarjha/unxip](https://github.com/saagarjha/unxip), a third-party replacement for Apple's `xip` tool, and uses it preferentially for Xcode extraction:

```powershell
if ([boolean] (Get-Command 'unxip' -ErrorAction 'SilentlyContinue')) {
    Invoke-ValidateCommand "unxip $xcodeXipPath"
} else {
    Invoke-ValidateCommand "xip -x $xcodeXipPath"
}
```

**Why:**

Apple's built-in `xip` command is single-threaded and very slow for large archives. `unxip` is significantly faster (often 3–5x) because it parallelizes decompression. When you're extracting multiple 15+ GB Xcode archives, this saves a massive amount of build time. The binary is pinned to a specific SHA-256 checksum for reproducibility.

---

### AppleScript-Driven UI Automation for Kernel Extension Approval

**Relevant files:**

- `images/macos/scripts/helpers/confirm-identified-developers-macos15.scpt`
- `images/macos/scripts/build/install-common-utils.sh` (lines 49–76)

**What it does:**

Uses AppleScript to physically navigate System Settings, click the "Allow" button for third-party kernel extensions (Parallels), and enter the password — exactly as a human would.

```applescript
tell application "System Settings"
    activate
    delay 5
end tell

tell application "System Events"
    tell process "System Settings"
        tell splitter group 1 of group 1 of window 1
            select row 27 of outline 1 of scroll area 1 of group 1
            click UI element 1 of row 27 of outline 1 of scroll area 1 of group 1
            keystroke userpassword
            keystroke return
        end tell
    end tell
end tell
```

**Why:**

macOS has no command-line API for approving third-party kernel extensions (kexts). Apple deliberately requires GUI interaction for security reasons. Since the VMs run with a full GUI session and have TCC permissions pre-granted for accessibility/AppleEvents, they can script the System Settings UI directly. The script includes retries because the UI can be timing-sensitive.

---

### Kernel Extension Policy Validation via SQLite

**Relevant file:**

- `images/macos/scripts/build/install-common-utils.sh` (lines 79–93)

**What it does:**

After the AppleScript approves the Parallels kext, the script verifies the approval succeeded by querying the kernel extension policy database directly:

```bash
dbName="/var/db/SystemPolicyConfiguration/KextPolicy"
dbQuery="SELECT * FROM kext_policy WHERE bundle_id LIKE 'com.parallels.kext.%';"
kext=$(sudo sqlite3 $dbName "$dbQuery")

if [[ -z $kext ]]; then
    echo "Parallels International GmbH not found"
    exit 1
fi
```

**Why:**

AppleScript UI interactions are inherently fragile. Rather than trusting the script succeeded, it verifies the actual system state by querying the KextPolicy SQLite database — the same database the kernel reads to determine which extensions are allowed to load.

---

### Homebrew Quarantine Bypass

**Relevant file:**

- `images/macos/assets/bashrc` (line 31)

```bash
export HOMEBREW_CASK_OPTS="--no-quarantine"
```

**Why:**

macOS marks downloaded files with a quarantine extended attribute (`com.apple.quarantine`). On first launch, this triggers a Gatekeeper dialog: "This app was downloaded from the internet. Are you sure you want to open it?" Setting `--no-quarantine` prevents Homebrew from applying this attribute, so cask-installed apps (Chrome, Firefox, etc.) launch without prompts.

---

### Homebrew Auto-Update Suppression

**Relevant file:**

- `images/macos/assets/bashrc` (lines 29–30)

```bash
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
```

**Why:**

By default, every `brew install` triggers a `brew update` first (checking for formula updates). In CI this wastes time and risks introducing version drift mid-build. `NO_INSTALL_CLEANUP` prevents Homebrew from removing old versions during install, avoiding potential race conditions during parallel installs.

---

### Shallow Git Clones for Homebrew Taps

**Relevant file:**

- `images/macos/scripts/build/install-homebrew.sh` (lines 23–24)

```bash
git clone https://github.com/Homebrew/homebrew-cask $(brew --repository)/Library/Taps/homebrew/homebrew-cask \
    --origin=origin --template= --config core.fsmonitor=false --depth 1
git clone https://github.com/Homebrew/homebrew-core $(brew --repository)/Library/Taps/homebrew/homebrew-core \
    --origin=origin --template= --config core.fsmonitor=false --depth 1
```

**Why:**

The homebrew-core repo has over 700,000 commits. A full clone would waste disk space and bandwidth. `--depth 1` grabs only the latest commit. `core.fsmonitor=false` disables the file system monitor (which would waste CPU watching thousands of formula files that never change in CI).

---

### `expect`-Driven Software Updates for ARM64

**Relevant file:**

- `images/macos/assets/auto-software-update-arm64.exp`

```expect
spawn sudo /usr/sbin/softwareupdate --restart --verbose --install "MACOSUPDATE"
expect "Password*"
send "[lindex $argv 0]\r"
expect eof
```

**Why:**

On ARM64 Macs, `softwareupdate` sometimes prompts for a password even when run with `sudo` (Apple Silicon secure boot requirements). The `expect` script automates this password entry. The placeholder `"MACOSUPDATE"` is replaced with the actual update label at runtime.

---

### XCTest Command Line Tools Installation Trick

**Relevant file:**

- `images/macos/scripts/build/install-xcode-clt.sh`

**What it does:**

Triggers Apple's software update mechanism to list Command Line Tools by creating a specific marker file:

```bash
clt_placeholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
sudo touch $clt_placeholder
```

Then parses the `softwareupdate -l` output for the latest CLT label and installs it.

**Why:**

There's no direct `xcode-select --install` equivalent that works non-interactively (it opens a GUI dialog). The `.installondemand.in-progress` marker file is an undocumented trick that tells `softwareupdate` to include Command Line Tools in its available updates list, enabling purely CLI-based installation.

---

### Safari WebDriver Remote Automation

**Relevant file:**

- `images/macos/scripts/build/install-safari.sh`

```bash
sudo safaridriver --enable

mkdir -p $HOME/Library/WebDriver
safari_plist="$HOME/Library/WebDriver/com.apple.Safari.plist"
/usr/libexec/PlistBuddy -c 'delete AllowRemoteAutomation' $safari_plist || true
/usr/libexec/PlistBuddy -c 'add AllowRemoteAutomation bool true' $safari_plist
```

**Why:**

Safari's WebDriver requires both the system-level driver to be enabled (`safaridriver --enable`) and the user-level "Allow Remote Automation" preference. Normally this is toggled in Safari's Develop menu — here it's set directly via `PlistBuddy` to avoid opening Safari's GUI.

---

### Launch Services Database Rebuild for Xcode

**Relevant file:**

- `images/macos/scripts/helpers/Xcode.Installer.psm1` (lines 238–247)

```powershell
function Initialize-XcodeLaunchServicesDb {
    $lsregister = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
    Get-ChildItem -Recurse -Filter "*.app" $xcodePath | Foreach-Object { & $lsregister -f $_.FullName }
}
```

**Why:**

macOS's Launch Services maps file types to applications. After installing multiple Xcode versions (each containing hundreds of embedded `.app` bundles), the system needs to know about them for proper file associations and `open -a` functionality. Explicitly registering them ensures they're discoverable immediately rather than waiting for Spotlight to index them.

---

### Dyld Shared Cache Pre-warming for Simulators

**Relevant file:**

- `images/macos/scripts/helpers/Xcode.Installer.psm1` (lines 326–335)

```powershell
function Update-DyldCache {
    Invoke-ValidateCommand "xcrun simctl runtime dyld_shared_cache update --all"
}
```

**Why:**

The dynamic linker cache (`dyld_shared_cache`) is a pre-linked blob of all shared libraries. Without pre-warming it for simulator runtimes, the first simulator launch in a user's job would trigger an expensive cache build (potentially minutes of CPU time). Doing it at image build time means every job starts with a ready-to-use simulator.

---

### Simulator Reset Across All Xcode Versions

**Relevant file:**

- `images/macos/scripts/build/configure-xcode.sh`

```bash
for XCODE_VERSION in ${XCODE_LIST[@]}; do
    launchctl remove com.apple.CoreSimulator.CoreSimulatorService || true
    sleep 3
    sudo xcode-select -s /Applications/Xcode_${XCODE_VERSION}.app/Contents/Developer
    xcrun simctl erase all
    sleep 10
done
```

**Why:**

Each Xcode version has its own simulator runtime. Erasing all simulators ensures they start in a clean state (no leftover app data from the build process). The `launchctl remove` and sleep dance is needed because CoreSimulatorService caches state — it must be stopped and restarted for each Xcode version switch to properly erase that version's simulators.

---

### Environment Variables for Non-Interactive Tool Behavior

**Relevant file:**

- `images/macos/assets/bashrc`

```bash
export RCT_NO_LAUNCH_PACKAGER=1          # React Native: don't auto-launch Metro bundler
export DOTNET_MULTILEVEL_LOOKUP=0         # .NET: don't search for global SDKs
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 # .NET: skip telemetry/welcome on first run
export DOTNET_NOLOGO=1                    # .NET: suppress startup banner
export BOOTSTRAP_HASKELL_NONINTERACTIVE=1 # GHCup: never prompt
export BOOTSTRAP_HASKELL_INSTALL_NO_STACK_HOOK=1  # GHCup: skip shell hook
```

**Why:**

Many developer tools have "first run" experiences — welcome messages, telemetry opt-ins, interactive setup wizards. Each of these would either waste time or block waiting for input. These environment variables disable all such behavior globally.

---

### `brew_smart_install` — Resilient Homebrew Installation

**Relevant file:**

- `images/macos/scripts/helpers/utils.sh` (lines 93–135)

**What it does:**

A custom wrapper around `brew install` that:
1. Resolves all dependencies first (`brew deps`)
2. Pre-caches every dependency bottle (`brew --cache`)
3. Attempts installation with up to 10 retries, sleeping 60 seconds between attempts

```bash
brew_smart_install() {
    local tool_name=$1
    # Pre-cache dependencies
    for dep in $(cat /tmp/$tool_name) $tool_name; do
        for i in {1..10}; do
            brew --cache $dep >/dev/null && failed=false || sleep 60
        done
    done
    # Install with retries
    for i in {1..10}; do
        brew install $tool_name && failed=false || sleep 60
    done
}
```

**Why:**

Homebrew relies on GitHub and CDN infrastructure that can have transient failures. A single failed download would abort the entire multi-hour image build. By pre-caching dependencies and retrying aggressively, the build is resilient to temporary network issues.

---

### UTC Timezone and Multiple NTP Servers

**Relevant file:**

- `images/macos/scripts/build/configure-ntpconf.sh`

```bash
# Multiple NTP sources for reliability
server 0.pool.ntp.org
server 1.pool.ntp.org
server 2.pool.ntp.org
server 3.pool.ntp.org
server time.apple.com
server time.windows.com

# Force UTC
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
```

**Why:**

CI jobs must have consistent, accurate timestamps for:
- Cache invalidation and artifact signing
- Certificate validation
- Log correlation across distributed systems
- Reproducible builds

UTC avoids daylight saving time surprises. Multiple NTP servers ensure the clock stays accurate even if one server is unreachable.

---

### Actions Cache Pre-population

**Relevant file:**

- `images/macos/scripts/build/install-actions-cache.sh`

**What it does:**

Downloads the latest release of `actions/action-versions` (a tarball of common GitHub Actions at specific versions) and unpacks it to `$ACTIONS_RUNNER_ACTION_ARCHIVE_CACHE`.

**Why:**

When a workflow uses `actions/checkout@v4`, the runner normally downloads that action at job start. By pre-caching popular actions in the image, jobs start faster — the runner finds the action locally instead of fetching from GitHub.

---

### Pinning Deprecated Homebrew Formulae by Git Commit

**Relevant files:**

- `images/macos/scripts/build/install-openssl.sh`
- `images/macos/scripts/build/install-rust.sh`

**What it does:**

When a formula has been deprecated/removed from Homebrew (like `openssl@1.1`) or needs pinning to a specific version (like `rustup`), the scripts download the formula file from a specific Git commit and install it with API fetching disabled:

```bash
COMMIT=d91dabd087cb0b906c92a825df9e5e5e1a4f59f8
FORMULA_URL="https://raw.githubusercontent.com/Homebrew/homebrew-core/$COMMIT/Formula/o/openssl@1.1.rb"
FORMULA_PATH="$(brew --repository)/Library/Taps/homebrew/homebrew-core/Formula/o/openssl@1.1.rb"
mkdir -p "$(dirname $FORMULA_PATH)"
curl -fsSL $FORMULA_URL -o $FORMULA_PATH
HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_FROM_API=1 brew install openssl@1.1
```

**Why:**

Homebrew aggressively deprecates and removes formulae. Users still depend on these packages (openssl@1.1 for legacy compatibility, specific rustup versions to avoid regressions). By pinning to a known-good commit of the formula and bypassing the API (`HOMEBREW_NO_INSTALL_FROM_API=1`), the image can install software that Homebrew no longer officially supports.

---

### Quarantine Removal for `.pkg` Installers

**Relevant file:**

- `images/macos/scripts/build/install-powershell.sh` (line 26)

```bash
sudo xattr -rd com.apple.quarantine $pkg_path
```

**Why:**

On macOS Big Sur 11.5+, the `installer` command can refuse to open `.pkg` files that have the quarantine extended attribute (downloaded from the internet). Stripping `com.apple.quarantine` before running `sudo installer -pkg` prevents the "can't be opened because Apple cannot check it for malicious software" error. This is separate from the Homebrew `--no-quarantine` flag — it applies to manually downloaded packages.

---

### Git `safe.directory` Wildcard

**Relevant file:**

- `images/macos/scripts/build/install-git.sh` (line 12)

```bash
git config --global --add safe.directory "*"
```

**Why:**

Git 2.35.2+ introduced ownership checks — it refuses to operate in directories owned by a different user (CVE-2022-24765). In CI, runners frequently check out repos into directories with mismatched ownership (e.g., root-owned workspace, runner user executing git). The wildcard `"*"` disables this check globally, preventing confusing "dubious ownership" errors during jobs.

---

### Suppressing All Git Advice Messages

**Relevant file:**

- `images/macos/scripts/build/install-git.sh` (lines 23–36)

```bash
git config --global advice.pushUpdateRejected false
git config --global advice.pushNonFFCurrent false
git config --global advice.pushNonFFMatching false
git config --global advice.pushAlreadyExists false
git config --global advice.pushFetchFirst false
git config --global advice.pushNeedsForce false
git config --global advice.statusHints false
git config --global advice.statusUoption false
git config --global advice.commitBeforeMerge false
git config --global advice.resolveConflict false
git config --global advice.implicitIdentity false
git config --global advice.detachedHead false
git config --global advice.amWorkDir false
git config --global advice.rmHints false
```

**Why:**

Git's advice messages (e.g., "hint: Updates were rejected because the tip of your current branch is behind") add noise to CI logs and can confuse log parsing. Disabling them all makes output cleaner and easier to parse programmatically.

---

### Toolcache Convention with `.complete` Marker Files

**Relevant files:**

- `images/macos/scripts/build/install-openjdk.sh` (lines 69–73)
- `images/macos/scripts/build/install-ruby.sh` (lines 54–58)
- `images/macos/scripts/build/install-codeql-bundle.sh` (lines 43–44)

**What it does:**

After extracting a tool to the toolcache directory, a zero-byte `.complete` file is created:

```bash
# Java
touch ${javaToolcacheVersionPath}/x64.complete

# Ruby
touch $complete_file_path  # e.g., Ruby/3.2.0/arm64.complete

# CodeQL
touch "$codeql_toolcache_path/pinned-version"
touch "$codeql_toolcache_path.complete"
```

**Why:**

The Actions runner uses these marker files to determine whether a tool version is fully installed. Without the `.complete` file, `setup-java`, `setup-ruby`, etc. would consider the tool missing and attempt to re-download it. This is a contract between the image and the `actions/setup-*` family of actions — they check for `<version>/<arch>.complete` before installing.

---

### Browser Auto-Update Prevention

**Relevant file:**

- `images/macos/scripts/build/install-edge.sh` (lines 44–63)

**What it does:**

Creates a managed preferences plist to disable Microsoft Edge auto-updates:

```bash
cat <<EOF | sudo tee "/Library/Managed Preferences/com.microsoft.EdgeUpdater.plist" > /dev/null
<plist version="1.0">
<dict>
    <key>updatePolicies</key>
    <dict>
        <key>global</key>
        <dict>
            <key>UpdateDefault</key>
            <integer>3</integer>
        </dict>
    </dict>
</dict>
</plist>
EOF
```

**Why:**

Browser auto-updates in CI are catastrophic — they can change the browser version mid-workflow, breaking Selenium/WebDriver compatibility. The `UpdateDefault: 3` policy means "updates disabled." Edge uses its own updater (EdgeUpdater) separate from macOS software update, requiring this separate managed preference.

---

### Matched ChromeDriver and "Chrome for Testing" Versions

**Relevant file:**

- `images/macos/scripts/build/install-chrome.sh`

**What it does:**

After installing Google Chrome via Homebrew cask, the script:
1. Parses Chrome's exact version
2. Queries the Chrome for Testing API to find the matching ChromeDriver version
3. Installs both ChromeDriver AND a separate "Google Chrome for Testing" app

```bash
full_chrome_version=$("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --version)
chrome_version=${full_chrome_version%.*}  # Strip patch version
chromedriver_url=$(cat $chrome_versions_json | jq -r '.builds["'"$chrome_version"'"].downloads.chromedriver[]...')
```

**Why:**

ChromeDriver must match the installed Chrome version exactly (major version at minimum). If they're mismatched, Selenium tests fail with cryptic version errors. "Chrome for Testing" is a separate, automation-optimized build that doesn't auto-update — giving users a stable target for their test suites.

---

### Duplicate Simulator Cleanup

**Relevant file:**

- `images/macos/scripts/build/Configure-Xcode-Simulators.ps1`

**What it does:**

Iterates through every Xcode version's simulators and removes duplicates (keeping the older-created one):

```powershell
if ($sameRuntimeDevices[$i].DeviceName -eq $sameRuntimeDevices[$i+1].DeviceName) {
    if ($sameRuntimeDevices[$i].DeviceCreationTime -lt $sameRuntimeDevices[$i+1].DeviceCreationTime) {
        xcrun simctl delete $sameRuntimeDevices[$i+1].DeviceId
    }
}
```

**Why:**

When multiple Xcode versions share simulator runtimes, the same device type can get created multiple times. Duplicate simulators waste disk space and can cause ambiguity when tests target a device by name. This script ensures exactly one simulator per device type per runtime.

---

### `.bashrc` as the Central Environment Configuration

**Relevant file:**

- `images/macos/assets/bashrc`
- `images/macos/assets/bashprofile` (just sources `.bashrc`)

**What it does:**

All environment configuration lives in `.bashrc`, with `.bash_profile` being a one-liner:

```bash
# .bash_profile
[ -f $HOME/.bashrc ] && source $HOME/.bashrc
```

Throughout the build, scripts append to `.bashrc`:
```bash
echo "export JAVA_HOME_11_X64=..." >> ${HOME}/.bashrc
echo "export ANDROID_NDK_HOME=..." >> ${HOME}/.bashrc
echo "export CHROMEWEBDRIVER=..." >> ${HOME}/.bashrc
```

**Why:**

On macOS, login shells source `.bash_profile` while non-login shells source `.bashrc`. SSH sessions (how Packer connects) use login shells, but scripts spawned within jobs may use non-login shells. By putting everything in `.bashrc` and sourcing it from `.bash_profile`, environment variables are available regardless of how the shell is invoked.

---

### Symlink for Java Discovery via `/usr/libexec/java_home`

**Relevant file:**

- `images/macos/scripts/build/install-openjdk.sh` (line 77)

```bash
sudo ln -sf ${javaToolcacheVersionArchPath} /Library/Java/JavaVirtualMachines/Temurin-Hotspot-${JAVA_VERSION}.jdk
```

**Why:**

macOS's built-in `/usr/libexec/java_home` tool discovers JDKs by scanning `/Library/Java/JavaVirtualMachines/`. The toolcache stores JDKs in a different location (`$HOME/hostedtoolcache/Java_Temurin-Hotspot_jdk/...`). The symlink makes the toolcache-installed JDKs visible to `java_home`, so tools like Gradle and Maven that rely on `java_home` can find them without extra configuration.

---

### Initializing Az PowerShell Module Cache

**Relevant file:**

- `images/macos/scripts/build/install-powershell.sh` (line 62)

```bash
pwsh -command "& {Import-Module Az}"
```

**Why:**

The comment says "A dummy call to initialize .IdentityService directory." Azure PowerShell modules create credential cache directories on first import. If this happens during a user's job, it may fail due to race conditions or permission issues. Running it once at image build time ensures the directory structure exists and has correct permissions.

---

### `close_finder_window` Called Before Python Installation

**Relevant file:**

- `images/macos/scripts/build/install-python.sh` (line 12)

```bash
# Close Finder window
close_finder_window
```

**Why:**

The Python installer (and some Homebrew cask operations) can trigger Finder windows to open (e.g., showing the Applications folder or mounted DMG volumes). If these windows are left open during subsequent steps, they can interfere with the UI-window-validation in `configure-windows.sh` which fails the build if unexpected windows are detected. Proactively closing Finder windows before known-noisy installs prevents this.

---

### `download_with_retry` — IPv4-Forced Downloads with Extensive Retries

**Relevant file:**

- `images/macos/scripts/helpers/utils.sh` (lines 3–42)

```bash
download_with_retry() {
    for ((retries=20; retries>0; retries--)); do
        if http_code=$(curl -4sSLo "$download_path" "$url" -w '%{http_code}'); then
            ...
        fi
        sleep $interval  # 30 seconds
    done
}
```

Key details:
- **`-4` flag**: Forces IPv4 connections
- **20 retries × 30 second intervals**: Up to 10 minutes of retry time
- **HTTP status code checking**: Treats non-200 responses as failures even if `curl` succeeds

**Why:**

The `-4` (IPv4-only) flag is notable — some CI environments have flaky IPv6 connectivity or DNS resolution issues with AAAA records. Forcing IPv4 avoids a common class of transient network failures. The aggressive retry pattern (20 attempts) reflects the reality that large downloads from CDNs, GitHub Releases, and Azure Blob Storage can fail intermittently at scale.
