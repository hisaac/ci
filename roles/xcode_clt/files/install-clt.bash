#!/bin/bash -euo pipefail

declare placeholder_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
touch "${placeholder_file}"
trap 'rm -f "${placeholder_file}"' EXIT

echo "🔎 Checking for Command Line Tools updates (querying software update catalog)..."
declare clt_label=""
clt_label="$(
	timeout 120 softwareupdate --list 2>&1 |
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

echo "📦 Installing ${clt_label} — this may take 10–20 minutes..."
echo "💡 Tip: on the target host, run: log stream --predicate 'process == \"softwareupdate\"' to watch real-time progress."
softwareupdate --install --no-scan --verbose "${clt_label}"
echo "✅ Installation complete. Switching active developer directory..."
xcode-select --switch "/Library/Developer/CommandLineTools"
echo "✅ Xcode CLT installation finished."
