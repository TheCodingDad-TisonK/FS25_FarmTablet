-- =========================================================
-- FS25 Farm Tablet -- Weather App
-- =========================================================

function FarmTabletUI:loadWeatherApp()
    self.ui.appTexts = {}
    local content = self.ui.appContentArea
    if not content then return end

    local C    = self.UI_CONSTANTS
    local padX = self:px(15)
    local padY = self:py(12)

    local titleY = content.y + content.height - padY - self:titleH()
    self:drawText("Weather", content.x + padX, titleY, 0.019, RenderText.ALIGN_LEFT, C.TITLE_COLOR)
    self:drawDivider(titleY - self:py(4))

    local w = self:getWeatherInfo()
    if not w then
        self:drawText("Weather data unavailable.", content.x + padX, titleY - 0.038, 0.015,
            RenderText.ALIGN_LEFT, C.WARNING_COLOR)
        return
    end

    local y = titleY - 0.030
    self:drawSectionHeader("CONDITIONS", y)
    y = y - 0.022

    -- Condition with color
    local condColor = C.VALUE_COLOR
    if w.isRaining     then condColor = {0.40, 0.65, 1.00, 1} end
    if w.isStorming    then condColor = {0.80, 0.50, 1.00, 1} end
    if w.isFoggy       then condColor = {0.75, 0.75, 0.80, 1} end
    self:drawRow("Condition",   w.condition,                       y, C.LABEL_COLOR, condColor)
    y = y - 0.022
    self:drawRow("Temperature", string.format("%.1f °C", w.temperature), y, C.LABEL_COLOR, C.VALUE_COLOR)
    y = y - 0.022

    if w.windSpeed and w.windSpeed > 0 then
        self:drawRow("Wind Speed", string.format("%.1f km/h", w.windSpeed), y, C.LABEL_COLOR, C.VALUE_COLOR)
        y = y - 0.022
    end

    self:drawRow("Cloud Cover", string.format("%.0f%%", w.cloudCover * 100), y, C.LABEL_COLOR, C.VALUE_COLOR)
    y = y - 0.022

    if w.humidity then
        self:drawRow("Humidity", string.format("%.0f%%", w.humidity), y, C.LABEL_COLOR, C.VALUE_COLOR)
        y = y - 0.022
    end

    -- Rain
    if w.isRaining then
        self:drawRow("Rain", "Active", y, C.LABEL_COLOR, {0.40, 0.65, 1.00, 1})
        y = y - 0.022
    end

    -- Forecast (if available)
    if w.forecast and #w.forecast > 0 then
        y = y - 0.010
        self:drawSectionHeader("FORECAST", y)
        y = y - 0.022
        for i = 1, math.min(3, #w.forecast) do
            local f = w.forecast[i]
            self:drawRow("Day +" .. i, f.condition or "Unknown", y, C.LABEL_COLOR, C.MUTED_COLOR)
            y = y - 0.020
        end
    end
end

function FarmTabletUI:getWeatherInfo()
    if not g_currentMission or not g_currentMission.environment then
        return nil
    end
    local env = g_currentMission.environment

    local rainScale   = env.currentRainScale or 0
    local cloudCover  = 0
    if env.cloudUpdater and env.cloudUpdater.getCloudCoverage then
        cloudCover = env.cloudUpdater:getCloudCoverage()
    elseif env.cloudCoverage then
        cloudCover = env.cloudCoverage
    end

    local temp = env.temperature or 20

    local w = {
        temperature = temp,
        isRaining   = rainScale > 0.05,
        isStorming  = rainScale > 0.70,
        isFoggy     = (env.fogScale or 0) > 0.3,
        cloudCover  = cloudCover,
        windSpeed   = env.windSpeed or 0,
        humidity    = env.humidity,
        forecast    = env.forecast,
    }

    if w.isStorming    then w.condition = "Stormy"
    elseif w.isRaining then w.condition = "Rainy"
    elseif w.isFoggy   then w.condition = "Foggy"
    elseif cloudCover > 0.70 then w.condition = "Overcast"
    elseif cloudCover > 0.30 then w.condition = "Partly Cloudy"
    else                          w.condition = "Clear"
    end

    return w
end
