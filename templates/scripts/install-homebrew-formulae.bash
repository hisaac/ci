#!/bin/bash -euo pipefail

# shellcheck source=../data/.profile
source "${HOME}/.profile"

function main() {
	local -r formulae="${1:-${BREW_FORMULAE}}"

	brew update
	brew install "${formulae}"
	brew autoremove
	brew cleanup
}

main "$@"
