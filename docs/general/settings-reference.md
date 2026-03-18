# Settings Reference

All Farm Tablet settings are accessible from three places:

1. **In-game tablet** — open the tablet and select the **Settings app** (`SET` in the sidebar)
2. **Pause menu** — press ESC → Settings tab → scroll to the Farm Tablet section
3. **Developer console** — `TabletShowSettings` to view, console commands to change

Settings are saved to `<savegame>/FS25_FarmTablet.xml` automatically. Each savegame has its own settings file.

---

## Display

### Position & Scale

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| `tabletPosX` | `0.5` | `0.0 – 1.0` | Horizontal screen position of the tablet centre (0 = left edge, 1 = right edge) |
| `tabletPosY` | `0.5` | `0.0 – 1.0` | Vertical screen position of the tablet centre (0 = bottom, 1 = top) |
| `tabletScale` | `1.0` | `0.5 – 2.0` | Overall size multiplier. 1.0 = 100%, 0.5 = half size, 2.0 = double |
| `tabletWidthMult` | `1.0` | `0.5 – 2.0` | Width-only stretch multiplier, independent of overall scale |

Position and scale are most easily set using **Edit Mode** — see [edit-mode.md](edit-mode.md).

To reset everything to centre/default: **Settings app → RESET POSITION & SCALE**  
Or via console: `TabletResetSettings`

---

## Sound

| Setting | Default | Description |
|---------|---------|-------------|
| `soundEffects` | `true` | Master toggle. When off, all sub-settings are silenced regardless of their own value |
| `soundOnAppSelect` | `true` | Plays a click sound when you switch apps in the sidebar |
| `soundOnHelpOpen` | `true` | Plays a paging sound when the FS25 in-game help panel opens or closes |
| `soundOnTabletToggle` | `true` | Plays a sound when you open or close the tablet |

All sounds use the game's built-in `GuiSoundPlayer` samples and respect the game's master volume.

---

## General

### Open Key

| Setting | Default | Description |
|---------|---------|-------------|
| `tabletKeybind` | `"T"` | The key that opens and closes the tablet |

**Supported keys:**

| Category | Keys |
|----------|------|
| Letters | `A` through `Z` (any single uppercase letter) |
| Function | `F1` through `F12` |
| Special | `TAB`, `SPACE`, `ENTER`, `BACKSPACE`, `DELETE`, `HOME`, `END`, `PAGEUP`, `PAGEDOWN`, `INSERT`, `ESC` |
| Arrows | `LEFT`, `RIGHT`, `UP`, `DOWN` |
| Numpad | `NUM0` through `NUM9`, `NUMMULT`, `NUMADD`, `NUMSUB`, `NUMDEC`, `NUMDIV` |
| Other | `` ` `` (grave/tilde), `CAPS`, `LSHIFT`, `LCTRL`, `LALT` |

Change via console: `TabletKeybind F5`  
The new key takes effect immediately — no restart needed.

> **Warning:** Do not bind to a key already used by the game (e.g. `W/A/S/D` for movement, `E` for interaction). The tablet polls the key every frame and will intercept it.

### Startup App

| Setting | Default | Description |
|---------|---------|-------------|
| `startupApp` | `"dashboard"` | The app shown first every time you open the tablet |

**Valid app IDs:** `dashboard` · `weather` · `field_status` · `animals` · `workshop` · `digging` · `bucket_tracker` · `income_mod` · `tax_mod` · `npc_favor` · `crop_stress` · `soil_fertilizer` · `app_store` · `settings` · `updates`

Change via the Settings app (cycles through common options) or console: `TabletSetStartupApp weather`

### Notifications

| Setting | Default | Description |
|---------|---------|-------------|
| `showTabletNotifications` | `true` | Shows a HUD welcome message when a savegame loads, telling you which key opens the tablet |

Disable if you already know the key and don't want the notification on every load.

### Vibration Feedback

| Setting | Default | Description |
|---------|---------|-------------|
| `vibrationFeedback` | `true` | Controller haptic feedback on interactions (reserved — not yet implemented in current release) |

### Debug Mode

| Setting | Default | Description |
|---------|---------|-------------|
| `debugMode` | `false` | Writes verbose diagnostic messages to the FS25 `log.txt` file |

All log lines are prefixed with `[FarmTablet]` or `[FarmTablet System]` / `[FarmTablet UI]` for easy filtering.

Enable debug mode when: filing a bug report, troubleshooting a missing app, or developing a new app that needs to inspect DataProvider output.

---

## Resetting All Settings

**From the tablet:** Settings app → scroll to bottom → **RESET ALL TO DEFAULTS**

**From the console:** `TabletResetSettings`

This restores everything to factory defaults including position, scale, key binding, and startup app. It cannot be undone.

---

## The XML File

Here is an example of what `FS25_FarmTablet.xml` looks like:

```xml
<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<FarmTablet>
    <enabled>true</enabled>
    <tabletKeybind>T</tabletKeybind>
    <showTabletNotifications>true</showTabletNotifications>
    <startupApp>dashboard</startupApp>
    <vibrationFeedback>true</vibrationFeedback>
    <soundEffects>true</soundEffects>
    <soundOnAppSelect>true</soundOnAppSelect>
    <soundOnHelpOpen>true</soundOnHelpOpen>
    <soundOnTabletToggle>true</soundOnTabletToggle>
    <debugMode>false</debugMode>
    <tabletPosX>0.5</tabletPosX>
    <tabletPosY>0.5</tabletPosY>
    <tabletScale>1.0</tabletScale>
    <tabletWidthMult>1.0</tabletWidthMult>
</FarmTablet>
```

You can edit this file directly with a text editor while the game is not running. The values will be validated on next load (out-of-range numbers are clamped, missing booleans default to `true`).
