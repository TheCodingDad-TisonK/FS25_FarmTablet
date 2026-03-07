-- =========================================================
-- FS25 Farm Tablet -- Updates / Changelog App
-- =========================================================

local CHANGELOG = {
    { version = "1.1.0.9", notes = {
        "Fixed Animals app crash (Lua 5.1 goto not supported in FS25)",
        "Fixed Workshop app not detecting vehicles (wrong player position reference)",
        "Fixed bullet character warning in Updates app (unsupported font glyph)",
        "Nav bar now uses two rows, supporting up to 16 apps",
    }},
    { version = "1.1.0.8", notes = {
        "Added in-game help section in the pause menu (F1 / Help tab)",
        "Help covers all built-in apps, open key, App Store and console commands",
    }},
    { version = "1.1.0.7", notes = {
        "New app: Workshop — detect nearby vehicles, view diagnostics, open workshop",
        "New app: Field Manager — all owned fields with crop type and growth state",
        "New app: Animals — animal pen food, water, cleanliness with progress bars",
    }},
    { version = "1.1.0.6", notes = {
        "Scale-aware layout helpers: titleH, lineH, smallLineH, sectionGap",
        "Section headers now render with a left accent bar for visual hierarchy",
        "New drawDivider — title underline rendered across all apps",
        "New drawProgressBar — fill level bar in Bucket Tracker app",
        "Content area top accent line for card-style visual framing",
        "Fixed hardcoded version strings in Settings and Updates apps",
    }},
    { version = "1.1.0.5", notes = {
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

    local titleY = content.y + content.height - padY - self:titleH()
    self:drawText("Updates & Changelog", content.x + padX, titleY, 0.019,
        RenderText.ALIGN_LEFT, C.TITLE_COLOR)
    self:drawDivider(titleY - self:py(4))

    local y = titleY - 0.032

    for _, entry in ipairs(CHANGELOG) do
        if y <= content.y + padY then break end

        -- Version header
        self:drawText("v" .. entry.version, content.x + padX, y, 0.015,
            RenderText.ALIGN_LEFT, C.SECTION_COLOR)
        y = y - 0.022

        for _, note in ipairs(entry.notes) do
            if y <= content.y + padY then break end
            self:drawText("-" .. note, content.x + padX + self:px(8), y, 0.013,
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
