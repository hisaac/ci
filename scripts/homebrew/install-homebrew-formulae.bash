#!/bin/bash -euo pipefail

function main() {
	local -r formulae="${1:-${BREW_FORMULAE}}"

	brew update
	brew install "${formulae}"
	brew autoremove
	brew cleanup
}

main "$@"
