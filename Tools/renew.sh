#!/bin/zsh
# Build Kata, install it on the owner's iPhone and launch it.
set -euo pipefail
DEVICE=00008030-000511D93CC0202E
cd "$(dirname "$0")/.."
if git remote get-url origin >/dev/null 2>&1; then git pull -q; fi
xcodebuild -project Kata.xcodeproj -scheme Kata -configuration Debug \
  -destination "id=$DEVICE" -derivedDataPath build -allowProvisioningUpdates -quiet build
xcrun devicectl device install app --device "$DEVICE" build/Build/Products/Debug-iphoneos/Kata.app
xcrun devicectl device process launch --device "$DEVICE" com.github.meysampg.kata
