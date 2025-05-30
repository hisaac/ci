packer {
  required_plugins {
    ipsw = {
      version = ">= 0.1.5"
      source  = "github.com/torarnv/ipsw"
    }

    tart = {
      version = ">= 1.14.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "macos_version" {
  type    = string
  default = "15"
}

variable "vm_name" {
  type    = string
  default = "macos-15-base"
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

data "ipsw" "macos" {
  os      = "macOS"
  version = var.macos_version
  device  = "VirtualMac2,1"
}

locals {
  boot_command = [
    # hello, hola, bonjour, etc.
    "<wait60s><spacebar>",

    # Language: most of the times we have a list of "English"[1], "English (UK)", etc. with
    # "English" language already selected. If we type "english", it'll cause us to switch
    # to the "English (UK)", which is not what we want. To solve this, we switch to some other
    # language first, e.g. "Italiano" and then switch back to "English". We'll then jump to the
    # first entry in a list of "english"-prefixed items, which will be "English".
    #
    # [1]: should be named "English (US)", but oh well 🤷
    "<wait60s>italiano<esc>english<enter>",

    # Select Your Country or Region
    "<wait30s>united states<leftShiftOn><tab><leftShiftOff><spacebar>",

    # Transfer Your Data to This Mac
    "<wait10s><tab><tab><tab><spacebar><tab><tab><spacebar>",

    # Written and Spoken Languages
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    # Accessibility
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    # Data & Privacy
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    # Create a Mac Account
    "<wait10s>${var.vm_username}<tab><tab>${var.vm_password}<tab>${var.vm_password}<tab><tab><spacebar><tab><tab><spacebar>",

    # Enable Voice Over
    # For whatever reason, the ability to navigate the installer using the keyboard goes away at this point,
    # so we enable Voice Over as a workaround, which allows us to navigate using the keyboard.
    "<wait120s><leftAltOn><f5><leftAltOff>",

    # Sign In with Your Apple ID
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    # Are you sure you want to skip signing in with an Apple ID?
    "<wait10s><tab><spacebar>",

    # Terms and Conditions
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    # I have read and agree to the macOS Software License Agreement
    "<wait10s><tab><spacebar>",

    # Enable Location Services
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    # Are you sure you don't want to use Location Services?
    "<wait10s><tab><spacebar>",

    # Select Your Time Zone
    "<wait10s><tab><tab>UTC<enter><leftShiftOn><tab><tab><leftShiftOff><spacebar>",

    # Analytics
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    # Screen Time
    "<wait10s><tab><spacebar>",

    # Siri
    "<wait10s><tab><spacebar><leftShiftOn><tab><leftShiftOff><spacebar>",

    # Choose Your Look
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    # Update Mac Automatically
    "<wait10s><tab><spacebar>",

    # Welcome to Mac
    "<wait10s><spacebar>",

    # Disable Voice Over
    "<leftAltOn><f5><leftAltOff>",

    # Enable Keyboard navigation
    # This is so that we can navigate the System Settings app using the keyboard
    "<wait10s><leftAltOn><spacebar><leftAltOff>Terminal<enter>",
    "<wait5s>defaults write NSGlobalDomain AppleKeyboardUIMode -int 3<enter>",

    # Disable Gatekeeper (1/2)
    "<wait10s>sudo spctl --global-disable<enter>",
    "<wait10s>${var.vm_password}<enter>",
    "<wait10s><leftAltOn>q<leftAltOff>",

    # Open "System Settings"
    "<wait10s><leftAltOn><spacebar><leftAltOff>System Settings<enter>",

    # Navigate to "Sharing"
    "<wait10s><leftAltOn><leftShiftOn>/<leftShiftOff><leftAltOff>Sharing<down><enter>",

    # Navigate to "Screen Sharing" and enable it
    "<wait10s><tab><tab><tab><tab><tab><tab><tab><spacebar>",

    # Navigate to "Remote Login" and enable it
    "<wait10s><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><spacebar>",

    # Disable Gatekeeper (2/2)
    "<wait10s><leftAltOn><leftShiftOn>/<leftShiftOff><leftAltOff>Privacy & Security<down><enter>",
    "<wait10s><leftShiftOn><tab><tab><tab><tab><tab><tab><tab><leftShiftOff>",
    "<wait10s><down><wait1s><down><wait1s><enter>",
    "<wait10s>${var.vm_password}<enter>",
    "<wait10s><leftShiftOn><tab><leftShiftOff><wait1s><spacebar>",

    # Quit System Settings
    "<wait10s><leftAltOn>q<leftAltOff>",
  ]

}

source "tart-cli" "initialize" {
  from_ipsw          = data.ipsw.macos.url
  vm_name            = var.vm_name
  cpu_count          = 4
  memory_gb          = 8
  disk_size_gb       = 100
  ssh_password       = var.vm_password
  ssh_username       = var.vm_username
  ssh_timeout        = "300s"
  recovery_partition = "keep"
  boot_command       = local.boot_command
  run_extra_args     = ["--no-audio"]

  # Workaround for Virtualization.Framework's installation process
  # not fully finishing in a timely manner
  create_grace_time = "30s"
}

build {
  name    = "stage1"
  sources = ["source.tart-cli.initialize"]

  provisioner "shell" {
    scripts = [
      "${path.root}/scripts/enable-passwordless-sudo.bash",
      "${path.root}/scripts/enable-auto-login.bash",
      "${path.root}/scripts/disable-screen-lock.bash",
      "${path.root}/scripts/configure-defaults.bash",
    ]
    env = {
      "VM_USERNAME" = var.vm_username,
      "VM_PASSWORD" = var.vm_password,
    }
  }
}
