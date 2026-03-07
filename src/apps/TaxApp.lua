-- =========================================================
-- FS25 Farm Tablet -- Tax Mod Integration App
-- =========================================================

local function fmt(amount)
    return g_i18n:formatMoney(amount, 0, true, true) or string.format("$%d", amount)
end

function FarmTabletUI:loadTaxApp()
    self.ui.appTexts = {}
    local content = self.ui.appContentArea
    if not content then return end

    local C    = self.UI_CONSTANTS
    local padX = self:px(15)
    local padY = self:py(12)

    local titleY = content.y + content.height - padY - self:titleH()
    self:drawText("Tax Mod", content.x + padX, titleY, 0.019, RenderText.ALIGN_LEFT, C.TITLE_COLOR)
    self:drawDivider(titleY - self:py(4))

    local inst = g_TaxManager

    if not inst then
        local y = titleY - 0.040
        self:drawText("Tax Mod is not installed.", content.x + padX, y, 0.015,
            RenderText.ALIGN_LEFT, C.NEGATIVE_COLOR)
        y = y - 0.024
        self:drawText("Install FS25_TaxMod to use this app.", content.x + padX, y, 0.013,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        return
    end

    local enabled  = inst.settings and inst.settings.enabled or false
    local taxRate  = (inst.settings and inst.settings.taxRate) or "medium"
    local retPct   = (inst.settings and inst.settings.returnPercentage) or 20
    local total    = inst.stats and inst.stats.totalTaxesPaid

    local y = titleY - 0.030
    self:drawSectionHeader("STATUS", y)
    y = y - 0.024

    self:drawRow("Status", enabled and "Enabled" or "Disabled", y,
        C.LABEL_COLOR, enabled and C.POSITIVE_COLOR or C.NEGATIVE_COLOR)
    y = y - 0.022
    self:drawRow("Tax Rate",    taxRate,                     y, C.LABEL_COLOR, C.VALUE_COLOR)
    y = y - 0.022
    self:drawRow("Return %",    tostring(retPct) .. "%",     y, C.LABEL_COLOR, C.VALUE_COLOR)
    y = y - 0.022
    if total then
        self:drawRow("Total Paid", fmt(total), y, C.LABEL_COLOR, C.WARNING_COLOR)
        y = y - 0.022
    end

    -- Toggle buttons
    y = y - 0.018
    local btnW = self:px(110)
    local btnH = self:py(26)

    self.ui.enableTaxButton = self:drawButton(
        "Enable", content.x + padX, y, btnW, btnH,
        enabled and C.BTN_GRAY or C.BTN_GREEN
    )
    self.ui.disableTaxButton = self:drawButton(
        "Disable", content.x + padX + btnW + self:px(10), y, btnW, btnH,
        enabled and C.BTN_RED or C.BTN_GRAY
    )
end
