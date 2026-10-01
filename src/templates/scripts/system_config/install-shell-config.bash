#!/bin/bash -euo pipefail

function main() {
	local -r data_dir="${DATA_DIRECTORY:?DATA_DIRECTORY must point to the staged configuration directory}"

	echo "Installing shell configuration..."
	install -m 644 "${data_dir}"/{.profile,.bash_profile,.bashrc,.zprofile,.zshenv,.zshrc} "${HOME}/"
}

main "$@"
