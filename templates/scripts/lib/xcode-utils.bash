#!/bin/bash

function select_xcode_version() {
	local -r xcode_version="$(normalize_xcode_version "$1")"
	local -r xcode_path="$(get_path_to_xcode_version "${xcode_version}")"
	local -r xcode_developer_dir="${xcode_path%/Contents/Developer}"
	sudo /usr/bin/xcrun xcode-select --switch "${xcode_developer_dir}"
}

function install_xcode_version() {
	local -r xcode_version="$(normalize_xcode_version "$1")"
	xcodes update &>/dev/null
	xcodes install "${xcode_version}" --experimental-unxip
}

function check_user_has_admin_privileges() {
	local -r user="$1"
	local -r user_group_membership="$(id -Gn "$user")"
	if [[ $user_group_membership == *"admin"* ]]; then
		return 0
	else
		return 1
	fi
}

function normalize_xcode_version() {
	local version="$1"
	IFS='.' read -r major minor patch <<< "$version"
	major="${major:-0}"
	minor="${minor:-0}"
	patch="${patch:-0}"
	echo "${major}.${minor}.${patch}"
}

function check_xcode_version_is_selected() {
	local -r xcode_version="$(normalize_xcode_version "$1")"
	local -r selected_xcode_version="$(get_selected_xcode_version)"
	if [[ "${selected_xcode_version}" == "${xcode_version}" ]]; then
		return 0
	else
		return 1
	fi
}

function check_xcode_version_is_installed() {
	local -r xcode_version="$(normalize_xcode_version "$1")"

	# Find paths to all locally installed Xcode versions
	local -a installed_xcode_paths
	while read -r xcode_path; do
		installed_xcode_paths+=("${xcode_path}")
	done < <(
		/usr/bin/mdfind -onlyin "/" "kMDItemCFBundleIdentifier='com.apple.dt.Xcode'"
	)

	# If the desired Xcode version is installed, return true
	for installed_xcode_path in "${installed_xcode_paths[@]}"; do
		local installed_xcode_version
		installed_xcode_version="$(get_xcode_version_at_path "${installed_xcode_path}")"

		if [[ "$(normalize_xcode_version "${installed_xcode_version}")" == "$(normalize_xcode_version "${xcode_version}")" ]]; then
			return 0
		fi
	done

	# If we've reached this point, it means that the desired Xcode version is not installed
	return 1
}

function get_selected_xcode_version() {
	local -r selected_xcode_developer_dir="$(/usr/bin/xcrun xcode-select --print-path)"
	local -r selected_xcode_app_path="${selected_xcode_developer_dir%/Contents/Developer}"
	local -r selected_xcode_version="$(get_xcode_version_at_path "${selected_xcode_app_path}")"
	normalize_xcode_version "${selected_xcode_version}"
}

function get_xcode_version_at_path() {
	local -r xcode_path="$1"
	local xcode_version

	# First try getting the version from Spotlight's metadata database
	xcode_version="$(/usr/bin/mdls --raw -name "kMDItemVersion" "${xcode_path}")"
	readonly xcode_version

	# If the Xcode version is not found in Spotlight's metadata database,
	# try reading it from the Info.plist
	if [[ "${xcode_version}" == *"null"* ]]; then
		xcode_version="$(
			/usr/bin/defaults read "${xcode_path}/Contents/Info.plist" CFBundleShortVersionString
		)"
	fi

	normalize_xcode_version "${xcode_version}"
}

function get_path_to_xcode_version() {
	local -r xcode_version="$(normalize_xcode_version "$1")"

	for installed_xcode_path in $(get_paths_to_installed_xcode_versions); do
		local installed_xcode_version
		installed_xcode_version="$(get_xcode_version_at_path "${installed_xcode_path}")"

		if [[ "${installed_xcode_version}" == "${xcode_version}" ]]; then
			echo "${installed_xcode_path}"
			return
		fi
	done
}

function get_paths_to_installed_xcode_versions() {
	local -a installed_xcode_paths
	while read -r xcode_path; do
		installed_xcode_paths+=("${xcode_path}")
	done < <(
		/usr/bin/mdfind -onlyin "/" "kMDItemCFBundleIdentifier='com.apple.dt.Xcode'"
	)
	echo "${installed_xcode_paths[@]}"
}
