-- =========================================================
-- FarmTablet v2 – Weather App  (FIXED v2)
-- Correctly reads FS25 weather/environment APIs and renders
-- a clean hero card + detail rows + forecast strip.
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.WEATHER, function(self)
    local data = self.system.data
    local w    = data:getWeather()

    local startY = self:drawAppHeader("Weather", "")
    local x, contentY, cw, _ = self:contentInner()
    local accent = FT.appColor(FT.APP.WEATHER)

    if not w then
        self.r:appText(x, startY - FT.py(10), FT.FONT.BODY,
            "Weather data unavailable.",
            RenderText.ALIGN_LEFT, FT.C.WARNING)
        self.r:appText(x, startY - FT.py(28), FT.FONT.SMALL,
            "Environment not loaded yet.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    local y = startY

    -- ── Condition hero card ────────────────────────────────
    y = y - FT.py(4)
    local heroH = FT.py(52)
    self.r:appRect(x, y - heroH, cw, heroH, FT.C.BG_CARD)

    -- Colored left accent stripe based on condition
    local condColor = accent  -- sky blue default
    if     w.isStorming             then condColor = FT.C.WEATHER_STORM
    elseif w.isRaining              then condColor = FT.C.WEATHER_RAIN
    elseif w.isFoggy                then condColor = FT.C.WEATHER_FOG
    elseif w.condKey == "clear"     then condColor = FT.C.WEATHER_SUN
    elseif w.condKey == "overcast"  then condColor = {0.55, 0.57, 0.65, 1.00}
    end

    self.r:appRect(x, y - heroH, FT.px(4), heroH, condColor)

    -- Condition icon text
    local condLabel = {
        storm    = "[!!]",
        rain     = "[~~]",
        fog      = "[..]",
        overcast = "[##]",
        cloudy   = "[~#]",
        clear    = "[**]",
    }
    local icon = condLabel[w.condKey] or "[?]"

    self.r:appText(x + FT.px(14), y - heroH/2 + FT.py(4),
        0.028, icon, RenderText.ALIGN_LEFT, condColor)

    -- Condition label
    self.r:appText(x + FT.px(62), y - heroH/2 + FT.py(12),
        FT.FONT.TITLE, w.condition,
        RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)

    -- Temperature (large)
    local tempStr
    if w.temperature ~= nil then
        tempStr = string.format("%.1f C", w.temperature)
    else
        tempStr = "-- C"
    end
    self.r:appText(x + FT.px(62), y - heroH/2 - FT.py(4),
        FT.FONT.BODY, tempStr,
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)

    -- Wind (right side of hero)
    if w.windSpeed and w.windSpeed > 0 then
        self.r:appText(x + cw - FT.px(10), y - heroH/2 + FT.py(10),
            FT.FONT.BODY, string.format("%.0f km/h", w.windSpeed),
            RenderText.ALIGN_RIGHT, FT.C.TEXT_NORMAL)
        self.r:appText(x + cw - FT.px(10), y - heroH/2 - FT.py(6),
            FT.FONT.TINY, "WIND",
            RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
        if w.windDir and w.windDir ~= "" then
            self.r:appText(x + cw - FT.px(10), y - heroH/2 - FT.py(16),
                FT.FONT.TINY, w.windDir,
                RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
        end
    end

    y = y - heroH - FT.py(6)
    y = self:drawRule(y, 0.35)

    -- ── Detail rows ────────────────────────────────────────
    y = self:drawSection(y, "CONDITIONS")

    -- Temperature with feel category
    if w.temperature ~= nil then
        local tempColor = w.temperature < 0  and FT.C.INFO
                       or w.temperature > 32 and FT.C.NEGATIVE
                       or w.temperature > 25 and FT.C.WARNING
                       or FT.C.TEXT_ACCENT
        local feelStr = w.temperature < 0  and "Freezing"
                     or w.temperature < 8  and "Cold"
                     or w.temperature < 16 and "Cool"
                     or w.temperature < 24 and "Mild"
                     or w.temperature < 32 and "Warm"
                     or "Hot"
        y = self:drawRow(y, "Temperature",
            string.format("%.1f C  (%s)", w.temperature, feelStr),
            nil, tempColor)
    end

    -- Cloud cover (0.0–1.0 → display as %)
    if w.cloudCover ~= nil then
        local cloudPct = math.floor(w.cloudCover * 100)
        local cloudStr = cloudPct < 20  and "Clear"
                      or cloudPct < 40  and "Partly Cloudy"
                      or cloudPct < 70  and "Mostly Cloudy"
                      or "Overcast"
        y = self:drawRow(y, "Cloud Cover",
            string.format("%d%%  (%s)", cloudPct, cloudStr))
    end

    -- Humidity (FS25 exposes this via environment.weather sometimes)
    if w.humidity ~= nil then
        y = self:drawRow(y, "Humidity",
            string.format("%.0f%%", w.humidity * 100))
    end

    -- Wind
    if w.windSpeed and w.windSpeed > 0 then
        local windStr = string.format("%.1f km/h", w.windSpeed)
        if w.windDir and w.windDir ~= "" then
            windStr = windStr .. "  " .. w.windDir
        end
        y = self:drawRow(y, "Wind Speed", windStr)
    end

    -- Precipitation
    if w.isStorming then
        y = self:drawRow(y, "Precipitation", "Heavy Storm", nil, FT.C.WEATHER_STORM)
        if w.rainScale then
            y = y + FT.py(FT.SP.ROW) - FT.py(8)
            y = self:drawBar(y, math.floor(w.rainScale * 100), 100, FT.C.WEATHER_STORM)
        end
    elseif w.isRaining then
        local intensity = w.rainScale and w.rainScale > 0.4 and "Moderate" or "Light"
        y = self:drawRow(y, "Precipitation", intensity .. " Rain", nil, FT.C.WEATHER_RAIN)
        if w.rainScale then
            y = y + FT.py(FT.SP.ROW) - FT.py(8)
            y = self:drawBar(y, math.floor(w.rainScale * 100), 100, FT.C.WEATHER_RAIN)
        end
    end

    if w.isFoggy then
        y = self:drawRow(y, "Fog", "Present", nil, FT.C.WEATHER_FOG)
    end

    -- ── Forecast strip ─────────────────────────────────────
    if w.forecast and #w.forecast > 0 then
        y = y - FT.py(4)
        y = self:drawRule(y, 0.25)
        y = self:drawSection(y, "FORECAST")

        for i = 1, math.min(5, #w.forecast) do
            local f = w.forecast[i]
            if f and y > contentY + FT.py(8) then
                -- Try every known field name across FS25 versions
                local cond = f.weatherType or f.condition or f.type
                           or f.conditionType or f.name or "Unknown"

                -- Normalise enum values to readable strings
                local condMap = {
                    [0] = "Clear", [1] = "Cloudy", [2] = "Rain",
                    [3] = "Storm", [4] = "Fog",    [5] = "Snow",
                    ["SUN"]     = "Clear",  ["CLOUDY"] = "Cloudy",
                    ["RAIN"]    = "Rain",   ["STORM"]  = "Storm",
                    ["FOG"]     = "Fog",    ["SNOW"]   = "Snow",
                }
                if type(cond) == "number" or condMap[cond] then
                    cond = condMap[cond] or tostring(cond)
                end

                local tempF = nil
                if f.maxTemperature ~= nil then
                    tempF = string.format("%.0f C", f.maxTemperature)
                elseif f.temperature ~= nil then
                    tempF = string.format("%.0f C", f.temperature)
                end

                y = self:drawRow(y,
                    "Day +" .. i,
                    tempF and (cond .. "  " .. tempF) or cond,
                    nil, FT.C.TEXT_DIM)
            end
        end
    end
end)
