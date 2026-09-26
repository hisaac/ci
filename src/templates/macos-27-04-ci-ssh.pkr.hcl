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
  default = "macos-27-03-ci-recovery"
}

variable "vm_name" {
  type    = string
  default = "macos-27-04-ci-ssh"
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

source "tart-cli" "ci-ssh" {
  # Clone the preceding stage so each attempt starts clean.
  vm_base_name = var.vm_base_name
  vm_name      = var.vm_name
  ssh_password = var.vm_password
  ssh_username = var.vm_username
  ssh_timeout  = "180s"
  run_extra_args = [
    "--no-audio",
    "--vnc-experimental",
  ]

}

build {
  sources = ["source.tart-cli.ci-ssh"]
}
