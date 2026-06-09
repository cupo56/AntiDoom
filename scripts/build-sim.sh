#!/usr/bin/env bash
# Autonomous verification build: compiles the app + all extensions for the iOS
# Simulator WITHOUT code signing. Signing and on-device runtime behaviour are
# verified separately by the user on a real iPhone (see device-test checklist).
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild \
  -project AntiDoom.xcodeproj \
  -scheme AntiDoom \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  clean build
