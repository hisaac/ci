#!/bin/bash -euo pipefail

set -x

# shellcheck source=./xcode-utils.bash
source "$(dirname "$0")/xcode-utils.bash"

function main() {
	declare -r username="${2:-${USERNAME}}"
	declare -r password="${3:-${PASSWORD}}"
	declare -r xcode_versions="${4:-${XCODE_VERSIONS}}"
	declare -r simulator_runtimes="${5:-${SIMULATOR_RUNTIMES}}"
	unset USERNAME PASSWORD XCODE_VERSIONS SIMULATOR_RUNTIMES

	enable_passwordless_sudo "${username}" "${password}"
	enable_auto_login "${username}" "${password}"
	disable_screensaver_at_login_screen
	disable_screensaver_for_admin_user
	prevent_vm_from_sleeping
	disable_screen_lock "${password}"
	disable_automatic_updates
	install_rosetta_2
	install_xcode_command_line_tools
	install_homebrew
	setup_shell_profile
	install_developer_certificates
	add_github_to_known_hosts

	for xcode_version in ${xcode_versions//,/ }; do
		install_xcode "${xcode_version}"
		if [[ -n "${simulator_runtimes}" ]]; then
			install_simulator_runtimes "${simulator_runtimes}"
		fi
		prewarm_simulators
	done
}

function enable_passwordless_sudo() {
	declare -r arg_username="${1}"
	declare -r arg_password="${2}"
	echo "Enabling passwordless sudo for ${arg_username} user..."
	echo "${arg_password}" | sudo -S sh -c "mkdir -p /etc/sudoers.d/; echo '${arg_username} ALL=(ALL) NOPASSWD: ALL' | EDITOR=tee visudo /etc/sudoers.d/${arg_username}-nopasswd"
}

# learned how to do this from https://github.com/freegeek-pdx/mkuser
function enable_auto_login() {
	declare -r arg_username="${1}"
	declare -r arg_password="${2}"
	echo "Enabling auto login for ${arg_username} user..."

	# See https://github.com/freegeek-pdx/mkuser/blob/b7a7900d2e6ef01dfafad1ba085c94f7302677d9/mkuser.sh#L6460-L6631

	# These are the special "kcpassword" repeating cipher hex characters.
	declare -ra cipher_key=( '7d' '89' '52' '23' 'd2' 'bc' 'dd' 'ea' 'a3' 'b9' '1f' )
	declare -ri cipher_key_length="${#cipher_key[@]}"

	declare encoded_password_hex_string
	declare -i this_password_hex_char_index=0
	while IFS='' read -r this_password_hex_char; do
		printf -v this_encoded_password_hex_char '%02x' "$(( 0x${this_password_hex_char} ^ 0x${cipher_key[this_password_hex_char_index % cipher_key_length]} ))"
		encoded_password_hex_string+="${this_encoded_password_hex_char} "
		this_password_hex_char_index+=1
	done < <(printf '%s' "${arg_password}" | xxd -c 1 -p)

	encoded_password_hex_string="${cipher_key[this_password_hex_char_index % cipher_key_length]}"

	sudo rm -rf '/private/etc/kcpassword'
	sudo touch '/private/etc/kcpassword'
	sudo chown 0:0 '/private/etc/kcpassword'
	sudo chmod 600 '/private/etc/kcpassword'

	echo "${encoded_password_hex_string}" | xxd -r -p | sudo tee '/private/etc/kcpassword' > /dev/null

	if [[ ! -f '/private/etc/kcpassword' ]] || ! encoded_password_length="$(sudo wc -c '/private/etc/kcpassword' 2> /dev/null | awk '{ print $1; exit }')" || (( encoded_password_length == 0 )); then
		echo "Failed to set auto login password"
		exit 1
	fi

	encoded_password_random_data_padding_multiples="$(( cipher_key_length + 1 ))"
	if (( (encoded_password_length % encoded_password_random_data_padding_multiples) != 0 )); then
		head -c "$(( encoded_password_random_data_padding_multiples - (encoded_password_length % encoded_password_random_data_padding_multiples) ))" /dev/urandom | sudo tee -a '/private/etc/kcpassword' > /dev/null
	fi

	sudo defaults write '/Library/Preferences/com.apple.loginwindow' autoLoginUser -string "${arg_username}"
}

function disable_screensaver_at_login_screen() {
	echo "Disabling screensaver at login screen..."
	sudo defaults write /Library/Preferences/com.apple.screensaver loginWindowIdleTime 0
}

function disable_screensaver_for_admin_user() {
	echo "Disabling screensaver for admin user..."
	defaults -currentHost write com.apple.screensaver idleTime 0
}

function prevent_vm_from_sleeping() {
	echo "Preventing VM from sleeping..."
	sudo systemsetup -setsleep Off 2>/dev/null
}

function disable_screen_lock() {
	declare -r arg_password="${1}"
	echo "Disabling screen lock..."
	sysadminctl -screenLock off -password "${arg_password}"
}

function disable_automatic_updates() {
	echo "Disabling automatic updates..."
	sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -boolean FALSE
	sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -boolean FALSE
}

function install_rosetta_2() {
	echo "Installing Rosetta 2..."
	sudo softwareupdate --install-rosetta --agree-to-license
}

function disable_tips() {
	defaults write com.apple.tipsd SiriTipsDisabled -bool true
	defaults write com.apple.Tips TipsDisabled -bool true
	killall Tips >/dev/null 2>&1 || true
}

# based on https://github.com/timsutton/osx-vm-templates/blob/d3de634fc09aed981e8ec53ba302163c4624f039/scripts/xcode-cli-tools.sh#L12-L19
function install_xcode_command_line_tools() {
	echo "Installing Xcode command line tools..."
	touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
	declare -r newest_command_line_tools="$(softwareupdate --list | grep "\*.*Command Line" | tail --lines=1)"
	declare -r newest_command_line_tools_name="${newest_command_line_tools#'* Label: '}"
	softwareupdate --install "$newest_command_line_tools_name" --verbose
	rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
}

function install_homebrew() {
	echo "Installing Homebrew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

function setup_shell_profile() {
	echo "Creating .zprofile..."
	{
		echo 'export SHELL_SESSIONS_DISABLE=1'
		echo 'export LANG=en_US.UTF-8'
		# We want this to output the eval command not the result of running it
		# shellcheck disable=SC2016
		echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
		echo 'export HOMEBREW_NO_AUTO_UPDATE=1'
		echo 'export HOMEBREW_NO_INSTALL_CLEANUP=1'
	} >> "$HOME/.zprofile"

	echo "Symlinking .zprofile to .profile..."
	ln -s "$HOME/.zprofile" "$HOME/.profile"

	echo "Sourcing .profile..."
	source "$HOME/.profile"
}

function install_developer_certificates() {
	echo "Installing developer certificates..."
	curl -o AppleWWDRCAG3.cer https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer
	curl -o DeveloperIDG2CA.cer https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer
	sudo security import AppleWWDRCAG3.cer -k "/Library/Keychains/System.keychain"
	sudo security import DeveloperIDG2CA.cer -k "/Library/Keychains/System.keychain"
	rm AppleWWDRCAG3.cer DeveloperIDG2CA.cer
}

function add_github_to_known_hosts() {
	echo "Adding GitHub to known hosts..."
	mkdir -p "$HOME/.ssh"
	chmod 777 "$HOME/.ssh"
	cat >> "$HOME/.ssh/known_hosts" <<- EOF
		# https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
		github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
		github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
		github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
	EOF
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
	# Sure, I could just use xcodes, but I want to learn how to do this manually

	sudo DevToolsSecurity -enable
	sudo dseditgroup -o edit -t group -a staff _developer

	declare -ra installed_xcode_paths="$(get_paths_to_installed_xcode_versions)"

	for xcode_path in "${installed_xcode_paths[@]}"; do
		declare xcode_version
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
		declare -r user_cache_dir="$(getconf DARWIN_USER_CACHE_DIR)"
		declare -r macos_build_version="$(sw_vers -buildVersion)"
		declare -r xcode_build_version="$(
			/usr/libexec/PlistBuddy -c "Print :ProductBuildVersion" "${xcode_path}/Contents/version.plist"
		)"
		touch "${user_cache_dir}/com.apple.dt.Xcode.InstallCheckCache_${macos_build_version}_${xcode_build_version}"
	done
}

function install_simulator_runtimes() {
	declare -r arg_simulator_runtimes="${1}"
	declare -r simulator_runtimes="$(echo "${arg_simulator_runtimes}" | tr ',' ' ')"
	for simulator_runtime in ${simulator_runtimes}; do
		echo "Installing simulator runtime: ${simulator_runtime}..."
		xcrun xcodebuild -downloadPlatform "${simulator_runtime}"
	done
	sudo xcrun xcodebuild -runFirstLaunch -checkForNewerComponents
}

function prewarm_simulators() {
	# This bit is based on https://github.com/biscuitehh/yeetd/blob/main/Resources/prewarm_simulators.sh
	echo "Prewarming simulators..."

	declare -r simulator_udids=("$(xcrun simctl list devices --json | jq '.devices[] | .[] | .udid')")
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

	declare -r selected_xcode_version="$(get_selected_xcode_version)"
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
