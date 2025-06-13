#!/usr/bin/env bash -euo pipefail

function main() {
	mkdir -p "${MISE_PROJECT_ROOT}/caches/xcode/"
	xcodes update
	xcodes download --latest --directory "${MISE_PROJECT_ROOT}/caches/xcode/"
}

main "$@"
