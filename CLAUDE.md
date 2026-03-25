# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

CLI tool to control HomeKit smart plugs from the terminal (Fish Shell + native Mac Catalyst bridge app). Replaces the Apple Shortcuts workaround with direct HomeKit framework access.

## Architecture

Two-layer design:

1. **Fish Shell layer** (`plug.fish`, `kaffee.fish`) — user-facing CLI, installed in `~/.config/fish/functions/`
2. **HomeKitBridge** (`HomeKitBridge/`) — headless Mac Catalyst app that talks to HomeKit via `HMHomeManager`

IPC is file-based JSON over `/tmp`: the fish function creates a unique temp dir (`/tmp/homekit-bridge.XXXXXX/`), writes a command to `command.json`, launches the app with `open -gnj`, and reads the response from `output.json`. The temp dir is cleaned up after each invocation.

HomeKit on macOS requires a signed `.app` bundle with the `com.apple.developer.homekit` entitlement and a provisioning profile — a plain CLI binary cannot access HomeKit.

The app runs completely headless: `LSUIElement=true` hides the Dock icon, an empty `UIApplicationSceneManifest` with a `HeadlessSceneDelegate` prevents any window from appearing.

## Build & Install

Requires: Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen), Apple Developer account with HomeKit capability registered for `de.gmx.ywenger.HomeKitBridge`.

Full install (build + copy fish functions + set app path):
```bash
bash install.sh
```

Build only:
```bash
cd HomeKitBridge
bash build.sh
```

The built app lands in `HomeKitBridge/build/DerivedData/Build/Products/Debug-maccatalyst/HomeKitBridge.app`.

`install.sh` sets the Fish universal variable `KAFFEE_HOMEKITBRIDGE_APP` so that `plug` can find the app from any working directory.

## App discovery

`_plug_find_app` in `plug.fish` searches for `HomeKitBridge.app` in this order:
1. `$KAFFEE_HOMEKITBRIDGE_APP` env/universal variable (set by `install.sh`)
2. Relative to `$PWD`, script dir, and function file location
3. `~/Library/Developer/Xcode/DerivedData`
4. Broad `$HOME` crawl (slow fallback)

## Language notes

User-facing strings (help text, error messages, CLI output) are in German.
