-- =========================================================
-- FarmTablet v2 – Time Controls App
-- Set game time scale and skip to a time of day.
-- =========================================================

-- ── Helpers ───────────────────────────────────────────────

local TC_SCALES = {
    {val = 0,   label = "⏸ PAUSE"},
    {val = 1,   label = "1×"},
    {val = 3,   label = "3×"},
    {val = 10,  label = "10×"},
    {val = 60,  label = "60×"},
    {val = 120, label = "120×"},
}

local function tc_getScale()
    if g_currentMission and g_currentMission.missionInfo then
        return g_currentMission.missionInfo.timeScale or 1
    end
    return 1
end

local function tc_setScale(scale)
    if g_currentMission then
        pcall(function() g_currentMission:setTimeScale(scale) end)
    end
end

local function tc_skipToHour(hour)
    local env = g_currentMission and g_currentMission.environment
    if not env then return end
    local dayTimeMs = math.floor(hour * 1000 * 60 * 60)
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

local function tc_getTimeStr()
    local env = g_currentMission and g_currentMission.environment
    if not env then return "--:--" end
    return string.format("%02d:%02d",
        math.floor(env.currentHour   or 0),
        math.floor(env.currentMinute or 0))
end

-- ── Drawer ────────────────────────────────────────────────

FarmTabletUI:registerDrawer(FT.APP.TIME_CONTROLS, function(self)
    local AC = FT.appColor(FT.APP.TIME_CONTROLS)

    if self:drawHelpPage("_timeHelp", FT.APP.TIME_CONTROLS, "Time Controls", AC, {
        { title = "TIME SCALE",
          body  = "Sets how fast in-game time passes.\n" ..
                  "⏸ PAUSE freezes time completely.\n" ..
                  "1× = real-time  ·  60× = fast-forward\n" ..
                  "The active speed is highlighted." },
        { title = "SKIP TO",
          body  = "Jumps the clock to a preset time of day.\n" ..
                  "If that time has already passed today,\n" ..
                  "it advances to tomorrow at that time." },
    }) then return end

    local cur    = tc_getScale()
    local startY = self:drawAppHeader("Time Controls", tc_getTimeStr())
    local x, _, cw, _ = self:contentInner()
    local y     = startY
    local BTN_H = FT.py(22)
    local GAP   = FT.py(6)

    -- ── Time Scale ────────────────────────────────────────
    y = self:drawSection(y, "TIME SCALE")
    y = y - GAP

    local N   = #TC_SCALES
    local gap = FT.px(3)
    local bw  = (cw - gap * (N - 1)) / N
    for i, sc in ipairs(TC_SCALES) do
        local bx = x + (i - 1) * (bw + gap)
        local active = math.abs(cur - sc.val) < 0.01
        local btn = self.r:button(bx, y - BTN_H, bw, BTN_H, sc.label,
            active and FT.C.BTN_ACTIVE or FT.C.BTN_NEUTRAL, {
            onClick = function() tc_setScale(sc.val) end
        })
        table.insert(self._contentBtns, btn)
    end
    y = y - BTN_H - FT.py(10)

    -- ── Skip To ───────────────────────────────────────────
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
            onClick = function() tc_skipToHour(t.h) end
        })
        table.insert(self._contentBtns, btn)
    end

    self:drawInfoIcon("_timeHelp", AC)
end)
