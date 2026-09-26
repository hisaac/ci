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
  default = "macos-27-02-ci-gui"
}

variable "vm_name" {
  type    = string
  default = "macos-27-03-ci-recovery"
}

variable "vm_password" {
  type      = string
  sensitive = true
  default   = "admin"
}

source "tart-cli" "ci-recovery" {
  # Clone the preceding stage so each attempt starts clean.
  vm_base_name = var.vm_base_name
  vm_name      = var.vm_name
  communicator = "none"
  recovery     = true
  run_extra_args = [
    "--no-audio",
    "--vnc-experimental",
  ]
  boot_command = [
    # Skip over "Macintosh" and select "Options" to boot into macOS Recovery
    "<wait60s><right><right><enter>",
    # Open Terminal
    "<wait10s><leftAltOn>T<leftAltOff>",
    # Disable SIP
    "<wait10s>csrutil disable<enter>",
    "<wait10s>y<enter>",
    "<wait10s>${var.vm_password}<enter>",
    # Shutdown
    "<wait10s>halt<enter>"
  ]
}

build {
  sources = ["source.tart-cli.ci-recovery"]
}
