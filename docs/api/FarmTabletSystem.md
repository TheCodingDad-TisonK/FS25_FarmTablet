# API — FarmTabletSystem

**File:** `src/FarmTabletSystem.lua`  
**Class:** `FarmTabletSystem`  
**Instance:** `self.system` from any app drawer

Pure data and state layer. Contains no rendering code. Safe to construct on all network contexts.

---

## Constructor

### `FarmTabletSystem.new(settings) → FarmTabletSystem`
Creates the system with an `AppRegistry`, a `FT_DataProvider`, and initial bucket state.

---

## Lifecycle

### `FarmTabletSystem:initialize()`
Runs `AppRegistry:autoDetect()` to register companion-mod apps. Called once, guarded by `isInitialized`.

### `FarmTabletSystem:update(dt)`
Per-frame update. Drives the bucket tracker when the bucket app is active and the tracker is enabled.

### `FarmTabletSystem:onTabletClosed()`
Resets stale selection state and invalidates the data cache.

```lua
-- What it resets:
self.workshopSelectedVehicle = nil
self.soilSelectedField       = nil
self.data:invalidate()
```

---

## Bucket Tracker

### `FarmTabletSystem:resetBucket()`
Clears all bucket history and resets session totals to zero.

```lua
self.system:resetBucket()
```

### `FarmTabletSystem:_getBucketVehicle() → vehicle | nil` *(internal)*
Returns the currently controlled vehicle if it is a compatible loader/excavator type, otherwise nil.

Detection checks `typeName` for: `wheelloader`, `frontloader`, `loader`, `excavator`, `backhoe`, `telehandler`, `skidsteer`, `materialhandler`. Also checks attached implements for `bucket`, `loader`, `grapple`, `fork` type names.

### `FarmTabletSystem:_getBucketFillInfo(v) → table` *(internal)*
Returns a fill info table for vehicle `v`:

```lua
-- {
--   total    = 390.0,     -- total litres across all fill units
--   cap      = 500.0,     -- total capacity
--   fillType = 3,         -- FS25 fill type index (nil if empty)
--   name     = "Dirt",    -- localised fill type name
--   pct      = 78.0,      -- percentage full
-- }
```

### `FarmTabletSystem:_estimateWeight(litres, fillType) → number` *(internal)*
Returns estimated weight in kg using the lazy density table. Falls back to 1.0 kg/L for unknown types.

---

## Logging

### `FarmTabletSystem:log(msg, ...)`
Writes to `Logging.info` only when `settings.debugMode` is true.

---

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `settings` | Settings | Reference to user preferences |
| `isInitialized` | bool | Whether `initialize()` has run |
| `registry` | AppRegistry | App catalogue |
| `data` | FT_DataProvider | Game data cache |
| `currentApp` | string | Active app ID |
| `isTabletOpen` | bool | Whether the tablet is currently open |
| `workshopSelectedVehicle` | vehicle\|nil | Pinned Workshop vehicle |
| `soilSelectedField` | number\|nil | Selected field ID in Soil app |
| `bucket` | table | Bucket tracker state (see below) |

### `bucket` state table

| Field | Type | Description |
|-------|------|-------------|
| `isEnabled` | bool | Whether tracking is active |
| `vehicle` | vehicle\|nil | Currently tracked vehicle |
| `history` | table[] | Up to 20 recent dump entries |
| `totalLoads` | number | Total dump count this session |
| `totalWeight` | number | Total estimated kg this session |
| `lastFill` | number | Fill level at last update (litres) |
| `lastType` | number\|nil | Fill type index at last update |
| `startTime` | number | Mission time when session started |

Each history entry: `{ n, typeName, litres, weight }`
