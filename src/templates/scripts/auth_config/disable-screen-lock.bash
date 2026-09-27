#!/bin/bash -euo pipefail

function main() {
	local -r password="${1:-${PASSWORD}}"

	echo "Disabling screen lock..."
	sysadminctl -screenLock off -password "${password}"
}

main "$@"
