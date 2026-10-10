#!/bin/zsh
# Runs the unit tests. No app launch, no Firebase, no signing — the suite
# compiles the pure-logic sources straight into the test bundle, so it stays
# fast enough to run on every change.
#
#   ./test.sh            runs everything
#   ./test.sh -q         only the result line
set -e
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")"

SIM=$(xcrun simctl list devices available -j | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
for runtime, devices in d.items():
    for dev in devices:
        if 'iPhone' in dev['name']:
            print(dev['udid']); raise SystemExit
print('', end='')")

if [[ -z "$SIM" ]]; then
  echo "Kein iPhone-Simulator gefunden. Xcode → Settings → Components." >&2
  exit 1
fi

LOG=$(mktemp)
set +e
xcodebuild test -project SocialSound.xcodeproj -scheme SocialSoundTests \
  -destination "id=$SIM" -quiet > "$LOG" 2>&1
CODE=$?
set -e

if [[ "$1" == "-q" ]]; then
  grep -E 'Test run with' "$LOG" | tail -1
else
  grep -E '✘|✔ Test run with|error:' "$LOG" | tail -30
fi
rm -f "$LOG"
exit $CODE
