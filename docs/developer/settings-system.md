# Settings System

The settings system is split into three classes with distinct responsibilities.

---

## Overview

```
SettingsManager  ←→  Settings  ←→  SettingsUI / SettingsGUI
(XML I/O)            (values)       (pause menu / console)
```

- **`Settings`** — plain value object that holds all preferences
- **`SettingsManager`** — reads/writes `FS25_FarmTablet.xml`
- **`SettingsUI`** — injects options into the FS25 pause-menu settings frame
- **`SettingsGUI`** — registers developer console commands

---

## Settings (value object)

**File:** `src/settings/Settings.lua`  
**Class:** `Settings`  
**Constructed by:** `FarmTabletManager.new()`

### Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | bool | `true` | Whether the mod is active |
| `tabletKeybind` | string | `"T"` | Key to open/close |
| `showTabletNotifications` | bool | `true` | HUD welcome message |
| `startupApp` | string | `"dashboard"` | App shown on open |
| `vibrationFeedback` | bool | `true` | Controller haptics (reserved) |
| `soundEffects` | bool | `true` | Master sound toggle |
| `soundOnAppSelect` | bool | `true` | Sidebar click sound |
| `soundOnHelpOpen` | bool | `true` | Help panel paging sound |
| `soundOnTabletToggle` | bool | `true` | Open/close sound |
| `debugMode` | bool | `false` | Verbose logging |
| `tabletPosX` | float | `0.5` | Horizontal tablet position (0–1) |
| `tabletPosY` | float | `0.5` | Vertical tablet position (0–1) |
| `tabletScale` | float | `1.0` | Overall scale (0.5–2.0) |
| `tabletWidthMult` | float | `1.0` | Width multiplier (0.5–2.0) |

### Key methods

```lua
Settings:load()               -- loads from XML via SettingsManager, then validates
Settings:save()               -- writes to XML via SettingsManager
Settings:resetToDefaults()    -- sets all fields to defaults and saves
Settings:validateSettings()   -- clamps ranges, coerces types, migrates legacy values
Settings:setKeybind(key)      -- sets tabletKeybind
Settings:setStartupApp(appId) -- sets startupApp
Settings:getStartupAppName()  -- returns UPPER(startupApp) for display
```

### Validation

`validateSettings()` runs after every load. It handles:

- **startupApp migration** — converts legacy integer indices (1-4) to string IDs using `STARTUP_MAP`
- **Boolean coercion** — `not not value` ensures all booleans are proper booleans, not nil
- **Numeric clamping** — scale and position values are clamped to their valid ranges

---

## SettingsManager (XML I/O)

**File:** `src/settings/SettingsManager.lua`  
**Class:** `SettingsManager`

### Save path

```lua
<savegame_directory>/FS25_FarmTablet.xml
```

Where `savegame_directory` comes from `g_currentMission.missionInfo.savegameDirectory`.

If the path is unavailable (e.g. mission not yet fully loaded), `getSavegameXmlFilePath()` returns `nil` and save/load silently no-ops.

### XML structure

The XML root tag is `FarmTablet`. All values are stored as immediate children:

```xml
<FarmTablet>
    <enabled>true</enabled>
    <tabletKeybind>T</tabletKeybind>
    <startupApp>dashboard</startupApp>
    <!-- ... other fields ... -->
</FarmTablet>
```

### Important type notes

| Field | XML type | API used |
|-------|----------|---------|
| `enabled` | bool | `getBool` / `setBool` |
| `tabletKeybind` | string | `getString` / `setString` |
| `startupApp` | string | `getString` / `setString` (was `getInt`/`setInt` in v1 — legacy migration in load) |
| `tabletPosX/Y` | float | `getFloat` / `setFloat` |
| `tabletScale` | float | `getFloat` / `setFloat` |
| `tabletWidthMult` | float | `getFloat` / `setFloat` |

### Legacy migration

Old saves (v1) stored `startupApp` as a numeric index. On load, the code first tries `getString` — if the result is empty it falls back to `getInt` and stores the raw integer. `Settings:validateSettings()` then converts it to a string ID via the `STARTUP_MAP` table.

---

## SettingsUI (pause-menu injection)

**File:** `src/settings/SettingsUI.lua`  
**Class:** `SettingsUI`

Injects Farm Tablet controls into the FS25 pause-menu settings frame (`InGameMenuSettingsFrame`). Uses `UIHelper` to create standard FS25 UI elements (section headers, checkbox rows, multi-option rows).

### Injection timing

`inject()` is called via an `Utils.appendedFunction` hook on `InGameMenuSettingsFrame.onFrameOpen`. The `self.injected` guard ensures it only runs once.

If injection fails (e.g. because the layout structure changed in a game update), it logs an error and does not crash.

### UI elements injected

- Section header: "Farm Tablet"
- Binary option: Enable/Disable
- Binary option: Debug Mode
- Multi option: Startup App (4 choices: Dashboard / App Store / Weather / Digging)
- Binary option: Notifications
- Binary option: Sound Effects

### Reset button

`ensureResetButton()` is called via a hook on `InGameMenuSettingsFrame.updateButtons`. It adds a "Reset Settings" button (bound to `InputAction.MENU_EXTRA_1`) to the frame footer. The button is only added once and is re-ensured on each frame open to handle cases where the footer is rebuilt.

---

## SettingsGUI (console commands)

**File:** `src/settings/SettingsGUI.lua`  
**Class:** `SettingsGUI`

Registers all console commands via `addConsoleCommand`. Commands are only registered when `mission:getIsClient()` is true.

All commands access `g_FarmTablet` (the global `FarmTabletManager` instance) and delegate to `g_FarmTablet.settings` or `g_FarmTablet.ui`.

---

## Adding a New Setting

1. Add the field with a default value in `Settings:resetToDefaults()`:
   ```lua
   self.myNewSetting = true
   ```

2. Add validation in `Settings:validateSettings()`:
   ```lua
   self.myNewSetting = not not self.myNewSetting
   ```

3. Add to `SettingsManager.defaultConfig`:
   ```lua
   myNewSetting = true,
   ```

4. Add load and save calls in `SettingsManager:loadSettings()` and `saveSettings()`:
   ```lua
   -- load
   settingsObject.myNewSetting = xml:getBool(self.XMLTAG..".myNewSetting", self.defaultConfig.myNewSetting)
   -- save
   xml:setBool(self.XMLTAG..".myNewSetting", settingsObject.myNewSetting)
   ```

5. Optionally expose it in the Settings app drawer (`src/apps/SettingsApp.lua`) and/or in `SettingsUI`.
