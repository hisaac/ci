#!/bin/bash -euo pipefail

function main() {
	local -r username="${1:-$USERNAME}"
	local -r password="${2:-$PASSWORD}"

	echo "==> Installing macOS updates..."

	# Trick macOS into thinking the setup assistant has already been run
	defaults write com.apple.SetupAssistant DidSeeAccessibility -bool TRUE
	defaults write com.apple.SetupAssistant DidSeeActivationLock -bool TRUE
	defaults write com.apple.SetupAssistant DidSeeAppStore -bool TRUE
	defaults write com.apple.SetupAssistant DidSeeAppearanceSetup -bool TRUE
	defaults write com.apple.SetupAssistant DidSeeApplePaySetup -bool TRUE
	defaults write com.apple.SetupAssistant DidSeeCloudSetup -bool TRUE
	defaults write com.apple.SetupAssistant DidSeeLockdownMode -bool TRUE
	defaults write com.apple.SetupAssistant DidSeePrivacy -bool TRUE
	defaults write com.apple.SetupAssistant DidSeeScreenTime -bool TRUE
	defaults write com.apple.SetupAssistant DidSeeSiriSetup -bool TRUE
	defaults write com.apple.SetupAssistant DidSeeSyncSetup -bool TRUE
	defaults write com.apple.SetupAssistant DidSeeSyncSetup2 -bool TRUE
	defaults write com.apple.SetupAssistant DidSeeTermsOfAddress -bool TRUE
	defaults write com.apple.SetupAssistant DidSeeTouchIDSetup -bool TRUE
	defaults write com.apple.SetupAssistant DidSeeiCloudLoginForStorageServices -bool TRUE

	# Trick macOS into thinking this version/build has already been set up
	defaults write com.apple.SetupAssistant LastPrivacyBundleVersion "999999"
	defaults write com.apple.SetupAssistant LastSeenBuddyBuildVersion "99Z999"
	defaults write com.apple.SetupAssistant LastSeenCloudProductVersion "99.99.99"

	# For some reason this is required. Without it, the final `softwareupdate` command fails at the very end.
	sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -boolean FALSE

	# We run the `--list` command first to ensure that the list of available updates is cached.
	softwareupdate --list --verbose

	# Find the label for the latest macOS update for this major version
	local -r os_major_version="$(sw_vers -productVersion | cut -d '.' -f 1)"
	local -r update_label=$(
		softwareupdate --list --verbose | grep "${os_major_version}" | grep -E 'Label:.*' | sed 's/^[^:]*: //'
	)

	echo "${password}" | sudo softwareupdate \
		--verbose \
		--install \
		--restart \
		--user "${username}" \
		--stdinpass \
		"${update_label}"
}

main "$@"
