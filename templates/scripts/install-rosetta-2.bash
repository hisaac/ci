#!/bin/bash -euo pipefail

# Note:
# There is a bug when installing Rosetta 2 on macOS Sonoma (14.0) that causes an error to be displayed,
# but the installation still succeeds. The error can be safely ignored.
#
# The error message is:
# 	softwareupdate[721:5244] Package Authoring Error: 062-58681: Package reference com.apple.pkg.RosettaUpdateAuto is missing installKBytes attribute

function main() {
	echo "Installing Rosetta 2..."
	softwareupdate --install-rosetta --agree-to-license --verbose
}

main "$@"
