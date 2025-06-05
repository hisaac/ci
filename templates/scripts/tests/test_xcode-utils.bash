#!/bin/bash

# shellcheck source=../lib/base.bash
source "$(dirname -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")")/lib/base.bash"

# shellcheck source=../lib/xcode-utils.bash
source "$(dirname -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")")/lib/xcode-utils.bash"

function main() {
	# Color codes
	GREEN='\033[0;32m'
	RED='\033[0;31m'
	NC='\033[0m' # No Color
	CHECK='✔'
	CROSS='✘'

	for fn in $(compgen -A function test_); do
		if $fn; then
			echo -e "${GREEN}${CHECK} $fn passed${NC}"
		else
			echo -e "${RED}${CROSS} $fn failed${NC}"
		fi
	done
}

function test_get_paths_to_installed_xcode_versions() {
	local paths
	paths=$(get_paths_to_installed_xcode_versions)
	[[ -n "$paths" ]]; return $?
}

function test_get_selected_xcode_version() {
	local version
	version=$(get_selected_xcode_version)
	[[ -n "$version" ]]; return $?
}

function test_get_xcode_version_at_path() {
       local all_ok=0
       local xcode_paths=()
       while IFS= read -r path; do
               xcode_paths+=("${path}")
       done < <(get_paths_to_installed_xcode_versions)
       for xcode_path in "${xcode_paths[@]}"; do
               local version
               version=$(get_xcode_version_at_path "$xcode_path")
               [[ -n "$version" ]] || all_ok=1
       done
       return $all_ok
}

function test_get_path_to_xcode_version() {
       local all_ok=0
       local xcode_paths=()
       while IFS= read -r path; do
               xcode_paths+=("${path}")
       done < <(get_paths_to_installed_xcode_versions)
       for xcode_path in "${xcode_paths[@]}"; do
               local version found_path
               version=$(get_xcode_version_at_path "$xcode_path")
               found_path=$(get_path_to_xcode_version "$version")
               [[ "$found_path" == "$xcode_path" ]] || all_ok=1
       done
       return $all_ok
}

function test_check_xcode_version_is_installed() {
       local all_ok=0
       local xcode_paths=()
       while IFS= read -r path; do
               xcode_paths+=("${path}")
       done < <(get_paths_to_installed_xcode_versions)
       for xcode_path in "${xcode_paths[@]}"; do
               local version
               version=$(get_xcode_version_at_path "$xcode_path")
               check_xcode_version_is_installed "$version" || all_ok=1
       done
       return $all_ok
}

function test_check_xcode_version_is_selected() {
	local selected_version
	selected_version=$(get_selected_xcode_version)
	check_xcode_version_is_selected "$selected_version"; return $?
}

function test_normalize_xcode_version() {
	local all_ok=0
	for v in "16.2" "16.2.0" "15" "15.1.0" "15.0"; do
		local norm
		norm=$(normalize_xcode_version "$v")
		if [[ "$v" == "16.2" && "$norm" != "16.2.0" ]]; then all_ok=1; fi
		if [[ "$v" == "15" && "$norm" != "15.0.0" ]]; then all_ok=1; fi
		# No output
	done
	return $all_ok
}

main "$@"
