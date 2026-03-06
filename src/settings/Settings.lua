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
---@class Settings

Settings = {}
local Settings_mt = Class(Settings)

-- Startup app options
Settings.STARTUP_DASHBOARD = 1
Settings.STARTUP_APP_STORE = 2
Settings.STARTUP_WEATHER = 3
Settings.STARTUP_DIGGING = 4

function Settings.new(manager)
    local self = setmetatable({}, Settings_mt)
    self.manager = manager
    
    self:resetToDefaults(false)
    
    Logging.info("Farm Tablet: Settings initialized")
    
    return self
end

function Settings:resetToDefaults(saveImmediately)
    saveImmediately = saveImmediately ~= false
    
    self.enabled = true
    self.tabletKeybind = "T"
    self.showTabletNotifications = true
    self.startupApp = Settings.STARTUP_DASHBOARD
    self.vibrationFeedback = true
    self.soundEffects = true
    self.debugMode = false
    
    if saveImmediately then
        self:save()
        print("Farm Tablet: Settings reset to defaults")
    end
end

function Settings:getStartupAppName()
    if self.startupApp == Settings.STARTUP_DASHBOARD then
        return "Dashboard"
    elseif self.startupApp == Settings.STARTUP_APP_STORE then
        return "App Store"
    elseif self.startupApp == Settings.STARTUP_WEATHER then
        return "Weather"
    elseif self.startupApp == Settings.STARTUP_DIGGING then
        return "Digging"
    else
        return "Dashboard"
    end
end

function Settings:load()
    self.manager:loadSettings(self)
    self:validateSettings()
    
    Logging.info("Farm Tablet: Settings Loaded. Enabled: %s, Key: %s, Startup: %s", 
        tostring(self.enabled), self.tabletKeybind, self:getStartupAppName())
end

function Settings:validateSettings()
    -- Ensure startup app is valid
    if self.startupApp < 1 or self.startupApp > 4 then
        Logging.warning("Farm Tablet: Invalid startup app %d, resetting to Dashboard", self.startupApp)
        self.startupApp = Settings.STARTUP_DASHBOARD
    end
    
    -- Ensure keybind is valid
    if self.tabletKeybind == nil or self.tabletKeybind == "" then
        self.tabletKeybind = "T"
    end
    
    -- Boolean validation
    self.enabled = not not self.enabled
    self.debugMode = not not self.debugMode
    self.showTabletNotifications = not not self.showTabletNotifications
    self.soundEffects = not not self.soundEffects
    self.vibrationFeedback = not not self.vibrationFeedback
end

function Settings:save()
    self.manager:saveSettings(self)
    Logging.info("Farm Tablet: Settings Saved. Keybind: %s, Startup: %s", 
        self.tabletKeybind, self:getStartupAppName())
end

function Settings:setStartupApp(app)
    if app >= 1 and app <= 4 then
        self.startupApp = app
        Logging.info("Farm Tablet: Startup app changed to: %s", self:getStartupAppName())
    end
end

function Settings:setKeybind(key)
    if key and key ~= "" then
        self.tabletKeybind = key
        Logging.info("Farm Tablet: Keybind changed to: %s", key)
    end
end