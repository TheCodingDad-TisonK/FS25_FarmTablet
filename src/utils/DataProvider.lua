-- =========================================================
-- FarmTablet v2 – DataProvider  (FIXED)
-- Single access point for all FS25 game data queries.
-- Includes a simple time-based cache to avoid per-frame lookups.
-- =========================================================
---@class FT_DataProvider
FT_DataProvider = {}
local FT_DataProvider_mt = Class(FT_DataProvider)

local CACHE_TTL_MS = 2000  -- refresh every 2 seconds

function FT_DataProvider.new()
    local self = setmetatable({}, FT_DataProvider_mt)
    self._cache = {}
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
            -- FIX: farm:getBalance() is the proven API (confirmed in AIJob.lua reference)
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

-- FIX: FS25 does NOT expose a statsItems list on g_currentMission.statistics.
-- Income/expenses come from farm.stats – a key/value table updated by the game.
function FT_DataProvider:getIncome(farmId)
    return self:_cached("income_"..farmId, 3000, function()
        if not g_farmManager then return 0 end
        local farm = g_farmManager:getFarmById(farmId)
        if not farm or not farm.stats then return 0 end

        local incomeKeys = {
            "fieldSelling", "woodSelling", "balesSelling", "milkSelling",
            "woolSelling", "eggsSelling", "animalsSelling", "manureSelling",
            "compostSelling", "digestateSelling", "propertyIncome",
            "missionIncome", "contractIncome",
        }
        local total = 0
        for _, key in ipairs(incomeKeys) do
            local v = farm.stats[key]
            if type(v) == "number" and v > 0 then total = total + v end
        end
        return math.floor(total)
    end)
end

function FT_DataProvider:getExpenses(farmId)
    return self:_cached("expenses_"..farmId, 3000, function()
        if not g_farmManager then return 0 end
        local farm = g_farmManager:getFarmById(farmId)
        if not farm or not farm.stats then return 0 end

        local expenseKeys = {
            "vehicleRunningCost", "vehicleRepairCost", "loanInterest",
            "propertyMaintenance", "workerWage", "seedCost", "fertilizerCost",
            "herbicideCost", "limeCost", "purchasedAnimals", "purchasedVehicles",
            "purchasedFarmland", "purchasedBuildings",
        }
        local total = 0
        for _, key in ipairs(expenseKeys) do
            local v = farm.stats[key]
            if type(v) == "number" and v > 0 then total = total + v end
        end
        return math.floor(total)
    end)
end

-- ── Farm Stats ────────────────────────────────────────────

-- FIX: Farmland.field is the single Field linked to a farmland (not a fieldIds array).
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
                -- FIX: use getOwnerFarmId() only – it is the authoritative method
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
        -- FIX: FS25 uses env.dayTime (ms within the day, 0–86400000).
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

        -- FIX: FS25 weather lives at env.weather (not env directly).
        -- Proven API: weather:getRainFallScale(), weather:getCurrentTemperature()
        local weather = env.weather
        if not weather then return nil end

        local rainScale = weather.getRainFallScale     and weather:getRainFallScale()     or 0
        local temp      = weather.getCurrentTemperature and weather:getCurrentTemperature() or 15

        -- Cloud coverage – try weather object first, then env fallbacks
        local cloud = 0
        if weather.getCloudCoverage then
            cloud = weather:getCloudCoverage()
        elseif env.cloudUpdater and env.cloudUpdater.getCloudCoverage then
            cloud = env.cloudUpdater:getCloudCoverage()
        elseif type(env.cloudCoverage) == "number" then
            cloud = env.cloudCoverage
        end

        -- Fog – not a standard weather API field, wrap defensively
        local fogScale = 0
        if type(env.fogScale) == "number" then fogScale = env.fogScale end

        -- Wind – not guaranteed in base game
        local windSpeed = 0
        if weather.getWindSpeed then
            windSpeed = weather:getWindSpeed()
        elseif type(env.windSpeed) == "number" then
            windSpeed = env.windSpeed
        end

        local w = {
            temperature = temp,
            rainScale   = rainScale,
            isRaining   = rainScale > 0.05,
            isStorming  = rainScale > 0.70,
            isFoggy     = fogScale  > 0.3,
            cloudCover  = cloud,   -- 0.0–1.0
            windSpeed   = windSpeed,
        }

        if     w.isStorming then w.condition = "Stormy";        w.condKey = "storm"
        elseif w.isRaining  then w.condition = "Rainy";         w.condKey = "rain"
        elseif w.isFoggy    then w.condition = "Foggy";         w.condKey = "fog"
        elseif cloud > 0.70 then w.condition = "Overcast";      w.condKey = "overcast"
        elseif cloud > 0.30 then w.condition = "Partly Cloudy"; w.condKey = "cloudy"
        else                     w.condition = "Clear";         w.condKey = "clear"
        end

        -- Forecast: try both naming conventions
        w.forecast = weather.forecast or weather.forecastItems or nil

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

-- FIX: Each Farmland links to ONE Field via farmland.field (set by FieldManager).
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

-- FIX: Animal pens are Placeables with spec_husbandry.
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

                -- FIX: operatingTime is on the vehicle root table in milliseconds
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

function FT_DataProvider:formatMoney(amount)
    if g_i18n then
        return g_i18n:formatMoney(amount, 0, true, true) or ("$"..amount)
    end
    return string.format("$%d", amount or 0)
end

-- FIX: guard against nil season (base game has no seasons mod)
local SEASON_NAMES = {"Spring","Summer","Autumn","Winter"}
function FT_DataProvider:getSeasonName(seasonIdx)
    if seasonIdx == nil then return nil end
    return SEASON_NAMES[seasonIdx + 1] or "Unknown"
end

function FT_DataProvider:invalidate()
    self._cache = {}
end
