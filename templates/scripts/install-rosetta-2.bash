#!/bin/bash -euo pipefail

function main() {
	echo "Installing Rosetta 2..."
	sudo softwareupdate --install-rosetta --agree-to-license
}

main "$@"
