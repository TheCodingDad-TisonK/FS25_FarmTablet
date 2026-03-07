-- =========================================================
-- FS25 Farm Tablet -- App Store App
-- =========================================================

function FarmTabletUI:loadAppStoreApp()
    self.ui.appTexts = {}
    local content = self.ui.appContentArea
    if not content then return end

    local C    = self.UI_CONSTANTS
    local padX = self:px(15)
    local padY = self:py(12)

    local titleY = content.y + content.height - padY - self:titleH()
    self:drawText("App Store", content.x + padX, titleY, 0.019, RenderText.ALIGN_LEFT, C.TITLE_COLOR)

    local apps = self.tabletSystem.registeredApps
    self:drawText(tostring(#apps) .. " apps installed",
        content.x + content.width - padX, titleY, 0.013, RenderText.ALIGN_RIGHT, C.MUTED_COLOR)

    self:drawDivider(titleY - self:py(4))
    local y = titleY - 0.030
    self:drawSectionHeader("INSTALLED APPS", y)
    y = y - 0.022

    for _, app in ipairs(apps) do
        if y <= content.y + padY then break end

        local name  = g_i18n:getText(app.name) or app.name
        local label = (app.navLabel and ("[" .. app.navLabel .. "]  ") or "") .. name
        local statusColor = app.enabled and C.VALUE_COLOR or C.MUTED_COLOR
        local statusText  = app.enabled and (app.version or "Built-in") or "Disabled"

        self:drawRow(label, statusText, y, C.LABEL_COLOR, statusColor)
        y = y - 0.021
    end
end
