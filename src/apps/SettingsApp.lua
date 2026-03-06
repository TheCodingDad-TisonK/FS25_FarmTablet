-- =========================================================
-- FS25 Farm Tablet Mod (version 1.1.0.1)
-- =========================================================
-- Settings App
-- =========================================================
-- Author: TisonK
-- =========================================================

function FarmTabletUI:loadSettingsApp()
    local content = self.ui.appContentArea
    if not content then return end

    local padX = self:px(15)
    local padY = self:py(15)
    local titleY = content.y + content.height - padY - 0.03

    -- Title
    table.insert(self.ui.appTexts, {
        text = "Tablet Settings",
        x = content.x + padX,
        y = titleY,
        size = 0.020,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })

    -- Instructions
    local startY = titleY - 0.045
    local lineHeight = 0.022

    local lines = {
        {text = "Settings are managed via:", size = 0.016, color = self.UI_CONSTANTS.TEXT_COLOR},
        {text = "1. Pause Menu → Settings", size = 0.014, color = {0.8, 0.8, 0.8, 1}},
        {text = "2. Console commands", size = 0.014, color = {0.8, 0.8, 0.8, 1}},
        {text = "", size = 0.014, color = {0.8, 0.8, 0.8, 1}},
        {text = "Console commands:", size = 0.016, color = self.UI_CONSTANTS.TEXT_COLOR},
        {text = "• Type 'tablet' for help", size = 0.014, color = {0.8, 0.8, 0.8, 1}},
        {text = "• Type 'tabletStatus' for info", size = 0.014, color = {0.8, 0.8, 0.8, 1}}
    }

    for i, line in ipairs(lines) do
        table.insert(self.ui.appTexts, {
            text = line.text,
            x = content.x + padX,
            y = startY - ((i - 1) * lineHeight),
            size = line.size,
            align = RenderText.ALIGN_LEFT,
            color = line.color
        })
    end
end