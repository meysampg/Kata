#!/bin/zsh
# Captures screenshots from a connected, unlocked iPhone using the DEBUG demo mode
# (Kata/App/DebugLaunch.swift). Demo mode uses an in-memory store, so real progress is untouched.
#
# Usage: Tools/capture_screenshots.sh [device-udid] [out-dir]
set -euo pipefail
cd "$(dirname "$0")/.."

UDID="${1:-00008030-000511D93CC0202E}"
OUT="${2:-docs/screenshots}"
BUNDLE_ID="com.github.meysampg.kata"
DERIVED="build-shots"
SCREENS=(today path library deck:definition deck:implementation deck:example deck:structure deck:tradeoffs deck:compare deck:sightings practice search:state settings)

xcodebuild -project Kata.xcodeproj -scheme Kata -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DERIVED" -allowProvisioningUpdates -quiet build

APP="$DERIVED/Build/Products/Debug-iphoneos/Kata.app"
xcrun devicectl device install app --device "$UDID" "$APP"

mkdir -p "$OUT"
# Warm-up launch so the first screenshot isn't a stale frame.
xcrun devicectl device process launch --device "$UDID" --terminate-existing "$BUNDLE_ID" -- \
  -KataDemo YES -KataScreen today
sleep 6
i=1
for screen in $SCREENS; do
  name="${screen//:/-}"
  file="$(printf '%s/%02d-%s.png' "$OUT" "$i" "$name")"
  echo "==> $screen -> $file"
  xcrun devicectl device process launch --device "$UDID" --terminate-existing "$BUNDLE_ID" -- \
    -KataDemo YES -KataScreen "$screen"
  sleep 4
  xcrun devicectl device capture screenshot --device "$UDID" --destination "$file"
  sips -Z 1000 "$file" >/dev/null  # keep the repo small
  i=$((i + 1))
done

# Leave the phone on the real (non-demo) app.
xcrun devicectl device process launch --device "$UDID" --terminate-existing "$BUNDLE_ID"
rm -rf "$DERIVED"
echo "Done. Screenshots are in $OUT"
