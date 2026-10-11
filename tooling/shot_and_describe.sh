#!/usr/bin/env bash
# Screenshot the emulator and describe it.
# Usage: shot_and_describe.sh <output_name> ["prompt"]
set -euo pipefail
export PATH="$PATH:/Users/mymac/Library/Android/sdk/platform-tools"
NAME="${1:?usage: shot_and_describe.sh <name> [prompt]}"
PROMPT="${2:-Describe this screen and note any visual issues.}"
adb exec-out screencap -p > "/tmp/ciss_shots/${NAME}.png" 2>/dev/null
cp "/tmp/ciss_shots/${NAME}.png" "/Users/mymac/Documents/CISS-Mobile/tooling/${NAME}.png"
export VISION_MODEL=mimo-v2.5-free
bash /Users/mymac/Documents/CISS-Mobile/tooling/describe_image.sh "/Users/mymac/Documents/CISS-Mobile/tooling/${NAME}.png" "$PROMPT"
