-- =========================================================
-- FS25 Farm Tablet -- Soil Fertilizer Integration App
-- =========================================================

function FarmTabletUI:loadSoilFertilizerApp()
    self.ui.appTexts = {}
    local content = self.ui.appContentArea
    if not content then return end

    local C    = self.UI_CONSTANTS
    local padX = self:px(15)
    local padY = self:py(12)

    local titleY = content.y + content.height - padY - 0.028
    self:drawText("Soil Fertilizer", content.x + padX, titleY, 0.019, RenderText.ALIGN_LEFT, C.TITLE_COLOR)

    local sfm = g_soilFertilizerManager
              or (g_currentMission and g_currentMission.soilFertilizerManager)

    if not sfm then
        local y = titleY - 0.040
        self:drawText("Soil Fertilizer mod not detected.", content.x + padX, y, 0.015,
            RenderText.ALIGN_LEFT, C.NEGATIVE_COLOR)
        y = y - 0.024
        self:drawText("Install FS25_SoilFertilizer to use this app.", content.x + padX, y, 0.013,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        return
    end

    local farmId = self.tabletSystem:getPlayerFarmId()
    local y = titleY - 0.030

    self:drawSectionHeader("SYSTEM", y)
    y = y - 0.022

    local isActive = sfm.isInitialized or sfm.isActive or true
    self:drawRow("Status", isActive and "Active" or "Inactive", y,
        C.LABEL_COLOR, isActive and C.POSITIVE_COLOR or C.WARNING_COLOR)
    y = y - 0.022

    -- Try to surface per-field soil nutrient data
    local fields = g_currentMission.fieldManager and g_currentMission.fieldManager:getFields()
    if fields and sfm.fieldNutrients then
        y = y - 0.010
        self:drawSectionHeader("FIELD NUTRIENTS  (top 6)", y)
        y = y - 0.022

        local count = 0
        for _, field in pairs(fields) do
            if count >= 6 then break end
            local fid = field.farmland and field.farmland.id
            if fid then
                local nuts = sfm.fieldNutrients[fid]
                if nuts then
                    local n = math.floor((nuts.nitrogen   or 0) * 100)
                    local p = math.floor((nuts.phosphorus or 0) * 100)
                    local k = math.floor((nuts.potassium  or 0) * 100)

                    local avg = math.floor((n + p + k) / 3)
                    local col = avg >= 60 and C.POSITIVE_COLOR or
                                avg >= 30 and C.WARNING_COLOR  or C.NEGATIVE_COLOR

                    self:drawRow("Field " .. fid,
                        string.format("N%d%%  P%d%%  K%d%%", n, p, k),
                        y, C.LABEL_COLOR, col)
                    y = y - 0.021
                    count = count + 1
                end
            end
            if y <= content.y + padY then break end
        end

        if count == 0 then
            self:drawText("No nutrient data available yet.", content.x + padX, y, 0.013,
                RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        end
    elseif fields then
        -- Manager present but no nutrient table — show generic status
        self:drawText("Nutrient data not yet populated.", content.x + padX, y, 0.013,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        y = y - 0.020
        self:drawText("Apply fertilizer to begin tracking.", content.x + padX, y, 0.013,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
    end
end
