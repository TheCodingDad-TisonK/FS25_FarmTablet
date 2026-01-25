-- =========================================================
-- FS25 Farm Tablet Mod (version 1.1.0.0)
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
---@class SettingsUI
SettingsUI = {}
local SettingsUI_mt = Class(SettingsUI)

function SettingsUI.new(settings)
    local self = setmetatable({}, SettingsUI_mt)
    self.settings = settings
    self.injected = false
    return self
end

function SettingsUI:inject()
    if self.injected then 
        return 
    end
    
    local page = g_gui.screenControllers[InGameMenu].pageSettings
    if not page then
        Logging.error("ft: Settings page not found - cannot inject settings!")
        return 
    end
    
    local layout = page.generalSettingsLayout
    if not layout then
        Logging.error("ft: Settings layout not found!")
        return 
    end
    
    local section = UIHelper.createSection(layout, "ft_section")
    if not section then
        Logging.error("ft: Failed to create settings section!")
        return
    end
    
    -- Enabled option
    local enabledOpt = UIHelper.createBinaryOption(
        layout,
        "ft_enabled",
        "ft_enabled",
        self.settings.enabled,
        function(val)
            self.settings.enabled = val
            self.settings:save()
            print("Farm Tablet: " .. (val and "Enabled" or "Disabled"))
        end
    )
    
    -- Debug mode option
    local debugOpt = UIHelper.createBinaryOption(
        layout,
        "ft_debug",
        "ft_debug",
        self.settings.debugMode,
        function(val)
            self.settings.debugMode = val
            self.settings:save()
            print("Farm Tablet: Debug mode " .. (val and "enabled" or "disabled"))
        end
    )
    
    -- Startup app option
    local startupOptions = {
        getTextSafe("ft_startupapp_1"),
        getTextSafe("ft_startupapp_2"),
        getTextSafe("ft_startupapp_3"),
        getTextSafe("ft_startupapp_4")
    }
    
    local startupOpt = UIHelper.createMultiOption(
        layout,
        "ft_startupapp",
        "ft_startupapp",
        startupOptions,
        self.settings.startupApp,
        function(val)
            self.settings.startupApp = val
            self.settings:save()
            print("Farm Tablet: Startup app set to " .. self.settings:getStartupAppName())
        end
    )
    
    -- Notifications option
    local notificationsOpt = UIHelper.createBinaryOption(
        layout,
        "ft_notifications",
        "ft_notifications",
        self.settings.showTabletNotifications,
        function(val)
            self.settings.showTabletNotifications = val
            self.settings:save()
            print("Farm Tablet: Notifications " .. (val and "enabled" or "disabled"))
        end
    )
    
    -- Sound effects option
    local soundOpt = UIHelper.createBinaryOption(
        layout,
        "ft_soundeffects",
        "ft_soundeffects",
        self.settings.soundEffects,
        function(val)
            self.settings.soundEffects = val
            self.settings:save()
            print("Farm Tablet: Sound effects " .. (val and "enabled" or "disabled"))
        end
    )
    
    self.enabledOption = enabledOpt
    self.debugOption = debugOpt
    self.startupOption = startupOpt
    self.notificationsOption = notificationsOpt
    self.soundOption = soundOpt
    
    self.injected = true
    layout:invalidateLayout()
    
    print("Farm Tablet: Settings UI injected successfully")
end

function getTextSafe(key)
    local text = g_i18n:getText(key)
    if text == nil or text == "" then
        return key
    end
    return text
end

function SettingsUI:refreshUI()
    if not self.injected then
        return
    end
    
    if self.enabledOption and self.enabledOption.setIsChecked then
        self.enabledOption:setIsChecked(self.settings.enabled)
    elseif self.enabledOption and self.enabledOption.setState then
        self.enabledOption:setState(self.settings.enabled and 2 or 1)
    end
    
    if self.debugOption and self.debugOption.setIsChecked then
        self.debugOption:setIsChecked(self.settings.debugMode)
    elseif self.debugOption and self.debugOption.setState then
        self.debugOption:setState(self.settings.debugMode and 2 or 1)
    end
    
    if self.startupOption and self.startupOption.setState then
        self.startupOption:setState(self.settings.startupApp)
    end
    
    if self.notificationsOption and self.notificationsOption.setIsChecked then
        self.notificationsOption:setIsChecked(self.settings.showTabletNotifications)
    elseif self.notificationsOption and self.notificationsOption.setState then
        self.notificationsOption:setState(self.settings.showTabletNotifications and 2 or 1)
    end
    
    if self.soundOption and self.soundOption.setIsChecked then
        self.soundOption:setIsChecked(self.settings.soundEffects)
    elseif self.soundOption and self.soundOption.setState then
        self.soundOption:setState(self.settings.soundEffects and 2 or 1)
    end
    
    print("Farm Tablet: UI refreshed")
end

function SettingsUI:ensureResetButton(settingsFrame)
    if not settingsFrame or not settingsFrame.menuButtonInfo then
        print("ft: ensureResetButton - settingsFrame invalid")
        return
    end
    
    if not self._resetButton then
        self._resetButton = {
            inputAction = InputAction.MENU_EXTRA_1, -- X button
            text = g_i18n:getText("ft_reset") or "Reset Settings",
            callback = function()
                print("ft: Reset button clicked!")
                if g_FarmTablet and g_FarmTablet.settings then
                    g_FarmTablet.settings:resetToDefaults()
                    if g_FarmTablet.settingsUI then
                        g_FarmTablet.settingsUI:refreshUI()
                    end
                end
            end,
            showWhenPaused = true
        }
    end
    
    for _, btn in ipairs(settingsFrame.menuButtonInfo) do
        if btn == self._resetButton then
            print("ft: Reset button already in menuButtonInfo")
            return
        end
    end
    
    table.insert(settingsFrame.menuButtonInfo, self._resetButton)
    settingsFrame:setMenuButtonInfoDirty()
    print("ft: Reset button added to footer! (X key)")
end
