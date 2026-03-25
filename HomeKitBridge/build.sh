#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Building Mac Catalyst app with automatic signing..."
xcodebuild \
  -project HomeKitBridge.xcodeproj \
  -scheme HomeKitBridge \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=S6YY3WWW2B \
  build 2>&1 | tail -10

# Find the built app
APP_PATH=$(find "$DERIVED_DATA" -path "*/HomeKitBridge-*/Build/Products/Debug-maccatalyst/HomeKitBridge.app" -maxdepth 5 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
  echo "ERROR: Could not find built app"
  exit 1
fi

echo "==> Built app at: $APP_PATH"
echo ""
echo "Run with:"
echo "  \"$APP_PATH/Contents/MacOS/HomeKitBridge\""
