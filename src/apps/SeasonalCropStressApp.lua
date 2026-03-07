-- =========================================================
-- FS25 Farm Tablet -- Seasonal Crop Stress Integration App
-- =========================================================

function FarmTabletUI:loadCropStressApp()
    self.ui.appTexts = {}
    local content = self.ui.appContentArea
    if not content then return end

    local C    = self.UI_CONSTANTS
    local padX = self:px(15)
    local padY = self:py(12)

    local titleY = content.y + content.height - padY - self:titleH()
    self:drawText("Crop Stress", content.x + padX, titleY, 0.019, RenderText.ALIGN_LEFT, C.TITLE_COLOR)
    self:drawDivider(titleY - self:py(4))

    local csm = g_currentMission and g_currentMission.cropStressManager

    if not csm then
        local y = titleY - 0.040
        self:drawText("Seasonal Crop Stress mod not detected.", content.x + padX, y, 0.015,
            RenderText.ALIGN_LEFT, C.NEGATIVE_COLOR)
        y = y - 0.024
        self:drawText("Install FS25_SeasonalCropStress to use this app.", content.x + padX, y, 0.013,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        return
    end

    local farmId = self.tabletSystem:getPlayerFarmId()
    local soil   = csm.soilSystem
    local y = titleY - 0.030

    self:drawSectionHeader("SYSTEM", y)
    y = y - 0.022
    self:drawRow("Status", csm.isInitialized and "Active" or "Initializing", y,
        C.LABEL_COLOR, csm.isInitialized and C.POSITIVE_COLOR or C.WARNING_COLOR)
    y = y - 0.022

    -- Field moisture summary
    if soil then
        y = y - 0.010
        self:drawSectionHeader("FIELD MOISTURE  (top 6)", y)
        y = y - 0.022

        local fields = g_currentMission.fieldManager and g_currentMission.fieldManager:getFields()
        local count  = 0

        if fields then
            for _, field in pairs(fields) do
                if count >= 6 then break end
                local fid = field.farmland and field.farmland.id
                if fid then
                    local moisture = soil.fieldMoisture and soil.fieldMoisture[fid]
                    local stress   = soil.fieldStress   and soil.fieldStress[fid]
                    if moisture ~= nil then
                        local mPct = math.floor(moisture * 100)
                        local mColor = mPct >= 60 and C.POSITIVE_COLOR or
                                       mPct >= 30 and C.WARNING_COLOR  or C.NEGATIVE_COLOR

                        local label = "Field " .. tostring(fid)
                        local value = string.format("%d%% moisture", mPct)
                        if stress and stress > 0.1 then
                            value = value .. string.format("  %.0f%% stress", stress * 100)
                        end
                        self:drawRow(label, value, y, C.LABEL_COLOR, mColor)
                        y = y - 0.021
                        count = count + 1
                    end
                end
                if y <= content.y + padY then break end
            end
        end

        if count == 0 then
            self:drawText("No field moisture data yet.", content.x + padX, y, 0.013,
                RenderText.ALIGN_LEFT, C.MUTED_COLOR)
            y = y - 0.020
        end
    end

    -- Consultant alerts
    if csm.consultant and csm.consultant.activeAlerts and #csm.consultant.activeAlerts > 0 then
        y = y - 0.010
        self:drawSectionHeader("ALERTS", y)
        y = y - 0.022
        for i = 1, math.min(3, #csm.consultant.activeAlerts) do
            local alert = csm.consultant.activeAlerts[i]
            self:drawText("• " .. (alert.message or "Unknown alert"), content.x + padX, y, 0.013,
                RenderText.ALIGN_LEFT, C.WARNING_COLOR)
            y = y - 0.019
        end
    end
end
