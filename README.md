# kaffee-cli

Steuerung einer HomeKit-Steckdose per Terminal (Fish Shell + Apple Shortcuts).

## Usage

```fish
kaffee        # Toggle (fragt echten HomeKit-Zustand ab)
kaffee an     # Einschalten
kaffee aus    # Ausschalten
```

## Installation

### 1. Apple Shortcuts anlegen

Erstelle drei Shortcuts in der Shortcuts-App:

| Shortcut | Aktion |
|---|---|
| **Kaffee an** | "Mein Zuhause steuern" → Steckdose → Einschalten |
| **Kaffee aus** | "Mein Zuhause steuern" → Steckdose → Ausschalten |
| **Kaffee Status** | "Status von Zuhause-Geräten abrufen" → Steckdose → Wenn eingeschaltet: Text "an", Sonst: Text "aus" |

> **Wichtig:** Der "Kaffee Status" Shortcut darf **nicht** "Stoppen und ausgeben" verwenden — stattdessen einfach den Text als letzte Aktion stehen lassen.

### 2. Fish-Funktion installieren

```fish
cp kaffee.fish ~/.config/fish/functions/kaffee.fish
```

Fish lädt die Funktion automatisch per Autoloading.

## Technische Details

- Apple bietet kein CLI für HomeKit — Umweg über `shortcuts run`
- `shortcuts run -o` braucht eine **`.txt` Dateiendung** — ohne Extension bleibt die Output-Datei leer!
- Der echte Gerätezustand wird über den Shortcut "Kaffee Status" abgefragt, nicht lokal gecacht
- Fish Autoloading: Dateiname = Funktionsname → automatisch verfügbar

## Voraussetzungen

- macOS mit HomeKit-konfigurierter Steckdose
- Fish Shell
- Apple Shortcuts CLI (`/usr/bin/shortcuts`)
