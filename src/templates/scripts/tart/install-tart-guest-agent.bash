#!/bin/bash -euo pipefail

function main() {
	local -r data_dir="${DATA_DIRECTORY:?DATA_DIRECTORY must point to the staged configuration directory}"
	local -r label="org.cirruslabs.tart-guest-agent"
	local -r staged_plist="${data_dir}/tart-guest-agent.plist"
	local -r installed_plist="/Library/LaunchAgents/${label}.plist"
	local domain
	domain="gui/$(id -u)"

	echo "Installing Tart guest LaunchAgent..."
	# Edit only Packer's uploaded copy, not the repository's plist.
	plutil -replace WorkingDirectory -string "${HOME}" "${staged_plist}"
	plutil -lint "${staged_plist}"
	sudo -n install -o root -g wheel -m 644 "${staged_plist}" "${installed_plist}"

	# Earlier VM stages enable automatic GUI login. Load as that user, not root.
	if launchctl print "${domain}/${label}" >/dev/null 2>&1; then
		launchctl bootout "${domain}/${label}"
	fi
	launchctl bootstrap "${domain}" "${installed_plist}"
	launchctl print "${domain}/${label}"
}

main "$@"
