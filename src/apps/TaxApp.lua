-- =========================================================
-- FS25 Farm Tablet Mod (version 1.1.0.1)
-- =========================================================
-- Tax Mod App - Integration with Tax Mod
-- =========================================================
-- Author: TisonK
-- =========================================================

function FarmTabletUI:loadTaxApp()
    local content = self.ui.appContentArea
    if not content then return end
    
    local padX = self:px(15)
    local padY = self:py(15)
    local titleY = content.y + content.height - padY - 0.03
    
    -- Title
    table.insert(self.ui.appTexts, {
        text = "Tax Mod",
        x = content.x + padX,
        y = titleY,
        size = 0.020,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })
    
    -- Check if Tax Mod is loaded
    local taxInstance = g_TaxManager
    
    if not taxInstance then
        table.insert(self.ui.appTexts, {
            text = "Tax Mod not installed",
            x = content.x + padX,
            y = titleY - 0.035,
            size = 0.016,
            align = RenderText.ALIGN_LEFT,
            color = {1, 0, 0, 1}
        })
        
        table.insert(self.ui.appTexts, {
            text = "Install via mod store",
            x = content.x + padX,
            y = titleY - 0.060,
            size = 0.014,
            align = RenderText.ALIGN_LEFT,
            color = {0.8, 0.8, 0.8, 1}
        })
        return
    end
    
    -- Get Tax Mod status
    local enabled = taxInstance.settings and taxInstance.settings.enabled or false
    local taxRate = taxInstance.settings and taxInstance.settings.taxRate or "medium"
    local returnPercent = taxInstance.settings and taxInstance.settings.returnPercentage or 20
    
    local statusText = enabled and "ENABLED" or "DISABLED"
    local statusColor = enabled and {0, 1, 0, 1} or {1, 0, 0, 1}
    
    -- Display status
    table.insert(self.ui.appTexts, {
        text = "Status: " .. statusText,
        x = content.x + padX,
        y = titleY - 0.035,
        size = 0.016,
        align = RenderText.ALIGN_LEFT,
        color = statusColor
    })
    
    table.insert(self.ui.appTexts, {
        text = "Tax Rate: " .. taxRate,
        x = content.x + padX,
        y = titleY - 0.060,
        size = 0.016,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })
    
    table.insert(self.ui.appTexts, {
        text = "Return: " .. returnPercent .. "%",
        x = content.x + padX,
        y = titleY - 0.085,
        size = 0.016,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })
    
    -- Show total taxes if available
    if taxInstance.stats and taxInstance.stats.totalTaxesPaid then
        local totalTaxes = taxInstance.stats.totalTaxesPaid
        local formattedTaxes = g_i18n:formatMoney(totalTaxes, 0, true, true) or string.format("$%d", totalTaxes)
        
        table.insert(self.ui.appTexts, {
            text = "Total Taxes: " .. formattedTaxes,
            x = content.x + padX,
            y = titleY - 0.110,
            size = 0.014,
            align = RenderText.ALIGN_LEFT,
            color = {0.8, 0.8, 0.8, 1}
        })
    end
    
    -- Control buttons
    local buttonWidth = self:px(100)
    local buttonHeight = self:py(35)
    local buttonY = titleY - 0.160
    
    -- Enable button
    local enableX = content.x + padX
    local enableButton = self:createBlankOverlay(
        enableX,
        buttonY,
        buttonWidth,
        buttonHeight,
        {0.3, 0.6, 0.3, 0.9}
    )
    enableButton:setVisible(true)
    table.insert(self.ui.overlays, enableButton)
    
    self.ui.enableTaxButton = {
        overlay = enableButton,
        x = enableX,
        y = buttonY,
        width = buttonWidth,
        height = buttonHeight
    }
    
    table.insert(self.ui.appTexts, {
        text = "Enable",
        x = enableX + buttonWidth / 2,
        y = buttonY + buttonHeight / 2 - 0.005,
        size = 0.014,
        align = RenderText.ALIGN_CENTER,
        color = {1, 1, 1, 1}
    })
    
    -- Disable button
    local disableX = enableX + buttonWidth + padX
    local disableButton = self:createBlankOverlay(
        disableX,
        buttonY,
        buttonWidth,
        buttonHeight,
        {0.8, 0.3, 0.3, 0.9}
    )
    disableButton:setVisible(true)
    table.insert(self.ui.overlays, disableButton)
    
    self.ui.disableTaxButton = {
        overlay = disableButton,
        x = disableX,
        y = buttonY,
        width = buttonWidth,
        height = buttonHeight
    }
    
    table.insert(self.ui.appTexts, {
        text = "Disable",
        x = disableX + buttonWidth / 2,
        y = buttonY + buttonHeight / 2 - 0.005,
        size = 0.014,
        align = RenderText.ALIGN_CENTER,
        color = {1, 1, 1, 1}
    })
end