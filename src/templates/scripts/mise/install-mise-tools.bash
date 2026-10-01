#!/bin/bash -euo pipefail

function main() {
	local -r data_dir="${DATA_DIRECTORY:?DATA_DIRECTORY must point to the staged configuration directory}"

	echo "Installing VM mise configuration and tools..."
	mkdir -p "${HOME}/.config/mise"
	install -m 644 "${data_dir}/mise.toml" "${HOME}/.config/mise/config.toml"

	export PATH="${HOME}/.local/bin:${PATH}"

	# Use only the VM user's configuration, not a config in the staging directory.
	cd "${HOME}"
	mise trust "${HOME}/.config/mise/config.toml"
	mise bootstrap --yes
}

main "$@"
