#!/usr/bin/env bash -euo pipefail

mkdir -p "${HOME}/caches/xcode/"
mise exec -- xcodes update
mise exec -- xcodes download --latest --directory "${HOME}/caches/xcode/"

xcrun xcodebuild -downloadAllPlatforms -exportPath "${HOME}/caches/simruntime/"

mise exec -- mist download firmware sequoia --output-directory "${HOME}/caches/macos/"
