packer {
  required_plugins {
    ansible = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/ansible"
    }

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
  validation {
    condition     = can(regex("^14", var.macos_version)) || can(regex("^15", var.macos_version))
    error_message = "Only macOS 14 and 15 are supported."
  }
}

variable "macos_14_sonoma_boot_command" {
  type = list(string)
}

variable "macos_15_sequoia_boot_command" {
  type = list(string)
}

data "ipsw" "macos" {
  os      = "macOS"
  version = var.macos_version
  device  = "VirtualMac2,1"
}

locals {
  version_string = join(".", [
    data.ipsw.macos.version_components.major,
    data.ipsw.macos.version_components.minor,
    data.ipsw.macos.version_components.patch,
  ])

  boot_command = (
    can(regex("^14", data.ipsw.macos.version)) ? var.macos_14_sonoma_boot_command :
    can(regex("^15", data.ipsw.macos.version)) ? var.macos_15_sequoia_boot_command :
    []
  )
}

source "tart-cli" "tart" {
  from_ipsw          = data.ipsw.macos.url
  vm_name            = "macos-${local.version_string}-base"
  cpu_count          = 4
  memory_gb          = 8
  disk_size_gb       = 100
  ssh_password       = "admin"
  ssh_username       = "admin"
  ssh_timeout        = "300s"
  recovery_partition = "keep"
  boot_command       = local.boot_command

  # A (hopefully) temporary workaround for Virtualization.Framework's
  # installation process not fully finishing in a timely manner
  create_grace_time = "30s"

  # Uncomment for quiet and headless mode
  # headless = true
  # run_extra_args = [
  #   "--no-audio",
  # ]
}

build {
  sources = ["source.tart-cli.tart"]

  # provisioner "ansible" {
  #   playbook_file    = "playbooks/playbook-system-updater.yml"
  #   ansible_env_vars = ["ANSIBLE_HOST_KEY_CHECKING=False"]
  #   use_proxy        = false
  # }
}
