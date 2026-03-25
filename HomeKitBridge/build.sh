#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

DERIVED_DATA="$SCRIPT_DIR/build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-maccatalyst/HomeKitBridge.app"

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Building Mac Catalyst app with automatic signing..."
xcodebuild \
  -project HomeKitBridge.xcodeproj \
  -scheme HomeKitBridge \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=S6YY3WWW2B \
  build 2>&1 | tail -10

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: Could not find built app"
  exit 1
fi

echo "==> Built app at: $APP_PATH"
echo ""
echo "Run with:"
echo "  open -gj \"$APP_PATH\" --args /tmp/homekit-bridge-command.json /tmp/homekit-bridge-output.json"
