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
  default = "macos-27-base"
}

variable "vm_name" {
  type    = string
  default = "macos-27-boot"
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

source "tart-cli" "tart" {
  // Clone the installed base so each boot-command attempt starts clean.
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
    "<wait60s>",

    # Open System Settings to give it time to settle
    "<wait10s><leftAltOn><spacebar><leftAltOff><wait2s>System Settings<wait10s><enter>",

    # Enable Keyboard navigation so we can navigate System Settings using the keyboard
    "<wait10s><leftAltOn><spacebar><leftAltOff><wait2s>Terminal<wait10s><enter>",
    "<wait10s>defaults write NSGlobalDomain AppleKeyboardUIMode -int 3<enter>",

    # # Enable on-screen keyboard for debugging
    # "<wait10s>open 'x-apple.systempreferences:com.apple.preference.universalaccess?Keyboard'<enter>",
    # "<wait10s><tab><tab><tab><tab><tab><tab><tab><tab><tab><spacebar>",

    # Disable Gatekeeper (1/2)
    "<wait10s><leftAltOn><spacebar><leftAltOff><wait2s>Terminal<wait10s><enter>",
    "<wait10s>sudo spctl --global-disable<enter>",
    "<wait10s>admin<enter>",
    # Disable Gatekeeper (2/2)
    "<wait10s>open 'x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension'<enter>",
    "<wait10s><leftShiftOn><tab><tab><tab><tab><tab><tab><tab><tab><leftShiftOff>",
    "<wait10s><down><wait1s><down><wait1s><enter>",
    "<wait10s>admin<enter>",
    "<wait10s><leftShiftOn><tab><leftShiftOff><wait1s><spacebar>",

    # Enable Screen Sharing through the UI to grant the required TCC permissions
    "<wait10s><leftAltOn><spacebar><leftAltOff><wait2s>Terminal<wait10s><enter>",
    "<wait10s>open 'x-apple.systempreferences:com.apple.Sharing-Settings.extension'<enter>",
    "<wait10s><tab><tab><tab><tab><tab><tab><spacebar>",
    "<wait10s>admin<enter>",

    # # Disable on-screen keyboard
    # "<wait10s><leftAltOn><spacebar><leftAltOff><wait2s>Terminal<wait10s><enter>",
    # "<wait10s>open 'x-apple.systempreferences:com.apple.preference.universalaccess?Keyboard'<enter>",
    # "<wait10s><tab><tab><tab><tab><tab><tab><tab><spacebar>",
    # "<wait10s><tab><spacebar>",

    # Quit System Settings
    "<wait10s><leftAltOn><spacebar><leftAltOff><wait2s>System Settings<wait10s><enter>",
    "<wait10s><leftAltOn>q<leftAltOff>",

    # Quit Terminal
    "<wait10s><leftAltOn><spacebar><leftAltOff><wait2s>Terminal<wait10s><enter>",
    "<wait10s><leftAltOn>q<leftAltOff>",
  ]
}

build {
  sources = ["source.tart-cli.tart"]

  provisioner "shell" {
    inline = [
      # Ensure that keyboard navigation is enabled.
      "test \"$(defaults read NSGlobalDomain AppleKeyboardUIMode)\" = 3",
      # Ensure that Gatekeeper is disabled.
      "spctl --status | grep -q 'assessments disabled'",
      # Ensure that Screen Sharing's service is loaded.
      "sudo launchctl print system/com.apple.screensharing > /dev/null",
    ]
  }
}
