#!/bin/bash -euo pipefail

function main() {
	echo "Installing developer certificates..."
	curl -o AppleWWDRCAG3.cer https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer
	curl -o DeveloperIDG2CA.cer https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer
	sudo security import AppleWWDRCAG3.cer -k "/Library/Keychains/System.keychain"
	sudo security import DeveloperIDG2CA.cer -k "/Library/Keychains/System.keychain"
	rm AppleWWDRCAG3.cer DeveloperIDG2CA.cer
}

main "$@"
