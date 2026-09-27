#!/bin/bash -euo pipefail

function main() {
	local -r username="${1:-${USERNAME}}"
	local -r password="${2:-${PASSWORD}}"

	echo "Enabling passwordless sudo for ${username}..."

	# Cache the password to avoid prompting for it later
	printf '%s\n' "${password}" | sudo --stdin --validate

	sudo mkdir -p /etc/sudoers.d/

	# Add the user to the sudoers file with NOPASSWD option
	echo "${username} ALL=(ALL) NOPASSWD: ALL" | sudo SUDO_EDITOR="tee" visudo "/etc/sudoers.d/${username}-nopasswd"

	# Clear the cached password to ensure no lingering sudo access
	sudo --remove-timestamp

	# Verify the new rule works without cached credentials or a password prompt.
	sudo --non-interactive true
}

main "$@"
