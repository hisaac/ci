#!/usr/bin/env bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.bash" || exit 1

function main() {
	local -r temp_dir=$(mktemp --directory)
	local -r xcodes_cache_dir="${CACHE_DIR}/xcodes"
	mkdir -p "${xcodes_cache_dir}"

	local -ra xcode_versions=(
		"16.2.0"
		"16.4.0"
		"26.0.1"
		"26.5.0"
	)

	for version in "${xcode_versions[@]}"; do
		xcodes download "${version}" --directory "${temp_dir}"
		local xip_path
		xip_path=$(find "${temp_dir}" -type f -name "*.xip" | head -1)
		if [[ -z "${xip_path}" ]]; then
			log_error "No .xip file found for version ${version}"
			continue
		fi
		mv "${xip_path}" "${xcodes_cache_dir}/xcode-${version}.xip"
	done

	rm -rf "${temp_dir}"
}

main "$@"
