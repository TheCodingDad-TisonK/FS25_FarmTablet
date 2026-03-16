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
---@class SettingsGUI

SettingsGUI = {}
local SettingsGUI_mt = Class(SettingsGUI)

function SettingsGUI.new()
    local self = setmetatable({}, SettingsGUI_mt)
    return self
end

function SettingsGUI:registerConsoleCommands()
    addConsoleCommand("TabletEnable", "Enable Farm Tablet", "consoleCommandTabletEnable", self)
    addConsoleCommand("TabletDisable", "Disable Farm Tablet", "consoleCommandTabletDisable", self)
    addConsoleCommand("TabletOpen", "Open tablet", "consoleCommandTabletOpen", self)
    addConsoleCommand("TabletClose", "Close tablet", "consoleCommandTabletClose", self)
    addConsoleCommand("TabletToggle", "Toggle tablet", "consoleCommandTabletToggle", self)
    addConsoleCommand("TabletKeybind", "Set tablet keybind", "consoleCommandTabletKeybind", self)
    addConsoleCommand("TabletSetNotifications", "Enable/disable notifications", "consoleCommandTabletSetNotifications", self)
    addConsoleCommand("TabletSetStartupApp", "Set startup app ID", "consoleCommandTabletSetStartupApp", self)
    addConsoleCommand("TabletApp", "Switch to app by ID", "consoleCommandTabletApp", self)
    addConsoleCommand("TabletShowSettings", "Show current settings", "consoleCommandTabletShowSettings", self)
    addConsoleCommand("TabletResetSettings", "Reset all settings to defaults", "consoleCommandTabletResetSettings", self)
    
    addConsoleCommand("tablet", "Show all tablet commands", "consoleCommandHelp", self)
    
    Logging.info("Farm Tablet console commands registered")
end

function SettingsGUI:consoleCommandHelp()
    print("=== Farm Tablet Console Commands ===")
    print("tablet - Show this help")
    print("TabletEnable/Disable - Toggle mod")
    print("TabletOpen/Close - Open/close tablet")
    print("TabletToggle - Toggle tablet")
    print("TabletKeybind [key] - Set open key")
    print("TabletSetNotifications true|false - Toggle notifications")
    print("TabletSetStartupApp [id] - Set startup app (e.g. dashboard, weather)")
    print("TabletApp [id] - Switch to app immediately")
    print("TabletShowSettings - Show current settings")
    print("TabletResetSettings - Reset to defaults")
    print("===================================")
    return "Type 'help' for more info"
end

function SettingsGUI:consoleCommandTabletApp(appId)
    if not appId or appId == "" then
        return "Usage: TabletApp [app_id] (e.g., dashboard, weather, animals)"
    end
    
    if g_FarmTablet then
        if g_FarmTablet:switchApp(appId) then
            return string.format("Switched to app: %s", appId)
        else
            return string.format("Error: App '%s' not found or not enabled", appId)
        end
    end
    
    return "Error: Farm Tablet not initialized"
end

function SettingsGUI:consoleCommandTabletEnable()
    if g_FarmTablet and g_FarmTablet.settings then
        g_FarmTablet.settings.enabled = true
        g_FarmTablet.settings:save()
        return "Farm Tablet enabled"
    end
    return "Error: Farm Tablet not initialized"
end

function SettingsGUI:consoleCommandTabletDisable()
    if g_FarmTablet and g_FarmTablet.settings then
        g_FarmTablet.settings.enabled = false
        g_FarmTablet.settings:save()
        return "Farm Tablet disabled"
    end
    return "Error: Farm Tablet not initialized"
end

function SettingsGUI:consoleCommandTabletOpen()
    if g_FarmTablet then
        g_FarmTablet:openTablet()
        return "Tablet opened"
    end
    return "Error: Farm Tablet not initialized"
end

function SettingsGUI:consoleCommandTabletClose()
    if g_FarmTablet then
        g_FarmTablet:closeTablet()
        return "Tablet closed"
    end
    return "Error: Farm Tablet not initialized"
end

function SettingsGUI:consoleCommandTabletToggle()
    if g_FarmTablet then
        g_FarmTablet:toggleTablet()
        return "Tablet toggled"
    end
    return "Error: Farm Tablet not initialized"
end

function SettingsGUI:consoleCommandTabletKeybind(key)
    if not key then
        return "Usage: TabletKeybind [key]"
    end
    
    if g_FarmTablet and g_FarmTablet.settings then
        g_FarmTablet.settings:setKeybind(key)
        g_FarmTablet.settings:save()
        
        -- Re-register input binding
        if g_FarmTablet.inputHandler then
            g_FarmTablet.inputHandler:registerKeyBinding()
        end
        
        return string.format("Tablet keybind set to: %s", key)
    end
    
    return "Error: Farm Tablet not initialized"
end

function SettingsGUI:consoleCommandTabletSetNotifications(enabled)
    if enabled == nil then
        return "Usage: TabletSetNotifications true|false"
    end
    
    local enable = enabled:lower()
    if enable ~= "true" and enable ~= "false" then
        return "Invalid value. Use 'true' or 'false'"
    end
    
    if g_FarmTablet and g_FarmTablet.settings then
        g_FarmTablet.settings.showTabletNotifications = (enable == "true")
        g_FarmTablet.settings:save()
        return string.format("Notifications %s", g_FarmTablet.settings.showTabletNotifications and "enabled" or "disabled")
    end
    
    return "Error: Farm Tablet not initialized"
end

function SettingsGUI:consoleCommandTabletSetStartupApp(appId)
    if not appId or appId == "" then
        return "Usage: TabletSetStartupApp [app_id] (e.g., dashboard, weather, animals)"
    end
    
    if g_FarmTablet and g_FarmTablet.settings then
        g_FarmTablet.settings:setStartupApp(appId)
        g_FarmTablet.settings:save()
        return string.format("Startup app set to: %s", g_FarmTablet.settings:getStartupAppName())
    end
    
    return "Error: Farm Tablet not initialized"
end

function SettingsGUI:consoleCommandTabletShowSettings()
    if g_FarmTablet and g_FarmTablet.settings then
        local settings = g_FarmTablet.settings
        local info = string.format(
            "=== Farm Tablet Settings ===\n" ..
            "Enabled: %s\n" ..
            "Open Key: %s\n" ..
            "Startup App: %s\n" ..
            "Notifications: %s\n" ..
            "Sound Effects: %s\n" ..
            "Debug Mode: %s\n" ..
            "==========================",
            tostring(settings.enabled),
            settings.tabletKeybind,
            settings:getStartupAppName(),
            tostring(settings.showTabletNotifications),
            tostring(settings.soundEffects),
            tostring(settings.debugMode)
        )
        print(info)
        return info
    end
    
    return "Error: Farm Tablet not initialized"
end

function SettingsGUI:consoleCommandTabletResetSettings()
    if g_FarmTablet and g_FarmTablet.settings then
        g_FarmTablet.settings:resetToDefaults()
        return "Farm Tablet settings reset to default!"
    end
    
    return "Error: Farm Tablet not initialized"
end