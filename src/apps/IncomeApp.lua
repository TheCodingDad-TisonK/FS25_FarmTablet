-- =========================================================
-- FS25 Farm Tablet -- Income Mod Integration App
-- =========================================================

function FarmTabletUI:loadIncomeApp()
    self.ui.appTexts = {}
    local content = self.ui.appContentArea
    if not content then return end

    local C    = self.UI_CONSTANTS
    local padX = self:px(15)
    local padY = self:py(12)

    local titleY = content.y + content.height - padY - 0.028
    self:drawText("Income Mod", content.x + padX, titleY, 0.019, RenderText.ALIGN_LEFT, C.TITLE_COLOR)

    local inst = g_IncomeManager or _G["Income"]

    if not inst then
        local y = titleY - 0.040
        self:drawText("Income Mod is not installed.", content.x + padX, y, 0.015,
            RenderText.ALIGN_LEFT, C.NEGATIVE_COLOR)
        y = y - 0.024
        self:drawText("Install FS25_IncomeMod to use this app.", content.x + padX, y, 0.013,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        return
    end

    local enabled = inst.settings and inst.settings.enabled or false
    local mode    = (inst.settings and inst.settings.getPayModeName and inst.settings:getPayModeName()) or "Unknown"
    local amount  = (inst.settings and inst.settings.getPaymentAmount and inst.settings:getPaymentAmount()) or 0

    local y = titleY - 0.030
    self:drawSectionHeader("STATUS", y)
    y = y - 0.024

    self:drawRow("Status", enabled and "Enabled" or "Disabled", y,
        C.LABEL_COLOR, enabled and C.POSITIVE_COLOR or C.NEGATIVE_COLOR)
    y = y - 0.022
    self:drawRow("Mode",   mode, y, C.LABEL_COLOR, C.VALUE_COLOR)
    y = y - 0.022
    self:drawRow("Amount", g_i18n:formatMoney(amount, 0, true, true) or tostring(amount),
        y, C.LABEL_COLOR, C.VALUE_COLOR)

    -- Toggle buttons (use drawButton / createAppOverlay for proper cleanup)
    y = y - 0.040
    local btnW = self:px(110)
    local btnH = self:py(26)

    self.ui.enableIncomeButton = self:drawButton(
        "Enable", content.x + padX, y, btnW, btnH,
        enabled and C.BTN_GRAY or C.BTN_GREEN
    )
    self.ui.disableIncomeButton = self:drawButton(
        "Disable", content.x + padX + btnW + self:px(10), y, btnW, btnH,
        enabled and C.BTN_RED or C.BTN_GRAY
    )
end
