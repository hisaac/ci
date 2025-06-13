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
  default = "macos-14-disable-sip"
}

variable "vm_username" {
  type    = string
  default = "admin"
}

variable "vm_password" {
  type    = string
  default = "admin"
}

locals {
  boot_command = [
    # Skip over "Macintosh" and select "Options" to boot into recovery mode
    "<wait60s><right><right><enter>",

    # Open Terminal
    "<wait10s><leftAltOn>T<leftAltOff>",

    # Disable SIP
    "<wait10s>csrutil disable<enter>",
    "<wait10s>y<enter>",
    "<wait10s>${var.vm_password}<enter>",

    # Shutdown
    "<wait10s>halt<enter>",
  ]
}

source "tart-cli" "recovery" {
  vm_name            = var.vm_name
  vm_base_name       = var.vm_base_name
  ssh_username       = var.vm_username
  ssh_password       = var.vm_password
  boot_command       = local.boot_command
  recovery_partition = "keep"
  recovery           = true
}

build {
  sources = ["source.tart-cli.recovery"]
}
