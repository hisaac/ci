#!/bin/bash -euo pipefail

function main() {
	echo "Installing Safari updates..."
	softwareupdate --install --safari-only --verbose
}

main "$@"
