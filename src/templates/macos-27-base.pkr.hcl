packer {
  required_plugins {
    ipsw = {
      version = ">= 0.1.10"
      source  = "github.com/torarnv/ipsw"
    }

    tart = {
      version = ">= 1.21.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "macos_version" {
  type    = string
  default = "27"
}

variable "vm_name" {
  type    = string
  default = "macos-27-base"
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

source "tart-cli" "tart" {
  from_ipsw          = data.ipsw.macos.url
  vm_name            = var.vm_name
  cpu_count          = 4
  memory_gb          = 8
  disk_size_gb       = 100
  disk_format        = "asif"
  ssh_password       = var.vm_password
  ssh_username       = var.vm_username
  ssh_timeout        = "180s"
  recovery_partition = "keep"
  run_extra_args = [
    "--no-audio",
    "--vnc-experimental",
    "--provisioning-opts=${join(",", [
      "fullName=${var.vm_username}",
      "username=${var.vm_username}",
      "password=${var.vm_password}",
      "logsInAutomatically=true",
      "enablesRemoteLogin=true",
    ])}",
  ]

  // A (hopefully) temporary workaround for Virtualization.Framework's
  // installation process not fully finishing in a timely manner
  create_grace_time = "30s"
}

build {
  sources = ["source.tart-cli.tart"]

  provisioner "shell" {
    script = "scripts/system_config/wait-for-spotlight.bash"
  }
}
