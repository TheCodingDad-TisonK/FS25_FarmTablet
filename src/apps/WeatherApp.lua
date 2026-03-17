-- =========================================================
-- FarmTablet v2 – Weather App  (FIXED)
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.WEATHER, function(self)
    local data = self.system.data
    local w    = data:getWeather()

    local startY = self:drawAppHeader("Weather", "")

    local x, _, cw, _ = self:contentInner()

    if not w then
        self.r:appText(x, startY - FT.py(10), FT.FONT.BODY,
            "Weather data unavailable.",
            RenderText.ALIGN_LEFT, FT.C.WARNING)
        return
    end

    local y = startY

    -- ── Condition hero card ────────────────────────────────
    y = y - FT.py(4)
    local heroH = FT.py(48)
    self.r:appRect(x, y - heroH, cw, heroH, FT.C.BG_CARD)

    local condColor = FT.C.TEXT_ACCENT
    if     w.isStorming             then condColor = FT.C.WEATHER_STORM
    elseif w.isRaining              then condColor = FT.C.WEATHER_RAIN
    elseif w.isFoggy                then condColor = FT.C.WEATHER_FOG
    elseif w.condKey == "clear"     then condColor = FT.C.WEATHER_SUN
    end

    local condLabel = {
        storm    = "[STORM]",
        rain     = "[RAIN]",
        fog      = "[FOG]",
        overcast = "[OVERCAST]",
        cloudy   = "[CLOUDY]",
        clear    = "[CLEAR]",
    }
    local icon = condLabel[w.condKey] or "[?]"

    self.r:appText(x + FT.px(14), y - heroH/2 + FT.py(2),
        0.032, icon, RenderText.ALIGN_LEFT, condColor)

    self.r:appText(x + FT.px(58), y - heroH/2 + FT.py(10),
        FT.FONT.TITLE, w.condition,
        RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)

    self.r:appText(x + FT.px(58), y - heroH/2 - FT.py(6),
        FT.FONT.SMALL, string.format("%.1f C", w.temperature),
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)

    if w.windSpeed and w.windSpeed > 0 then
        self.r:appText(x + cw - FT.px(12), y - heroH/2 + FT.py(6),
            FT.FONT.BODY, string.format("%.0f km/h", w.windSpeed),
            RenderText.ALIGN_RIGHT, FT.C.TEXT_NORMAL)
        self.r:appText(x + cw - FT.px(12), y - heroH/2 - FT.py(8),
            FT.FONT.TINY, "WIND",
            RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
    end

    y = y - heroH - FT.py(8)
    y = self:drawRule(y, 0.35)

    -- ── Detail rows ────────────────────────────────────────
    y = self:drawSection(y, "CONDITIONS")

    y = self:drawRow(y, "Temperature",
        string.format("%.1f C", w.temperature), nil,
        w.temperature < 0 and FT.C.INFO or
        w.temperature > 30 and FT.C.WARNING or FT.C.TEXT_ACCENT)

    -- FIX: cloudCover is 0.0–1.0, so multiply by 100 to get a percentage
    y = self:drawRow(y, "Cloud Cover",
        string.format("%.0f%%", w.cloudCover * 100))

    if w.windSpeed and w.windSpeed > 0 then
        y = self:drawRow(y, "Wind Speed",
            string.format("%.1f km/h", w.windSpeed))
    end

    if w.isRaining then
        local rainLabel = w.isStorming and "Heavy storm" or "Light rain"
        y = self:drawRow(y, "Precipitation", rainLabel, nil, FT.C.WEATHER_RAIN)
    end

    if w.isFoggy then
        y = self:drawRow(y, "Fog", "Present", nil, FT.C.WEATHER_FOG)
    end

    -- ── Forecast ───────────────────────────────────────────
    if w.forecast and #w.forecast > 0 then
        y = y - FT.py(4)
        y = self:drawRule(y, 0.25)
        y = self:drawSection(y, "FORECAST")

        for i = 1, math.min(4, #w.forecast) do
            local f = w.forecast[i]
            if f then
                y = self:drawRow(y,
                    "Day +" .. i,
                    (f.condition or f.weatherType or f.type or "Unknown"),
                    nil, FT.C.TEXT_DIM)
            end
        end
    end
end)
