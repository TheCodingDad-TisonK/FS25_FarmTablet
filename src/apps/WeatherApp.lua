-- =========================================================
-- FS25 Farm Tablet Mod (version 1.1.0.1)
-- =========================================================
-- Weather App
-- =========================================================
-- Author: TisonK
-- =========================================================

function FarmTabletUI:loadWeatherApp()
    local content = self.ui.appContentArea
    if not content then 
        self:log("No content area in weather app")
        return 
    end

    local padX = self:px(15)
    local padY = self:py(15)
    local titleY = content.y + content.height - padY - 0.03

    -- Title
    table.insert(self.ui.appTexts, {
        text = "Weather Information",
        x = content.x + padX,
        y = titleY,
        size = 0.020,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })

    -- Get weather data
    local weatherData = self:getWeatherInfo()
    local y = titleY - 0.035
    
    if not weatherData then
        table.insert(self.ui.appTexts, {
            text = "Weather data unavailable",
            x = content.x + padX,
            y = y,
            size = 0.016,
            align = RenderText.ALIGN_LEFT,
            color = {1, 0.5, 0, 1}
        })
        return
    end

    -- Display weather info
    local items = {
        {"Current Weather", weatherData.condition or "Unknown"},
        {"Temperature", string.format("%.1f °C", weatherData.temperature or 20)},
        {"Wind Speed", string.format("%.1f km/h", weatherData.windSpeed or 0)},
        {"Humidity", string.format("%.0f%%", weatherData.humidity or 50)},
        {"Rain", weatherData.isRaining and "Yes" or "No"},
        {"Clouds", string.format("%.0f%%", (weatherData.cloudCover or 0) * 100)}
    }

    for i, item in ipairs(items) do
        local yPos = y - ((i - 1) * 0.024)

        table.insert(self.ui.appTexts, {
            text = item[1] .. ":",
            x = content.x + padX,
            y = yPos,
            size = 0.016,
            align = RenderText.ALIGN_LEFT,
            color = self.UI_CONSTANTS.TEXT_COLOR
        })

        table.insert(self.ui.appTexts, {
            text = item[2],
            x = content.x + content.width - padX,
            y = yPos,
            size = 0.016,
            align = RenderText.ALIGN_RIGHT,
            color = {0.4, 0.8, 0.4, 1}
        })
    end
end

function FarmTabletUI:getWeatherInfo()
    if not g_currentMission or not g_currentMission.environment then
        return nil
    end
    
    local env = g_currentMission.environment
    
    -- FS25 weather data access
    local weatherInfo = {
        temperature = env.temperature or 20,
        isRaining = (env.currentRainScale or 0) > 0.05,
        cloudCover = env.cloudUpdater and env.cloudUpdater:getCloudCoverage() or 0,
        windSpeed = env.windSpeed or 0,
        humidity = env.humidity or 50
    }
    
    -- Determine condition
    if weatherInfo.isRaining then
        weatherInfo.condition = "Rainy"
    elseif weatherInfo.cloudCover > 0.7 then
        weatherInfo.condition = "Cloudy"
    else
        weatherInfo.condition = "Clear"
    end
    
    return weatherInfo
end
