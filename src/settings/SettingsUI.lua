-- =========================================================
-- FarmTablet v2 – SettingsUI
-- Injects Farm Tablet options into the FS25 pause-menu
-- settings page (InGameMenuSettingsFrame / generalSettingsLayout).
-- Also adds a reset button to the frame footer.
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

local function getTextSafe(key)
    local text = g_i18n:getText(key)
    if text == nil or text == "" then return key end
    return text
end

function SettingsUI:inject()
    if self.injected then return end

    local ok, err = pcall(function()
        self:_doInject()
    end)
    if not ok then
        Logging.error("ft: Settings injection failed: " .. tostring(err))
    end
end

function SettingsUI:_doInject()
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

    local section = UIHelper.createSection(layout, "ft_ui_section")
    if not section then
        Logging.error("ft: Failed to create settings section!")
        return
    end

    -- Enabled option
    local enabledOpt = UIHelper.createBinaryOption(
        layout,
        "ft_ui_enabled",
        "ft_ui_enabled",
        self.settings.enabled,
        function(val)
            self.settings.enabled = val
            self.settings:save()
            Logging.info("Farm Tablet: " .. (val and "Enabled" or "Disabled"))
        end
    )
    
    -- Debug mode option
    local debugOpt = UIHelper.createBinaryOption(
        layout,
        "ft_ui_debug",
        "ft_ui_debug",
        self.settings.debugMode,
        function(val)
            self.settings.debugMode = val
            self.settings:save()
            Logging.info("Farm Tablet: Debug mode " .. (val and "enabled" or "disabled"))
        end
    )
    
    -- Startup app option — UIHelper.createMultiOption uses 1-based numeric indices;
    -- Settings.startupApp is now a string ID. We map between them here.
    local startupIdMap = { "dashboard", "app_store", "weather", "digging" }
    local startupIdxMap = {}
    for i, id in ipairs(startupIdMap) do startupIdxMap[id] = i end

    local startupOptions = {
        getTextSafe("ft_ui_startupapp_1"),
        getTextSafe("ft_ui_startupapp_2"),
        getTextSafe("ft_ui_startupapp_3"),
        getTextSafe("ft_ui_startupapp_4")
    }

    local startupState = startupIdxMap[self.settings.startupApp] or 1

    local startupOpt = UIHelper.createMultiOption(
        layout,
        "ft_ui_startupapp",
        "ft_ui_startupapp",
        startupOptions,
        startupState,
        function(val)
            -- val is the 1-based numeric index chosen by the UI element
            self.settings.startupApp = startupIdMap[val] or "dashboard"
            self.settings:save()
            Logging.info("Farm Tablet: Startup app set to " .. self.settings:getStartupAppName())
        end
    )
    
    -- Notifications option
    local notificationsOpt = UIHelper.createBinaryOption(
        layout,
        "ft_ui_notifications",
        "ft_ui_notifications",
        self.settings.showTabletNotifications,
        function(val)
            self.settings.showTabletNotifications = val
            self.settings:save()
            Logging.info("Farm Tablet: Notifications " .. (val and "enabled" or "disabled"))
        end
    )
    
    -- Sound effects option
    local soundOpt = UIHelper.createBinaryOption(
        layout,
        "ft_ui_soundeffects",
        "ft_ui_soundeffects",
        self.settings.soundEffects,
        function(val)
            self.settings.soundEffects = val
            self.settings:save()
            Logging.info("Farm Tablet: Sound effects " .. (val and "enabled" or "disabled"))
        end
    )
    
    self.enabledOption = enabledOpt
    self.debugOption = debugOpt
    self.startupOption = startupOpt
    self.notificationsOption = notificationsOpt
    self.soundOption = soundOpt
    
    self.injected = true
    layout:invalidateLayout()
    Logging.info("Farm Tablet: Settings UI injected successfully")
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
        -- Map string app ID back to 1-based numeric index for the UI element
        local startupIdxMap = { dashboard=1, app_store=2, weather=3, digging=4 }
        local idx = startupIdxMap[self.settings.startupApp] or 1
        self.startupOption:setState(idx)
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
    
    Logging.info("Farm Tablet: UI refreshed")
end

function SettingsUI:ensureResetButton(settingsFrame)
    if not settingsFrame or not settingsFrame.menuButtonInfo then
        Logging.warning("ft: ensureResetButton - settingsFrame invalid")
        return
    end
    
    if not self._resetButton then
        self._resetButton = {
            inputAction = InputAction.MENU_EXTRA_1, -- X button
            text = g_i18n:getText("ft_ui_reset") or "Reset Settings",
            callback = function()
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
        if btn == self._resetButton then return end
    end

    table.insert(settingsFrame.menuButtonInfo, self._resetButton)
    settingsFrame:setMenuButtonInfoDirty()
    Logging.info("ft: Reset button added to footer")
end