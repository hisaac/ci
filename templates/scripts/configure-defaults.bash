#!/bin/bash -euo pipefail

function main() {
	# Disable the "Click to Show Desktop" feature
	defaults write com.apple.WindowManager EnableStandardClickToShowDesktop 0

	# Disable the "Tips" feature and notifications
	defaults write com.apple.tipsd SiriTipsDisabled -bool true
	defaults write com.apple.Tips TipsDisabled -bool true

	# Disable the "Update to the latest version of macOS" notification
	sudo touch /Library/Preferences/com.apple.SoftwareUpdate.plist
	sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate.plist "DoNotOfferNewVersion" -bool TRUE

	# Disable reopening of open apps on login
	defaults write com.apple.loginwindow TALLogoutSavesState -bool false
	defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool false

	# Finder: Set column view as default
	# Source: https://krypted.com/mac-os-x/change-default-finder-views-using-defaults/
	defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

	# Finder: show hidden/invisible files by default
	defaults write com.apple.finder AppleShowAllFiles -bool true

	# Finder: show all filename extensions
	defaults write NSGlobalDomain AppleShowAllExtensions -bool true

	# Disable the warning when changing a file extension
	defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

	# Show hard drives on desktop
	defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true

	# Show mounted servers on desktop
	defaults write com.apple.finder ShowMountedServersOnDesktop -bool true

	# Show the ~/Library folder
	chflags nohidden ~/Library

	# Show the /Volumes folder
	sudo chflags nohidden /Volumes

	# Disable default simulator set creation
	# CoreSimulator now supports a mode in which the developer has full control over devices in the default device set.
	# The system won’t create default devices nor manage pairing relationships between watches and phones in that set when placed into this mode.
	# source: https://developer.apple.com/documentation/xcode-release-notes/xcode-16_2-release-notes#Simulator
	defaults write com.apple.CoreSimulator EnableDefaultSetCreation -bool NO

	# Disable Xcode Cloud upsell
	defaults write com.apple.dt.Xcode XcodeCloudUpsellPromptEnabled -bool false

	# Show file extensions
	defaults write com.apple.dt.Xcode IDEFileExtensionDisplayMode -int 1
}

main "$@"
