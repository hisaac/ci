#!/bin/bash -euo pipefail

function main() {
	export_global_variables
}

function export_global_variables() {
	declare -r PROJECT_ROOT="$(git rev-parse --show-toplevel)"

	# Load environment variables from the .env file if it exists
	if [[ -f "${PROJECT_ROOT}/.env" ]]; then
		set -o allexport
		source "${PROJECT_ROOT}/.env"
		set +o allexport
	fi
}

main "$@"
