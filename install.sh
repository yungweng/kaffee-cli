#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FISH_FUNCTIONS_DIR="$HOME/.config/fish/functions"

echo "==> kaffee-cli installieren"
echo ""

# 1. HomeKitBridge bauen
echo "==> HomeKitBridge bauen..."
bash "$SCRIPT_DIR/HomeKitBridge/build.sh"

APP_PATH="$SCRIPT_DIR/HomeKitBridge/build/DerivedData/Build/Products/Debug-maccatalyst/HomeKitBridge.app"
if [ ! -d "$APP_PATH" ]; then
  echo "FEHLER: HomeKitBridge.app wurde nicht gefunden nach dem Build." >&2
  exit 1
fi
echo "==> HomeKitBridge.app gebaut: $APP_PATH"
echo ""

# 2. Fish-Funktionen installieren
echo "==> Fish-Funktionen installieren nach $FISH_FUNCTIONS_DIR ..."
mkdir -p "$FISH_FUNCTIONS_DIR"

cp "$SCRIPT_DIR/plug.fish" "$FISH_FUNCTIONS_DIR/plug.fish"
cp "$SCRIPT_DIR/kaffee.fish" "$FISH_FUNCTIONS_DIR/kaffee.fish"

echo "  plug.fish    -> $FISH_FUNCTIONS_DIR/plug.fish"
echo "  kaffee.fish  -> $FISH_FUNCTIONS_DIR/kaffee.fish"
echo ""

echo "==> Installation abgeschlossen!"
echo ""
echo "Benutzung:"
echo "  kaffee an     – Kaffeemaschine einschalten"
echo "  kaffee aus    – Kaffeemaschine ausschalten"
echo "  plug status   – Status aller Geräte anzeigen"
