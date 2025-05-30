#!/bin/bash -euo pipefail

function main() {
	echo "Disabling sleep..."
	sudo systemsetup -setsleep Off 2>/dev/null
}

main "$@"
