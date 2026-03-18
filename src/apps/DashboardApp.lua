-- =========================================================
-- FarmTablet v2 – Dashboard App
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.DASHBOARD, function(self)
    local AC = FT.appColor(FT.APP.DASHBOARD)

    -- Help sub-page
    if self:drawHelpPage("_dashHelp", FT.APP.DASHBOARD, "Dashboard", AC, {
        { title = "CURRENT BALANCE",
          body  = "Your farm's total available money.\n" ..
                  "Green = positive, Red = overdrawn.\n" ..
                  "Loan amount shown top-right if active." },
        { title = "INCOME / EXPENSES / NET P/L",
          body  = "Income: money earned this session.\n" ..
                  "Expenses: money spent this session.\n" ..
                  "Net P/L: profit or loss (income minus expenses)." },
        { title = "ACTIVE FIELDS",
          body  = "Number of fields you own with a crop growing." },
        { title = "VEHICLES",
          body  = "Total vehicles owned by your farm.\n" ..
                  "Open the Workshop app for per-vehicle diagnostics." },
        { title = "SEASON / DAY / TIME",
          body  = "In-game season (requires Seasons mod), day number,\n" ..
                  "and current time of day on a 24-hour clock." },
        { title = "WEATHER",
          body  = "Live condition and temperature.\n" ..
                  "Blue = rain  |  Orange = storm  |  White = clear.\n" ..
                  "Open the Weather app for a full multi-day forecast." },
    }) then return end

    -- Normal page
    local data   = self.system.data
    local farmId = data:getPlayerFarmId()

    local balance  = data:getBalance(farmId)
    local loan     = data:getLoan(farmId)
    local income   = data:getIncome(farmId)
    local expenses = data:getExpenses(farmId)
    local profit   = income - expenses
    local fields   = data:getActiveFieldCount(farmId)
    local vehicles = data:getVehicleCount(farmId)
    local world    = data:getWorldInfo()
    local weather  = data:getWeather()

    local startY = self:drawAppHeader("Dashboard", data:getFarmName(farmId) or "")
    local x, contentY, w, _ = self:contentInner()
    local y = startY

    -- Hero: Balance
    y = y - FT.py(4)
    self.r:appRect(x, y - FT.py(28), w, FT.py(34), FT.C.BG_CARD)
    self.r:appText(x + FT.px(12), y - FT.py(5),
        FT.FONT.TINY, "CURRENT BALANCE", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    local balColor = balance >= 0 and FT.C.POSITIVE or FT.C.NEGATIVE
    self.r:appText(x + FT.px(12), y - FT.py(22),
        FT.FONT.HUGE, data:formatMoney(balance), RenderText.ALIGN_LEFT, balColor)
    if loan > 0 then
        self.r:appText(x + w - FT.px(12), y - FT.py(8),
            FT.FONT.TINY, "LOAN", RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
        self.r:appText(x + w - FT.px(12), y - FT.py(22),
            FT.FONT.SMALL, data:formatMoney(loan), RenderText.ALIGN_RIGHT, FT.C.WARNING)
    end
    y = y - FT.py(36)
    y = self:drawRule(y, 0.4)

    -- Finance
    y = self:drawSection(y, "FINANCES")
    local incColor = income  > 0 and FT.C.POSITIVE or FT.C.TEXT_DIM
    local expColor = expenses > 0 and FT.C.NEGATIVE or FT.C.TEXT_DIM
    local plColor  = profit >= 0 and FT.C.POSITIVE  or FT.C.NEGATIVE
    y = self:drawRow(y, "Income",   data:formatMoney(income),   nil, incColor)
    y = self:drawRow(y, "Expenses", data:formatMoney(expenses), nil, expColor)
    y = self:drawRow(y, "Net P/L",  data:formatMoney(profit),   nil, plColor)
    y = y - FT.py(4)
    y = self:drawRule(y, 0.25)

    -- Farm stats
    y = self:drawSection(y, "FARM")
    y = self:drawRow(y, "Active Fields", tostring(fields))
    y = self:drawRow(y, "Vehicles",      tostring(vehicles))

    -- World
    if world then
        y = y - FT.py(4)
        y = self:drawRule(y, 0.25)
        y = self:drawSection(y, "WORLD")
        local timeStr    = string.format("%02d:%02d", world.hour % 24, world.minute)
        local seasonName = data:getSeasonName(world.season)
        if seasonName then y = self:drawRow(y, "Season", seasonName) end
        y = self:drawRow(y, "Day",  tostring(world.day))
        y = self:drawRow(y, "Time", timeStr)
        if weather then
            local wColor = FT.C.TEXT_ACCENT
            if weather.isStorming             then wColor = FT.C.WEATHER_STORM
            elseif weather.isRaining          then wColor = FT.C.WEATHER_RAIN
            elseif weather.condKey == "clear" then wColor = FT.C.WEATHER_SUN
            end
            y = self:drawRow(y, "Weather",
                string.format("%s  %.0f'C", weather.condition, weather.temperature),
                nil, wColor)
        end
    end

    self:drawInfoIcon("_dashHelp", AC)
end)
