#!/bin/bash -euo pipefail

declare placeholder_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
touch "${placeholder_file}"

echo "🔎 Finding latest Command Line Tools..."
declare clt_label=""
while [[ -z "${clt_label}" ]]; do
	clt_label="$(
		softwareupdate --list 2>/dev/null |
		grep --after-context=1 '\* Label: Command Line Tools' |
		paste - - |
		sed 's/.*\* Label: //; s/\tTitle:.*Version: /\t/' |
		sort --field-separator=$'\t' --key=2 --version-sort |
		tail -n1 |
		cut -f1
	)"
done

echo "📦 Installing ${clt_label}..."
softwareupdate --install --no-scan --verbose "${clt_label}"
xcode-select --switch "/Library/Developer/CommandLineTools"

rm -f "${placeholder_file}"
