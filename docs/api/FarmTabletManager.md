# API — FarmTabletManager

**File:** `src/FarmTabletManager.lua`  
**Class:** `FarmTabletManager`  
**Global:** `g_FarmTablet` (set in `main.lua` after construction)

The top-level coordinator. Owns all subsystems and is the single entry point for external code (console commands, companion mods).

---

## Constructor

### `FarmTabletManager.new(mission, modDirectory, modName) → FarmTabletManager`
Creates the manager and all subsystems. Called once by `main.lua` during `Mission00.load`.

Only called when `g_dedicatedServer` is falsy. Should not be called manually.

---

## Lifecycle Methods

### `FarmTabletManager:onMissionLoaded()`
Called via `Mission00.loadMission00Finished` hook. Initialises the system, registers the key binding, and shows the welcome notification.

### `FarmTabletManager:update(dt)`
Called every frame via `FSBaseMission.update` hook. Delegates to `InputHandler`, `FarmTabletSystem`, and `FarmTabletUI`.

`dt` is in milliseconds.

### `FarmTabletManager:delete()`
Called via `FSBaseMission.delete` hook. Saves settings, unregisters the key binding, and destroys all UI overlays.

---

## Tablet Control

### `FarmTabletManager:openTablet()`
Opens the tablet. No-op if already open or if `ui` does not exist.

### `FarmTabletManager:closeTablet()`
Closes the tablet. No-op if already closed.

### `FarmTabletManager:toggleTablet()`
Opens if closed, closes if open.

### `FarmTabletManager:switchApp(appId) → boolean`
Switches the active app. Returns `true` on success, `false` if the app ID is not registered or not enabled.

```lua
g_FarmTablet:switchApp("weather")   -- true
g_FarmTablet:switchApp("invalid")   -- false
```

---

## Notifications

### `FarmTabletManager:showNotification(title, message)`
Shows a blinking HUD warning via `mission.hud:showBlinkingWarning()`. Silently no-ops if notifications are disabled or the HUD is unavailable.

```lua
g_FarmTablet:showNotification("Farm Tablet", "Press T to open")
```

Duration is fixed at 4000 ms.

---

## Logging

### `FarmTabletManager:log(msg, ...)`
Writes to `Logging.info` only when `settings.debugMode` is `true`. Uses `string.format` for the message.

```lua
g_FarmTablet:log("App switched to %s", appId)
```

---

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `mission` | mission | The FS25 mission object |
| `modDirectory` | string | Absolute path to the mod directory (trailing slash) |
| `modName` | string | The mod name string from FS25 |
| `settings` | Settings | User preferences object |
| `settingsManager` | SettingsManager | XML serialisation handler |
| `system` | FarmTabletSystem | Data and state layer |
| `ui` | FarmTabletUI\|nil | Rendering layer (nil on server peers) |
| `inputHandler` | InputHandler\|nil | Key polling (nil on server peers) |
| `settingsUI` | SettingsUI\|nil | Pause menu injection |
| `settingsGUI` | SettingsGUI\|nil | Console commands |
