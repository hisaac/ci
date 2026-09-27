#!/bin/bash -euo pipefail

function main() {
	local -r placeholder_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
	touch "${placeholder_file}"

	local command_line_tools_label
	if ! command_line_tools_label="$(
		softwareupdate --list |
			grep -B 1 -E 'Command Line Tools' |
			awk -F'*' '/^ *\*/ {print $2}' |
			sed -e 's/^ *Label: //' -e 's/^ *//' |
			sort -V |
			tail -n 1
	)" || [[ -z "${command_line_tools_label}" ]]; then
		echo "Could not find a Command Line Tools update." >&2
		return 1
	fi

	echo "Installing ${command_line_tools_label}..."

	softwareupdate --install "${command_line_tools_label}" --verbose
	rm -f "${placeholder_file}"
}

main "$@"
