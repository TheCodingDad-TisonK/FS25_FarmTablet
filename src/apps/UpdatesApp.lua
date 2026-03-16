-- =========================================================
-- FarmTablet v2 – Updates / Changelog App
-- =========================================================

local CHANGELOG = {
    {
        version = "2.0.0",
        date    = "2025",
        changes = {
            "Complete V2 overhaul — new sidebar layout",
            "FT_Renderer: centralized drawing API",
            "FT_DataProvider: cached game data queries",
            "AppRegistry: dynamic app registration system",
            "EventBus: decoupled pub/sub communication",
            "All apps rewritten with new drawer pattern",
            "Improved progress bars with glow effects",
            "Clock + farm name in persistent topbar",
            "Hero card for balance on Dashboard",
            "Weather hero card with condition icon",
            "Field list with phase badges + row highlights",
            "Animal pens with per-metric color bars",
            "Workshop: vehicle selection with diagnostics",
            "Bucket Tracker: summary stat cards",
        },
    },
    {
        version = "1.1.2",
        date    = "2024",
        changes = {
            "Added Soil Fertilizer integration",
            "Added Seasonal Crop Stress integration",
            "Added NPC Favor integration",
            "Fixed nav button overflow on small screens",
        },
    },
    {
        version = "1.1.1",
        date    = "2024",
        changes = {
            "Tax Mod integration app",
            "Income Mod integration app",
            "Bucket Tracker app introduced",
            "Scale fixes for ultrawide monitors",
        },
    },
    {
        version = "1.0.0",
        date    = "2024",
        changes = {
            "Initial release",
            "Dashboard, Weather, Fields, Animals, Workshop",
            "Settings integration in pause menu",
            "Console commands for power users",
        },
    },
}

FarmTabletUI:registerDrawer(FT.APP.UPDATES, function(self)
    local startY = self:drawAppHeader("Updates", "Changelog")

    local x, contentY, cw, _ = self:contentInner()
    local y = startY
    local minY = contentY + FT.py(8)

    for _, entry in ipairs(CHANGELOG) do
        if y < minY then break end

        -- Version header
        self.r:appRect(x - FT.px(4), y - FT.py(2),
            cw + FT.px(8), FT.py(18), FT.C.BG_CARD)
        self.r:appText(x + FT.px(6), y + FT.py(4),
            FT.FONT.BODY, "v" .. entry.version,
            RenderText.ALIGN_LEFT, FT.C.BRAND)
        self.r:appText(x + cw - FT.px(4), y + FT.py(4),
            FT.FONT.TINY, entry.date,
            RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)

        y = y - FT.py(22)

        for _, change in ipairs(entry.changes) do
            if y < minY then break end

            -- Bullet point
            self.r:appRect(x + FT.px(6), y + FT.py(5),
                FT.px(4), FT.px(4), FT.C.BRAND_DIM)

            local txt = change
            if #txt > 46 then txt = txt:sub(1,44) .. "…" end
            self.r:appText(x + FT.px(16), y, FT.FONT.SMALL,
                txt, RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)

            y = y - FT.py(16)
        end

        y = y - FT.py(6)
    end
end)
