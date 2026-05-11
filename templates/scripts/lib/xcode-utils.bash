#!/bin/bash -euo pipefail

function select_xcode_version() {
	local -r xcode_version="$(normalize_version_number "$1")"
	local -r xcode_path="$(get_path_to_xcode_version "${xcode_version}")"
	local -r xcode_developer_dir="${xcode_path%/Contents/Developer}"
	sudo xcrun xcode-select --switch "${xcode_developer_dir}"
}

function normalize_version_number() {
	local version="$1"
	IFS='.' read -r major minor patch <<<"$version"
	major="${major:-0}"
	minor="${minor:-0}"
	patch="${patch:-0}"
	echo "${major}.${minor}.${patch}"
}

function enable_developer_mode() {
	# Enable developer mode for the current user
	# This is required to run certain Xcode commands without sudo
	sudo DevToolsSecurity -enable
	sudo dseditgroup -o edit -t group -a staff _developer
}

# This function runs in a subshell to avoid polluting the current directory
# (note the parentheses at the start of the function definition instead of curly braces)
function install_xcode_from_xip() (
	local -r xip_file_path="$1"

	local -r xip_file_name="$(basename "${xip_file_path}")"
	local -r xip_file_containing_dir="$(dirname "${xip_file_path}")"

	cd "${xip_file_containing_dir}" || exit 1
	xip --expand "$xip_file_name"

	local -r xcode_version="$(get_xcode_version_at_path "${xcode_cache_dir}/Xcode.app")"
	local -r xcode_app_name="Xcode-${xcode_version}.app"
	local -r xcode_app_destination="/Applications/${xcode_app_name}"

	mv "Xcode.app" "${xcode_app_destination}"
	rm "$xip_file_path"

	sudo xcode-select --switch "$xcode_app_destination"
	sudo xcrun xcodebuild -license accept
	sudo xcrun xcodebuild -runFirstLaunch

	# I'm not sure why we create this file, but xcodes does it, so we'll do it too.
	# ref: https://github.com/XcodesOrg/xcodes/blob/1.6.2/Sources/XcodesKit/XcodeInstaller.swift/#L746-L763
	local -r user_cache_dir="$(getconf DARWIN_USER_CACHE_DIR)"
	local -r macos_build_version="$(sw_vers -buildVersion)"
	local -r xcode_build_version="$(
		/usr/libexec/PlistBuddy -c "Print :ProductBuildVersion" "${xcode_app_destination}/Contents/version.plist"
	)"
	touch "${user_cache_dir}/com.apple.dt.Xcode.InstallCheckCache_${macos_build_version}_${xcode_build_version}"

	install_simulator_runtime "iOS"

	# If the Xcode version is 16.2.0, we need to also download the iOS 18.2 platform separately
	if [[ "${xcode_version}" == "16.2.0" ]]; then
		install_simulator_runtime "iOS" "18.2"
	fi

	# If the Xcode version is 16.2 or greater, we also check for newer components
	# (e.g. device support files)
	if [[ "$(printf '%s\n' "${xcode_version}" "16.2" | sort -V | head -n1)" == "16.2" ]]; then
		# Workaround to ensure that the device support files are downloaded correctly
		open -a "Xcode" &
		sleep 10
		osascript -e 'tell application "Xcode" to quit'

		sudo xcrun xcodebuild -runFirstLaunch -checkForNewerComponents
	fi

	prewarm_simulators
)

function install_simulator_runtime() {
	local -r simulator_runtime="${1}"
	local -r build_version="${2:-}"

	# Note: The `xcrun xcodebuild -downloadPlatform` command often (always?) throws a scary error at the end of the
	# download process, but this is a false alarm. The download still succeeds, so we can ignore this error.
	# The error message contains:
	# 	DVTDownloadable: Observed finish. Cancelling download asset.

	if [[ -n "${build_version}" ]]; then
		# If a build version is specified, download the specific platform version
		echo "Installing simulator runtime: ${simulator_runtime} with build version ${build_version}..."
		xcrun xcodebuild -downloadPlatform "${simulator_runtime}" -buildVersion "${build_version}"
	else
		# Otherwise, download the latest platform version
		echo "Installing simulator runtime: ${simulator_runtime}..."
		xcrun xcodebuild -downloadPlatform "${simulator_runtime}"
	fi

	# Wait for verification to complete
	while pgrep -fiq "simruntime"; do
		echo "Waiting for Simulator runtime verification to complete..."
		sleep 10
	done
	echo "No more simruntime processes found."
}

function prewarm_simulators() {
	# This bit is based on https://github.com/biscuitehh/yeetd/blob/main/Resources/prewarm_simulators.sh
	echo "Prewarming simulators..."

	while IFS= read -r simulator_udid; do
		# Remove leading and trailing quotes
		simulator_udid="${simulator_udid%\"}"
		simulator_udid="${simulator_udid#\"}"

		echo "Booting the Simulator..."
		xcrun simctl bootstatus "${simulator_udid}" -b
		xcrun simctl shutdown "${simulator_udid}"
	done < <(
		xcrun simctl list devices --json | jq '.devices[] | .[] | .udid'
	)

	# Wait for the "update_dyld_sim_shared_cache" process to finish to avoid wasting CPU cycles after boot
	# sources:
	#   - https://github.com/cirruslabs/macos-image-templates/blob/5b17f4e2644723b2124c5cf1c1def4ba81fc6db7/templates/xcode.pkr.hcl#L243-L252
	#   - https://apple.stackexchange.com/questions/412101/update-dyld-sim-shared-cache-is-taking-up-a-lot-of-memory
	#   - https://github.com/cirruslabs/macos-image-templates/issues/236
	#   - https://stackoverflow.com/a/68394101/9316533
	echo "Waiting for simulator shared cache to update..."

	local -r selected_xcode_version="$(get_selected_xcode_version)"
	if [[ "$(printf '%s\n' "${selected_xcode_version}" "16.4" | sort -V | head -n1)" == "16.4" ]]; then
		# If the selected Xcode version is 16.4 or greater, we can use the new simulator shared cache update process
		xcrun simctl runtime dyld_shared_cache update --all
	else
		# If the selected Xcode version is less than 16.4, we need to use the old simulator shared cache update process
		while pgrep -fiq "update_dyld_sim_shared_cache"; do
			echo "Simulator shared cache is still being updated..."
			sleep 2
		done
	fi
	echo "Simulator shared cache update complete"
}

# Check Methods #

function check_xcode_version_is_selected() {
	local -r xcode_version="$(normalize_version_number "$1")"
	local -r selected_xcode_version="$(get_selected_xcode_version)"
	if [[ "${selected_xcode_version}" == "${xcode_version}" ]]; then
		return 0
	else
		return 1
	fi
}

function check_xcode_version_is_installed() {
	local -r xcode_version="$(normalize_version_number "$1")"

	# If the desired Xcode version is installed, return true
	for installed_xcode_path in $(get_paths_to_installed_xcode_versions); do
		local installed_xcode_version
		installed_xcode_version="$(get_xcode_version_at_path "${installed_xcode_path}")"

		if [[ "${installed_xcode_version}" == "${xcode_version}" ]]; then
			return 0
		fi
	done

	# If we've reached this point, it means that the desired Xcode version is not installed
	return 1
}

# Get Methods #

function get_selected_xcode_version() {
	local -r selected_xcode_developer_dir="$(xcrun xcode-select --print-path)"
	local -r selected_xcode_app_path="${selected_xcode_developer_dir%/Contents/Developer}"
	local -r selected_xcode_version="$(get_xcode_version_at_path "${selected_xcode_app_path}")"
	local -r normalized_version="$(normalize_version_number "${selected_xcode_version}")"
	echo "${normalized_version}"
}

function get_xcode_version_at_path() {
	local -r xcode_path="$1"
	local -r xcode_version="$(
		defaults read "${xcode_path}/Contents/Info.plist" CFBundleShortVersionString
	)"
	local -r normalized_version="$(normalize_version_number "${xcode_version}")"
	echo "${normalized_version}"
}

function get_path_to_xcode_version() {
	local -r xcode_version="$(normalize_version_number "$1")"

	local installed_xcode_version
	local path_to_xcode_version

	for installed_xcode_path in $(get_paths_to_installed_xcode_versions); do
		installed_xcode_version="$(get_xcode_version_at_path "${installed_xcode_path}")"

		if [[ "${installed_xcode_version}" == "${xcode_version}" ]]; then
			path_to_xcode_version=$installed_xcode_path
			break
		fi
	done
	echo "${path_to_xcode_version}"
}

function get_paths_to_installed_xcode_versions() {
	local -a installed_xcode_paths
	while read -r xcode_path; do
		installed_xcode_paths+=("${xcode_path}")
	done < <(
		find /Applications -maxdepth 1 -type d -name "Xcode*.app"
	)
	echo "${installed_xcode_paths[@]}"
}
