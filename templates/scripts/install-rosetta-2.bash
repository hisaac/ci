#!/bin/bash -euo pipefail

function main() {
	echo "Installing Rosetta 2..."
	softwareupdate --install-rosetta --agree-to-license --verbose
}

main "$@"
