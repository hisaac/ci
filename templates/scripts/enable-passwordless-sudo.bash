#!/bin/bash -euo pipefail

function main() {
	declare -r username="${1:-${VM_USERNAME}}"
	declare -r password="${2:-${VM_PASSWORD}}"

	echo "Enabling passwordless sudo for ${username} user..."
	echo "${password}" | sudo -S sh -c "mkdir -p /etc/sudoers.d/; echo '${username} ALL=(ALL) NOPASSWD: ALL' | EDITOR=tee visudo /etc/sudoers.d/${username}-nopasswd"
}

main "$@"
