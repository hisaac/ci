packer {
  required_plugins {
    tart = {
      version = ">= 1.14.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "vm_base_name" {
  type = string
}

variable "vm_name" {
  type    = string
  default = "macos-14-ci-base"
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

build {
  sources = ["source.tart-cli.boot"]

  # Install Xcode Command Line Tools first, as it is required for many other scripts
  provisioner "shell" {
    script = "${path.root}/scripts/install-xcode-command-line-tools.bash"
  }

  provisioner "shell" {
    scripts = [
      "${path.root}/scripts/cleanup-spotlight-index.bash",
      "${path.root}/scripts/configure-ssh-known-hosts.bash",
      "${path.root}/scripts/configure-system.bash",
      "${path.root}/scripts/disable-protected-services.bash",
      "${path.root}/scripts/disable-spctl.bash",
      "${path.root}/scripts/install-homebrew.bash",
      "${path.root}/scripts/install-rosetta-2.bash",
    ]
  }

  provisioner "file" {
    source      = "${path.root}/data/.profile"
    destination = "~/.profile"
  }

  provisioner "shell" {
    inline = [
      "ln -s ~/.profile ~/.zprofile",
    ]
  }
}
