#!/usr/bin/env bash
#MISE description="Downloads requests Xcode versions and kicks off a Packer build for Sonoma using Tart"
#USAGE flag "--macos-version <macos_version>" {
#USAGE 	help    "The macOS version to use to create the VM image"
#USAGE 	default "latest"
#USAGE }
#USAGE flag "--xcode-versions <xcode_versions>" {
#USAGE 	help    "A comma separated list of the Xcode versions to install on the VM image"
#USAGE }
#USAGE flag "--simulator-runtimes <simulator_runtimes>" {
#USAGE 	help    "A comma separated list of the simulator runtimes to install on the VM image <iOS|watchOS|tvOS|visionOS>"
#USAGE }

set -euo pipefail
IFS=$'\n\t'

function main() {
	local -r packer_template="${MISE_PROJECT_ROOT}/templates/macos.base.pkr.hcl"

	# download_xcode_versions "${usage_xcode_versions:---latest}"

	usage_macos_version=">= 14"
	usage_xcode_versions='15.1.0,15.4.0'
	usage_simulator_runtimes='iOS'

	packer init -upgrade "${packer_template}"
	packer build \
		-var "macos_version=\"${usage_macos_version}\"" \
		-var "xcode_versions=\"[${usage_xcode_versions}]\"" \
		-var "simulator_runtimes=\"[${usage_simulator_runtimes}]\"" \
		"${packer_template}"
}

function download_xcode_versions() {
	local -a xcode_versions
	IFS=',' read -ra xcode_versions <<< "${1}"
	readonly xcode_versions

	local -r xcodes_download_dir="${MISE_PROJECT_ROOT}/xcodes"
	rm -rf "${xcodes_download_dir}"
	mkdir -p "${xcodes_download_dir}"

	xcodes update >/dev/null

	for version in "${xcode_versions[@]}"; do
		echo "Downloading Xcode ${version}"
		xcodes download "$version" --directory "${xcodes_download_dir}"
	done
}

main "$@"
