#!/bin/bash -euo pipefail

function main() {
	declare -r password="${1:-${VM_PASSWORD}}"

	echo "Disabling screen lock..."
	sysadminctl -screenLock off -password "${password}"
}

main "$@"
