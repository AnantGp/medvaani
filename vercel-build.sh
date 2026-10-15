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
# API_BASE_URL must be set in Vercel dashboard:
# Project Settings → Environment Variables → API_BASE_URL = https://your-backend.onrender.com
flutter build web \
  --no-wasm-dry-run \
  --dart-define=API_BASE_URL=${API_BASE_URL:-https://medical-translation-5.onrender.com} \
  --release

echo "=== Build Complete ==="
