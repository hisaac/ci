packer {
  required_plugins {
    tart = {
      version = ">= 1.14.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

source "tart-cli" "tart" {
  vm_base_name = "sequoia-base"
  vm_name      = "sequoia-configured"
  ssh_password = "admin"
  ssh_username = "admin"
  ssh_timeout  = "300s"
}

build {
  sources = ["source.tart-cli.tart"]

  provisioner "breakpoint" {
    disable = true
    note    = "waiting post-install"
  }

  provisioner "file" {
    source      = pathexpand("~/caches/xcode/Xcode-16.2.0+16C5032a.xip")
    destination = "/Users/admin/Downloads/Xcode-16.2.0.xip"
  }

  provisioner "file" {
    source      = pathexpand("~/caches/simruntime/iphonesimulator_18.2_22C150.dmg")
    destination = "/Users/admin/Downloads/iphonesimulator_18.2.dmg"
  }

  provisioner "shell" {
    script = "${path.root}/scripts/initialize.bash"
    env = {
      "VM_BASE"  = "false",
      "USERNAME" = "admin",
      "PASSWORD" = "admin",
    }
  }

  provisioner "breakpoint" {
    disable = true
    note    = "waiting post-initialization"
  }
}
