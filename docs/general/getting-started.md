# Getting Started

Farm Tablet is a full-screen HUD overlay for Farming Simulator 25. It lets you check your balance, fields, weather, animals, vehicles, and more — all without leaving the game or opening any menus.

---

## Requirements

- Farming Simulator 25 (PC / Mac)
- No other mods required
- Companion mods are optional — their apps appear automatically when installed

---

## Installation

**1. Download**

Get the latest zip from the [GitHub Releases page](https://github.com/TheCodingDad-TisonK/FS25_FarmTablet/releases).
The file will be named `FS25_FarmTablet.zip`.

**2. Drop into mods folder**

```
Windows:  %USERPROFILE%\Documents\My Games\FarmingSimulator2025\mods\
macOS:    ~/Documents/My Games/FarmingSimulator2025/mods/
```

Do **not** unzip it — FS25 reads mods directly from the zip.

**3. Enable in mod manager**

Start FS25, go to the mod manager, and make sure Farm Tablet is ticked.

**4. Load a savegame**

Load any existing save or start a new one. You will see a brief HUD notification when the mod is ready.

**5. Press `T`**

The tablet opens. That's it.

---

## First Open

When the tablet opens for the first time it shows the **Dashboard** app. This is the default startup app and gives you a quick overview of your farm:

- Current balance
- Income, expenses, net profit/loss
- Active field count and vehicle count
- Current time, season, and live weather

---

## Navigating

The tablet has three zones:

```
┌───────────┬───────────────────────────────────────────────┐
│           │  TOPBAR — farm name · current app · clock     │
│  SIDEBAR  ├───────────────────────────────────────────────┤
│  (icons)  │                                               │
│           │         CONTENT AREA (current app)            │
│           │                                               │
└───────────┴───────────────────────────────────────────────┘
```

- **Sidebar** — click any icon to switch apps. Scroll the mouse wheel over the sidebar if you have more apps than fit.
- **Content area** — the active app. Some apps (Settings, Field Status with many fields) scroll with the mouse wheel.
- **Topbar** — always visible. Shows your farm name, the current app name, and the in-game clock.
- **X button** (top-right of topbar) — closes the tablet.

---

## Changing the Open Key

The default key is `T`. To change it:

- Open the tablet → **Settings app** → find **OPEN KEY** and click **STARTUP APP** to cycle options  
  *(full key change is via console command — see below)*
- Or type in the developer console: `TabletKeybind F5`

The change takes effect immediately, no restart needed.

---

## Closing the Tablet

Three ways to close:

1. Press `T` again (or whatever key you bound)
2. Click the **X** button in the top-right corner
3. Press `ESC`

---

## Where Settings Are Saved

Settings are stored in a per-savegame XML file:

```
<savegame directory>/FS25_FarmTablet.xml
```

This means each savegame can have different settings (different key, different startup app, etc.). The file is created automatically on first save.

---

## Uninstalling

1. Remove `FS25_FarmTablet.zip` from your mods folder
2. The `FS25_FarmTablet.xml` file in your savegame directory is safe to delete manually if you want a clean uninstall

The mod does not modify any game files — uninstalling it leaves your savegame completely intact.
