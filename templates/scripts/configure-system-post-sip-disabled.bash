#!/bin/bash -euo pipefail

function main() {
	# If a service is not running, `launchctl bootout` will return a non-zero exit code,
	# so we use `|| true` to ignore that.

	echo "==> Disabling notification center agent"
	launchctl bootout "gui/$(id -u)" /System/Library/LaunchAgents/com.apple.notificationcenterui.plist || true

	echo "==> Disabling Time Machine daemon"
	sudo launchctl bootout system /System/Library/LaunchDaemons/com.apple.backupd.plist || true
	sudo launchctl bootout system /System/Library/LaunchDaemons/com.apple.backupd-helper.plist || true

	echo "==> Disabling analytics daemon"
	sudo launchctl bootout system /System/Library/LaunchDaemons/com.apple.SubmitDiagInfo.plist || true

	echo "==> Disabling Apple Push Notification Service daemon"
	sudo launchctl bootout system /System/Library/LaunchDaemons/com.apple.apsd.plist || true
}

main "$@"
