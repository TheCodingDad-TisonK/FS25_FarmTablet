# Console Commands

The developer console is opened with the **grave/tilde key** (`` ` `` or `~`). Type `tablet` and press Enter to see all commands.

Console commands are only available on the **local client** — they do not work on dedicated servers and are not available to other players in multiplayer.

---

## Full Command Reference

### `tablet`
Shows the full list of available commands in the console output.

---

### `TabletOpen`
Opens the tablet if it is closed. Does nothing if already open.

```
TabletOpen
```

---

### `TabletClose`
Closes the tablet if it is open. Does nothing if already closed.

```
TabletClose
```

---

### `TabletToggle`
Opens the tablet if closed, closes it if open. Equivalent to pressing the keybind key.

```
TabletToggle
```

---

### `TabletEnable`
Enables the mod if it has been disabled. The tablet will respond to the keybind again.

```
TabletEnable
```

---

### `TabletDisable`
Disables the mod. The tablet will no longer open when the keybind is pressed. The setting is saved.

```
TabletDisable
```

---

### `TabletKeybind [key]`
Changes the key used to open/close the tablet. Takes effect immediately.

```
TabletKeybind F5
TabletKeybind B
TabletKeybind TAB
TabletKeybind NUM1
```

**Valid values:** any letter `A–Z`, `F1–F12`, `TAB`, `SPACE`, `ENTER`, `BACKSPACE`, `DELETE`, `HOME`, `END`, `PAGEUP`, `PAGEDOWN`, `INSERT`, `ESC`, `LEFT`, `RIGHT`, `UP`, `DOWN`, numpad `NUM0–NUM9`, `NUMMULT`, `NUMADD`, `NUMSUB`, `NUMDEC`, `NUMDIV`.

Keys are **case-insensitive** — `f5`, `F5`, and `f5` all work.

> If you enter an invalid key, the keybind defaults back to `T`.

---

### `TabletApp [app_id]`
Switches the tablet to the specified app. Opens the tablet if it is closed.

```
TabletApp weather
TabletApp field_status
TabletApp workshop
TabletApp bucket_tracker
```

**Valid app IDs:**

| ID | App |
|----|-----|
| `dashboard` | Dashboard |
| `weather` | Weather |
| `field_status` | Field Status |
| `animals` | Animal Husbandry |
| `workshop` | Workshop |
| `digging` | Digging |
| `bucket_tracker` | Bucket Tracker |
| `income_mod` | Income Mod *(requires companion mod)* |
| `tax_mod` | Tax Mod *(requires companion mod)* |
| `npc_favor` | NPC Favor *(requires companion mod)* |
| `crop_stress` | Seasonal Crop Stress *(requires companion mod)* |
| `soil_fertilizer` | Soil Fertilizer *(requires companion mod)* |
| `app_store` | App Store |
| `settings` | Settings |
| `updates` | Updates / Changelog |

---

### `TabletSetStartupApp [app_id]`
Sets which app opens first every time you press the keybind. The change is saved.

```
TabletSetStartupApp weather
TabletSetStartupApp dashboard
```

---

### `TabletSetNotifications true|false`
Enables or disables the HUD welcome notification shown when a savegame loads.

```
TabletSetNotifications false
TabletSetNotifications true
```

---

### `TabletShowSettings`
Prints all current settings to the console output. Useful for bug reports.

```
TabletShowSettings
```

Example output:
```
=== Farm Tablet Settings ===
Enabled: true
Open Key: T
Startup App: DASHBOARD
Notifications: true
Sound Effects: true
Debug Mode: false
==========================
```

---

### `TabletResetSettings`
Resets **all** settings to factory defaults — keybind, startup app, position, scale, sounds, everything. Cannot be undone.

```
TabletResetSettings
```

---

## Tips

**Open a specific app instantly from the console:**
```
TabletApp weather
```
This is useful during development or testing to skip navigating the sidebar.

**Check the log for tablet activity:**  
Enable debug mode and watch `log.txt` — all tablet events, app switches, and data refreshes are logged with `[FarmTablet]` prefix.

**Reset position if the tablet goes off-screen:**
```
TabletResetSettings
```
Or if you only want to reset position/scale without changing other settings, open the tablet (it will still render even if partially off-screen), navigate to Settings → RESET POSITION & SCALE.
