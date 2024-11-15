#!/bin/bash -euo pipefail

xcodes download "16.1" "${HOME}/caches/xcode/"
mist download firmware sequoia --output-directory "${HOME}/caches/macos/"
xcrun xcodebuild -downloadPlatform iOS -buildVersion "18.1" -exportPath "${HOME}/caches/simruntime/"
