#!/usr/bin/env bash
set -euo pipefail
FLUTTER_RELEASE="3.47.7"
FLUTTER_ROOT_DIR="${VERCEL_CACHE_DIR:-/tmp}/medivaanii-flutter-${FLUTTER_RELEASE}"
if [ ! -x "$FLUTTER_ROOT_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_RELEASE" https://github.com/flutter/flutter.git "$FLUTTER_ROOT_DIR"
fi
# The animated demo on the upload page (React + the Stageshow kit) is built
# into flutter_app/web/demo, which `flutter build web` then copies.
(cd demo && npm install --no-audit --no-fund && npm run build)
test -f flutter_app/web/demo/index.html
export PATH="$FLUTTER_ROOT_DIR/bin:$PATH"
export CI=true
flutter config --no-analytics
cd flutter_app
flutter pub get
flutter build web --release --no-tree-shake-icons --no-wasm-dry-run --dart-define=API_BASE_URL=/api
