# DataProvider

`FT_DataProvider` is the single access point for all FS25 game-data queries inside Farm Tablet. Every app reads data through it rather than accessing game globals directly.

**File:** `src/utils/DataProvider.lua`  
**Class:** `FT_DataProvider`  
**Instance:** `self.system.data` (accessible from any app drawer)

---

## Why Use It

- **Caching** — game APIs are expensive. DataProvider caches each result for a configurable TTL so the same data is not re-fetched on every frame during a render.
- **Null safety** — every method guards against nil game globals and returns a safe fallback value, so app code never needs to check `if g_farmManager then`.
- **Normalisation** — weather, field state, vehicle data are each normalised into a consistent table shape regardless of which game version or companion mod API variant is active.

---

## Cache System

All data is stored in `self._cache` as `{ [key] = { v = value, t = timestamp } }`.

A cached entry is returned when `(now - entry.t) < ttl`. `now` is `g_currentMission.time` (milliseconds since mission start). TTL values are therefore in **milliseconds**.

### Default TTLs by method

| Method | TTL | Rationale |
|--------|-----|-----------|
| `getBalance` | 1 000 ms | Changes on every transaction — refreshed quickly |
| `getLoan` | 2 000 ms | Changes less frequently |
| `getIncome` / `getExpenses` | 3 000 ms | Session totals, updated periodically by engine |
| `getWorldInfo` | 500 ms | Clock needs to update visibly |
| `getWeather` | 2 000 ms | Weather changes slowly |
| `getOwnedFields` | 4 000 ms | Field state changes only on player action |
| `getAnimalPens` | 3 000 ms | Food/water drains gradually |
| `getActiveFieldCount` / `getVehicleCount` | 5 000 ms | Changes rarely |

### Invalidation

Call `data:invalidate()` to flush all cached entries immediately. This is done automatically:
- When the tablet is closed (`FarmTabletSystem:onTabletClosed()`)
- After a vehicle repair (Workshop app `REPAIR` button)

---

## Methods

### Farm / Finance

#### `getPlayerFarmId() → number`
Returns the farm ID the local player belongs to. Falls back to `1` (single-player default) if the player object is unavailable.

```lua
local farmId = data:getPlayerFarmId()  -- typically 1 in singleplayer
```

#### `getBalance(farmId) → number`
Returns the farm's current balance in whole currency units (floored). Returns `0` if `g_farmManager` is unavailable.

```lua
local balance = data:getBalance(farmId)
-- balance can be negative (overdrawn)
```

#### `getLoan(farmId) → number`
Returns the active loan amount. Returns `0` if no loan or manager unavailable.

#### `getFarmName(farmId) → string | nil`
Returns the farm's display name, or `nil` if not set (empty string farms return nil too).

```lua
local name = data:getFarmName(farmId) or "My Farm"
```

#### `getIncome(farmId) → number`
Returns the sum of all income-type stat keys for the current session. Reads from `farm.stats` — the key/value table FS25 updates as money comes in.

Income keys tracked:
`fieldSelling`, `woodSelling`, `balesSelling`, `milkSelling`, `woolSelling`, `eggsSelling`, `animalsSelling`, `manureSelling`, `compostSelling`, `digestateSelling`, `propertyIncome`, `missionIncome`, `contractIncome`

#### `getExpenses(farmId) → number`
Returns the sum of all expense-type stat keys for the current session.

Expense keys tracked:
`vehicleRunningCost`, `vehicleRepairCost`, `loanInterest`, `propertyMaintenance`, `workerWage`, `seedCost`, `fertilizerCost`, `herbicideCost`, `limeCost`, `purchasedAnimals`, `purchasedVehicles`, `purchasedFarmland`, `purchasedBuildings`

---

### Farm Stats

#### `getActiveFieldCount(farmId) → number`
Returns how many farmland parcels owned by this farm have an associated `Field` object (i.e. are used for crops, not just purchased land).

Uses `g_farmlandManager.farmlands` with `g_fieldManager.farmlandIdFieldMapping` as a fallback.

#### `getVehicleCount(farmId) → number`
Returns the count of motorised vehicles (those with `spec_motorized`) owned by the farm, using `v:getOwnerFarmId()`.

---

### World / Environment

#### `getWorldInfo() → table | nil`
Returns a table describing the current in-game world state, or `nil` if the environment is not loaded.

```lua
local world = data:getWorldInfo()
-- world = {
--   day    = 47,       -- current day number
--   season = 0,        -- 0=Spring, 1=Summer, 2=Autumn, 3=Winter (nil in base game)
--   hour   = 14,       -- 0-23
--   minute = 32,       -- 0-59
-- }
```

`season` is `nil` when no Seasons mod is active — always guard with `if world.season then`.

#### `getWeather() → table | nil`
Returns a normalised weather table, or `nil` if the environment is unavailable.

```lua
local w = data:getWeather()
-- w = {
--   temperature = 18.5,        -- degrees Celsius
--   rainScale   = 0.0,         -- 0.0-1.0 precipitation intensity
--   isRaining   = false,       -- rainScale > 0.05
--   isStorming  = false,       -- rainScale > 0.70
--   isFoggy     = false,       -- fogScale > 0.3
--   cloudCover  = 0.45,        -- 0.0-1.0
--   windSpeed   = 14.4,        -- km/h (converted from m/s if needed)
--   windDir     = "NW",        -- compass string, or nil
--   humidity    = 0.62,        -- 0.0-1.0, or nil if unavailable
--   condition   = "Partly Cloudy",
--   condKey     = "cloudy",    -- "clear","cloudy","overcast","fog","rain","storm"
--   forecast    = { ... },     -- array of up to 7 forecast entries, or nil
-- }

-- Each forecast entry:
-- {
--   weatherType    = "Rain",      -- condition string or number
--   temperature    = 14.0,        -- average temperature (may be nil)
--   maxTemperature = 17.0,        -- (may be nil)
--   minTemperature = 11.0,        -- (may be nil)
-- }
```

The method tries multiple API variants for each field (different FS25 versions and mod weather systems expose them differently). Cloud cover values above `1.0` are automatically divided by 100.

---

### Fields

#### `getOwnedFields(farmId) → table[]`
Returns an array of field records for all farmland owned by this farm that has a linked field, sorted by field ID ascending.

```lua
local fields = data:getOwnedFields(farmId)
-- fields[i] = {
--   id         = 3,            -- farmland/field ID
--   cropName   = "Wheat",      -- localised crop name, or "Empty"
--   stateName  = "Ready",      -- growth stage label
--   stateColor = FT.C.POSITIVE,-- RGBA color for the state dot
--   phase      = "ready",      -- "ready", "growing", or "empty"
--   area       = 4.2,          -- field area in hectares
-- }
```

**Growth state → phase mapping:**

| FS25 state index | Label | Phase |
|-----------------|-------|-------|
| 0 | Withered | empty |
| 1 | Seeded | growing |
| 2 | Germinated | growing |
| 3-5 | Growing | growing |
| 6 | Ripening | growing |
| 7 | Ready | ready |
| 8 | Harvested | empty |

---

### Animals

#### `getAnimalPens(farmId) → table[]`
Returns an array of animal pen records for all placeables with `spec_husbandry` owned by this farm.

```lua
local pens = data:getAnimalPens(farmId)
-- pens[i] = {
--   typeName       = "Cows",      -- animal type name
--   numAnimals     = 12,
--   maxAnimals     = 20,
--   foodPct        = 78,          -- 0-100, or nil if not applicable
--   waterPct       = 55,          -- 0-100, or nil if not applicable
--   cleanPct       = 40,          -- 0-100, or nil if not applicable
--   hasFood        = true,        -- whether food data is available
--   hasWater       = true,
--   hasCleanliness = true,
-- }
```

Food is from `getTotalFood()` / `getFoodCapacity()`.  
Water is `getHusbandryFillLevel(FillType.WATER)` / `getHusbandryCapacity(FillType.WATER)`.  
Cleanliness is from the first entry in `getConditionInfos()` that has a `ratio` field.

---

### Vehicles

#### `getNearbyVehicles(radiusM) → table[]`
Returns an array of motorised vehicles within `radiusM` metres of the player (default: 20). Results are sorted by distance ascending.

```lua
local vehicles = data:getNearbyVehicles(35)
-- vehicles[i] = {
--   vehicle  = <VehicleObject>,  -- the raw FS25 vehicle object
--   name     = "Fendt 516",      -- display name
--   distance = 12,               -- metres (floored integer)
--   fuel     = 390.0,            -- current fuel litres
--   fuelCap  = 500.0,            -- tank capacity litres
--   fuelPct  = 78,               -- 0-100 (floored integer)
--   wearPct  = 23,               -- 0-100 (floored integer)
--   opHours  = 842,              -- total operating hours (floored integer)
-- }
```

Position is taken from the player's controlled vehicle root node if seated, otherwise the player root node.  
Fuel is from `spec_motorized.fuelFillLevel` / `fuelCapacity`.  
Wear is from `spec_wearable.totalAmount` or `getVehicleWearAmount()`.  
Operating time is `v.operatingTime` (milliseconds) converted to hours.

---

### Helpers

#### `formatMoney(amount) → string`
Formats a number as a currency string using the game's locale-aware `g_i18n:formatMoney()`. Falls back to `"$amount"` if i18n is unavailable.

```lua
data:formatMoney(1284750)  -- "$1,284,750" (locale-dependent)
```

#### `getSeasonName(seasonIdx) → string | nil`
Converts a season index (0–3) to a display string. Returns `nil` if `seasonIdx` is `nil` (base game has no seasons).

```lua
data:getSeasonName(0)    -- "Spring"
data:getSeasonName(nil)  -- nil (safe to call)
```

#### `invalidate()`
Flushes the entire cache immediately.

---

## Adding New Data Methods

Follow the pattern of existing methods:

```lua
function FT_DataProvider:getMyData(farmId)
    return self:_cached("mydata_"..farmId, 2000, function()
        -- guard against nil globals
        if not g_someManager then return defaultValue end
        -- do the actual query
        local result = g_someManager:getSomething(farmId)
        return result
    end)
end
```

Cache key naming convention: `"shortname_" .. farmId` for per-farm data, plain string for global data.
