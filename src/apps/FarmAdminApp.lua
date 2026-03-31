-- =========================================================
-- FarmTablet v2 – Farm Admin App
-- Compact admin controls inspired by Easy Dev Controls:
-- money, time scale, time-of-day skip, vehicle repair/fuel.
-- =========================================================

-- ── Helpers ───────────────────────────────────────────────

local function fa_getFarmId()
    if g_localPlayer and g_localPlayer.farmId then
        return g_localPlayer.farmId
    end
    if g_currentMission and g_currentMission.player
    and g_currentMission.player.farmId then
        return g_currentMission.player.farmId
    end
    return FarmManager.SINGLEPLAYER_FARM_ID
end

local function fa_getBalance()
    if not g_farmManager then return 0 end
    local ok, farm = pcall(function()
        return g_farmManager:getFarmById(fa_getFarmId())
    end)
    return (ok and farm and farm:getBalance()) or 0
end

local function fa_addMoney(amount)
    local farmId = fa_getFarmId()
    pcall(function()
        local farm = g_farmManager:getFarmById(farmId)
        if farm then
            farm:changeBalance(amount, MoneyType.OTHER)
            g_currentMission:addMoneyChange(amount, farmId, MoneyType.OTHER, true)
        end
    end)
end

local function fa_getScale()
    if g_currentMission and g_currentMission.missionInfo then
        return g_currentMission.missionInfo.timeScale or 1
    end
    return 1
end

local function fa_setScale(scale)
    if g_currentMission then
        pcall(function() g_currentMission:setTimeScale(scale) end)
    end
end

local function fa_skipToHour(hour)
    local env = g_currentMission and g_currentMission.environment
    if not env then return end
    local dayTimeMs    = math.floor(hour * 1000 * 60 * 60)
    local daysToAdvance = (dayTimeMs <= (env.dayTime or 0)) and 1 or 0
    pcall(function()
        env:setEnvironmentTime(
            (env.currentMonotonicDay or 0) + daysToAdvance,
            (env.currentDay or 0) + daysToAdvance,
            dayTimeMs,
            env.daysPerPeriod or 1,
            false)
        if env.lighting then env.lighting:setDayTime(dayTimeMs, true) end
        if env.weather  then env.weather.cheatedTime = true end
    end)
end

local function fa_getVehicles()
    if not g_currentMission or not g_currentMission.vehicleSystem then
        return {}
    end
    local farmId = fa_getFarmId()
    local out = {}
    for _, v in ipairs(g_currentMission.vehicleSystem.vehicles or {}) do
        if v.getOwnerFarmId and v:getOwnerFarmId() == farmId then
            table.insert(out, v)
        end
    end
    return out
end

local function fa_repairAll()
    for _, v in ipairs(fa_getVehicles()) do
        if v.spec_wearable then
            pcall(function() v:setDamageAmount(0, true) end)
        end
    end
end

local function fa_fillAllFuel()
    local farmId = fa_getFarmId()
    for _, v in ipairs(fa_getVehicles()) do
        local spec = v.spec_motorized
        if spec and spec.fuelFillUnitIndex and spec.fuelFillType then
            pcall(function()
                v:addFillUnitFillLevel(
                    farmId,
                    spec.fuelFillUnitIndex,
                    math.huge,
                    spec.fuelFillType,
                    ToolType.UNDEFINED)
            end)
        end
        -- AdBlue / DEF
        if spec and spec.adBlueFillUnitIndex and spec.adBlueFillType then
            pcall(function()
                v:addFillUnitFillLevel(
                    farmId,
                    spec.adBlueFillUnitIndex,
                    math.huge,
                    spec.adBlueFillType,
                    ToolType.UNDEFINED)
            end)
        end
    end
end

local function fa_getTimeStr()
    local env = g_currentMission and g_currentMission.environment
    if not env then return "--:--" end
    return string.format("%02d:%02d",
        math.floor(env.currentHour   or 0),
        math.floor(env.currentMinute or 0))
end

local function fa_formatMoney(amount)
    if g_i18n then
        local ok, s = pcall(function()
            return g_i18n:formatMoney(amount, 0, true, true)
        end)
        if ok and s then return s end
    end
    return string.format("$%d", math.floor(amount))
end

-- ── Drawer ────────────────────────────────────────────────

FarmTabletUI:registerDrawer(FT.APP.FARM_ADMIN, function(self)
    local AC = FT.appColor(FT.APP.FARM_ADMIN)

    if self:drawHelpPage("_adminHelp", FT.APP.FARM_ADMIN, "Farm Admin", AC, {
        { title = "MONEY",
          body  = "Adds funds to your farm account.\n" ..
                  "Amounts: +$1K · +$10K · +$100K · +$1M" },
        { title = "TIME SCALE",
          body  = "Sets how fast game time passes.\n" ..
                  "⏸ PAUSE freezes time. Active speed highlighted." },
        { title = "SKIP TO",
          body  = "Jumps the clock to a preset time of day.\n" ..
                  "Advances to tomorrow if time has passed today." },
        { title = "VEHICLES",
          body  = "REPAIR ALL — resets damage on all your vehicles.\n" ..
                  "FILL FUEL  — fills fuel (and AdBlue) to max\n" ..
                  "             on all your motorized vehicles." },
    }) then return end

    local balance  = fa_getBalance()
    local curScale = fa_getScale()
    local vehicles = fa_getVehicles()
    local startY   = self:drawAppHeader("Farm Admin",
        fa_formatMoney(balance))
    local x, cy, cw, _ = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y       = startY + scrollY
    local BTN_H   = FT.py(22)
    local GAP     = FT.py(6)

    -- ── MONEY ─────────────────────────────────────────────
    y = self:drawSection(y, "MONEY")
    y = y - GAP

    local AMOUNTS = {
        {val = 1000,    label = "+$1K"},
        {val = 10000,   label = "+$10K"},
        {val = 100000,  label = "+$100K"},
        {val = 1000000, label = "+$1M"},
    }
    local gap4 = FT.px(3)
    local bw4  = (cw - gap4 * 3) / 4
    for i, am in ipairs(AMOUNTS) do
        local bx  = x + (i - 1) * (bw4 + gap4)
        local btn = self.r:button(bx, y - BTN_H, bw4, BTN_H,
            am.label, FT.C.BTN_PRIMARY, {
            onClick = function() fa_addMoney(am.val) end
        })
        table.insert(self._contentBtns, btn)
    end
    y = y - BTN_H - FT.py(10)

    -- ── TIME SCALE ────────────────────────────────────────
    y = self:drawRule(y - FT.py(4), 0.3)
    y = y - FT.py(6)
    y = self:drawSection(y, "TIME SCALE  ·  now: " .. fa_getTimeStr())
    y = y - GAP

    local FA_SCALES = {
        {val = 0,   label = "⏸"},
        {val = 1,   label = "1×"},
        {val = 3,   label = "3×"},
        {val = 10,  label = "10×"},
        {val = 60,  label = "60×"},
        {val = 120, label = "120×"},
    }
    local N   = #FA_SCALES
    local gap = FT.px(3)
    local bw  = (cw - gap * (N - 1)) / N
    for i, sc in ipairs(FA_SCALES) do
        local bx     = x + (i - 1) * (bw + gap)
        local active = math.abs(curScale - sc.val) < 0.01
        local btn    = self.r:button(bx, y - BTN_H, bw, BTN_H, sc.label,
            active and FT.C.BTN_ACTIVE or FT.C.BTN_NEUTRAL, {
            onClick = function() fa_setScale(sc.val) end
        })
        table.insert(self._contentBtns, btn)
    end
    y = y - BTN_H - FT.py(10)

    -- ── SKIP TO ───────────────────────────────────────────
    y = self:drawRule(y - FT.py(4), 0.3)
    y = y - FT.py(6)
    y = self:drawSection(y, "SKIP TO")
    y = y - GAP

    local TIMES = {
        {h = 6,  label = "6 AM"},
        {h = 12, label = "12 PM"},
        {h = 18, label = "6 PM"},
        {h = 0,  label = "MIDNIGHT"},
    }
    local halfW = (cw - FT.px(4)) / 2
    for i, t in ipairs(TIMES) do
        local col = (i - 1) % 2
        local row = math.ceil(i / 2) - 1
        local bx  = x + col * (halfW + FT.px(4))
        local by  = y - row * (BTN_H + GAP) - BTN_H
        local btn = self.r:button(bx, by, halfW, BTN_H, t.label,
            FT.C.BTN_NEUTRAL, {
            onClick = function() fa_skipToHour(t.h) end
        })
        table.insert(self._contentBtns, btn)
    end
    y = y - math.ceil(#TIMES / 2) * (BTN_H + GAP) + GAP
    y = y - FT.py(4)

    -- ── VEHICLES ──────────────────────────────────────────
    y = self:drawRule(y - FT.py(4), 0.3)
    y = y - FT.py(6)
    y = self:drawSection(y,
        string.format("VEHICLES  ·  %d owned", #vehicles))
    y = y - GAP

    local btnRepair = self.r:button(x, y - BTN_H, halfW, BTN_H,
        "REPAIR ALL", FT.C.BTN_NEUTRAL, {
        onClick = function() fa_repairAll() end
    })
    table.insert(self._contentBtns, btnRepair)

    local btnFuel = self.r:button(x + halfW + FT.px(4), y - BTN_H, halfW, BTN_H,
        "FILL FUEL", FT.C.BTN_NEUTRAL, {
        onClick = function() fa_fillAllFuel() end
    })
    table.insert(self._contentBtns, btnFuel)
    y = y - BTN_H - GAP

    self:setContentHeight(startY - y + scrollY)
    self:drawInfoIcon("_adminHelp", AC)
end)
