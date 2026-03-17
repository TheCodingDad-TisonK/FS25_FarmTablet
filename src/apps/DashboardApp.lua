-- =========================================================
-- FarmTablet v2 – Dashboard App  (FIXED)
-- Rich overview: hero balance, finance, farm stats, world
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.DASHBOARD, function(self)
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

    local startY = self:drawAppHeader("Dashboard",
        data:getFarmName(farmId) or "")

    local x, _, w, _ = self:contentInner()
    local y = startY

    -- ── Hero: Balance ──────────────────────────────────────
    y = y - FT.py(4)
    self.r:appRect(x, y - FT.py(28), w, FT.py(34), FT.C.BG_CARD)
    self.r:appText(x + FT.px(12), y - FT.py(5),
        FT.FONT.TINY, "CURRENT BALANCE",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    local balColor = balance >= 0 and FT.C.POSITIVE or FT.C.NEGATIVE
    self.r:appText(x + FT.px(12), y - FT.py(22),
        FT.FONT.HUGE, data:formatMoney(balance),
        RenderText.ALIGN_LEFT, balColor)
    if loan > 0 then
        self.r:appText(x + w - FT.px(12), y - FT.py(8),
            FT.FONT.TINY, "LOAN",
            RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
        self.r:appText(x + w - FT.px(12), y - FT.py(22),
            FT.FONT.SMALL, data:formatMoney(loan),
            RenderText.ALIGN_RIGHT, FT.C.WARNING)
    end

    y = y - FT.py(36)
    y = self:drawRule(y, 0.4)

    -- ── Finance section ────────────────────────────────────
    y = self:drawSection(y, "FINANCES")

    local incColor = income  > 0 and FT.C.POSITIVE or FT.C.TEXT_DIM
    local expColor = expenses > 0 and FT.C.NEGATIVE or FT.C.TEXT_DIM
    local plColor  = profit >= 0 and FT.C.POSITIVE  or FT.C.NEGATIVE

    y = self:drawRow(y, "Income",   data:formatMoney(income),   nil, incColor)
    y = self:drawRow(y, "Expenses", data:formatMoney(expenses), nil, expColor)
    y = self:drawRow(y, "Net P/L",  data:formatMoney(profit),   nil, plColor)

    y = y - FT.py(4)
    y = self:drawRule(y, 0.25)

    -- ── Farm Stats ─────────────────────────────────────────
    y = self:drawSection(y, "FARM")
    y = self:drawRow(y, "Active Fields", tostring(fields))
    y = self:drawRow(y, "Vehicles",      tostring(vehicles))

    -- ── World ──────────────────────────────────────────────
    if world then
        y = y - FT.py(4)
        y = self:drawRule(y, 0.25)
        y = self:drawSection(y, "WORLD")

        local timeStr = string.format("%02d:%02d", world.hour % 24, world.minute)
        -- FIX: season is nil in base game – only show it when available
        local seasonName = data:getSeasonName(world.season)
        if seasonName then
            y = self:drawRow(y, "Season", seasonName)
        end
        y = self:drawRow(y, "Day",  tostring(world.day))
        y = self:drawRow(y, "Time", timeStr)

        if weather then
            local wColor = FT.C.TEXT_ACCENT
            if weather.isStorming        then wColor = FT.C.WEATHER_STORM
            elseif weather.isRaining     then wColor = FT.C.WEATHER_RAIN
            elseif weather.condKey == "clear" then wColor = FT.C.WEATHER_SUN
            end
            y = self:drawRow(y, "Weather",
                string.format("%s  %.0f'C", weather.condition, weather.temperature),
                nil, wColor)
        end
    end
end)
