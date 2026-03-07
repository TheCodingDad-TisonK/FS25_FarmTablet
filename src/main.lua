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
local modDirectory = g_currentModDirectory
local modName = g_currentModName

-- Load all modules
source(modDirectory .. "src/settings/SettingsManager.lua")
source(modDirectory .. "src/settings/Settings.lua")
source(modDirectory .. "src/settings/SettingsGUI.lua")
source(modDirectory .. "src/settings/SettingsUI.lua")
source(modDirectory .. "src/utils/UIHelper.lua")
source(modDirectory .. "src/utils/InputHandler.lua")
source(modDirectory .. "src/utils/FunctionHooks.lua")
source(modDirectory .. "src/FarmTabletSystem.lua")
source(modDirectory .. "src/FarmTabletUI.lua")
source(modDirectory .. "src/FarmTabletManager.lua")

-- Load apps
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
    if not isEnabled() then
        return
    end
    
    if mission.cancelLoading then
        return
    end
    
    farmTabletManager:onMissionLoaded()
end

local function load(mission)
    if farmTabletManager == nil then
        print("Farm Tablet: Initializing...")
        farmTabletManager = FarmTabletManager.new(mission, modDirectory, modName)
        getfenv(0)["g_FarmTablet"] = farmTabletManager
        print("Farm Tablet: Initialized successfully")
    end
end

local function unload()
    if farmTabletManager ~= nil then
        farmTabletManager:delete()
        farmTabletManager = nil
        getfenv(0)["g_FarmTablet"] = nil
    end
end

-- FS25 Hooks
Mission00.load = Utils.prependedFunction(Mission00.load, load)
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)

FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, function(mission, dt)
    if farmTabletManager then
        farmTabletManager:update(dt)
    end
end)

-- Console commands
function tablet()
    if g_FarmTablet and g_FarmTablet.settingsGUI then
        return g_FarmTablet.settingsGUI:consoleCommandHelp()
    else
        print("=== Farm Tablet Commands ===")
        print("Type these commands in console (~):")
        print("TabletShowSettings - Show current settings")
        print("TabletEnable/Disable - Enable/disable mod")
        print("TabletOpen/Close - Open/close tablet")
        print("TabletToggle - Toggle tablet")
        print("TabletApp [app_id] - Switch to specific app")
        print("TabletKeybind [key] - Set open key (e.g., T)")
        print("TabletSetNotifications true|false - Toggle notifications")
        print("TabletSetStartupApp 1|2|3|4 - Set startup app")
        print("TabletResetSettings - Reset to defaults")
        print("============================")
        return "Farm Tablet commands listed above"
    end
end

function tabletStatus()
    if g_FarmTablet and g_FarmTablet.settings then
        local settings = g_FarmTablet.settings
        print(string.format(
            "Enabled: %s\nOpen Key: %s\nStartup App: %s\nNotifications: %s\nSound Effects: %s\nDebug Mode: %s",
            tostring(settings.enabled),
            settings.tabletKeybind,
            settings.startupApp,
            tostring(settings.showTabletNotifications),
            tostring(settings.soundEffects),
            tostring(settings.debugMode)
        ))
    else
        print("Farm Tablet not initialized")
    end
end

-- Register global functions
getfenv(0)["tablet"] = tablet
getfenv(0)["tabletStatus"] = tabletStatus
getfenv(0)["tabletOpen"] = function()
    if g_FarmTablet then
        g_FarmTablet:openTablet()
        return "Tablet opened"
    end
    return "Farm Tablet not initialized"
end

getfenv(0)["tabletClose"] = function()
    if g_FarmTablet then
        g_FarmTablet:closeTablet()
        return "Tablet closed"
    end
    return "Farm Tablet not initialized"
end

getfenv(0)["tabletToggle"] = function()
    if g_FarmTablet then
        g_FarmTablet:toggleTablet()
        return "Tablet toggled"
    end
    return "Farm Tablet not initialized"
end

print("========================================")
print("     FS25 Farm Tablet v1.1.0.0 LOADED   ")
print("     Integrated into settings system    ")
print("     Type 'tablet' in console for help  ")
print("========================================")