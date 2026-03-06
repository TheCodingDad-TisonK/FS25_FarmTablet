-- =========================================================
-- FS25 Farm Tablet Mod (version 1.1.0.1)
-- =========================================================
-- Dashboard App
-- =========================================================
-- Author: TisonK
-- =========================================================

function FarmTabletUI:loadDashboardApp()
    local content = self.ui.appContentArea
    if not content then return end

    local padX = self:px(15)
    local padY = self:py(15)
    local titleY = content.y + content.height - padY - 0.03

    -- Title
    table.insert(self.ui.appTexts, {
        text = "Farm Dashboard",
        x = content.x + padX,
        y = titleY,
        size = 0.020,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })

    local farmId = self.tabletSystem:getPlayerFarmId()
    
    local function formatMoney(amount)
        return g_i18n:formatMoney(amount, 0, true, true) or string.format("€ %s", tostring(amount))
    end

    local items = {
        {label = "Current Balance", value = formatMoney(self.tabletSystem:TotalMoney(farmId))},
        {label = "Total Income", value = formatMoney(self.tabletSystem:TotalIncome(farmId))},
        {label = "Total Expenses", value = formatMoney(self.tabletSystem:TotalExpenses(farmId))},
        {label = "Loaned Money", value = formatMoney(self.tabletSystem:LoanedMoney(farmId))},
        {label = "Active Fields", value = self.tabletSystem:ActiveFields(farmId)},
        {label = "Vehicles", value = self.tabletSystem:VehiclesCount(farmId)}
    }

    local itemsStartY = titleY - 0.035
    local lineHeight = 0.025

    for i = 1, #items do
        local item = items[i]
        local yPos = itemsStartY - (i * lineHeight)

        if yPos > content.y + padY then
            -- Label
            table.insert(self.ui.appTexts, {
                text = item.label .. ":",
                x = content.x + padX,
                y = yPos,
                size = 0.016,
                align = RenderText.ALIGN_LEFT,
                color = self.UI_CONSTANTS.TEXT_COLOR
            })

            -- Value
            table.insert(self.ui.appTexts, {
                text = tostring(item.value),
                x = content.x + content.width - padX,
                y = yPos,
                size = 0.016,
                align = RenderText.ALIGN_RIGHT,
                color = {0.4, 0.8, 0.4, 1}
            })
        end
    end
end