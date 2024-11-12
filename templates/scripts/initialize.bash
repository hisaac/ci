#!/bin/bash -euo pipefail

function main() {
	declare -r username="${1:-admin}"
	declare -r password="${2:-admin}"

	enable_passwordless_sudo "${username}"
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
	install_xcode "16.1.0"
	prewarm_simulators
}

function enable_passwordless_sudo() {
	declare -r username="${1}"
	echo "Enabling passwordless sudo for ${username} user..."
	echo "${password}" | sudo -S sh -c "mkdir -p /etc/sudoers.d/; echo '${username} ALL=(ALL) NOPASSWD: ALL' | EDITOR=tee visudo /etc/sudoers.d/${username}-nopasswd"
}

# learned how to do this from https://github.com/freegeek-pdx/mkuser
function enable_auto_login() {
	declare -r username="${1}"
	declare -r password="${2}"
	echo "Enabling auto login for ${username} user..."
	sysadminctl -autologin set -userName "${username}" -password "${password}"
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
	declare -r newest_command_line_tools="$(softwareupdate -l | grep "\*.*Command Line" | head -n 1)"
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

# TODO: Figure out how to install Xcode and prewarm simulators
function install_xcode() {
	declare -r version="${1}"
	echo "Installing Xcode ${version}..."
	# xcodes install --experimental-unxip --empty-trash 15.1 # 15.4 16.0
	# sudo xcodes select 16.0
	# xcodes runtimes install "iOS 17.2" # 17.5 18.0
}

function prewarm_simulators() {
	echo "Prewarming simulators..."
	echo "Not sure yet how to automate this, so just do it manually"
}

main "$@"
