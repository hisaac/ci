#!/bin/bash -euo pipefail

declare placeholder_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
touch "${placeholder_file}"
trap 'rm -f "${placeholder_file}"' EXIT

echo "🔎 Checking for Command Line Tools updates..."
declare clt_label=""
clt_label="$(
	softwareupdate --list 2>/dev/null |
		grep --after-context=1 '\* Label: Command Line Tools' |
		paste - - |
		sed 's/.*\* Label: //; s/\tTitle:.*Version: /\t/' |
		sort --field-separator=$'\t' --key=2 --version-sort |
		tail -n1 |
		cut -f1
)"

if [[ -z "${clt_label}" ]]; then
	echo "✅ Command Line Tools are already up to date."
	exit 0
fi

echo "📦 Installing ${clt_label}..."
softwareupdate --install --no-scan --verbose "${clt_label}"
xcode-select --switch "/Library/Developer/CommandLineTools"
