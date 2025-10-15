packer {
  required_plugins {
    tart = {
      version = ">= 1.14.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "vm_base_name" {
  type    = string
  default = "macos-14-ci-base"
}

variable "vm_name" {
  type    = string
  default = "macos-14-ci-ios"
}

variable "vm_username" {
  type    = string
  default = "admin"
}

variable "vm_password" {
  type    = string
  default = "admin"
}

source "tart-cli" "boot" {
  vm_name            = var.vm_name
  vm_base_name       = var.vm_base_name
  ssh_username       = var.vm_username
  ssh_password       = var.vm_password
  recovery_partition = "keep"
}

locals {
  xcodes_cache_dir      = "/Users/${var.vm_username}/Downloads/"
  default_xcode_version = "16.2"
}

build {
  sources = ["source.tart-cli.boot"]

  provisioner "file" {
    sources = [
      "${path.root}/data/xcodes/Xcode-15.1.0+15C65.xip",
      "${path.root}/data/xcodes/Xcode-15.4.0+15F31d.xip",
      "${path.root}/data/xcodes/Xcode-16.2.0+16C5032a.xip",
    ]
    destination = local.xcodes_cache_dir
  }

  provisioner "file" {
    source      = "${path.root}/scripts/lib/xcode-utils.bash"
    destination = "/tmp/"
  }

  provisioner "shell" {
    scripts = [
      "${path.root}/scripts/configure-xcode.bash",
      "${path.root}/scripts/install-cached-xcode-versions.bash",
    ]
    env = {
      XCODE_CACHE_DIR       = local.xcodes_cache_dir
      DEFAULT_XCODE_VERSION = local.default_xcode_version
    }
  }

  provisioner "shell" {
    script = "${path.root}/scripts/install-developer-certificates.bash"
  }
}
