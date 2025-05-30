#!/usr/bin/env bash -euo pipefail

#MISE description="Downloads requests Xcode versions and kicks off a Packer build for using Tart"
#USAGE flag "--macos-version <macos_version>" {
#USAGE 	help    "The macOS version to use to create the VM image"
#USAGE 	default "14"
#USAGE }

function main() {
	packer init -upgrade "${MISE_PROJECT_ROOT}/templates/macos-${usage_macos_version}-base.pkr.hcl"
	# packer build "${MISE_PROJECT_ROOT}/templates/macos-${usage_macos_version}-base.pkr.hcl"
	# packer build "${MISE_PROJECT_ROOT}/templates/macos-${usage_macos_version}-disable-sip.pkr.hcl"
	packer build "${MISE_PROJECT_ROOT}/templates/macos-${usage_macos_version}-configured.pkr.hcl"
}

main "$@"
