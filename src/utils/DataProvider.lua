-- =========================================================
-- FarmTablet v2 – DataProvider
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
            if farm then return math.floor(farm:getBalance() or 0) end
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

function FT_DataProvider:getIncome(farmId)
    return self:_cached("income_"..farmId, 3000, function()
        local total = 0
        if not (g_currentMission and g_currentMission.statistics) then return 0 end
        local keywords = {"income","revenue","harvest","mission","selling","contract"}
        for _, item in ipairs(g_currentMission.statistics.statsItems or {}) do
            if item.farmId == farmId and item.name then
                local nm = item.name:lower()
                for _, k in ipairs(keywords) do
                    if nm:find(k) then
                        local v = item:getValue() or 0
                        if v > 0 then total = total + v end
                        break
                    end
                end
            end
        end
        return math.floor(total)
    end)
end

function FT_DataProvider:getExpenses(farmId)
    return self:_cached("expenses_"..farmId, 3000, function()
        local total = 0
        if not (g_currentMission and g_currentMission.statistics) then return 0 end
        local keywords = {"expense","cost","maintenance","wage","fuel","seed",
                          "fertilizer","spray","repair","lease","insurance",
                          "animal","property","loanInterest"}
        for _, item in ipairs(g_currentMission.statistics.statsItems or {}) do
            if item.farmId == farmId and item.name then
                local nm = item.name:lower()
                for _, k in ipairs(keywords) do
                    if nm:find(k) then
                        local v = item:getValue() or 0
                        if v > 0 then total = total + v end
                        break
                    end
                end
            end
        end
        return math.floor(total)
    end)
end

-- ── Farm Stats ────────────────────────────────────────────

function FT_DataProvider:getActiveFieldCount(farmId)
    return self:_cached("fieldcount_"..farmId, 5000, function()
        local count = 0
        if g_farmlandManager then
            for _, fl in pairs(g_farmlandManager.farmlands) do
                if fl.farmId == farmId and fl.fieldIds then
                    count = count + #fl.fieldIds
                end
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
                if v.spec_motorized then
                    local fid = (v.getOwnerFarmId and v:getOwnerFarmId()) or v.farmId
                    if fid == farmId then count = count + 1 end
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
        local ms  = g_currentMission.time or 0
        return {
            day    = env.currentDay or 1,
            season = env.currentSeason,
            hour   = math.floor(ms / 3600000),
            minute = math.floor((ms % 3600000) / 60000),
        }
    end)
end

function FT_DataProvider:getWeather()
    return self:_cached("weather", 2000, function()
        if not (g_currentMission and g_currentMission.environment) then
            return nil
        end
        local env       = g_currentMission.environment
        local rainScale = env.currentRainScale or 0
        local cloud     = 0
        if env.cloudUpdater and env.cloudUpdater.getCloudCoverage then
            cloud = env.cloudUpdater:getCloudCoverage()
        elseif env.cloudCoverage then
            cloud = env.cloudCoverage
        end
        local temp = env.temperature or 20
        local w = {
            temperature = temp,
            rainScale   = rainScale,
            isRaining   = rainScale > 0.05,
            isStorming  = rainScale > 0.70,
            isFoggy     = (env.fogScale or 0) > 0.3,
            cloudCover  = cloud,
            windSpeed   = env.windSpeed or 0,
            windDir     = env.windDir or 0,
            humidity    = env.humidity,
            forecast    = env.forecast,
        }
        if     w.isStorming     then w.condition = "Stormy";       w.condKey = "storm"
        elseif w.isRaining      then w.condition = "Rainy";        w.condKey = "rain"
        elseif w.isFoggy        then w.condition = "Foggy";        w.condKey = "fog"
        elseif cloud > 0.70     then w.condition = "Overcast";     w.condKey = "overcast"
        elseif cloud > 0.30     then w.condition = "Partly Cloudy";w.condKey = "cloudy"
        else                         w.condition = "Clear";        w.condKey = "clear"
        end
        return w
    end)
end

-- ── Fields ────────────────────────────────────────────────

-- Growth state names
local GROWTH_STATES = {
    [0]  = { name = "Withered",  color = FT.C.NEGATIVE  },
    [1]  = { name = "Seeded",    color = FT.C.MUTED     },
    [2]  = { name = "Germinated",color = FT.C.INFO      },
    [3]  = { name = "Growing",   color = FT.C.WARNING   },
    [4]  = { name = "Growing",   color = FT.C.WARNING   },
    [5]  = { name = "Growing",   color = FT.C.WARNING   },
    [6]  = { name = "Ripening",  color = FT.C.BRAND     },
    [7]  = { name = "Ready",     color = FT.C.POSITIVE  },
    [8]  = { name = "Harvested", color = FT.C.MUTED     },
}

function FT_DataProvider:getOwnedFields(farmId)
    return self:_cached("fields_"..farmId, 4000, function()
        local out = {}
        if not g_farmlandManager then return out end
        for _, fl in pairs(g_farmlandManager.farmlands) do
            if fl.farmId == farmId then
                for _, fieldId in ipairs(fl.fieldIds or {}) do
                    local field = g_fieldManager and g_fieldManager:getFieldById(fieldId)
                    if field then
                        local cropName  = "Empty"
                        local stateName = "Empty"
                        local stateColor= FT.C.MUTED
                        local phase     = "empty"

                        if field.fruitType and g_fruitTypeManager then
                            local ft2 = g_fruitTypeManager:getFruitTypeByIndex(field.fruitType)
                            if ft2 then
                                cropName = ft2.nameI18N or ft2.name or "Unknown"
                                local gs = GROWTH_STATES[field.growthState] or
                                           { name="Growing", color=FT.C.WARNING }
                                stateName  = gs.name
                                stateColor = gs.color
                                if field.growthState == 7 then phase = "ready"
                                elseif field.growthState and field.growthState > 0 then phase = "growing"
                                end
                            end
                        end

                        table.insert(out, {
                            id         = fl.id,
                            fieldId    = fieldId,
                            cropName   = cropName,
                            stateName  = stateName,
                            stateColor = stateColor,
                            phase      = phase,
                            area       = fl.totalFieldArea or 0,
                        })
                    end
                end
            end
        end
        table.sort(out, function(a, b) return a.id < b.id end)
        return out
    end)
end

-- ── Animals ───────────────────────────────────────────────

function FT_DataProvider:getAnimalPens(farmId)
    return self:_cached("animals_"..farmId, 3000, function()
        local out = {}
        if not (g_currentMission and g_currentMission.husbandrySystem) then
            return out
        end
        for _, cluster in pairs(g_currentMission.husbandrySystem.clusters or {}) do
            if cluster.farmId == farmId or
               (cluster.getFarmId and cluster:getFarmId() == farmId) then

                local typeName = cluster.typeName or "Unknown"
                local num  = 0
                local maxN = 0

                if cluster.getNumAnimals then
                    num = cluster:getNumAnimals()
                elseif cluster.numAnimals then
                    num = cluster.numAnimals
                end
                if cluster.maxNumAnimals then maxN = cluster.maxNumAnimals end

                local function getPct(spec, key)
                    if spec then
                        local v = spec[key]
                        if type(v) == "number" then return math.floor(v * 100) end
                        if spec.getFillLevel and spec.capacity then
                            return math.floor(spec:getFillLevel() / math.max(spec.capacity,1) * 100)
                        end
                    end
                    return nil
                end

                table.insert(out, {
                    typeName   = typeName,
                    numAnimals = num,
                    maxAnimals = maxN,
                    foodPct    = getPct(cluster.foodSpec,  "fillLevel") or
                                 (cluster.food ~= nil and math.floor(cluster.food*100)) or nil,
                    waterPct   = getPct(cluster.waterSpec, "fillLevel") or
                                 (cluster.water ~= nil and math.floor(cluster.water*100)) or nil,
                    cleanPct   = (cluster.cleanliness ~= nil and math.floor(cluster.cleanliness*100)) or nil,
                    hasFood    = cluster.foodSpec ~= nil or cluster.food ~= nil,
                    hasWater   = cluster.waterSpec ~= nil or cluster.water ~= nil,
                    hasCleanliness = cluster.cleanliness ~= nil,
                })
            end
        end
        return out
    end)
end

-- ── Vehicles ──────────────────────────────────────────────

function FT_DataProvider:getNearbyVehicles(radiusM)
    radiusM = radiusM or 20
    if not (g_currentMission and g_currentMission.player) then
        return {}
    end

    -- Get actual world position, considering if seated
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
                -- Fuel
                local fuel, fuelCap = 0, 1
                local ms = v.spec_motorized
                if ms then
                    if ms.fuelFillLevel and ms.fuelCapacity then
                        fuel    = ms.fuelFillLevel
                        fuelCap = math.max(ms.fuelCapacity, 1)
                    end
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
                -- Operating hours
                local opHours = 0
                if v.spec_motorized and v.spec_motorized.operatingTime then
                    opHours = math.floor(v.spec_motorized.operatingTime / 3600)
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

local SEASON_NAMES = {"Spring","Summer","Autumn","Winter"}
function FT_DataProvider:getSeasonName(seasonIdx)
    return SEASON_NAMES[(seasonIdx or 0) + 1] or "Unknown"
end

function FT_DataProvider:invalidate()
    self._cache = {}
end
