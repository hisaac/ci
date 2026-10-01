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

  provisioner "shell" {
    script           = "${path.root}/scripts/auth_config/enable-passwordless-sudo.bash"
    environment_vars = ["USERNAME=${var.vm_username}", "PASSWORD=${var.vm_password}"]
  }

  provisioner "shell" {
    script = "${path.root}/scripts/xcode_clt/install-xcode-command-line-tools.bash"
  }

  provisioner "shell" {
    script           = "${path.root}/scripts/homebrew/install-homebrew.bash"
    environment_vars = ["NONINTERACTIVE=1"]
  }

  provisioner "shell" {
    script = "${path.root}/scripts/mise/install-mise.bash"
  }

  provisioner "shell" {
    inline = ["mkdir -p /tmp/hisaac-ci-shell-config"]
  }

  provisioner "file" {
    source      = "${path.root}/data/"
    destination = "/tmp/hisaac-ci-shell-config/"
  }

  provisioner "shell" {
    scripts = [
      "${path.root}/scripts/system_config/install-shell-config.bash",
      "${path.root}/scripts/mise/install-mise-tools.bash",
      "${path.root}/scripts/tart/install-tart-guest-agent.bash",
    ]
    environment_vars = ["DATA_DIRECTORY=/tmp/hisaac-ci-shell-config"]
  }

  provisioner "shell" {
    inline = [
      "xcode-select --print-path",
      "/bin/zsh -lc 'brew --version && mise --version && ruby --version && node --version && python --version'",
      "/bin/bash -lc 'brew --version && mise --version && ruby --version && node --version && python --version'",
    ]
  }

  provisioner "shell" {
    script           = "${path.root}/scripts/auth_config/configure-ssh-tcc.bash"
    environment_vars = ["DATA_DIRECTORY=/tmp/hisaac-ci-shell-config"]
  }

  provisioner "shell" {
    inline = ["rm -rf /tmp/hisaac-ci-shell-config"]
  }

  provisioner "shell" {
    script = "${path.root}/scripts/system_config/wait-for-spotlight.bash"
  }

  provisioner "shell" {
    scripts = [
      "${path.root}/scripts/system_config/dismiss-notifications.applescript",
      "${path.root}/scripts/system_config/quit-applications.applescript",
    ]
    execute_command = "{{ .Vars }} /usr/bin/osascript '{{ .Path }}'"
  }
}
