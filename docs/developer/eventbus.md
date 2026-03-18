# EventBus

`FT_EventBus` is a lightweight singleton publish/subscribe system used for decoupled communication between Farm Tablet components.

**File:** `src/core/EventBus.lua`  
**Global:** `FT_EventBus` (available after `EventBus.lua` is sourced)

---

## When to Use It

Use the EventBus when you need to react to tablet-level events from code that does not have a direct reference to the UI or system objects — for example, from a companion mod that wants to refresh its app when the user opens the tablet.

For code that already has access to `self.system` or `self.r` (i.e. inside a drawer function), you generally do not need the EventBus — just read the data you need.

---

## API

### `FT_EventBus:on(event, fn)`
Registers a listener function for the given event. The listener is stored and called every time the event is emitted.

```lua
FT_EventBus:on(FT_EventBus.EVENTS.TABLET_OPENED, function()
    -- Called every time the tablet opens
    print("Tablet opened")
end)

FT_EventBus:on(FT_EventBus.EVENTS.APP_SWITCHED, function(appId)
    -- Called every time the user switches app
    if appId == "my_custom_app" then
        -- refresh local state
    end
end)
```

Listeners are stored indefinitely. They persist for the entire game session unless explicitly removed.

### `FT_EventBus:off(event, fn)`
Removes a specific listener function. The function reference must match exactly (same closure or named function).

```lua
local function onOpened()
    -- ...
end

FT_EventBus:on(FT_EventBus.EVENTS.TABLET_OPENED, onOpened)
-- later:
FT_EventBus:off(FT_EventBus.EVENTS.TABLET_OPENED, onOpened)
```

### `FT_EventBus:emit(event, ...)`
Fires the event, calling all registered listeners with the given arguments. Each listener is called inside a `pcall` — a failing listener logs a warning and does not interrupt the others.

```lua
-- Internal use — called by FarmTabletUI and FarmTabletSystem
FT_EventBus:emit(FT_EventBus.EVENTS.APP_SWITCHED, "weather")
```

---

## Well-Known Events

All event name strings are in `FT_EventBus.EVENTS`:

### `TABLET_OPENED`
Emitted when the tablet finishes opening (after the drawable is registered and mouse capture is set).

```lua
FT_EventBus:on(FT_EventBus.EVENTS.TABLET_OPENED, function()
    -- no arguments
end)
```

**Emitted by:** `FarmTabletUI:openTablet()`

### `TABLET_CLOSED`
Emitted when the tablet finishes closing (after the drawable is removed and stale state is reset).

```lua
FT_EventBus:on(FT_EventBus.EVENTS.TABLET_CLOSED, function()
    -- no arguments
end)
```

**Emitted by:** `FarmTabletUI:closeTablet()`

### `APP_SWITCHED`
Emitted when the active app changes. Receives the new app ID as the first argument.

```lua
FT_EventBus:on(FT_EventBus.EVENTS.APP_SWITCHED, function(appId)
    -- appId: string e.g. "weather", "dashboard"
end)
```

**Emitted by:** `FarmTabletUI:switchApp()`

### `APP_REGISTERED`
Emitted when a new app is registered with the `AppRegistry`. Receives the app ID.

```lua
FT_EventBus:on(FT_EventBus.EVENTS.APP_REGISTERED, function(appId)
    -- appId: the newly registered app
end)
```

**Emitted by:** `AppRegistry:register()`

### `SETTINGS_CHANGED`
Reserved for future use. Currently not emitted by the core. Companion mods or future Settings app updates may emit it.

```lua
FT_EventBus:on(FT_EventBus.EVENTS.SETTINGS_CHANGED, function()
    -- settings object has been modified
end)
```

### `DATA_REFRESHED`
Reserved for future use. Intended to signal that the DataProvider cache has been invalidated.

---

## Implementation Notes

- `FT_EventBus._listeners` is a **module-level table** (not per-instance). All listeners from all parts of the mod share the same table for the lifetime of the game session.
- The EventBus itself is never reset between tablet open/close cycles. Listeners registered at mod-load time remain active.
- Listeners are called in registration order.
- If you register the same function multiple times, it will be called multiple times per emit.
- There is no wildcard or pattern matching — subscribe to specific event strings only.

---

## Using EventBus in a Companion Mod

If your companion mod is loaded after Farm Tablet, you can subscribe to events safely at mission-load time:

```lua
-- In your mod's main.lua, inside the loadedMission callback:
local function loadedMission()
    if FT_EventBus then
        FT_EventBus:on(FT_EventBus.EVENTS.TABLET_OPENED, function()
            -- tablet just opened — your app may want to reset state or preload data
        end)
    end
end

Mission00.loadMission00Finished = Utils.appendedFunction(
    Mission00.loadMission00Finished, loadedMission)
```

Always guard with `if FT_EventBus then` in case Farm Tablet is not installed.

---

## Emitting Custom Events

You can use the EventBus for communication between your own app components by using custom event strings:

```lua
-- Define your event names
local MY_EVENTS = {
    VEHICLE_SELECTED = "my_mod_vehicle_selected",
    DATA_READY       = "my_mod_data_ready",
}

-- Emit
FT_EventBus:emit(MY_EVENTS.VEHICLE_SELECTED, vehicleId)

-- Listen
FT_EventBus:on(MY_EVENTS.VEHICLE_SELECTED, function(vehicleId)
    -- handle selection
end)
```

Use a unique prefix (your mod name) to avoid collisions with future built-in events.
