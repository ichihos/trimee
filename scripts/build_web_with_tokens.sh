#!/bin/bash

# .envファイルから環境変数を読み込む
if [ -f .env ]; then
  echo "Reading .env file..."
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found!"
  exit 1
fi

if [ -z "$GOOGLE_MAPS_API_KEY_WEB" ]; then
  echo "Error: GOOGLE_MAPS_API_KEY_WEB is not set in .env"
  exit 1
fi

echo "Building web app..."
flutter build web --release

echo "Injecting Google Maps API Key..."
# build/web/index.html の INSERT_KEY_HERE を実際のキーに置換
# バックアップを作成せずに置換 (macOS sed format)
sed -i '' "s/INSERT_KEY_HERE/${GOOGLE_MAPS_API_KEY_WEB}/g" build/web/index.html

echo "Web build completed successfully with API Key injected."
