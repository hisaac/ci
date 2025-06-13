#!/bin/bash -euo pipefail

# shellcheck source=lib/xcode-utils.bash
source "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")/lib/xcode-utils.bash"

function main() {
	local -r xcode_versions="${1:-${XCODE_VERSIONS}}"
	local -r simulator_runtimes="${2:-${SIMULATOR_RUNTIMES}}"
	unset USERNAME PASSWORD XCODE_VERSIONS SIMULATOR_RUNTIMES

	for xcode_version in ${xcode_versions//,/ }; do
		install_xcode "${xcode_version}"
		if [[ -n "${simulator_runtimes}" ]]; then
			install_simulator_runtimes "${simulator_runtimes}"
		fi
		prewarm_simulators
	done

	echo "==> Xcode: Disabling default simulator set creation"
	# CoreSimulator now supports a mode in which the developer has full control over devices in the default device set.
	# The system won’t create default devices nor manage pairing relationships between watches and phones in that set when placed into this mode.
	# source: https://developer.apple.com/documentation/xcode-release-notes/xcode-16_2-release-notes#Simulator
	defaults write com.apple.CoreSimulator EnableDefaultSetCreation -bool NO

	echo "==> Xcode: Disabling Xcode Cloud upsell"
	defaults write com.apple.dt.Xcode XcodeCloudUpsellPromptEnabled -bool false

	echo "==> Xcode: Disabling file extensions"
	defaults write com.apple.dt.Xcode IDEFileExtensionDisplayMode -int 1
}

function install_xcode() {
	(
		# The xip tool expands to the current directory.
		# We'll `cd` into the downloads directory in a subshell to not pollute the current directory.
		cd /tmp/xcodes || exit 1

		for xip_file in Xcode-*.xip; do
			if [[ -f "$xip_file" ]]; then
				echo "Unzipping Xcode archive: $xip_file"
				xip --expand "$xip_file"
				local xcode_app_name="${xip_file%.xip}.app"
				echo "Moving Xcode to /Applications/${xcode_app_name}"
				mv "Xcode.app" "/Applications/${xcode_app_name}"
				echo "Xcode installed to /Applications/${xcode_app_name}"
				rm "$xip_file"
			fi
		done
	)

	rm -rf /tmp/xcodes

	# Most of these steps are based on xcodes' install process
	# We could just use xcodes, but I want to learn how to do this manually

	sudo DevToolsSecurity -enable
	sudo dseditgroup -o edit -t group -a staff _developer

	local -ra installed_xcode_paths="$(get_paths_to_installed_xcode_versions)"

	for xcode_path in "${installed_xcode_paths[@]}"; do
		local xcode_version
		xcode_version="$(get_xcode_version_at_path "$xcode_path")"
		sudo xcode-select --switch "$xcode_path"
		sudo xcodebuild -license accept

		if [[ "$(printf '%s\n' "${xcode_version}" "16.2" | sort -V | head -n1)" == "16.2" ]]; then
			# If the Xcode version is 16.2 or greater, we can also check for newer components
			sudo xcrun xcodebuild -runFirstLaunch -checkForNewerComponents
		else
			sudo xcrun xcodebuild -runFirstLaunch
		fi

		# TODO: Figure out what this is actually doing.
		# I'm not sure why we create this file, but xcodes does it, so we'll do it too.
		local -r user_cache_dir="$(getconf DARWIN_USER_CACHE_DIR)"
		local -r macos_build_version="$(sw_vers -buildVersion)"
		local -r xcode_build_version="$(
			/usr/libexec/PlistBuddy -c "Print :ProductBuildVersion" "${xcode_path}/Contents/version.plist"
		)"
		touch "${user_cache_dir}/com.apple.dt.Xcode.InstallCheckCache_${macos_build_version}_${xcode_build_version}"
	done
}

function install_simulator_runtimes() {
	local -r arg_simulator_runtimes="${1}"
	local -r simulator_runtimes="$(echo "${arg_simulator_runtimes}" | tr ',' ' ')"
	for simulator_runtime in ${simulator_runtimes}; do
		echo "Installing simulator runtime: ${simulator_runtime}..."
		xcrun xcodebuild -downloadPlatform "${simulator_runtime}"
	done
	sudo xcrun xcodebuild -runFirstLaunch -checkForNewerComponents
}

function prewarm_simulators() {
	# This bit is based on https://github.com/biscuitehh/yeetd/blob/main/Resources/prewarm_simulators.sh
	echo "Prewarming simulators..."

	local -r simulator_udids=("$(xcrun simctl list devices --json | jq '.devices[] | .[] | .udid')")
	for simulator_udid in "${simulator_udids[@]}"; do
		# Remove leading and trailing quotes
		simulator_udid="${simulator_udid%\"}"
		simulator_udid="${simulator_udid#\"}"

		echo "Booting the Simulator..."
		xcrun simctl bootstatus "${simulator_udid}" -b
		xcrun simctl shutdown "${simulator_udid}"
	done

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
		while pgrep -q "update_dyld_sim_shared_cache"; do
			echo "Simulator shared cache is still being updated..."
			sleep 5
		done
	fi
	echo "Simulator shared cache update complete"
}

main "$@"
