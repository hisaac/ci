#!/bin/bash -euo pipefail

function main() {
	echo "Installing mise..."
	curl -fsSL https://mise.run | sh
	"${HOME}/.local/bin/mise" --version
}

main "$@"
