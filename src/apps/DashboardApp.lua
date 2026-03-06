-- =========================================================
-- FS25 Farm Tablet -- Dashboard App
-- =========================================================

local function fmt(amount)
    return g_i18n:formatMoney(amount, 0, true, true) or string.format("$%d", amount)
end

function FarmTabletUI:loadDashboardApp()
    self.ui.appTexts = {}
    local content = self.ui.appContentArea
    if not content then return end

    local C  = self.UI_CONSTANTS
    local padX = self:px(15)
    local padY = self:py(12)
    local sys  = self.tabletSystem
    local farmId = sys:getPlayerFarmId()

    -- Title
    local titleY = content.y + content.height - padY - 0.028
    self:drawText("Farm Dashboard", content.x + padX, titleY, 0.019, RenderText.ALIGN_LEFT, C.TITLE_COLOR)

    -- Farm name (if available)
    local farm = g_farmManager and g_farmManager:getFarmById(farmId)
    local farmName = (farm and farm.name and farm.name ~= "") and farm.name or nil
    if farmName then
        self:drawText(farmName, content.x + content.width - padX, titleY, 0.013,
            RenderText.ALIGN_RIGHT, C.MUTED_COLOR)
    end

    -- Divider
    local y = titleY - 0.028

    -- === Finance ===
    self:drawSectionHeader("FINANCES", y)
    y = y - 0.022

    local balance  = sys:TotalMoney(farmId)
    local loan     = sys:LoanedMoney(farmId)
    local income   = sys:TotalIncome(farmId)
    local expenses = sys:TotalExpenses(farmId)
    local profit   = income - expenses

    self:drawRow("Balance",   fmt(balance),  y,
        C.LABEL_COLOR,
        balance >= 0 and C.POSITIVE_COLOR or C.NEGATIVE_COLOR)
    y = y - 0.022

    if loan > 0 then
        self:drawRow("Loan", fmt(loan), y, C.LABEL_COLOR, C.WARNING_COLOR)
        y = y - 0.022
    end

    self:drawRow("Income",   fmt(income),   y, C.LABEL_COLOR, C.POSITIVE_COLOR)
    y = y - 0.022
    self:drawRow("Expenses", fmt(expenses), y, C.LABEL_COLOR, C.NEGATIVE_COLOR)
    y = y - 0.022
    self:drawRow("Net P/L",  fmt(profit),   y,
        C.LABEL_COLOR,
        profit >= 0 and C.POSITIVE_COLOR or C.NEGATIVE_COLOR)

    -- === Farm ===
    y = y - 0.032
    self:drawSectionHeader("FARM", y)
    y = y - 0.022

    local fields   = sys:ActiveFields(farmId)
    local vehicles = sys:VehiclesCount(farmId)
    self:drawRow("Active Fields", tostring(fields),   y, C.LABEL_COLOR, C.VALUE_COLOR)
    y = y - 0.022
    self:drawRow("Vehicles",      tostring(vehicles), y, C.LABEL_COLOR, C.VALUE_COLOR)

    -- === World ===
    if g_currentMission and g_currentMission.environment then
        local env = g_currentMission.environment
        y = y - 0.032
        self:drawSectionHeader("WORLD", y)
        y = y - 0.022

        local day    = env.currentDay    or 1
        local season = env.currentSeason
        local hour   = math.floor((g_currentMission.time or 0) / 3600000)
        local minute = math.floor(((g_currentMission.time or 0) % 3600000) / 60000)

        local seasonNames = { "Spring", "Summer", "Autumn", "Winter" }
        local seasonStr = season and (seasonNames[season + 1] or "Season " .. season) or "Unknown"

        self:drawRow("Season / Day", seasonStr .. "  Day " .. day, y, C.LABEL_COLOR, C.VALUE_COLOR)
        y = y - 0.022
        self:drawRow("Time", string.format("%02d:%02d", hour % 24, minute), y, C.LABEL_COLOR, C.VALUE_COLOR)
    end
end
