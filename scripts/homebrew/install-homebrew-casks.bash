#!/bin/bash -euo pipefail

# shellcheck source=../../templates/data/.profile
source "${HOME}/.profile"

function main() {
	local -r casks="${1:-${BREW_CASKS}}"

	brew update
	brew install --cask "${casks}"
	brew autoremove
	brew cleanup
}

main "$@"
