#!/usr/bin/env bash

#MISE description="Downloads requests Xcode versions and kicks off a Packer build for Sonoma using Tart"
#USAGE flag "--macos-version <macos_version>" {
#USAGE 	help    "The macOS version to use to create the VM image"
#USAGE 	default "15"
#USAGE }

set -o errexit  # Exit on error
set -o nounset  # Exit on unset variable
set -o pipefail # Exit on pipe failure
IFS=$'\n\t'

if [[ "${TRACE:-}" == true ]]; then
	set -o xtrace # Trace the execution of the script (debug)
fi

function main() {
	declare -r packer_var_file="${MISE_PROJECT_ROOT}/templates/macos-${usage_macos_version}.pkrvars.hcl"
	declare -r packer_template="${MISE_PROJECT_ROOT}/templates/macos.base.pkr.hcl"
	packer init -upgrade "${packer_template}"
	packer build -var-file="${packer_var_file}" "${packer_template}"
}

trap exit_handler EXIT
function exit_handler() {
	declare -ri exit_code="$?"
	declare -r script_name="${0##*/}"
	echo -e "\n==> ${script_name} exited with code ${exit_code}"
}

main "$@"
