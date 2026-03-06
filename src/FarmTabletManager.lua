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
---@class FarmTabletManager
FarmTabletManager = {}
local FarmTabletManager_mt = Class(FarmTabletManager)

function FarmTabletManager.new(mission, modDirectory, modName)
    local self = setmetatable({}, FarmTabletManager_mt)
    
    self.mission = mission
    self.modDirectory = modDirectory
    self.modName = modName
    
    -- Initialize subsystems
    self.settingsManager = SettingsManager.new()
    self.settings = Settings.new(self.settingsManager)
    
    self.farmTabletSystem = FarmTabletSystem.new(self.settings)
    self.farmTabletUI = FarmTabletUI.new(self.settings, self.farmTabletSystem)
    
    -- Initialize input handler
    self.inputHandler = InputHandler.new(self)
    
    -- Settings UI for pause menu
    if mission:getIsClient() and g_gui then
        self.settingsUI = SettingsUI.new(self.settings)
        
        InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
            self.settingsUI:inject()
        end)
        
        InGameMenuSettingsFrame.updateButtons = Utils.appendedFunction(InGameMenuSettingsFrame.updateButtons, function(frame)
            if self.settingsUI then
                self.settingsUI:ensureResetButton(frame)
            end
        end)
    end
    
    -- Console commands
    self.settingsGUI = SettingsGUI.new()
    self.settingsGUI:registerConsoleCommands()
    
    -- Load settings
    self.settings:load()
    
    return self
end

function FarmTabletManager:onMissionLoaded()
    if self.farmTabletSystem then
        self.farmTabletSystem:initialize()
    end
    
    -- Register input binding
    self.inputHandler:registerKeyBinding()
    
    if self.settings.enabled and self.settings.showTabletNotifications then
        self:showNotification(
            g_i18n:getText("ft_welcome_title") or "Farm Tablet",
            string.format(g_i18n:getText("ft_welcome_message") or "Press %s to open", self.settings.tabletKeybind)
        )
    end
end

function FarmTabletManager:update(dt)
    if not self.settings.enabled then
        return
    end
    
    -- Update input handler (checks for key presses)
    if self.inputHandler then
        self.inputHandler:update(dt)
    end
    
    -- Update system
    if self.farmTabletSystem then
        self.farmTabletSystem:update(dt)
    end
    
    -- Update UI
    if self.farmTabletUI then
        self.farmTabletUI:update(dt)
    end
end

function FarmTabletManager:openTablet()
    if self.farmTabletUI then
        self.farmTabletUI:openTablet()
    end
end

function FarmTabletManager:closeTablet()
    if self.farmTabletUI then
        self.farmTabletUI:closeTablet()
    end
end

function FarmTabletManager:toggleTablet()
    if self.farmTabletUI then
        self.farmTabletUI:toggleTablet()
    end
end

function FarmTabletManager:showNotification(title, message)
    if not self.mission or not self.settings.showTabletNotifications then
        return
    end
    
    if self.mission.hud and self.mission.hud.showBlinkingWarning then
        self.mission.hud:showBlinkingWarning(string.format("%s: %s", title, message), 4000)
    end
end

function FarmTabletManager:log(msg, ...)
    if self.settings.debugMode then
        print(string.format("[Farm Tablet] " .. msg, ...))
    end
end

function FarmTabletManager:delete()
    if self.settings then
        self.settings:save()
    end
    
    if self.inputHandler then
        self.inputHandler:unregisterKeyBinding()
    end
    
    if self.farmTabletUI then
        self.farmTabletUI:delete()
    end
    
    print("Farm Tablet: Shutting down")
end