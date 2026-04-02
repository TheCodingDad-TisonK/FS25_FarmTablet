-- =========================================================
-- FarmTablet v2 – Dashboard App
-- Customisable farm overview. Players toggle individual
-- widgets on/off via the EDIT picker sub-view.
-- State is persisted to settings.dashWidgets (comma-string).
-- =========================================================

local _dashView = "home"   -- "home" | "customize"

-- ── Widget registry ───────────────────────────────────────
-- Defines every possible widget, its display label, and the
-- section it belongs to. Render order follows this table.
local WIDGET_DEFS = {
    { id = "balance",   label = "Current Balance",  section = "FINANCES" },
    { id = "loan",      label = "Loan Amount",       section = "FINANCES" },
    { id = "income",    label = "Income",             section = "FINANCES" },
    { id = "expenses",  label = "Expenses",           section = "FINANCES" },
    { id = "net_pl",    label = "Net P/L",            section = "FINANCES" },
    { id = "fields",    label = "Active Fields",      section = "FARM"     },
    { id = "vehicles",  label = "Vehicles",           section = "FARM"     },
    { id = "contracts", label = "Active Contracts",   section = "FARM"     },
    { id = "season",    label = "Season",             section = "WORLD"    },
    { id = "day",       label = "Day",                section = "WORLD"    },
    { id = "time",      label = "Time",               section = "WORLD"    },
    { id = "weather",   label = "Weather",            section = "WORLD"    },
}

-- Default widget set (contracts off — it's a separate app)
local DEFAULT_WIDGETS =
    "balance,loan,income,expenses,net_pl,fields,vehicles,season,day,time,weather"

-- Build a set-table from the comma-separated widget string
local function parseWidgets(str)
    local t = {}
    for id in (str or ""):gmatch("[^,]+") do t[id] = true end
    return t
end

-- Rebuild the comma-string from an enabled set, preserving canonical order
local function buildWidgetStr(enabledMap)
    local parts = {}
    for _, def in ipairs(WIDGET_DEFS) do
        if enabledMap[def.id] then parts[#parts+1] = def.id end
    end
    return table.concat(parts, ",")
end

-- Toggle one widget and persist immediately
local function toggleWidget(settings, widgetId)
    local enabled = parseWidgets(settings.dashWidgets or DEFAULT_WIDGETS)
    if enabled[widgetId] then enabled[widgetId] = nil
    else                       enabled[widgetId] = true
    end
    settings.dashWidgets = buildWidgetStr(enabled)
    settings:save()
end

-- ── App Drawer ────────────────────────────────────────────

FarmTabletUI:registerDrawer(FT.APP.DASHBOARD, function(self)
    local AC       = FT.appColor(FT.APP.DASHBOARD)
    local settings = self.system.settings

    if self:drawHelpPage("_dashHelp", FT.APP.DASHBOARD, "Dashboard", AC, {
        { title = "CURRENT BALANCE",
          body  = "Your farm's total available money.\n" ..
                  "Green = positive, Red = overdrawn.\n" ..
                  "Loan amount shown alongside balance if active." },
        { title = "INCOME / EXPENSES / NET P/L",
          body  = "Tracked from the current session (since load).\n" ..
                  "Income: money earned. Expenses: money spent.\n" ..
                  "Net P/L: income minus expenses." },
        { title = "ACTIVE FIELDS / VEHICLES",
          body  = "Fields: land you own with a crop growing.\n" ..
                  "Vehicles: motorised vehicles owned by your farm." },
        { title = "ACTIVE CONTRACTS",
          body  = "Count of accepted contracts currently in progress.\n" ..
                  "Open the Contracts app for details and deadlines." },
        { title = "SEASON / DAY / TIME / WEATHER",
          body  = "Season requires the Seasons mod — blank in base game.\n" ..
                  "Day and time show the in-game clock (24h)." },
        { title = "CUSTOMISING WIDGETS",
          body  = "Tap the small EDIT button (top-right of the dashboard)\n" ..
                  "to show or hide individual data rows.\n" ..
                  "Changes are saved automatically." },
    }) then return end

    if _dashView == "customize" then
        _dashDrawCustomize(self, settings, AC)
    else
        _dashDrawHome(self, settings, AC)
    end
end)

-- ── HOME VIEW ─────────────────────────────────────────────

function _dashDrawHome(self, settings, AC)
    local data    = self.system.data
    local farmId  = data:getPlayerFarmId()
    local enabled = parseWidgets(settings.dashWidgets or DEFAULT_WIDGETS)

    -- Pull all data up front (cached by DataProvider)
    local balance  = data:getBalance(farmId)
    local loan     = data:getLoan(farmId)
    local income   = data:getIncome(farmId)
    local expenses = data:getExpenses(farmId)
    local profit   = income - expenses
    local fields   = data:getActiveFieldCount(farmId)
    local vehicles = data:getVehicleCount(farmId)
    local world    = data:getWorldInfo()
    local weather  = data:getWeather()

    -- Active contracts count (lightweight — no full card render)
    local contractCount = 0
    if enabled["contracts"] and g_missionManager then
        local ok, missions = pcall(function()
            return g_missionManager:getMissionsByFarmId(farmId)
        end)
        if ok and missions then
            for _, m in ipairs(missions) do
                if m:getIsInProgress() then contractCount = contractCount + 1 end
            end
        end
    end

    local startY = self:drawAppHeader("Dashboard", data:getFarmName(farmId) or "")
    local x, contentY, w, _ = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y = startY + scrollY

    -- EDIT button — subtle, top-right corner
    local editBW = FT.px(32)
    local editBH = FT.py(14)
    local editBtn = self.r:button(
        x + w - editBW, y - FT.py(1), editBW, editBH,
        "EDIT", {0.18, 0.20, 0.26, 0.65}, {
        onClick = function()
            _dashView = "customize"
            self:switchApp(FT.APP.DASHBOARD)
        end
    })
    table.insert(self._contentBtns, editBtn)
    y = y - FT.py(18)

    -- Empty-state guard
    local anyOn = false
    for _, def in ipairs(WIDGET_DEFS) do
        if enabled[def.id] then anyOn = true; break end
    end
    if not anyOn then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Nothing pinned.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, y - FT.py(28), FT.FONT.SMALL,
            "Tap EDIT to add widgets.",
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        return
    end

    -- ── Balance hero ──────────────────────────────────────
    if enabled["balance"] then
        self.r:appRect(x, y - FT.py(28), w, FT.py(34), FT.C.BG_CARD)
        self.r:appText(x + FT.px(12), y - FT.py(5),
            FT.FONT.TINY, "CURRENT BALANCE",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        local balColor = balance >= 0 and FT.C.POSITIVE or FT.C.NEGATIVE
        self.r:appText(x + FT.px(12), y - FT.py(22),
            FT.FONT.HUGE, data:formatMoney(balance),
            RenderText.ALIGN_LEFT, balColor)
        if enabled["loan"] and loan > 0 then
            self.r:appText(x + w - FT.px(12), y - FT.py(8),
                FT.FONT.TINY, "LOAN",
                RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
            self.r:appText(x + w - FT.px(12), y - FT.py(22),
                FT.FONT.SMALL, data:formatMoney(loan),
                RenderText.ALIGN_RIGHT, FT.C.WARNING)
        end
        y = y - FT.py(36)
        y = self:drawRule(y, 0.4)
    end

    -- ── FINANCES section ──────────────────────────────────
    local hasFinance = enabled["income"] or enabled["expenses"] or enabled["net_pl"]
    if hasFinance then
        y = self:drawSection(y, "FINANCES")
        if enabled["income"] then
            local c = income  > 0 and FT.C.POSITIVE or FT.C.TEXT_DIM
            y = self:drawRow(y, "Income",   data:formatMoney(income),   nil, c)
        end
        if enabled["expenses"] then
            local c = expenses > 0 and FT.C.NEGATIVE or FT.C.TEXT_DIM
            y = self:drawRow(y, "Expenses", data:formatMoney(expenses), nil, c)
        end
        if enabled["net_pl"] then
            local c = profit >= 0 and FT.C.POSITIVE or FT.C.NEGATIVE
            y = self:drawRow(y, "Net P/L",  data:formatMoney(profit),   nil, c)
        end
        y = y - FT.py(4)
        y = self:drawRule(y, 0.25)
    end

    -- ── FARM section ──────────────────────────────────────
    local hasFarm = enabled["fields"] or enabled["vehicles"] or enabled["contracts"]
    if hasFarm then
        y = self:drawSection(y, "FARM")
        if enabled["fields"] then
            y = self:drawRow(y, "Active Fields", tostring(fields))
        end
        if enabled["vehicles"] then
            y = self:drawRow(y, "Vehicles", tostring(vehicles))
        end
        if enabled["contracts"] then
            local cStr   = contractCount > 0 and tostring(contractCount) or "none"
            local cColor = contractCount > 0 and FT.C.TEXT_ACCENT or FT.C.TEXT_DIM
            y = self:drawRow(y, "Active Contracts", cStr, nil, cColor)
        end
        y = y - FT.py(4)
        y = self:drawRule(y, 0.25)
    end

    -- ── WORLD section ─────────────────────────────────────
    local hasWorld = enabled["season"] or enabled["day"] or enabled["time"] or enabled["weather"]
    if world and hasWorld then
        y = self:drawSection(y, "WORLD")
        local timeStr    = string.format("%02d:%02d", world.hour % 24, world.minute)
        local seasonName = data:getSeasonName(world.season)
        if enabled["season"] and seasonName then
            y = self:drawRow(y, "Season", seasonName)
        end
        if enabled["day"] then
            y = self:drawRow(y, "Day",  tostring(world.day))
        end
        if enabled["time"] then
            y = self:drawRow(y, "Time", timeStr)
        end
        if enabled["weather"] and weather then
            local wColor = FT.C.TEXT_ACCENT
            if     weather.isStorming            then wColor = FT.C.WEATHER_STORM
            elseif weather.isRaining             then wColor = FT.C.WEATHER_RAIN
            elseif weather.condKey == "clear"    then wColor = FT.C.WEATHER_SUN
            end
            y = self:drawRow(y, "Weather",
                string.format("%s  %.0f'C", weather.condition, weather.temperature),
                nil, wColor)
        end
    end

    self:setContentHeight(startY - y + scrollY)
    self:drawInfoIcon("_dashHelp", AC)
    self:drawScrollBar()
end

-- ── CUSTOMIZE VIEW ────────────────────────────────────────

function _dashDrawCustomize(self, settings, AC)
    local enabled = parseWidgets(settings.dashWidgets or DEFAULT_WIDGETS)

    local startY = self:drawAppHeader("Dashboard", "Customize Widgets")
    local x, contentY, cw, _ = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y = startY + scrollY - FT.py(2)

    -- DONE button (top-right)
    local doneBW = FT.px(48)
    local doneBH = FT.py(20)
    local doneBtn = self.r:button(x + cw - doneBW, y, doneBW, doneBH,
        "DONE", FT.C.BTN_PRIMARY, {
        onClick = function()
            _dashView = "home"
            self:switchApp(FT.APP.DASHBOARD)
        end
    })
    table.insert(self._contentBtns, doneBtn)

    self.r:appText(x, y + FT.py(4), FT.FONT.TINY,
        "Tap ON/OFF to show or hide each widget.",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - FT.py(26)

    -- Widget rows, grouped by section
    local lastSection = ""
    local rowH = FT.py(22)
    local togW = FT.px(34)
    local togH = FT.py(16)

    for _, def in ipairs(WIDGET_DEFS) do
        -- Section header on group change
        if def.section ~= lastSection then
            if lastSection ~= "" then y = y - FT.py(4) end
            self.r:appText(x, y, FT.FONT.TINY, def.section,
                RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            y = y - FT.py(16)
            lastSection = def.section
        end

        local isOn     = enabled[def.id] == true
        local labelClr = isOn and FT.C.TEXT_NORMAL or FT.C.TEXT_DIM
        local togColor = isOn and FT.C.BTN_PRIMARY  or FT.C.BTN_NEUTRAL
        local togLabel = isOn and "ON"              or "OFF"

        -- Row background
        self.r:appRect(x - FT.px(4), y - FT.py(4), cw + FT.px(8), rowH,
            {0.08, 0.10, 0.14, 0.45})

        -- Widget label
        self.r:appText(x + FT.px(8), y, FT.FONT.BODY, def.label,
            RenderText.ALIGN_LEFT, labelClr)

        -- Toggle button
        local defId  = def.id  -- capture for closure
        local togBtn = self.r:button(x + cw - togW, y - FT.py(1), togW, togH,
            togLabel, togColor, {
            onClick = function()
                toggleWidget(settings, defId)
                self:switchApp(FT.APP.DASHBOARD)
            end
        })
        table.insert(self._contentBtns, togBtn)

        y = y - rowH - FT.py(2)
    end

    y = y - FT.py(8)
    self:setContentHeight(startY - y + scrollY)
    self:drawScrollBar()
end
