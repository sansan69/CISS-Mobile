#!/usr/bin/env bash
# Builds the production web bundle for https://cisskerala.site/app/.
#
# The app is served from the same origin as the API, so every request stays
# same-origin and the API host does not need a CORS exception. The base href
# must match the path the bundle is published under.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

base_href="${CISS_WEB_BASE_HREF:-/app/}"
out="${1:-}"

flutter pub get
flutter analyze
flutter test

flutter build web \
  --release \
  --base-href="$base_href" \
  --dart-define=CISS_API_BASE_URL="${CISS_WEB_API_BASE_URL:-}"

echo "Built web bundle in build/web (base href: $base_href)"

if [[ -n "$out" ]]; then
  mkdir -p "$out"
  rsync -a --delete build/web/ "$out/"
  echo "Published web bundle to $out"
fi
