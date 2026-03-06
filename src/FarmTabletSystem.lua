-- =========================================================
-- FS25 Farm Tablet Mod (version 1.1.0.1)
-- =========================================================
-- Central tablet interface for farm management mods
-- =========================================================
-- Author: TisonK
-- =========================================================
-- COPYRIGHT NOTICE:
-- All rights reserved. Unauthorized redistribution, copying,
-- or claiming this code as your own is strictly prohibited.
-- Original author: TisonK
-- =========================================================
---@class FarmTabletSystem
FarmTabletSystem = {}
local FarmTabletSystem_mt = Class(FarmTabletSystem)

function FarmTabletSystem.new(settings)
    local self = setmetatable({}, FarmTabletSystem_mt)
    self.settings = settings
    self.isInitialized = false
    
    -- Registered apps
    self.registeredApps = {
        {
            id = "financial_dashboard",
            name = "ft_app_dashboard",
            navLabel = "DASH",
            icon = "dashboard_icon",
            developer = "FarmTablet",
            version = "Built-in",
            enabled = true
        },
        {
            id = "app_store",
            name = "ft_app_store",
            navLabel = "APPS",
            icon = "store_icon",
            developer = "FarmTablet",
            version = "Built-in",
            enabled = true
        },
        {
            id = "settings",
            name = "ft_app_settings",
            navLabel = "SET",
            icon = "settings_icon",
            developer = "FarmTablet",
            version = "Built-in",
            enabled = true
        },
        {
            id = "updates",
            name = "ft_app_updates",
            navLabel = "UPD",
            icon = "updates_icon",
            developer = "FarmTablet",
            version = "Built-in",
            enabled = true
        },
        -- {
        --     id = "workshop",
        --     name = "ft_app_workshop",
        --     icon = "workshop_icon",
        --     developer = "FarmTablet",
        --     version = "Built-in",
        --     enabled = true
        -- },
        {
            id = "weather",
            name = "ft_app_weather",
            navLabel = "WTH",
            icon = "weather_icon",
            developer = "FarmTablet",
            version = "Built-in",
            enabled = true
        },
        {
            id = "digging",
            name = "ft_app_digging",
            navLabel = "DIG",
            icon = "digging_app",
            developer = "FarmTablet",
            version = "Built-in",
            enabled = true
        },
        {
            id = "bucket_tracker",
            name = "ft_app_bucket_tracker",
            navLabel = "BCK",
            icon = "bucket_icon",
            developer = "FarmTablet",
            version = "Built-in",
            enabled = true
        }
    }

    -- Maps settings.startupApp integer to string app ID
    FarmTabletSystem.STARTUP_APP_IDS = {
        [1] = "financial_dashboard",
        [2] = "app_store",
        [3] = "weather",
        [4] = "digging",
    }
    
    -- Current state — map int 1-4 to string app ID
    self.currentApp = FarmTabletSystem.STARTUP_APP_IDS[self.settings.startupApp] or "financial_dashboard"
    self.isTabletOpen = false
    
    -- Live data cache
    self.liveCache = {
        balance = -1,
        income = -1,
        expenses = -1,
        profit = -1
    }
    
    -- Bucket tracker
    self.bucketTracker = {
        isEnabled = true,
        currentVehicle = nil,
        bucketHistory = {},
        totalLoads = 0,
        totalWeight = 0,
        currentFillLevel = 0,
        currentFillType = nil,
        startTime = 0,
        lastLoadTime = 0
    }
    
    return self
end

function FarmTabletSystem:initialize()
    if self.isInitialized then
        return
    end
    
    self.isInitialized = true
    self:log("Farm Tablet System initialized successfully")
    self:log("Startup app: %s", self.currentApp)
    self:log("Registered apps: %d", #self.registeredApps)
    
    -- Auto-detect other mods
    self:autoRegisterModApps()
end

function FarmTabletSystem:log(msg, ...)
    if self.settings.debugMode then
        print(string.format("[Farm Tablet] " .. msg, ...))
    end
end

function FarmTabletSystem:_appRegistered(id)
    for _, app in ipairs(self.registeredApps) do
        if app.id == id then return true end
    end
    return false
end

function FarmTabletSystem:autoRegisterModApps()
    self:log("Starting mod auto-registration")
    
    -- Check for Income Mod
    if g_IncomeManager or _G["Income"] or (g_modIsLoaded and g_modIsLoaded["FS25_IncomeMod"]) then
        if not self:_appRegistered("income_mod") then
            table.insert(self.registeredApps, {
                id = "income_mod",
                name = "ft_app_income_mod",
                navLabel = "INC",
                icon = "income_icon",
                developer = "TisonK",
                version = "Integrated",
                enabled = true
            })
            self:log("Income Mod app registered")
        end
    end
    
    -- Check for Tax Mod
    if g_TaxManager then
        if not self:_appRegistered("tax_mod") then
            table.insert(self.registeredApps, {
                id = "tax_mod",
                name = "ft_app_tax_mod",
                navLabel = "TAX",
                icon = "tax_icon",
                developer = "TisonK",
                version = "Integrated",
                enabled = true
            })
            self:log("Tax Mod app registered")
        end
    end
    
    -- Check for NPC Favor
    local npcFavorPresent = g_currentMission and g_currentMission.npcFavorSystem ~= nil
    if npcFavorPresent and not self:_appRegistered("npc_favor") then
        table.insert(self.registeredApps, {
            id = "npc_favor",
            name = "ft_app_npc_favor",
            navLabel = "NPC",
            developer = "TisonK",
            version = "Integrated",
            enabled = true
        })
        self:log("NPC Favor app registered")
    end

    -- Check for Seasonal Crop Stress
    local cropStressPresent = g_currentMission and g_currentMission.cropStressManager ~= nil
    if cropStressPresent and not self:_appRegistered("crop_stress") then
        table.insert(self.registeredApps, {
            id = "crop_stress",
            name = "ft_app_crop_stress",
            navLabel = "CRPS",
            developer = "TisonK",
            version = "Integrated",
            enabled = true
        })
        self:log("Seasonal Crop Stress app registered")
    end

    -- Check for Soil Fertilizer
    local soilFertPresent = g_soilFertilizerManager ~= nil or
        (g_currentMission and g_currentMission.soilFertilizerManager ~= nil)
    if soilFertPresent and not self:_appRegistered("soil_fertilizer") then
        table.insert(self.registeredApps, {
            id = "soil_fertilizer",
            name = "ft_app_soil_fertilizer",
            navLabel = "SOIL",
            developer = "TisonK",
            version = "Integrated",
            enabled = true
        })
        self:log("Soil Fertilizer app registered")
    end

    self:log("Mod auto-registration complete")
    self:log("Total registered apps: %d", #self.registeredApps)
end

function FarmTabletSystem:getPlayerFarmId()
    if g_currentMission ~= nil then
        if g_currentMission.player ~= nil then
            local player = g_currentMission.player
            if player.getFarmId ~= nil then
                return player:getFarmId()
            elseif player.farmId ~= nil then
                return player.farmId
            end
        end
        
        if g_currentMission:getFarmId() ~= nil then
            return g_currentMission:getFarmId()
        end
    end
    
    return 1
end

function FarmTabletSystem:TotalMoney(farmId)
    if g_farmManager ~= nil then
        local farm = g_farmManager:getFarmById(farmId)
        if farm ~= nil then
            return math.floor(farm:getBalance() or 0)
        end
    end
    return 0
end

function FarmTabletSystem:TotalIncome(farmId)
    local totalIncome = 0

    if g_currentMission == nil or g_currentMission.statistics == nil then
        return 0
    end

    local incomeKeywords = {
        "income",
        "revenue",
        "harvest",
        "mission",
        "selling",
        "contract"
    }

    for _, statsItem in ipairs(g_currentMission.statistics.statsItems or {}) do
        if statsItem.farmId == farmId and statsItem.name then
            local name = statsItem.name:lower()
            for _, key in ipairs(incomeKeywords) do
                if name:find(key) then
                    local v = statsItem:getValue() or 0
                    if v > 0 then
                        totalIncome = totalIncome + v
                    end
                    break
                end
            end
        end
    end

    return math.floor(totalIncome)
end

function FarmTabletSystem:TotalExpenses(farmId)
    local totalExpenses = 0

    if g_currentMission == nil or g_currentMission.statistics == nil then
        return 0
    end

    local expenseKeywords = {
        "expense",
        "cost",
        "maintenance",
        "wage",
        "fuel",
        "seed",
        "fertilizer",
        "spray",
        "repair",
        "lease",
        "insurance",
        "animal",
        "property",
        "loanInterest"
    }

    if g_currentMission.statistics.statsItems ~= nil then
        for _, statsItem in ipairs(g_currentMission.statistics.statsItems) do
            if statsItem.farmId == farmId and statsItem.name ~= nil then
                local nameLower = statsItem.name:lower()

                for _, keyword in ipairs(expenseKeywords) do
                    if nameLower:find(keyword) then
                        local value = statsItem:getValue() or 0
                        if value > 0 then
                            totalExpenses = totalExpenses + value
                        end
                        break
                    end
                end
            end
        end
    end

    return math.floor(totalExpenses)
end

function FarmTabletSystem:LoanedMoney(farmId)
    if g_farmManager ~= nil then
        local farm = g_farmManager:getFarmById(farmId)
        if farm ~= nil and farm.loan ~= nil then
            return math.floor(farm.loan)
        end
    end
    return 0
end

function FarmTabletSystem:ActiveFields(farmId)
    local count = 0

    if g_farmlandManager == nil then
        return 0
    end

    for farmlandId, farmland in pairs(g_farmlandManager.farmlands) do
        if farmland.farmId == farmId then
            if farmland.fieldIds ~= nil then
                count = count + #farmland.fieldIds
            end
        end
    end

    return count
end

function FarmTabletSystem:VehiclesCount(farmId)
    local count = 0

    if g_currentMission ~= nil and g_currentMission.vehicles ~= nil then
        for _, vehicle in pairs(g_currentMission.vehicles) do
            if vehicle.spec_motorized ~= nil then
                local ownerFarmId = nil

                if vehicle.getOwnerFarmId ~= nil then
                    ownerFarmId = vehicle:getOwnerFarmId()
                elseif vehicle.farmId ~= nil then
                    ownerFarmId = vehicle.farmId
                end

                if ownerFarmId == farmId then
                    count = count + 1
                end
            end
        end
    end

    return count
end

function FarmTabletSystem:update(dt)
    if not self.settings.enabled or not self.isInitialized then
        return
    end
    
    -- Update bucket tracker if enabled
    if self.bucketTracker.isEnabled and self.currentApp == "bucket_tracker" then
        self:trackBucketLoad()
    end
end

-- Bucket tracker functions
function FarmTabletSystem:getCurrentBucketVehicle()
    if g_currentMission == nil or g_currentMission.controlledVehicle == nil then
        return nil
    end
    
    local vehicle = g_currentMission.controlledVehicle
    
    if self:isBucketVehicle(vehicle) then
        return vehicle
    end
    
    return nil
end

function FarmTabletSystem:isBucketVehicle(vehicle)
    if not vehicle then return false end
    
    -- Check vehicle type
    local typeName = vehicle.typeName or ""
    typeName = typeName:lower()
    
    local bucketVehicleTypes = {
        "wheelLoader",
        "frontLoader",
        "loader",
        "excavator",
        "backhoe",
        "telehandler",
        "skidSteer",
        "materialHandler"
    }
    
    for _, vehicleType in ipairs(bucketVehicleTypes) do
        if typeName:find(vehicleType) then
            return true
        end
    end
    
    -- Check attachments
    if vehicle.getAttachedImplements then
        local attached = vehicle:getAttachedImplements()
        for _, impl in ipairs(attached) do
            local implType = impl.object.typeName or ""
            implType = implType:lower()
            
            if implType:find("bucket") or 
               implType:find("loader") or 
               implType:find("grapple") or
               implType:find("fork") then
                return true
            end
        end
    end
    
    return false
end

function FarmTabletSystem:getBucketFillInfo(vehicle)
    local fillInfo = {
        hasFillUnit = false,
        totalCapacity = 0,
        totalFillLevel = 0,
        currentFillType = nil,
        fillTypeName = "Empty",
        fillPercentage = 0
    }
    
    if vehicle == nil or g_fillTypeManager == nil then
        return fillInfo
    end
    
    -- Check vehicle's fill units
    if vehicle.spec_fillUnit then
        local fillUnitSpec = vehicle.spec_fillUnit
        fillInfo.hasFillUnit = true
        
        for _, fillUnit in ipairs(fillUnitSpec.fillUnits) do
            fillInfo.totalCapacity = fillInfo.totalCapacity + (fillUnit.capacity or 0)
            fillInfo.totalFillLevel = fillInfo.totalFillLevel + (fillUnit.fillLevel or 0)
            
            if (fillUnit.fillLevel or 0) > 0 then
                fillInfo.currentFillType = fillUnit.fillType or FillType.UNKNOWN
            end
        end
    end
    
    -- Calculate percentage
    if fillInfo.totalCapacity > 0 then
        fillInfo.fillPercentage = (fillInfo.totalFillLevel / fillInfo.totalCapacity) * 100
    end
    
    -- Get fill type name
    if fillInfo.currentFillType and g_fillTypeManager then
        local fillType = g_fillTypeManager:getFillTypeByIndex(fillInfo.currentFillType)
        if fillType then
            fillInfo.fillTypeName = fillType.title or "Unknown"
        end
    end
    
    return fillInfo
end

function FarmTabletSystem:estimateBucketWeight(fillInfo)
    if fillInfo.totalFillLevel <= 0 then
        return 0
    end
    
    -- Rough weight estimation (liters to kg)
    local densities = {
        [FillType.SAND] = 1.6,
        [FillType.GRAVEL] = 1.7,
        [FillType.CRUSHEDSTONE] = 1.6,
        [FillType.STONE] = 2.6,
        [FillType.DIRT] = 1.3,
        [FillType.CLAY] = 1.8,
        [FillType.LIMESTONE] = 2.6,
        [FillType.COAL] = 1.3,
        [FillType.ORE] = 2.5,
        [FillType.CONCRETE] = 2.4
    }
    
    local fillType = fillInfo.currentFillType or FillType.UNKNOWN
    local density = densities[fillType] or 1.5
    
    return math.floor(fillInfo.totalFillLevel * density)
end

function FarmTabletSystem:resetBucketTracker()
    self.bucketTracker = {
        isEnabled = true,
        currentVehicle = nil,
        bucketHistory = {},
        totalLoads = 0,
        totalWeight = 0,
        currentFillLevel = 0,
        currentFillType = nil,
        startTime = g_currentMission.time or 0,
        lastLoadTime = 0
    }
    
    self:log("Bucket tracker reset")
end

function FarmTabletSystem:trackBucketLoad()
    if not self.bucketTracker.isEnabled then
        return
    end

    local vehicle = self:getCurrentBucketVehicle()

    if vehicle then
        if self.bucketTracker.currentVehicle ~= vehicle then
            self.bucketTracker.currentVehicle = vehicle
            self.bucketTracker.currentFillLevel = 0
            self.bucketTracker.currentFillType = nil
        end

        local fillInfo = self:getBucketFillInfo(vehicle)
        local oldFillLevel = self.bucketTracker.currentFillLevel or 0
        local newFillLevel = fillInfo.totalFillLevel

        -- Detect a dump: bucket had a meaningful amount and is now near-empty
        local dumpThreshold = math.max(50, (fillInfo.totalCapacity or 0) * 0.10)
        if oldFillLevel >= dumpThreshold and newFillLevel < dumpThreshold and oldFillLevel > 0 then
            self.bucketTracker.totalLoads = self.bucketTracker.totalLoads + 1
            if self.bucketTracker.startTime == 0 then
                self.bucketTracker.startTime = g_currentMission.time or 0
            end
            local weight = self:estimateBucketWeight({
                totalFillLevel = oldFillLevel,
                currentFillType = self.bucketTracker.currentFillType
            })
            self.bucketTracker.totalWeight = self.bucketTracker.totalWeight + weight
            self.bucketTracker.lastLoadTime = g_currentMission.time or 0

            table.insert(self.bucketTracker.bucketHistory, {
                number = self.bucketTracker.totalLoads,
                volume = math.floor(oldFillLevel),
                fillType = self.bucketTracker.currentFillType,
                fillTypeName = fillInfo.fillTypeName,
                weight = weight,
                time = self.bucketTracker.lastLoadTime
            })
            -- Keep history capped at 20 entries
            if #self.bucketTracker.bucketHistory > 20 then
                table.remove(self.bucketTracker.bucketHistory, 1)
            end
        end

        -- Update tracker state
        self.bucketTracker.currentFillLevel = newFillLevel
        self.bucketTracker.currentFillType = fillInfo.currentFillType
    else
        -- No bucket vehicle, reset current
        if self.bucketTracker.currentVehicle ~= nil then
            self.bucketTracker.currentVehicle = nil
            self.bucketTracker.currentFillLevel = 0
            self.bucketTracker.currentFillType = nil
        end
    end
end

function FarmTabletSystem:saveState()
    return {
        currentApp = self.currentApp,
        isTabletOpen = self.isTabletOpen,
        bucketTracker = self.bucketTracker
    }
end

function FarmTabletSystem:loadState(state)
    if state then
        self.currentApp = state.currentApp or "financial_dashboard"
        self.isTabletOpen = state.isTabletOpen or false
        self.bucketTracker = state.bucketTracker or {
            isEnabled = true,
            currentVehicle = nil,
            bucketHistory = {},
            totalLoads = 0,
            totalWeight = 0,
            currentFillLevel = 0,
            currentFillType = nil,
            startTime = 0,
            lastLoadTime = 0
        }
    end
end