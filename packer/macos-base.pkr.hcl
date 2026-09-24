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
