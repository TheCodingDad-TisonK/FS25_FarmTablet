-- =========================================================
-- FS25 Farm Tablet -- Updates / Changelog App
-- =========================================================

local CHANGELOG = {
    { version = "1.1.0.1", notes = {
        "NPC Favor, Seasonal Crop Stress, Soil Fertilizer integrations",
        "Interactive in-tablet Settings app with toggle buttons",
        "Drawing helper system: drawRow, drawButton, drawSectionHeader",
        "Fixed app-specific overlay leak on app switch",
        "Fixed startup app mapping (now correctly resolves app ID)",
        "Workshop app temporarily disabled (WIP)",
    }},
    { version = "1.1.0.0", notes = {
        "Initial FS25 release",
        "Dashboard, Weather, Digging, Bucket Tracker apps",
        "Pause menu settings integration",
        "Income Mod and Tax Mod integration",
    }},
}

function FarmTabletUI:loadUpdatesApp()
    self.ui.appTexts = {}
    local content = self.ui.appContentArea
    if not content then return end

    local C    = self.UI_CONSTANTS
    local padX = self:px(15)
    local padY = self:py(12)

    local titleY = content.y + content.height - padY - 0.028
    self:drawText("Updates & Changelog", content.x + padX, titleY, 0.019,
        RenderText.ALIGN_LEFT, C.TITLE_COLOR)

    local y = titleY - 0.032

    for _, entry in ipairs(CHANGELOG) do
        if y <= content.y + padY then break end

        -- Version header
        self:drawText("v" .. entry.version, content.x + padX, y, 0.015,
            RenderText.ALIGN_LEFT, C.SECTION_COLOR)
        y = y - 0.022

        for _, note in ipairs(entry.notes) do
            if y <= content.y + padY then break end
            self:drawText("• " .. note, content.x + padX + self:px(8), y, 0.013,
                RenderText.ALIGN_LEFT, C.MUTED_COLOR)
            y = y - 0.019
        end

        y = y - 0.012
    end

    -- Footer
    if y > content.y + padY then
        self:drawText("Full changelog on KingMods.", content.x + padX, content.y + padY + 0.010,
            0.012, RenderText.ALIGN_LEFT, C.MUTED_COLOR)
    end
end
