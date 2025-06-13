#!/usr/bin/env bash -euo pipefail

#MISE description="Downloads requests Xcode versions and kicks off a Packer build for using Tart"
#USAGE flag "--macos-version <macos_version>" {
#USAGE 	help    "The macOS version to use to create the VM image"
#USAGE 	default "14"
#USAGE }

function main() {
	case "${usage_macos_version}" in
		14)
			build_template "${MISE_PROJECT_ROOT}/templates/macos-14-vanilla.pkr.hcl"
			build_template "${MISE_PROJECT_ROOT}/templates/macos-14-base-ci-disable-sip.pkr.hcl"
			build_template "${MISE_PROJECT_ROOT}/templates/macos-14-base-ci-configure.pkr.hcl"
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

function build_template() {
	local -r template_path="$1"
	packer init -upgrade "${template_path}"
	packer build "${template_path}"
}

main "$@"
