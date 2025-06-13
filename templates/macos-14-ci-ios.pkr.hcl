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

variable "xcode_versions" {
  type    = list(string)
  default = ["15.1", "15.4", "16.2", "16.4"]
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


}
