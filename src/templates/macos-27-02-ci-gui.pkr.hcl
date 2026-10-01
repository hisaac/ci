# For reference, it is possible to enable the on-screen keyboard to allow for improved debugability
# of these workflows that require GUI interaction. Here is how you'd do that:
#
# "<wait10s>open 'x-apple.systempreferences:com.apple.preference.universalaccess?Keyboard'<enter>",
# "<wait10s><tab><tab><tab><tab><tab><tab><tab><tab><tab><spacebar>",
#
# And to disable:
#
# "<wait10s>open 'x-apple.systempreferences:com.apple.preference.universalaccess?Keyboard'<enter>",
# "<wait10s><tab><tab><tab><tab><tab><tab><tab><spacebar>",
# "<wait10s><tab><spacebar>",

packer {
  required_plugins {
    tart = {
      version = ">= 1.21.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "vm_base_name" {
  type    = string
  default = "macos-27-01-base"
}

variable "vm_name" {
  type    = string
  default = "macos-27-02-ci-gui"
}

variable "vm_username" {
  type      = string
  sensitive = true
  default   = "admin"
}

variable "vm_password" {
  type      = string
  sensitive = true
  default   = "admin"
}

source "tart-cli" "ci-gui" {
  # Clone the installed base so each boot-command attempt starts clean.
  vm_base_name = var.vm_base_name
  vm_name      = var.vm_name
  ssh_password = var.vm_password
  ssh_username = var.vm_username
  ssh_timeout  = "180s"
  run_extra_args = [
    "--no-audio",
    "--vnc-experimental",
  ]

  boot_command = [
    # Give the OS a bit to settle
    "<wait30s>",

    # Open System Settings to give it time to settle
    "<wait10s><leftAltOn><spacebar><leftAltOff><wait2s>System Settings<wait10s><enter>",

    # Enable Keyboard Navigation so we can navigate System Settings using the keyboard
    "<wait10s><leftAltOn><spacebar><leftAltOff><wait2s>Terminal<wait10s><enter>",
    "<wait10s>defaults write NSGlobalDomain AppleKeyboardUIMode -int 3<enter>",

    # Disable Gatekeeper (1/2)
    "<wait10s>sudo spctl --global-disable<enter>",
    "<wait10s>admin<enter>",
    # Disable Gatekeeper (2/2)
    "<wait10s>open 'x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension'<enter>",
    "<wait10s><leftShiftOn><tab><tab><tab><tab><tab><tab><leftShiftOff>",
    "<wait10s><down><wait1s><down><wait1s><enter>",
    "<wait10s>admin<enter>",
    "<wait10s><leftShiftOn><tab><leftShiftOff><wait1s><spacebar>",

    # Enable Screen Sharing through the UI to grant the required TCC permissions
    "<wait10s><leftAltOn><spacebar><leftAltOff><wait2s>Terminal<wait10s><enter>",
    "<wait10s>open 'x-apple.systempreferences:com.apple.Sharing-Settings.extension'<enter>",
    "<wait10s><tab><tab><tab><tab><tab><spacebar>",
    "<wait10s>admin<enter>",
  ]
}

build {
  sources = ["source.tart-cli.ci-gui"]

  provisioner "shell" {
    inline = [
      # Quit System Settings and Terminal
      "killall 'System Settings' 'Terminal'",
      # Return Keyboard Navigation to its default state
      "defaults delete NSGlobalDomain AppleKeyboardUIMode",
      # Ensure that Gatekeeper is disabled.
      "spctl --status | grep -q 'assessments disabled'",
      # Ensure that Screen Sharing's service is loaded.
      "echo '${var.vm_password}' | sudo -S -p '' launchctl print system/com.apple.screensharing > /dev/null",
    ]
  }

  provisioner "shell" {
    script = "${path.root}/scripts/system_config/wait-for-spotlight.bash"
  }
}
