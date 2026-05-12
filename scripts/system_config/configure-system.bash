#!/bin/bash -euo pipefail

# TODO: Find a way to set the wallpaper to a solid color

function main() {
	echo "==> Disabling the 'Click to Show Desktop' feature"
	defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

	echo "==> Disabling the 'Tips' feature and notifications"
	defaults write com.apple.tipsd SiriTipsDisabled -bool true
	defaults write com.apple.tipsd TipsDisabled -bool true

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

	# Finder: show status bar
	defaults write com.apple.finder ShowStatusBar -bool true

	# Finder: show path bar
	defaults write com.apple.finder ShowPathbar -bool true

	# Display full POSIX path as Finder window title
	defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

	# Keep folders on top when sorting by name
	defaults write com.apple.finder _FXSortFoldersFirst -bool true
	defaults write com.apple.finder _FXSortFoldersFirstOnDesktop -bool true

	# When performing a search, search the current folder by default
	defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

	# Change the default folder shown in Finder windows.
	defaults write com.apple.finder NewWindowTarget -string "OS volume"

	echo "==> Finder: Show hard drives, servers, and removable media on the desktop"
	defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
	defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
	defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
	defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

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
	# This sets all sleep settings to off
	# - Computer Sleep `-setcomputersleep`
	# - Display Sleep `-setdisplaysleep`
	# - Disk Sleep `-setharddisksleep`
	sudo systemsetup -setsleep Off 2>/dev/null

	echo "==> Disabling energy saving features"
	sudo pmset -a displaysleep 0 disksleep 0 sleep 0

	echo "==> Disabling hibernation"
	sudo pmset -a hibernatemode 0

	# Prevent system sleep
	sudo pmset -a sleep 0

	# Prevent display sleep (not strictly needed on headless, but avoids surprises)
	sudo pmset -a displaysleep 0

	# Prevent disk sleep
	sudo pmset -a disksleep 0

	# Disable Power Nap (background tasks during sleep)
	sudo pmset -a powernap 0

	# Keep network reachability prioritized during sleep (shouldn't sleep anyway)
	sudo pmset -a networkoversleep 1

	# Prevent sleep when SSH/TTY sessions are active
	sudo pmset -a ttyskeepawake 1

	# Maintain TCP connections during light sleep (dark wake)
	sudo pmset -a tcpkeepalive 1

	# Disable standby/deep idle sleep
	sudo pmset -a standby 0

	# Enable Wake-on-LAN (magic packet)
	sudo pmset -a womp 1

	# Auto-restart after power failure
	sudo pmset -a autorestart 1

	# powermode has three modes:
	# 	0 = Balanced (default)
	# 	1 = Low Power Mode
	# 	2 = High Power Mode (if supported)
	# It's not super easy to determine if the system supports High Power Mode, so we set it to Balanced first,
	# then switch to High Power Mode if supported.
	# If the system doesn't support High Power Mode, the command will print a warning, but the command will still succeed.
	sudo pmset -a powermode 0
	sudo pmset -a powermode 2

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

	# Enable "Developer Mode" for Terminal.app to speed up script execution
	# add all terminals to the Developer Tools section
	# https://notes.billmill.org/computer_usage/mac_os/Avoiding_gatekeeper_in_your_terminal.html
	sudo spctl developer-mode enable-terminal

	# TODO: Use tccutil to manipulate privacy database
}

main "$@"
