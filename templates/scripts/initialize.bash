#!/bin/bash -euo pipefail

function main() {
	declare -r username="${1:-admin}"
	declare -r password="${2:-admin}"

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
	install_xcode "16.1.0+16B40"
	prewarm_simulators
}

function enable_passwordless_sudo() {
	declare -r username="${1}"
	declare -r password="${2}"
	echo "Enabling passwordless sudo for ${username} user..."
	echo "${password}" | sudo -S sh -c "mkdir -p /etc/sudoers.d/; echo '${username} ALL=(ALL) NOPASSWD: ALL' | EDITOR=tee visudo /etc/sudoers.d/${username}-nopasswd"
}

# learned how to do this from https://github.com/freegeek-pdx/mkuser
function enable_auto_login() {
	declare -r username="${1}"
	declare -r password="${2}"
	echo "Enabling auto login for ${username} user..."

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
	done < <(printf '%s' "${password}" | xxd -c 1 -p)

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

	sudo defaults write '/Library/Preferences/com.apple.loginwindow' autoLoginUser -string "${username}"
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
	declare -r password="${1}"
	echo "Disabling screen lock..."
	sysadminctl -screenLock off -password "${password}"
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
	touch "$HOME/.ssh/known_hosts"
	ssh-keyscan -t rsa github.com >> "$HOME/.ssh/known_hosts"
}

function install_xcode() {
	declare -r version="${1}"
	echo "Installing Xcode ${version}..."

	(
		# The xip tool expands to the current directory.
		# We'll `cd` into the downloads directory in a subshell to not pollute the current directory.
		cd "${HOME}/Downloads" || exit 1
		xip --expand "Xcode-${version}.xip"
		mv "Xcode.app" "/Applications/Xcode-${version}.app"
		rm "Xcode-${version}.xip"
	)

	# Most of these steps are based on xcodes' install process
	# Sure, I could just use xcodes, but I want to learn how to do this manually

	sudo DevToolsSecurity -enable
	sudo dseditgroup -o edit -t group -a staff _developer

	sudo xcrun xcode-select --switch "/Applications/Xcode-${version}.app"
	sudo xcrun xcodebuild -license accept
	sudo xcrun xcodebuild -runFirstLaunch

	# TODO: Figure out what this is actually doing. I'm not sure why we create this file.
	declare -r user_cache_dir="$(getconf DARWIN_USER_CACHE_DIR)"
	declare -r macos_build_version="$(sw_vers -buildVersion)"
	declare -r xcode_build_version="$(
		/usr/libexec/PlistBuddy -c "Print :ProductBuildVersion" \
			"/Applications/Xcode-${version}.app/Contents/version.plist"
	)"
	touch "${user_cache_dir}/com.apple.dt.Xcode.InstallCheckCache_${macos_build_version}_${xcode_build_version}"
}

function prewarm_simulators() {
	echo "Prewarming simulators..."

	# source: https://developer.apple.com/documentation/xcode/installing-additional-simulator-runtimes
	echo "Importing iOS simulator runtime..."
	xcrun xcodebuild -importPlatform "${HOME}/Downloads/iphonesimulator_18.1_22B81.dmg"
	rm "${HOME}/Downloads/iphonesimulator_18.1_22B81.dmg"

	echo "Deleting all simulators..."
	xcrun simctl delete all

	echo "Creating new simulator..."
	declare -r simulator_udid="$(xcrun simctl create "iPhone 16" "iPhone 16" "iOS18.1")"

	# This bit is based on https://github.com/biscuitehh/yeetd/blob/main/Resources/prewarm_simulators.sh
	echo "Prewarming new simulator..."
	xcrun simctl bootstatus "${simulator_udid}" -b
	xcrun simctl shutdown "${simulator_udid}"

	# Wait for the "update_dyld_sim_shared_cache" process to finish to avoid wasting CPU cycles after boot
	# sources:
	#   - https://github.com/cirruslabs/macos-image-templates/blob/5b17f4e2644723b2124c5cf1c1def4ba81fc6db7/templates/xcode.pkr.hcl#L243-L252
	#   - https://apple.stackexchange.com/questions/412101/update-dyld-sim-shared-cache-is-taking-up-a-lot-of-memory
	#   - https://stackoverflow.com/a/68394101/9316533
	echo "Waiting for simulator shared cache to update..."
	while pgrep -q "update_dyld_sim_shared_cache"; do
		echo "Simulator shared cache is still being updated..."
		sleep 5
	done
	echo "Simulator shared cache update complete"
}

main "$@"
