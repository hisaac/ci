#!/bin/bash -euo pipefail

function main() {
	echo "Disabling screensaver for current user..."
	defaults -currentHost write com.apple.screensaver idleTime 0
}

main "$@"
