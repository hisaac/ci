#!/bin/bash -euo pipefail

function main() {
	# Erase all indexes and wait until the rebuilding process ends,
	# for now there is no clear way to get status of indexing process on macOS, it takes around 3-6 minutes to accomplish
	echo "Erase all MDS indexes and wait until the rebuilding process ends"
	sudo mdutil -E / > /dev/null

	echo "Wait for 6 minutes or until the indexing process end signal is found in logs"
	for _ in {1..12}; do
		sleep 30
		result=$(sudo log show --last 1m | grep -E 'mds.*Released.*BackgroundTask' || true)
		if [[ -n "$result" ]]; then
			echo "Sign of indexing completion found:"
			echo "$result"
			break
		fi
	done
}

main "$@"
