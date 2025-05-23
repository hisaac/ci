packer {
  required_plugins {
    tart = {
      version = ">= 1.14.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "vm_name" {
  type = string
}

variable "username" {
  type    = string
  default = "admin"
}

variable "password" {
  type    = string
  default = "admin"
}

source "tart-cli" "tart" {
  vm_name      = var.vm_name
  recovery     = true
  ssh_username = var.username
  ssh_password = var.password

  boot_command = [
    # Skip over "Macintosh" and select "Options" to boot into recovery mode
    "<wait60s><right><right><enter>",

    # Open Terminal
    "<wait10s><leftAltOn>T<leftAltOff>",

    # Disable SIP
    "<wait10s>csrutil disable<enter>",
    "<wait10s>y<enter>",
    "<wait10s>${password}<enter>",

    # Shutdown
    "<wait10s>halt<enter>",
  ]
}

build {
  sources = ["source.tart-cli.tart"]
}
