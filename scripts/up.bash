#!/bin/bash -euo pipefail

xcodes download "16.2" --directory "${HOME}/caches/xcode/"
mist download firmware sequoia --output-directory "${HOME}/caches/macos/"
xcrun xcodebuild -downloadPlatform iOS -buildVersion "18.2" -exportPath "${HOME}/caches/simruntime/"
