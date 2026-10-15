#!/bin/bash
set -e

echo "=== Installing Flutter ==="
FLUTTER_DIR="$HOME/flutter"
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  rm -rf "$FLUTTER_DIR"
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version

echo "=== Enabling Web Support ==="
flutter config --enable-web
flutter precache --web

echo "=== Installing Dependencies ==="
cd flutter_app
flutter pub get

echo "=== Building Web App ==="
# API_BASE_URL is set as a Netlify environment variable
flutter build web \
  --dart-define=API_BASE_URL=${API_BASE_URL:-http://127.0.0.1:8000} \
  --release

echo "=== Build Complete ==="
