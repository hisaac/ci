#!/bin/bash -euo pipefail

function main() {
	# Open Apps from anywhere
	sudo spctl --master-disable
}

main "$@"
