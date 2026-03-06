-- =========================================================
-- FS25 Farm Tablet -- Settings App (in-tablet interactive settings)
-- =========================================================

function FarmTabletUI:loadSettingsApp()
    self.ui.appTexts = {}
    self.ui.settingsToggleButtons = {}
    local content = self.ui.appContentArea
    if not content then return end

    local C    = self.UI_CONSTANTS
    local padX = self:px(15)
    local padY = self:py(12)
    local s    = self.settings

    local titleY = content.y + content.height - padY - 0.028
    self:drawText("Settings", content.x + padX, titleY, 0.019, RenderText.ALIGN_LEFT, C.TITLE_COLOR)

    local version = "v1.1.0.1"
    self:drawText(version, content.x + content.width - padX, titleY, 0.012,
        RenderText.ALIGN_RIGHT, C.MUTED_COLOR)

    local y = titleY - 0.032
    self:drawSectionHeader("TABLET", y)
    y = y - 0.024

    -- Helper: draw a toggle row with ON/OFF button
    local btnW = self:px(52)
    local btnH = self:py(20)

    local function drawToggle(label, state, key, y_)
        self:drawText(label, content.x + padX, y_ + 0.003, 0.014,
            RenderText.ALIGN_LEFT, C.LABEL_COLOR)

        local bx = content.x + content.width - padX - btnW
        local by = y_ - 0.002
        local btn = self:drawButton(
            state and "ON" or "OFF",
            bx, by, btnW, btnH,
            state and C.BTN_GREEN or C.BTN_RED
        )
        btn.settingKey = key
        btn.currentState = state
        table.insert(self.ui.settingsToggleButtons, btn)
    end

    drawToggle("Tablet Enabled",    s.enabled,                 "enabled",                 y)
    y = y - 0.030
    drawToggle("Notifications",     s.showTabletNotifications, "showTabletNotifications", y)
    y = y - 0.030
    drawToggle("Sound Effects",     s.soundEffects,            "soundEffects",            y)
    y = y - 0.030
    drawToggle("Debug Logging",     s.debugMode,               "debugMode",               y)

    -- Keybind display
    y = y - 0.038
    self:drawSectionHeader("CONTROLS", y)
    y = y - 0.024
    self:drawRow("Open Key",    "[" .. (s.tabletKeybind or "T") .. "]",    y, C.LABEL_COLOR, C.VALUE_COLOR)
    y = y - 0.022
    self:drawText("Change via: TabletKeybind [KEY] in console", content.x + padX,
        y, 0.012, RenderText.ALIGN_LEFT, C.MUTED_COLOR)

    -- Startup app display
    y = y - 0.034
    self:drawSectionHeader("STARTUP", y)
    y = y - 0.024
    self:drawRow("Startup App", s:getStartupAppName(), y, C.LABEL_COLOR, C.VALUE_COLOR)
    y = y - 0.022
    self:drawText("Change via: TabletSetStartupApp 1-4 in console", content.x + padX,
        y, 0.012, RenderText.ALIGN_LEFT, C.MUTED_COLOR)
end

function FarmTabletUI:handleSettingsAppMouseEvent(posX, posY)
    local btns = self.ui.settingsToggleButtons
    if not btns then return false end
    for _, btn in ipairs(btns) do
        if posX >= btn.x and posX <= btn.x + btn.width and
           posY >= btn.y and posY <= btn.y + btn.height then
            -- Toggle the setting
            local key = btn.settingKey
            if key and self.settings[key] ~= nil then
                self.settings[key] = not self.settings[key]
                self.settings:save()
            end
            -- Refresh app
            self:switchApp("settings")
            return true
        end
    end
    return false
end
