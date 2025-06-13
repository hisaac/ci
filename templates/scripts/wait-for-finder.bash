#!/bin/bash -euo pipefail

function main() {
	local -r timeout="${1:-${TIMEOUT:-30}}"

	# `SECONDS` is a bash builtin that auto-increments every second. Neat!
	SECONDS=0

	echo "Waiting ${timeout} seconds for Finder to start..."

	until pgrep -x "Finder" > /dev/null; do
		sleep 1
		if [[ "$SECONDS" -ge "$timeout" ]]; then
			echo "Finder did not start within ${timeout} seconds."
			echo "Exiting..."
			exit 1
		fi
	done
	echo "Finder is now running"
}

main "$@"
