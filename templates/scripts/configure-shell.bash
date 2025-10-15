#!/bin/bash -euo pipefail

function main() {
	local -r username="${1:-${USERNAME:-$(whoami)}}"

	echo "==> Configuring shell environment"
	sudo chsh -s /bin/bash "$username"
	sudo chsh -s /bin/bash root
}

main "$@"
