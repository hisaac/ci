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

data "ipsw" "macos" {
  os      = "macOS"
  version = "^15"
  device  = "VirtualMac2,1"
}

source "tart-cli" "tart" {
  from_ipsw    = "${data.ipsw.macos.url}"
  vm_name      = "sequoia-base"
  cpu_count    = 4
  memory_gb    = 8
  disk_size_gb = 100
  ssh_password = "admin"
  ssh_username = "admin"
  ssh_timeout  = "300s"

  // Uncomment for quiet and headless mode
  // headless = true
  // run_extra_args = [
  //   "--no-audio",
  // ]

  // A (hopefully) temporary workaround for Virtualization.Framework's
  // installation process not fully finishing in a timely manner
  create_grace_time = "30s"

  boot_command = [
    // hello, hola, bonjour, etc.
    "<wait60s><spacebar>",

    // Language: most of the times we have a list of "English"[1], "English (UK)", etc. with
    // "English" language already selected. If we type "english", it'll cause us to switch
    // to the "English (UK)", which is not what we want. To solve this, we switch to some other
    // language first, e.g. "Italiano" and then switch back to "English". We'll then jump to the
    // first entry in a list of "english"-prefixed items, which will be "English".
    //
    // [1]: should be named "English (US)", but oh well 🤷
    "<wait30s>italiano<esc>english<enter>",

    // Select Your Country and Region
    "<wait30s>united states<leftShiftOn><tab><leftShiftOff><spacebar>",

    // Written and Spoken Languages
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    // Accessibility
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    // Data & Privacy
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    // Migration Assistant
    "<wait10s><tab><tab><tab><spacebar>",

    // Sign In with Your Apple ID
    "<wait10s><leftShiftOn><tab><leftShiftOff><leftShiftOn><tab><leftShiftOff><spacebar>",

    // Are you sure you want to skip signing in with an Apple ID?
    "<wait10s><tab><spacebar>",

    // Terms and Conditions
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    // I have read and agree to the macOS Software License Agreement
    "<wait10s><tab><spacebar>",

    // Create a Computer Account
    "<wait10s>admin<tab><tab>admin<tab>admin<tab><tab><tab><spacebar>",

    // Enable Location Services
    "<wait120s><leftShiftOn><tab><leftShiftOff><spacebar>",

    // Are you sure you don't want to use Location Services?
    "<wait10s><tab><spacebar>",

    // Select Your Time Zone
    "<wait10s><tab><tab>UTC<enter><leftShiftOn><tab><tab><leftShiftOff><spacebar>",

    // Analytics
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    // Screen Time
    "<wait10s><tab><spacebar>",

    // Siri
    "<wait10s><tab><spacebar><leftShiftOn><tab><leftShiftOff><spacebar>",

    // Choose Your Look
    "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    // Welcome to Mac
    "<wait20s><spacebar>",

    // Enable Keyboard navigation
    // This is so that we can navigate the System Settings app using the keyboard
    "<wait10s><leftAltOn><spacebar><leftAltOff>Terminal<enter>",
    "<wait5s>defaults write NSGlobalDomain AppleKeyboardUIMode -int 3<enter>",
    "<wait5s><leftAltOn>q<leftAltOff>",

    // Now that the installation is done, open "System Settings"
    "<wait10s><leftAltOn><spacebar><leftAltOff>System Settings<enter>",

    // Navigate to "Sharing"
    "<wait10s><leftAltOn>f<leftAltOff>sharing<enter>",

    // Navigate to "Screen Sharing" and enable it
    "<wait10s><tab><tab><tab><tab><tab><spacebar>",

    // Navigate to "Remote Login" and enable it
    "<wait10s><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><spacebar>",

    // Quit System Settings
    "<wait10s><leftAltOn>q<leftAltOff>",
  ]
}

build {
  sources = ["source.tart-cli.tart"]

  provisioner "breakpoint" {
    disable = true
    note    = "waiting post-install"
  }

  provisioner "shell" {
    script = "${path.root}/scripts/initialize.bash"
    env = {
      "VM_BASE"  = "true",
      "USERNAME" = "admin",
      "PASSWORD" = "admin",
    }
  }
}
