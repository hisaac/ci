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
}

main "$@"
