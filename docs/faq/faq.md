# Frequently Asked Questions

---

## 🧑‍🌾 Player Questions

### The tablet doesn't open when I press T

1. Make sure `FS25_FarmTablet.zip` is in your mods folder and the mod is enabled in the mod manager for this savegame.
2. Reload the savegame after enabling it — the mod initialises at mission load time.
3. Open the developer console (`` ` `` key) and type `TabletEnable`. If it says "Farm Tablet not initialized", the mod didn't load — check `log.txt` for errors.
4. If it says "Farm Tablet enabled", press `T` again.
5. Still nothing? Try `TabletToggle` in the console to force-open it.

---

### I changed the key with `TabletKeybind` but pressing the new key doesn't work

The key string must be exact. Check the supported key list in [general/console-commands.md](../general/console-commands.md). Common mistakes:
- `tabletKeybind f5` — letters in the key name must be uppercase: `TabletKeybind F5`
- `TabletKeybind numpad1` — use `TabletKeybind NUM1`
- Binding to a key already used by the game (e.g. `E`, `F`, `H`) — the game may intercept it before the mod sees it

---

### The tablet is off-screen / I can't see it

Open the console and run:
```
TabletResetSettings
```
This resets position and scale to centre/default. Alternatively, open the tablet (it will open even if partially off-screen), navigate to the Settings app by typing `TabletApp settings`, and click **RESET POSITION & SCALE**.

---

### The balance shows $0 or wrong numbers

The Dashboard reads from `farm.stats` which is updated by the game engine. On a fresh savegame it may show `$0` until the first transaction is recorded. If it shows an unexpected value, try opening and closing the tablet once to force a cache refresh.

---

### Fields aren't showing in the Field Status app

The Field Status app shows farmland parcels that have a linked crop field. Purchased land that has never been ploughed or planted may not have a field object yet — cultivate and seed it first. Fields owned by other farms in multiplayer will not appear.

---

### The Workshop app shows no vehicles

Walk to within 35 metres of a vehicle. The detection radius is intentionally local. The vehicle must be motorised (have an engine) — trailers and implements without a motor will not appear.

---

### A companion mod app (Income, Tax, NPC, etc.) isn't appearing

1. The companion mod must be active **in this savegame's mod list**, not just installed.
2. The app only appears after the mission finishes loading. If you added the companion mod while the game was running, restart the game session.
3. Enable debug mode (`TabletApp settings` → Debug Mode ON), reload the save, and check `log.txt` for `[FarmTablet System]` lines to see what was detected.

---

### The forecast in the Weather app is empty

The forecast requires the game's weather system to have forecast data available. On some maps, in very early saves, or when using certain weather mods, forecast data may not be populated. The current conditions (temperature, rain, wind) are always available even without a forecast.

---

### The tablet opened but it's completely black / blank

This usually means the FS25 overlay manager couldn't create overlays. Possible causes:
- Extremely low graphics settings that disable HUD overlays
- Conflict with another mod that also takes over the overlay manager
- GPU driver issue

Try pressing `T` to close and reopen the tablet. If it persists, check `log.txt` for `Could not create overlay` warnings.

---

### Can I use this in multiplayer?

Yes. The tablet runs independently on each player's client. Each player sees data for their own farm. There is no shared state between players. The mod is completely skipped on dedicated servers — there is no server-side overhead.

---

### Will this break my savegame?

No. Farm Tablet only reads game data — it does not modify any savegame files. The only file it writes is `FS25_FarmTablet.xml` (in your savegame directory), which contains only tablet settings. Removing the mod leaves your savegame completely intact.

---

### How do I uninstall?

1. Remove `FS25_FarmTablet.zip` from your mods folder.
2. Optionally delete `FS25_FarmTablet.xml` from your savegame directory for a clean removal.

---

### Can I have different settings on different savegames?

Yes. Each savegame has its own `FS25_FarmTablet.xml`. You can have different keybinds, positions, startup apps, and sound settings per save.

---

### How do I report a bug?

1. Enable debug mode (Settings app → Debug Mode ON)
2. Reproduce the bug
3. Find the relevant lines in `log.txt` (search for `[FarmTablet]`)
4. Open a [Bug Report](https://github.com/TheCodingDad-TisonK/FS25_FarmTablet/issues/new?template=bug_report.yml) on GitHub and paste the log lines

---

## 🧑‍💻 Developer Questions

### How do I write a new app?

See [developer/writing-an-app.md](../developer/writing-an-app.md) for a step-by-step guide from registration to a working drawer with buttons, help page, and data access.

### How do I register my companion mod app so it auto-detects?

Add a detection block to `AppRegistry:autoDetect()` in `src/core/AppRegistry.lua`:

```lua
if g_currentMission and g_currentMission.myModManager then
    if not self:has("my_app_id") then
        self:register({ id = "my_app_id", ... })
    end
end
```

Or, if you're shipping a standalone companion mod (not modifying Farm Tablet's source), call `AppRegistry:register()` directly from your mod's mission-loaded callback after checking `if AppRegistry then`.

---

### What's the global I use to access the tablet from my mod?

```lua
g_FarmTablet                          -- FarmTabletManager instance
g_FarmTablet.ui                       -- FarmTabletUI (nil on server)
g_FarmTablet.system                   -- FarmTabletSystem
g_FarmTablet.system.registry          -- AppRegistry
g_FarmTablet.system.data              -- FT_DataProvider
g_FarmTablet.settings                 -- Settings
```

Always guard with `if g_FarmTablet then` in case Farm Tablet is not installed.

---

### How do I make my app refresh automatically?

For most apps, clicking a button calls `self:switchApp(appId)` which rebuilds the content area. For live data that needs continuous updates (like position in the Digging app), add your app ID to the `update(dt)` block in `FarmTabletUI:update()`:

```lua
if appId == "my_app" then
    if self.updateMyApp then self:updateMyApp(dt) end
end
```

Then define `FarmTabletUI.updateMyApp` as a function that calls `self.r:clearAppLayer()` + `self:_drawContent()` on a timer. See `DiggingApp.lua` for the pattern.

---

### Can I draw directly with FS25 rendering functions instead of the Renderer?

Avoid it. The Renderer handles layer ordering, clip culling, and overlay lifecycle. Calling `renderOverlay()` or `renderText()` directly from a drawer will draw in the wrong z-order (usually under the chrome) and leak resources (overlays won't be cleaned up on app switch or tablet close).

The Edit Mode border is the one exception — it uses native `renderOverlay` calls because it must render on top of everything, including cover strips.

---

### Why do `FT.px()` and `FT.py()` return 0?

They return `FT.LAYOUT.scaleX * v` and `FT.LAYOUT.scaleY * v`. `scaleX`/`scaleY` are set by `FarmTabletUI:_build()`, which only runs when the tablet opens. If you call `FT.px()` at module-load time (outside a function), the layout hasn't been built yet and the values will be 0.

Always use `FT.px()` and `FT.py()` inside function bodies — drawer functions, onClick handlers, etc.

---

### What events can I listen to from my mod?

```lua
FT_EventBus.EVENTS.TABLET_OPENED   -- no args
FT_EventBus.EVENTS.TABLET_CLOSED   -- no args
FT_EventBus.EVENTS.APP_SWITCHED    -- args: appId (string)
FT_EventBus.EVENTS.APP_REGISTERED  -- args: appId (string)
```

Register listeners during mission load:
```lua
if FT_EventBus then
    FT_EventBus:on(FT_EventBus.EVENTS.TABLET_OPENED, function()
        -- ...
    end)
end
```

---

### The DataProvider doesn't have a method I need — can I add one?

Yes. Follow the caching pattern in `DataProvider.lua`:

```lua
function FT_DataProvider:getMyData(farmId)
    return self:_cached("mydata_"..farmId, 2000, function()
        if not g_myManager then return defaultValue end
        return g_myManager:getSomething(farmId)
    end)
end
```

If you're building a companion mod rather than modifying Farm Tablet, you can add your own data helper to the existing instance at runtime:
```lua
if g_FarmTablet and g_FarmTablet.system.data then
    g_FarmTablet.system.data.getMyData = function(self, farmId)
        -- ...
    end
end
```

---

### How does the repair button work in the Workshop app?

1. Locally it sets `spec_wearable.totalAmount = 0` and zeroes all component amounts directly
2. It also tries `workshop:repairVehicle(vehicle)` via `pcall`
3. If the local client is not the server (pure client in multiplayer), it sends a `VehicleRepairEvent` network event via `g_client:getServerConnection():sendEvent()`

---

### The Settings app has a scroll but my app doesn't — how do I add it?

Call `self:setContentHeight(totalH)` at the end of your drawer where `totalH = startY - y` (the total vertical extent of everything you drew). Then use `self:getContentScrollY()` at the top of your drawer and add it to your starting Y. The scroll wheel over the content area is handled automatically. See `SettingsApp.lua` for the full pattern.

---

### How do I store per-app state that persists while the tablet is open?

Store it on `self.system`:
```lua
self.system.myAppFilter = self.system.myAppFilter or "all"
```

State stored on `self.system` survives app switches (the system object is not rebuilt). It is reset when the tablet closes if you add a nil assignment to `FarmTabletSystem:onTabletClosed()`.

For truly persistent state (across tablet open/close), store it in a custom Settings field or a separate XML file.

---

### Is there a way to test apps without a full FS25 install?

Not officially — the mod requires the FS25 Lua runtime, overlay manager, and game globals. However, you can use `debugMode = true` to get verbose log output, and structure your drawer functions so all FS25-dependent code is isolated in DataProvider methods (which you can mock with simple tables during development).
