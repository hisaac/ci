#!/bin/bash -euo pipefail

function main() {
	echo "==> Disabling the 'Click to Show Desktop' feature"
	defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

	echo "==> Disabling the 'Tips' feature and notifications"
	defaults write com.apple.tipsd SiriTipsDisabled -bool true
	defaults write com.apple.Tips TipsDisabled -bool true

	echo "==> Disabling the 'Update to the latest version of macOS' notification"
	sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate DoNotOfferNewVersion -bool true

	echo "==> Disabling automatic updates..."
	sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false
	sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false

	echo "==> Disabling reopening of open apps on login"
	defaults write com.apple.loginwindow TALLogoutSavesState -bool false
	defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool false

	echo "==> Finder: Setting column view as default"
	# Source: https://krypted.com/mac-os-x/change-default-finder-views-using-defaults/
	defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

	echo "==> Finder: Enable showing hidden/invisible files by default"
	defaults write com.apple.finder AppleShowAllFiles -bool true

	echo "==> Finder: Enable showing all filename extensions"
	defaults write NSGlobalDomain AppleShowAllExtensions -bool true

	echo "==> Finder: Disabling the warning when changing a file extension"
	defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

	echo "==> Finder: Show hard drives on desktop"
	defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true

	echo "==> Finder: Show mounted servers on desktop"
	defaults write com.apple.finder ShowMountedServersOnDesktop -bool true

	echo "==> Disabling Handoff and Continuity"
	defaults write com.apple.coreservices.useractivityd ActivityReceivingEnabled -bool false
	defaults write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false

	echo "==> Disabling graphic effects in System"
	defaults write com.apple.universalaccess reduceMotion -bool true
	defaults write com.apple.universalaccess reduceTransparency -bool true

	echo "==> Unhiding the ~/Library folder"
	chflags nohidden ~/Library

	echo "==> Unhiding the /Volumes folder"
	sudo chflags nohidden /Volumes

	echo "==> Disabling sleep..."
	sudo systemsetup -setsleep Off 2>/dev/null

	echo "==> Disabling energy saving features"
	sudo pmset -a displaysleep 0 disksleep 0 sleep 0

	echo "==> Disabling hibernation"
	sudo pmset hibernatemode 0

	echo "==> Deleting sleep image file"
	sudo rm -f /var/vm/sleepimage

	echo "==> Disabling Time Machine"
	sudo tmutil disable

	echo "==> Disabling App Nap"
	defaults write NSGlobalDomain NSAppSleepDisabled -bool true

	echo "==> Disabling the screensaver for the current user"
	defaults -currentHost write com.apple.screensaver idleTime 0

	echo "==> Disabling the screensaver at the login window"
	sudo defaults write /Library/Preferences/com.apple.screensaver loginWindowIdleTime 0

	echo "==> Disabling Keyboard Setup Assistant window"
	sudo defaults write /Library/Preferences/com.apple.keyboardtype keyboardtype -dict-add "3-7582-0" -int 40
}

main "$@"
