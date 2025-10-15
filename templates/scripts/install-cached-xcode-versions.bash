#!/bin/bash -euo pipefail

# shellcheck source=lib/xcode-utils.bash
source "/tmp/xcode-utils.bash"

function main() {
	local -r xcode_cache_dir="${1:-${XCODE_CACHE_DIR:-/tmp/}}"
	local -r default_xcode_version="${2:-${DEFAULT_XCODE_VERSION:-}}"

	enable_developer_mode

	for xip_file in "${xcode_cache_dir}"/Xcode-*.xip; do
		if [[ -f "$xip_file" ]]; then
			install_xcode_from_xip "$xip_file"
		else
			echo "No Xcode .xip files found in ${xcode_cache_dir}."
			echo "Please ensure you have downloaded the Xcode versions you want to install."
			exit 1
		fi
	done

	if [[ -n "${default_xcode_version}" ]]; then
		select_xcode_version "${default_xcode_version}"
	else
		sudo xcode-select --reset
	fi
}

main "$@"
