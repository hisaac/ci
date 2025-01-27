# `hisaac/ci`

This is my place to experiment with various CI/CD tools and techniques.

(Also see [`hisaac/workbench`](https://github.com/hisaac/workbench) where I'm experimenting with writing a Swift CLI tool for inspecting, configuring, and managing macOS VMs and machines.)

## Current Explorations

My current explorations are around using [Packer](https://packer.io) and [Tart](https://tart.run) to build macOS VM images for use in CI/CD pipelines.

- [`sequoia.base.pkr.hcl`](templates/sequoia.base.pkr.hcl) - A base image for macOS.
- [`sequoia.configured.pkr.hcl`](templates/sequoia.configured.pkr.hcl) - A base image for macOS with Xcode and the iOS simulator installed.
- [`initialize.bash`](scripts/initialize.bash) - A script to initialize the macOS VM with the necessary tools and settings.

Next I'm going to experiment with using [Ansible](https://ansible.com) to modify VM images after they've been built.
