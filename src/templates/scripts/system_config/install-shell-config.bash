#!/bin/bash -euo pipefail

function main() {
	local -r data_dir="${1:?Usage: install-shell-config.bash DATA_DIRECTORY}"

	echo "Installing shell configuration..."
	install -m 644 "${data_dir}"/{.profile,.bash_profile,.bashrc,.zprofile,.zshenv,.zshrc} "${HOME}/"
}

main "$@"
