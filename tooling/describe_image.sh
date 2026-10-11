#!/usr/bin/env bash
# Describe an image via the opencode zen vision endpoint.
# Usage: describe_image.sh <image_path> ["optional prompt"]
set -euo pipefail

IMG="${1:?usage: describe_image.sh <image> [prompt]}"
PROMPT="${2:-Describe this image in detail.}"
KEY="${OPENCODE_API_KEY:?OPENCODE_API_KEY not set}"
MODEL="${VISION_MODEL:-mimo-v2.5-free}"
BASE="https://opencode.ai/zen/v1"

MIME="image/png"
case "$IMG" in
  *.jpg|*.jpeg) MIME="image/jpeg" ;;
  *.webp) MIME="image/webp" ;;
  *.gif) MIME="image/gif" ;;
esac

PAYLOAD_FILE=$(mktemp)
trap 'rm -f "$PAYLOAD_FILE"' EXIT

python3 - "$IMG" "$PAYLOAD_FILE" "$PROMPT" "$MIME" "$MODEL" <<'PY'
import base64, json, sys

img_path, out_path, prompt, mime, model = sys.argv[1:6]
b64 = base64.b64encode(open(img_path, "rb").read()).decode()
payload = {
    "model": model,
    "messages": [{
        "role": "user",
        "content": [
            {"type": "text", "text": prompt},
            {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}},
        ],
    }],
    "max_tokens": 2000,
}
open(out_path, "w").write(json.dumps(payload))
PY

curl -s -m 120 -X POST "$BASE/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KEY" \
  --data-binary "@$PAYLOAD_FILE" \
| python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'error' in data:
    print('API error:', json.dumps(data['error'])[:500], file=sys.stderr)
    sys.exit(1)
print(data['choices'][0]['message']['content'])
"
