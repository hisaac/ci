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
  vm_name      = "virtual-keyboard-tester"
  ssh_password = "admin"
  ssh_username = "admin"
  ssh_timeout  = "300s"

  run_extra_args = [
    "--no-audio",
    "--suspendable",
  ]

  // A (hopefully) temporary workaround for Virtualization.Framework's
  // installation process not fully finishing in a timely manner
  create_grace_time = "30s"

  boot_command = [
    "<wait500s>",
    // // hello, hola, bonjour, etc.
    // "<wait60s><spacebar>",

    // // Language: most of the times we have a list of "English"[1], "English (UK)", etc. with
    // // "English" language already selected. If we type "english", it'll cause us to switch
    // // to the "English (UK)", which is not what we want. To solve this, we switch to some other
    // // language first, e.g. "Italiano" and then switch back to "English". We'll then jump to the
    // // first entry in a list of "english"-prefixed items, which will be "English".
    // //
    // // [1]: should be named "English (US)", but oh well 🤷
    // "<wait30s>italiano<esc>english<enter>",

    // // Select Your Country and Region
    // "<wait30s>united states<leftShiftOn><tab><leftShiftOff><spacebar>",

    // // Written and Spoken Languages
    // "<wait10s><leftShiftOn><tab><leftShiftOff><spacebar>",

    // // Accessibility
    // "<wait10s><tab><tab><spacebar>",
    // "<wait10s><tab><spacebar>",

    // // Testing
    // "<wait5s>llllssssuuuuppppeeeerrrr",
    // "<wait1s><leftSuperOn><wait1s><leftSuperOff>",
    // "<wait1s><leftSuperOn><wait1s><leftSuperOff>",
    // "<wait5s>rrrrssssuuuuppppeeeerrrr",
    // "<wait1s><rightSuperOn><wait1s><rightSuperOff>",
    // "<wait1s><rightSuperOn><wait1s><rightSuperOff>",

    // "<wait5s>llllaaaalllltttt",
    // "<wait1s><leftAltOn><wait1s><leftAltOff>",
    // "<wait1s><leftAltOn><wait1s><leftAltOff>",
    // "<wait5s>rrrraaaalllltttt",
    // "<wait1s><rightAltOn><wait1s><rightAltOff>",
    // "<wait1s><rightAltOn><wait1s><rightAltOff>",

    // "<wait5s>llllmmmmeeeettttaaaa",
    // "<wait1s><leftMetaOn><wait1s><leftMetaOff>",
    // "<wait1s><leftMetaOn><wait1s><leftMetaOff>",
    // "<wait5s>rrrrmmmmeeeettttaaaa",
    // "<wait1s><rightMetaOn><wait1s><rightMetaOff>",
    // "<wait1s><rightMetaOn><wait1s><rightMetaOff>",
  ]
}

build {
  sources = ["source.tart-cli.tart"]

  provisioner "breakpoint" {
    disable = false
    note    = "waiting post-keyboard-test"
  }
}
