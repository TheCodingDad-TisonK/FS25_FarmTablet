# API — EventBus (`FT_EventBus`)

**File:** `src/core/EventBus.lua`  
**Global:** `FT_EventBus`

Quick-reference. See [developer/eventbus.md](../developer/eventbus.md) for usage patterns and implementation notes.

---

## Methods

### `FT_EventBus:on(event, fn)`
Registers `fn` as a listener for `event`. Persists for the game session.

### `FT_EventBus:off(event, fn)`
Removes `fn` from `event`. The function reference must match exactly.

### `FT_EventBus:emit(event, ...)`
Calls all listeners for `event` with `...` as arguments. Each listener is wrapped in `pcall`.

---

## Well-Known Events

All names are in `FT_EventBus.EVENTS`:

| Constant | String | Arguments | Emitted by |
|----------|--------|-----------|-----------|
| `TABLET_OPENED` | `"tablet_opened"` | — | `FarmTabletUI:openTablet()` |
| `TABLET_CLOSED` | `"tablet_closed"` | — | `FarmTabletUI:closeTablet()` |
| `APP_SWITCHED` | `"app_switched"` | `appId: string` | `FarmTabletUI:switchApp()` |
| `APP_REGISTERED` | `"app_registered"` | `appId: string` | `AppRegistry:register()` |
| `SETTINGS_CHANGED` | `"settings_changed"` | — | *(reserved)* |
| `DATA_REFRESHED` | `"data_refreshed"` | — | *(reserved)* |

---

## Example

```lua
-- Subscribe at mission load time
FT_EventBus:on(FT_EventBus.EVENTS.TABLET_OPENED, function()
    -- refresh your mod's state here
end)

FT_EventBus:on(FT_EventBus.EVENTS.APP_SWITCHED, function(appId)
    if appId == "my_app" then
        -- user just switched to my app
    end
end)
```
