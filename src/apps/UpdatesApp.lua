-- =========================================================
-- FS25 Farm Tablet Mod (version 1.1.0.1)
-- =========================================================
-- Updates App
-- =========================================================
-- Author: TisonK
-- =========================================================

function FarmTabletUI:loadUpdatesApp()
    local content = self.ui.appContentArea
    if not content then return end
    
    local padX = self:px(15)
    local padY = self:py(15)
    local titleY = content.y + content.height - padY - 0.03
    
    -- Title
    table.insert(self.ui.appTexts, {
        text = "Updates",
        x = content.x + padX,
        y = titleY,
        size = 0.020,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })

    local updates = {
        "Version 1.1.0.1 == [Workshop app temporarily disabled]",
        "version 1.1.0.0 == [Release for FS25]",
        "END OF LIST >> To see lower version updates, please look at changelog on KingMods",
    }

    local itemsStartY = titleY - 0.035
    local lineHeight = 0.022
    
    for i, updateText in ipairs(updates) do
        local yPos = itemsStartY - ((i - 1) * lineHeight)
        
        if yPos > content.y + padY then
            local color = updateText:find("Version") and {0.4, 0.8, 0.4, 1} or 
                         updateText:find("-") and {0.8, 0.8, 0.8, 1} or 
                         self.UI_CONSTANTS.TEXT_COLOR
            
            table.insert(self.ui.appTexts, {
                text = updateText,
                x = content.x + padX,
                y = yPos,
                size = 0.016,
                align = RenderText.ALIGN_LEFT,
                color = color
            })
        end
    end
end