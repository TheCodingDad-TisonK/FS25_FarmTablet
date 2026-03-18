# API — DataProvider (`FT_DataProvider`)

**File:** `src/utils/DataProvider.lua`  
**Class:** `FT_DataProvider`  
**Instance:** `self.system.data` from any app drawer

Full reference for all public methods. See [developer/data-provider.md](../developer/data-provider.md) for implementation details and the caching system.

---

## Constructor

### `FT_DataProvider.new() → FT_DataProvider`

---

## Farm / Finance

### `getPlayerFarmId() → number`
Returns the local player's farm ID. Fallback: `1`.

### `getBalance(farmId) → number`
Returns the farm's current balance (floored integer). TTL: 1 000 ms.

### `getLoan(farmId) → number`
Returns the active loan amount. TTL: 2 000 ms.

### `getFarmName(farmId) → string | nil`
Returns the farm's display name, or `nil` if not set.

### `getIncome(farmId) → number`
Returns total session income (sum of all income stat keys). TTL: 3 000 ms.

### `getExpenses(farmId) → number`
Returns total session expenses (sum of all expense stat keys). TTL: 3 000 ms.

---

## Farm Stats

### `getActiveFieldCount(farmId) → number`
Returns the count of owned farmland parcels with a linked field. TTL: 5 000 ms.

### `getVehicleCount(farmId) → number`
Returns the count of motorised vehicles owned by the farm. TTL: 5 000 ms.

---

## World / Environment

### `getWorldInfo() → table | nil`
TTL: 500 ms. Returns:

```lua
{
  day    = number,   -- current day number
  season = number|nil, -- 0=Spring … 3=Winter; nil in base game
  hour   = number,   -- 0–23
  minute = number,   -- 0–59
}
```

### `getWeather() → table | nil`
TTL: 2 000 ms. Returns:

```lua
{
  temperature = number,     -- °C
  rainScale   = number,     -- 0.0–1.0
  isRaining   = boolean,    -- rainScale > 0.05
  isStorming  = boolean,    -- rainScale > 0.70
  isFoggy     = boolean,    -- fogScale > 0.3
  cloudCover  = number,     -- 0.0–1.0
  windSpeed   = number,     -- km/h
  windDir     = string|nil, -- "N","NE","E","SE","S","SW","W","NW" or nil
  humidity    = number|nil, -- 0.0–1.0 or nil
  condition   = string,     -- "Clear","Partly Cloudy","Overcast","Foggy","Rainy","Stormy"
  condKey     = string,     -- "clear","cloudy","overcast","fog","rain","storm"
  forecast    = table|nil,  -- array of up to 7 entries (see below)
}
```

Forecast entry:
```lua
{
  weatherType    = string|number|nil,
  temperature    = number|nil,
  maxTemperature = number|nil,
  minTemperature = number|nil,
}
```

---

## Fields

### `getOwnedFields(farmId) → table[]`
TTL: 4 000 ms. Returns array sorted by field ID ascending:

```lua
{
  id         = number,   -- farmland / field ID
  cropName   = string,   -- localised crop name or "Empty"
  stateName  = string,   -- growth stage label
  stateColor = {r,g,b,a},
  phase      = string,   -- "ready", "growing", or "empty"
  area       = number,   -- hectares
}
```

---

## Animals

### `getAnimalPens(farmId) → table[]`
TTL: 3 000 ms. Returns one entry per animal pen placeable:

```lua
{
  typeName       = string,
  numAnimals     = number,
  maxAnimals     = number,
  foodPct        = number|nil,  -- 0–100
  waterPct       = number|nil,  -- 0–100
  cleanPct       = number|nil,  -- 0–100
  hasFood        = boolean,
  hasWater       = boolean,
  hasCleanliness = boolean,
}
```

---

## Vehicles

### `getNearbyVehicles(radiusM) → table[]`
Not cached. Returns motorised vehicles within `radiusM` metres (default 20), sorted by distance:

```lua
{
  vehicle  = object,   -- raw FS25 vehicle
  name     = string,
  distance = number,   -- metres (integer)
  fuel     = number,   -- litres
  fuelCap  = number,
  fuelPct  = number,   -- 0–100
  wearPct  = number,   -- 0–100
  opHours  = number,   -- integer hours
}
```

---

## Helpers

### `formatMoney(amount) → string`
Locale-aware money formatting via `g_i18n:formatMoney()`. Fallback: `"$amount"`.

### `getSeasonName(seasonIdx) → string | nil`
`0`→`"Spring"`, `1`→`"Summer"`, `2`→`"Autumn"`, `3`→`"Winter"`. Returns `nil` if `seasonIdx` is `nil`.

### `invalidate()`
Flushes the entire cache immediately.
