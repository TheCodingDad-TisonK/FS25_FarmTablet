-- =========================================================
-- FS25 Farm Tablet  v2.1.0.0  (complete overhaul)
-- Author: TisonK
-- =========================================================
local modDirectory = g_currentModDirectory
local modName      = g_currentModName

-- Core
source(modDirectory .. "src/core/Constants.lua")
source(modDirectory .. "src/core/EventBus.lua")
source(modDirectory .. "src/core/AppRegistry.lua")

-- Settings
source(modDirectory .. "src/settings/SettingsManager.lua")
source(modDirectory .. "src/settings/Settings.lua")
source(modDirectory .. "src/settings/SettingsGUI.lua")
source(modDirectory .. "src/settings/SettingsUI.lua")

-- Utils
source(modDirectory .. "src/utils/UIHelper.lua")
source(modDirectory .. "src/utils/InputHandler.lua")
source(modDirectory .. "src/utils/FunctionHooks.lua")
source(modDirectory .. "src/utils/Renderer.lua")
source(modDirectory .. "src/utils/DataProvider.lua")

-- System & UI
source(modDirectory .. "src/FarmTabletSystem.lua")
source(modDirectory .. "src/FarmTabletUI.lua")
source(modDirectory .. "src/FarmTabletManager.lua")

-- Built-in Apps
source(modDirectory .. "src/apps/DashboardApp.lua")
source(modDirectory .. "src/apps/AppStoreApp.lua")
source(modDirectory .. "src/apps/SettingsApp.lua")
source(modDirectory .. "src/apps/UpdatesApp.lua")
source(modDirectory .. "src/apps/WeatherApp.lua")
source(modDirectory .. "src/apps/WorkshopApp.lua")
source(modDirectory .. "src/apps/FieldStatusApp.lua")
source(modDirectory .. "src/apps/AnimalHusbandryApp.lua")
source(modDirectory .. "src/apps/DiggingApp.lua")
source(modDirectory .. "src/apps/BucketTrackerApp.lua")
source(modDirectory .. "src/apps/IncomeApp.lua")
source(modDirectory .. "src/apps/TaxApp.lua")
source(modDirectory .. "src/apps/NPCFavorApp.lua")
source(modDirectory .. "src/apps/SeasonalCropStressApp.lua")
source(modDirectory .. "src/apps/SoilFertilizerApp.lua")

local farmTabletManager

local function isEnabled()
    return farmTabletManager ~= nil
end

local function loadedMission(mission, node)
    if not isEnabled() then return end
    if mission.cancelLoading then return end
    farmTabletManager:onMissionLoaded()
end

local function load(mission)
    if farmTabletManager == nil then
        Logging.info("[FarmTablet v2] Initializing...")
        
        farmTabletManager = FarmTabletManager.new(mission, modDirectory, modName)
        getfenv(0)["g_FarmTablet"] = farmTabletManager
        Logging.info("[FarmTablet v2] Ready.")
    end
end

local function unload()
    if farmTabletManager ~= nil then
        farmTabletManager:delete()
        farmTabletManager = nil
        getfenv(0)["g_FarmTablet"] = nil
    end
end

Mission00.load                  = Utils.prependedFunction(Mission00.load, load)
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
FSBaseMission.delete            = Utils.appendedFunction(FSBaseMission.delete, unload)

FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, function(mission, dt)
    if farmTabletManager then farmTabletManager:update(dt) end
end)

Logging.info("[FarmTablet v2] Module loaded.")
