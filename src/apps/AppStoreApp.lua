-- =========================================================
-- FS25 Farm Tablet Mod (version 1.1.0.1)
-- =========================================================
-- App Store App
-- =========================================================
-- Author: TisonK
-- =========================================================

function FarmTabletUI:loadAppStoreApp()
    local content = self.ui.appContentArea
    if not content then return end
    
    local padX = self:px(15)
    local padY = self:py(15)
    local titleY = content.y + content.height - padY - 0.03
    
    -- Title
    table.insert(self.ui.appTexts, {
        text = "App Store",
        x = content.x + padX,
        y = titleY,
        size = 0.020,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })

    local subtitleY = titleY - 0.03
    
    table.insert(self.ui.appTexts, {
        text = "Installed Apps:",
        x = content.x + padX,
        y = subtitleY,
        size = 0.016,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })

    local itemsStartY = subtitleY - 0.025
    local lineHeight = 0.020
    
    for i, app in ipairs(self.tabletSystem.registeredApps) do
        local yPos = itemsStartY - ((i - 1) * lineHeight)
        
        if yPos > content.y + padY then
            local status = app.enabled and "✓" or "✗"
            local statusColor = app.enabled and {0, 1, 0, 1} or {1, 0, 0, 1}

            -- Status icon
            table.insert(self.ui.appTexts, {
                text = status,
                x = content.x + padX,
                y = yPos,
                size = 0.018,
                align = RenderText.ALIGN_LEFT,
                color = statusColor
            })

            -- App name
            table.insert(self.ui.appTexts, {
                text = g_i18n:getText(app.name) or app.name,
                x = content.x + padX + 0.02,
                y = yPos,
                size = 0.016,
                align = RenderText.ALIGN_LEFT,
                color = self.UI_CONSTANTS.TEXT_COLOR
            })

            -- Version
            table.insert(self.ui.appTexts, {
                text = app.version,
                x = content.x + content.width - padX,
                y = yPos,
                size = 0.014,
                align = RenderText.ALIGN_RIGHT,
                color = {0.7, 0.7, 0.7, 1}
            })
        end
    end
end
