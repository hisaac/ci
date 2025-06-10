#!/usr/bin/env bash -euo pipefail

#MISE description="Downloads requests Xcode versions and kicks off a Packer build for using Tart"
#USAGE flag "--macos-version <macos_version>" {
#USAGE 	help    "The macOS version to use to create the VM image"
#USAGE 	default "14"
#USAGE }

function main() {
	case "${usage_macos_version}" in
		14)
			packer init -upgrade "${MISE_PROJECT_ROOT}/templates/macos-14-base.pkr.hcl"
			packer init -upgrade "${MISE_PROJECT_ROOT}/templates/macos-14-disable-sip.pkr.hcl"

			packer build "${MISE_PROJECT_ROOT}/templates/macos-14-base.pkr.hcl"
			packer build "${MISE_PROJECT_ROOT}/templates/macos-14-disable-sip.pkr.hcl"
			;;
		15)
			echo "macOS 15 is not yet supported"
			;;
		26)
			echo "macOS 26 is not yet supported"
			;;
		*)
			echo "macOS ${usage_macos_version} is not yet supported"
			;;
	esac
}

main "$@"
