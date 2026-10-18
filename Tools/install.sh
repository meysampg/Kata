#!/bin/zsh
# Build Kata, install it on a connected iPhone/iPad and launch it.
#
# Usage:
#   Tools/install.sh [device]
#
#   device   UDID, or a case-insensitive part of the device name, as shown by
#            `xcrun devicectl list devices`. Omit it to pick from the connected
#            physical iOS devices (auto-selected when there is only one).
#            `-h`/`--help` prints this text.
#
# Environment (all optional):
#   TEAM=<team id>       sign with this team (DEVELOPMENT_TEAM)
#   BUNDLE_ID=<id>       override the app's bundle identifier (needed when signing
#                        with a different Apple ID; free teams cannot share ids)
#   CONFIG=Debug         build configuration (default Debug)
#   NO_PULL=1            skip `git pull` (otherwise pulled only if a remote exists
#                        and the working tree is clean)
#
# The device needs: connected (USB or paired on the same network), trusted,
# Developer Mode on (Settings > Privacy & Security > Developer Mode). After the
# first install, trust the developer under Settings > General > VPN & Device
# Management. The iCloud account on the device does not matter.
set -euo pipefail

APP=Kata
DEFAULT_BUNDLE_ID=com.github.meysampg.kata
CONFIG=${CONFIG:-Debug}
BUNDLE_ID=${BUNDLE_ID:-}
TEAM=${TEAM:-}

case "${1:-}" in
  -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [[ -z "${NO_PULL:-}" ]] && git remote get-url origin >/dev/null 2>&1 \
   && [[ -z "$(git status --porcelain --untracked-files=no)" ]]; then
  git pull -q || echo "warning: git pull failed, continuing" >&2
fi

# Connected physical iOS devices as "udid<TAB>name<TAB>state".
xcrun devicectl list devices --json-output "$TMP/devices.json" >/dev/null 2>&1 || true
DEVICES=$(python3 - "$TMP/devices.json" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for d in data.get("result", {}).get("devices", []):
    hw = d.get("hardwareProperties", {})
    if hw.get("reality") == "simulated" or hw.get("platform") != "iOS":
        continue
    udid = hw.get("udid") or d.get("identifier", "")
    name = d.get("deviceProperties", {}).get("name", "?")
    conn = d.get("connectionProperties", {})
    state = conn.get("transportType", "") or conn.get("tunnelState", "")
    print(f"{udid}\t{name}\t{state}")
PY
)

if [[ -z "$DEVICES" ]]; then
  echo "No physical iOS device found. Connect it (USB), unlock it and tap Trust." >&2
  exit 1
fi

DEVS=("${(@f)DEVICES}")
UDID=""; NAME=""
if [[ -n "${1:-}" ]]; then
  want=${1:l}
  for l in $DEVS; do
    f=("${(@ps:\t:)l}")
    if [[ ${f[1]:l} == $want || ${f[2]:l} == *$want* ]]; then UDID=$f[1]; NAME=$f[2]; break; fi
  done
  if [[ -z "$UDID" ]]; then
    echo "No connected device matches '$1'. Available:" >&2
    for l in $DEVS; do f=("${(@ps:\t:)l}"); echo "  $f[2]  ($f[1])" >&2; done
    exit 1
  fi
elif (( ${#DEVS} == 1 )); then
  f=("${(@ps:\t:)DEVS[1]}"); UDID=$f[1]; NAME=$f[2]
else
  echo "Several devices are connected:"
  i=1
  for l in $DEVS; do f=("${(@ps:\t:)l}"); echo "  $i) $f[2]  ($f[1], $f[3])"; (( i++ )); done
  printf "Choose [1-%d]: " ${#DEVS}
  read -r n
  if [[ ! $n == <-> ]] || (( n < 1 || n > ${#DEVS} )); then echo "Invalid choice." >&2; exit 1; fi
  f=("${(@ps:\t:)DEVS[n]}"); UDID=$f[1]; NAME=$f[2]
fi
echo "Device: $NAME ($UDID)"

OVERRIDES=()
[[ -n "$TEAM" ]] && OVERRIDES+=("DEVELOPMENT_TEAM=$TEAM")
[[ -n "$BUNDLE_ID" ]] && OVERRIDES+=("PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE_ID")
LAUNCH_ID=${BUNDLE_ID:-$DEFAULT_BUNDLE_ID}

echo "Building $APP ($CONFIG)..."
xcodebuild -project "$APP.xcodeproj" -scheme "$APP" -configuration "$CONFIG" \
  -destination "id=$UDID" -derivedDataPath build -allowProvisioningUpdates -quiet \
  $OVERRIDES build

echo "Installing..."
xcrun devicectl device install app --device "$UDID" "build/Build/Products/$CONFIG-iphoneos/$APP.app"

echo "Launching $LAUNCH_ID..."
if ! xcrun devicectl device process launch --device "$UDID" "$LAUNCH_ID" >"$TMP/launch.log" 2>&1; then
  cat <<HINT
Installed, but the app could not be launched automatically.
  - Unlock the iPhone and run again, or just open $APP from the home screen.
  - First install? Trust the developer on the device: Settings > General >
    VPN & Device Management > (your Apple ID) > Trust.
  - Developer Mode must be on: Settings > Privacy & Security > Developer Mode.
HINT
fi
exit 0
