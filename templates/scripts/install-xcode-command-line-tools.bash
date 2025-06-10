#!/bin/bash -euo pipefail

function main() {
	declare -r placeholder_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
	touch "${placeholder_file}"

	declare -r command_line_tools_label="$(
		softwareupdate --list |
			grep --extended-regexp --only-matching 'Label: Command Line Tools for Xcode-[0-9.]+' |
			sort --key=2 --field-separator=- --version-sort --reverse |
			head --lines=1 |
			cut -d':' -f2 |
			sed 's/^ //'
	)"

	echo "Installing ${command_line_tools_label}..."

	softwareupdate --install "${command_line_tools_label}" --verbose
	rm -f "${placeholder_file}"
}

main "$@"
