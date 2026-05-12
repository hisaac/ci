#!/bin/bash -euo pipefail

function main() {
	echo "==> Xcode: Disabling Xcode Cloud upsell"
	defaults write com.apple.dt.Xcode XcodeCloudUpsellPromptEnabled -bool false

	echo "==> Xcode: Disabling the welcome window"
	defaults write com.apple.dt.Xcode DVTWelcomeWindowLastShownVersion -string "9999.0"

	echo "==> Xcode: Disabling telemetry and crash dialogs"
	defaults write com.apple.dt.Xcode IDEDisableCrashReporting -bool true

	echo "==> Xcode: Disabling unnecessary warnings and prompts"
	defaults write com.apple.dt.Xcode IDENeverShowSVNConversionWarning -bool true
	defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidation -bool true
	defaults write com.apple.dt.Xcode IDETrustAllCertificates -bool true

	echo "==> Xcode: Setting default provisioning style to manual"
	defaults write com.apple.dt.Xcode IDEProvisioningStyle -string "Manual"

	echo "==> Xcode: Disabling automatic test result collection by default"
	# Can be slow and unnecessary for many projects
	defaults write com.apple.dt.XCTest AutomaticallyCollectTestResults -bool false

	echo "==> Xcode: Disabling automatic window minimization in the iOS simulator"
	defaults write com.apple.iphonesimulator AutomaticMinimizedWindowShowingEnabled -bool false

	echo "==> Xcode: Enabling clean launches for the iOS simulator"
	defaults write com.apple.iphonesimulator CleanLaunchesEnabled -bool true

	echo "==> Xcode: Disabling device discovery popups"
	defaults write com.apple.iphonesimulator DeviceDiscoveryDisabled -bool true
}

main "$@"
