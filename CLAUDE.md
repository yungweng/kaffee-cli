# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

CLI tool to control HomeKit smart plugs from the terminal (Fish Shell + native Mac Catalyst bridge app). Replaces the Apple Shortcuts workaround with direct HomeKit framework access.

## Architecture

Two-layer design:

1. **Fish Shell layer** (`plug.fish`, `kaffee.fish`) — user-facing CLI, installed in `~/.config/fish/functions/`
2. **HomeKitBridge** (`HomeKitBridge/`) — headless Mac Catalyst app that talks to HomeKit via `HMHomeManager`

IPC is file-based JSON over `/tmp`: the fish function writes a command to `/tmp/homekit-bridge-command.json`, launches the app with `open -gj`, and reads the response from `/tmp/homekit-bridge-output.json`.

HomeKit on macOS requires a signed `.app` bundle with the `com.apple.developer.homekit` entitlement and a provisioning profile — a plain CLI binary cannot access HomeKit.

## Build

Requires: Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen), Apple Developer account with HomeKit capability registered for `de.gmx.ywenger.HomeKitBridge`.

```bash
cd HomeKitBridge
bash build.sh
```

Or manually:
```bash
xcodegen generate
xcodebuild -project HomeKitBridge.xcodeproj -scheme HomeKitBridge \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -allowProvisioningUpdates CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=S6YY3WWW2B build
```

The built app lands in `~/Library/Developer/Xcode/DerivedData/HomeKitBridge-*/Build/Products/Debug-maccatalyst/HomeKitBridge.app`.

## Install fish functions

```bash
cp plug.fish ~/.config/fish/functions/plug.fish
cp kaffee.fish ~/.config/fish/functions/kaffee.fish
```

The `_plug_wait_output` helper function also needs to be in `~/.config/fish/functions/`.

## Language notes

User-facing strings (help text, error messages, CLI output) are in German.
