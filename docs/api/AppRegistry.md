# API — AppRegistry

**File:** `src/core/AppRegistry.lua`  
**Class:** `AppRegistry`  
**Instance:** `self.system.registry`

Central catalogue of all installed apps. Maintains registration order and enables/disables individual apps.

---

## Constructor

### `AppRegistry.new() → AppRegistry`
Creates a new registry and registers all `BUILTIN_APPS` entries immediately.

---

## Registration

### `AppRegistry:register(def)`
Registers an app definition. Silently no-ops if the ID is already registered.

After insertion, the `_order` list is re-sorted by `def.order` (ascending).

Emits `FT_EventBus.EVENTS.APP_REGISTERED` with the app ID.

**`def` table fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | ✅ | Unique app ID (e.g. `"weather"`) |
| `group` | string | ✅ | Category: `"core"`, `"farm"`, `"finance"`, `"mods"` |
| `name` | string | ✅ | i18n key for the display name |
| `navLabel` | string | ✅ | 3–4 char sidebar label (e.g. `"WTH"`) |
| `icon` | string | — | Icon identifier (for future use) |
| `order` | number | — | Sort position in sidebar (default: 50) |
| `developer` | string | — | Developer name shown in App Store |
| `version` | string | — | Version string shown in App Store |
| `description` | string | — | Short description shown in App Store |
| `enabled` | bool | — | Whether the app is visible (default: `true`) |

---

## Querying

### `AppRegistry:get(id) → def | nil`
Returns the app definition for the given ID, or `nil` if not registered.

```lua
local app = self.system.registry:get("weather")
-- app.navLabel == "WTH"
```

### `AppRegistry:getAll() → def[]`
Returns an array of all enabled app definitions, sorted by `order`.

```lua
for _, app in ipairs(self.system.registry:getAll()) do
    print(app.id, app.navLabel)
end
```

### `AppRegistry:has(id) → boolean`
Returns `true` if an app with this ID is registered (regardless of enabled state).

---

## Enable / Disable

### `AppRegistry:setEnabled(id, state)`
Enables or disables an app. Disabled apps are excluded from `getAll()` and cannot be switched to.

```lua
self.system.registry:setEnabled("digging", false)
```

---

## Auto-Detection

### `AppRegistry:autoDetect()`
Checks for companion mods and registers their apps if the mod's global manager is present.

Called once from `FarmTabletSystem:initialize()` after the mission finishes loading.

**Detection globals:**

| App | Global checked |
|-----|---------------|
| Income Mod | `g_currentMission.incomeManager` |
| Tax Mod | `g_currentMission.taxManager` |
| NPC Favor | `g_NPCSystem` or `g_currentMission.npcFavorSystem` |
| Crop Stress | `getfenv(0)["g_cropStressManager"]` |
| Soil Fertilizer | `g_SoilFertilityManager`, `g_soilFertilizerManager`, or `g_currentMission.soil*Manager` |

---

## Groups

```lua
AppRegistry.GROUPS = {
    { id = "core",    label = "CORE",    icon = "CORE" },
    { id = "farm",    label = "FARM",    icon = "FARM" },
    { id = "finance", label = "FINANCE", icon = "FIN"  },
    { id = "mods",    label = "MODS",    icon = "MODS" },
}
```

Used by the App Store app to group entries by category.
