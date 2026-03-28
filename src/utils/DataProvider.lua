-- =========================================================
-- FarmTablet v2 – DataProvider
-- Single access point for all FS25 game-data queries.
-- All public methods are cached with a per-key TTL so the
-- underlying FS25 APIs are not polled every frame.
--
-- Cache contract:
--   • Data is refreshed when (now - entry.t) >= TTL.
--   • "now" is g_currentMission.time (milliseconds since
--     mission start), so TTL values are in milliseconds.
--   • Call :invalidate() to flush all entries immediately
--     (used on tablet close and after repairs).
-- =========================================================
---@class FT_DataProvider
FT_DataProvider = {}
local FT_DataProvider_mt = Class(FT_DataProvider)

local CACHE_TTL_MS = 2000  -- refresh every 2 seconds

function FT_DataProvider.new()
    local self = setmetatable({}, FT_DataProvider_mt)
    self._cache            = {}
    self._sessionIncome    = {}   -- [farmId] = accumulated income this session
    self._sessionExpenses  = {}   -- [farmId] = accumulated expenses this session
    self._origChangeBalance = nil -- saved original Farm.changeBalance for cleanup
    return self
end

function FT_DataProvider:_cached(key, ttl, fn)
    local now = g_currentMission and g_currentMission.time or 0
    local entry = self._cache[key]
    if entry and (now - entry.t) < (ttl or CACHE_TTL_MS) then
        return entry.v
    end
    local v = fn()
    self._cache[key] = { v = v, t = now }
    return v
end

-- ── Farm / Finance ────────────────────────────────────────

--- Returns the farm ID that the local player belongs to.
--- Falls back to 1 (the default single-player farm) if the player object
--- is not yet available or does not expose getFarmId().
function FT_DataProvider:getPlayerFarmId()
    if g_currentMission and g_currentMission.player then
        local p = g_currentMission.player
        return (p.getFarmId and p:getFarmId()) or p.farmId or 1
    end
    return 1
end

function FT_DataProvider:getBalance(farmId)
    return self:_cached("balance_"..farmId, 1000, function()
        if g_farmManager then
            local farm = g_farmManager:getFarmById(farmId)
            -- farm:getBalance() is the authoritative FS25 API (confirmed in AIJob.lua)
            if farm and farm.getBalance then
                return math.floor(farm:getBalance() or 0)
            elseif farm and farm.balance then
                return math.floor(farm.balance)
            end
        end
        return 0
    end)
end

function FT_DataProvider:getLoan(farmId)
    return self:_cached("loan_"..farmId, 2000, function()
        if g_farmManager then
            local farm = g_farmManager:getFarmById(farmId)
            if farm and farm.loan then return math.floor(farm.loan) end
        end
        return 0
    end)
end

function FT_DataProvider:getFarmName(farmId)
    if g_farmManager then
        local farm = g_farmManager:getFarmById(farmId)
        if farm and farm.name and farm.name ~= "" then return farm.name end
    end
    return nil
end

-- Income and expenses are tracked by hooking Farm.changeBalance.
-- FS25 has no stats table with per-category money keys; all money
-- flows through farm:changeBalance(amount, moneyType).  We accumulate
-- session totals ourselves so any mod (IncomeMod, TaxMod, NPCFavor
-- contractor pay, UsedPlus deals, etc.) is automatically captured.
-- Call initSessionTracking() once after mission load.
function FT_DataProvider:getIncome(farmId)
    return math.floor(self._sessionIncome[farmId] or 0)
end

function FT_DataProvider:getExpenses(farmId)
    return math.floor(self._sessionExpenses[farmId] or 0)
end

-- Hook Farm.changeBalance to accumulate session income/expenses.
-- Safe to call multiple times — installs the hook only once.
function FT_DataProvider:initSessionTracking()
    if self._origChangeBalance then return end  -- already hooked
    if not Farm or not Farm.changeBalance then return end

    local data = self
    local orig = Farm.changeBalance
    self._origChangeBalance = orig

    Farm.changeBalance = function(farm, amount, moneyType)
        orig(farm, amount, moneyType)
        if type(amount) ~= "number" or amount == 0 then return end
        local fid = farm.farmId or (farm.getId and farm:getId()) or 0
        if not fid or fid == 0 then return end
        if amount > 0 then
            data._sessionIncome[fid] = (data._sessionIncome[fid] or 0) + amount
        else
            data._sessionExpenses[fid] = (data._sessionExpenses[fid] or 0) + math.abs(amount)
        end
    end
end

-- Restore Farm.changeBalance to its original on unload.
function FT_DataProvider:stopSessionTracking()
    if self._origChangeBalance then
        Farm.changeBalance = self._origChangeBalance
        self._origChangeBalance = nil
    end
end

-- ── Farm Stats ────────────────────────────────────────────

-- Each Farmland links to one Field via farmland.field (set by FieldManager).
-- g_fieldManager.farmlandIdFieldMapping[farmlandId] is the authoritative lookup.
function FT_DataProvider:getActiveFieldCount(farmId)
    return self:_cached("fieldcount_"..farmId, 5000, function()
        local count = 0
        if not g_farmlandManager then return 0 end
        for _, fl in pairs(g_farmlandManager.farmlands) do
            if fl.farmId == farmId then
                local hasField = fl.field ~= nil
                if not hasField and g_fieldManager and g_fieldManager.farmlandIdFieldMapping then
                    hasField = g_fieldManager.farmlandIdFieldMapping[fl.id] ~= nil
                end
                if hasField then count = count + 1 end
            end
        end
        return count
    end)
end

function FT_DataProvider:getVehicleCount(farmId)
    return self:_cached("vehcount_"..farmId, 5000, function()
        local count = 0
        if g_currentMission and g_currentMission.vehicles then
            for _, v in pairs(g_currentMission.vehicles) do
                -- use getOwnerFarmId() only – it is the authoritative method
                if v.spec_motorized and v.getOwnerFarmId then
                    if v:getOwnerFarmId() == farmId then count = count + 1 end
                end
            end
        end
        return count
    end)
end

-- ── World / Environment ───────────────────────────────────

function FT_DataProvider:getWorldInfo()
    return self:_cached("world", 500, function()
        if not (g_currentMission and g_currentMission.environment) then
            return nil
        end
        local env = g_currentMission.environment
        -- FS25 uses env.dayTime (ms within the day, 0–86400000).
        -- Seasons mod adds currentSeason; guard with nil check.
        local dayTimeMs  = env.dayTime or 0
        local totalHours = dayTimeMs / 3600000
        return {
            day    = env.currentDay or 1,
            season = env.currentSeason,   -- nil in base game
            hour   = math.floor(totalHours) % 24,
            minute = math.floor((totalHours % 1) * 60),
        }
    end)
end

function FT_DataProvider:getWeather()
    return self:_cached("weather", 2000, function()
        if not (g_currentMission and g_currentMission.environment) then
            return nil
        end
        local env = g_currentMission.environment

        -- FS25 v1.17+: weather lives at env.weatherSystem.
        -- Older builds / some mods expose env.weather as a fallback.
        local weather = env.weatherSystem or env.weather
        if not weather then return nil end

        -- ── Rain / precipitation ──────────────────────────
        -- Try all known FS25 rain scale method/field names
        local rainScale = 0
        if     weather.getRainFallScale          then rainScale = weather:getRainFallScale()
        elseif weather.getRainScale              then rainScale = weather:getRainScale()
        elseif weather.getPrecipitationIntensity then rainScale = weather:getPrecipitationIntensity()
        elseif type(weather.rainFallScale) == "number" then rainScale = weather.rainFallScale
        elseif type(env.rainScale)         == "number" then rainScale = env.rainScale
        end

        -- ── Temperature ───────────────────────────────────
        local temp = 15
        if     weather.getCurrentTemperature then temp = weather:getCurrentTemperature()
        elseif weather.getTemperature        then temp = weather:getTemperature()
        elseif type(weather.temperature) == "number" then temp = weather.temperature
        elseif type(env.temperature)     == "number" then temp = env.temperature
        end

        -- ── Cloud cover (0.0 – 1.0) ───────────────────────
        local cloud = 0
        if     weather.getCloudCoverage then
            cloud = weather:getCloudCoverage()
        elseif env.cloudUpdater and env.cloudUpdater.getCloudCoverage then
            cloud = env.cloudUpdater:getCloudCoverage()
        elseif type(weather.cloudCoverage) == "number" then cloud = weather.cloudCoverage
        elseif type(env.cloudCoverage)     == "number" then cloud = env.cloudCoverage
        end
        -- Clamp to 0–1 (some mods return 0–100)
        if cloud > 1.0 then cloud = cloud / 100 end

        -- ── Fog ───────────────────────────────────────────
        local fogScale = 0
        if     type(weather.fogScale) == "number" then fogScale = weather.fogScale
        elseif type(env.fogScale)     == "number" then fogScale = env.fogScale
        end

        -- ── Wind ──────────────────────────────────────────
        local windSpeed = 0
        if     weather.getWindSpeed       then windSpeed = weather:getWindSpeed()
        elseif type(weather.windSpeed) == "number" then windSpeed = weather.windSpeed
        elseif type(env.windSpeed)     == "number" then windSpeed = env.windSpeed
        end
        -- Convert m/s → km/h if value looks like m/s (< 30)
        if windSpeed > 0 and windSpeed < 30 then windSpeed = windSpeed * 3.6 end

        -- Wind direction (optional)
        local windDir = nil
        if     weather.getWindDirection then
            local deg = weather:getWindDirection()
            if type(deg) == "number" then
                local dirs = {"N","NE","E","SE","S","SW","W","NW"}
                local idx  = math.floor(((deg + 22.5) % 360) / 45) + 1
                windDir    = dirs[idx]
            end
        elseif type(weather.windDirection) == "number" then
            local deg  = weather.windDirection
            local dirs = {"N","NE","E","SE","S","SW","W","NW"}
            local idx  = math.floor(((deg + 22.5) % 360) / 45) + 1
            windDir    = dirs[idx]
        end

        -- ── Humidity (optional, present in some mods) ─────
        local humidity = nil
        if     weather.getHumidity        then humidity = weather:getHumidity()
        elseif type(weather.humidity) == "number" then humidity = weather.humidity
        elseif type(env.humidity)     == "number" then humidity = env.humidity
        end
        if humidity and humidity > 1.0 then humidity = humidity / 100 end

        -- ── Build result table ─────────────────────────────
        local w = {
            temperature = temp,
            rainScale   = rainScale,
            isRaining   = rainScale > 0.05,
            isStorming  = rainScale > 0.70,
            isFoggy     = fogScale  > 0.3,
            cloudCover  = cloud,       -- 0.0–1.0
            windSpeed   = windSpeed,   -- km/h
            windDir     = windDir,     -- compass string or nil
            humidity    = humidity,    -- 0.0–1.0 or nil
        }

        if     w.isStorming then w.condition = "Stormy";        w.condKey = "storm"
        elseif w.isRaining  then w.condition = "Rainy";         w.condKey = "rain"
        elseif w.isFoggy    then w.condition = "Foggy";         w.condKey = "fog"
        elseif cloud > 0.70 then w.condition = "Overcast";      w.condKey = "overcast"
        elseif cloud > 0.30 then w.condition = "Partly Cloudy"; w.condKey = "cloudy"
        else                     w.condition = "Clear";         w.condKey = "clear"
        end

        -- ── Projected 5-day Forecast ──────────────────────
        -- FS25 has no public forecast Lua API (confirmed: SeasonalCropStress
        -- WeatherIntegration.lua comment).  We build a projection from:
        --   • Near-term (days 1-2): current cloud coverage → rain probability
        --   • Far-term  (days 3-5): seasonal base rain probability, blended in
        -- Temperature drifts ±1 C per day toward the seasonal mean.
        do
            -- Seasonal base rain probabilities (spring/summer/autumn/winter)
            local SEASONAL_RAIN = {[0]=0.30, [1]=0.12, [2]=0.28, [3]=0.35}
            local season = env.currentSeason
            season = (type(season) == "number") and math.floor(season) or 0
            local seasonRain = SEASONAL_RAIN[season] or 0.25

            -- Best cloud coverage reading for the projection
            local cloudFC = cloud  -- already clamped 0-1 above
            if env.cloudUpdater and env.cloudUpdater.getCloudCoverage then
                cloudFC = env.cloudUpdater:getCloudCoverage()
                if cloudFC > 1.0 then cloudFC = cloudFC / 100 end
            end

            local fc = {}
            for day = 1, 5 do
                -- Blend: day 1 = 100% cloud-based, day 5 = 100% seasonal
                local blend   = (day - 1) / 4   -- 0.0 → 1.0
                local rainProb = cloudFC * 0.7 * (1 - blend) + seasonRain * blend

                -- Slight temperature drift toward seasonal typical
                local seasonalMid = ({[0]=12, [1]=24, [2]=14, [3]=2})[season] or 15
                local projTemp = math.floor(temp + (seasonalMid - temp) * blend * 0.3)

                local condKey, condition
                if     rainProb > 0.60 then condKey, condition = "storm",    "Stormy"
                elseif rainProb > 0.35 then condKey, condition = "rain",     "Rainy"
                elseif cloudFC  > 0.55 then condKey, condition = "overcast", "Overcast"
                elseif cloudFC  > 0.25 then condKey, condition = "cloudy",   "Partly Cloudy"
                else                        condKey, condition = "clear",    "Clear"
                end

                table.insert(fc, {
                    condition   = condition,
                    condKey     = condKey,
                    temperature = projTemp,
                    rainProb    = math.floor(rainProb * 100),
                })
            end
            w.forecast = fc
        end

        return w
    end)
end

-- ── Fields ────────────────────────────────────────────────

local GROWTH_STATES = {
    [0]  = { name = "Withered",   color = FT.C.NEGATIVE  },
    [1]  = { name = "Seeded",     color = FT.C.MUTED     },
    [2]  = { name = "Germinated", color = FT.C.INFO      },
    [3]  = { name = "Growing",    color = FT.C.WARNING   },
    [4]  = { name = "Growing",    color = FT.C.WARNING   },
    [5]  = { name = "Growing",    color = FT.C.WARNING   },
    [6]  = { name = "Ripening",   color = FT.C.BRAND     },
    [7]  = { name = "Ready",      color = FT.C.POSITIVE  },
    [8]  = { name = "Harvested",  color = FT.C.MUTED     },
}

-- Each Farmland links to ONE Field via farmland.field (set by FieldManager).
-- Crop/growth state must be queried via FieldState:update(cx, cz), not from field directly.
function FT_DataProvider:getOwnedFields(farmId)
    return self:_cached("fields_"..farmId, 4000, function()
        local out = {}
        if not g_farmlandManager then return out end

        -- One reusable FieldState for sampling crop/growth at each field's center
        local fieldState = (FieldState ~= nil) and FieldState.new() or nil

        for _, fl in pairs(g_farmlandManager.farmlands) do
            if fl.farmId == farmId then
                -- Resolve the field linked to this farmland
                local field = fl.field
                if field == nil and g_fieldManager and g_fieldManager.farmlandIdFieldMapping then
                    field = g_fieldManager.farmlandIdFieldMapping[fl.id]
                end

                if field then
                    local cropName   = "Empty"
                    local stateName  = "Empty"
                    local stateColor = FT.C.MUTED
                    local phase      = "empty"

                    if fieldState and field.getCenterOfFieldWorldPosition then
                        local cx, cz = field:getCenterOfFieldWorldPosition()
                        if cx then
                            fieldState:update(cx, cz)

                            local fruitIdx = fieldState.fruitTypeIndex
                            local unknown  = FruitType and FruitType.UNKNOWN or 0
                            if fruitIdx and fruitIdx ~= unknown and g_fruitTypeManager then
                                local ft2 = g_fruitTypeManager:getFruitTypeByIndex(fruitIdx)
                                if ft2 then
                                    cropName = ft2.nameI18N or ft2.name or "Unknown"
                                    local gs  = fieldState.growthState or 0
                                    local gsd = GROWTH_STATES[gs] or { name="Growing", color=FT.C.WARNING }
                                    stateName  = gsd.name
                                    stateColor = gsd.color
                                    if gs == 7 then
                                        phase = "ready"
                                    elseif gs > 0 then
                                        phase = "growing"
                                    end
                                end
                            end
                        end
                    end

                    table.insert(out, {
                        id         = fl.id,
                        cropName   = cropName,
                        stateName  = stateName,
                        stateColor = stateColor,
                        phase      = phase,
                        area       = fl.areaInHa or 0,
                    })
                end
            end
        end

        table.sort(out, function(a, b) return a.id < b.id end)
        return out
    end)
end

-- ── Animals ───────────────────────────────────────────────

-- Animal pens are Placeables with spec_husbandry.
-- Counts:  placeable:getNumOfAnimals() / getMaxNumOfAnimals()
-- Food:    placeable:getTotalFood()    / getFoodCapacity()
-- Water:   placeable:getHusbandryFillLevel(FillType.WATER) / getHusbandryCapacity(FillType.WATER)
-- Straw:   placeable:getConditionInfos() → array of {title, value, ratio}
function FT_DataProvider:getAnimalPens(farmId)
    return self:_cached("animals_"..farmId, 3000, function()
        local out = {}
        if not (g_currentMission and g_currentMission.placeableSystem) then
            return out
        end

        for _, placeable in pairs(g_currentMission.placeableSystem.placeables) do
            if placeable.spec_husbandry and
               placeable.getOwnerFarmId and
               placeable:getOwnerFarmId() == farmId then

                -- Animal type name from spec_husbandryAnimals
                local typeName = "Unknown"
                if placeable.spec_husbandryAnimals then
                    local aspec = placeable.spec_husbandryAnimals
                    if aspec.animalType and aspec.animalType.name then
                        typeName = aspec.animalType.name
                    end
                end

                -- Count
                local numAnimals = 0
                local maxAnimals = 0
                if placeable.getNumOfAnimals then
                    numAnimals = placeable:getNumOfAnimals()
                end
                if placeable.getMaxNumOfAnimals then
                    maxAnimals = placeable:getMaxNumOfAnimals()
                end

                -- Food
                local foodPct = nil
                if placeable.getTotalFood and placeable.getFoodCapacity then
                    local cap = placeable:getFoodCapacity()
                    if cap and cap > 0 then
                        foodPct = math.floor(placeable:getTotalFood() / cap * 100)
                    end
                end

                -- Water
                local waterPct = nil
                if placeable.getHusbandryFillLevel and placeable.getHusbandryCapacity then
                    local wt = FillType and FillType.WATER
                    if wt then
                        local wCap = placeable:getHusbandryCapacity(wt)
                        if wCap and wCap > 0 then
                            waterPct = math.floor(
                                placeable:getHusbandryFillLevel(wt) / wCap * 100)
                        end
                    end
                end

                -- Straw/cleanliness from condition infos
                local cleanPct = nil
                if placeable.getConditionInfos then
                    local infos = placeable:getConditionInfos() or {}
                    for _, info in ipairs(infos) do
                        if info.ratio ~= nil then
                            cleanPct = math.floor(info.ratio * 100)
                            break
                        end
                    end
                end

                table.insert(out, {
                    typeName       = typeName,
                    numAnimals     = numAnimals,
                    maxAnimals     = maxAnimals,
                    foodPct        = foodPct,
                    waterPct       = waterPct,
                    cleanPct       = cleanPct,
                    hasFood        = placeable.getTotalFood ~= nil,
                    hasWater       = placeable.getHusbandryFillLevel ~= nil and FillType ~= nil,
                    hasCleanliness = placeable.getConditionInfos ~= nil,
                })
            end
        end
        return out
    end)
end

-- ── Vehicles ──────────────────────────────────────────────

function FT_DataProvider:getNearbyVehicles(radiusM)
    radiusM = radiusM or 20
    if not (g_currentMission and g_currentMission.player) then return {} end

    local px, py, pz
    local player = g_currentMission.player
    local seatedVehicle = player.getCurrentVehicle and player:getCurrentVehicle()

    if seatedVehicle and seatedVehicle.rootNode then
        px, py, pz = getWorldTranslation(seatedVehicle.rootNode)
    elseif player.rootNode then
        px, py, pz = getWorldTranslation(player.rootNode)
    else
        return {}
    end

    local out = {}
    for _, v in pairs(g_currentMission.vehicles or {}) do
        if v.rootNode and v.spec_motorized then
            local vx, vy, vz = getWorldTranslation(v.rootNode)
            local dist = math.sqrt((px-vx)^2 + (py-vy)^2 + (pz-vz)^2)
            if dist <= radiusM then
                local name = (v.getFullName and v:getFullName()) or
                             v.configFileName or "Unknown"

                -- Fuel is on spec_motorized
                local fuel, fuelCap = 0, 1
                local ms = v.spec_motorized
                if ms then
                    fuel    = ms.fuelFillLevel or 0
                    fuelCap = math.max(ms.fuelCapacity or 1, 1)
                end

                -- Wear
                local wearPct = 0
                if v.spec_wearable then
                    local ws = v.spec_wearable
                    if ws.totalAmount then
                        wearPct = math.floor(ws.totalAmount * 100)
                    elseif ws.getVehicleWearAmount then
                        wearPct = math.floor(ws:getVehicleWearAmount() * 100)
                    end
                end

                -- operatingTime is on the vehicle root table in milliseconds
                local opHours = 0
                if v.operatingTime then
                    opHours = math.floor(v.operatingTime / 3600000)
                end

                table.insert(out, {
                    vehicle  = v,
                    name     = name,
                    distance = math.floor(dist),
                    fuel     = fuel,
                    fuelCap  = fuelCap,
                    fuelPct  = math.floor(fuel / fuelCap * 100),
                    wearPct  = wearPct,
                    opHours  = opHours,
                })
            end
        end
    end
    table.sort(out, function(a,b) return a.distance < b.distance end)
    return out
end

-- ── Helpers ───────────────────────────────────────────────

--- Formats an integer money amount using the game's locale-aware formatter.
--- Falls back to a simple "$amount" string if g_i18n is unavailable.
---@param amount number
---@return string
function FT_DataProvider:formatMoney(amount)
    if g_i18n then
        return g_i18n:formatMoney(amount, 0, true, true) or ("$"..amount)
    end
    return string.format("$%d", amount or 0)
end

-- guard against nil season (base game has no seasons mod)
--- Returns the display name for a season index (0=Spring … 3=Winter).
--- Returns nil if seasonIdx is nil (base game has no seasons).
local SEASON_NAMES = {"Spring","Summer","Autumn","Winter"}
function FT_DataProvider:getSeasonName(seasonIdx)
    if seasonIdx == nil then return nil end
    return SEASON_NAMES[seasonIdx + 1] or "Unknown"
end

--- Flushes all cached data immediately.
--- Call this after any action that changes game state (repairs, tablet close, etc.)
--- so the next draw cycle picks up fresh values.
function FT_DataProvider:invalidate()
    self._cache = {}
end
