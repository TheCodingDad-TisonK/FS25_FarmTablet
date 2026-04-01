-- =========================================================
-- FarmTablet v2 – Updates / Changelog App
-- =========================================================

local CHANGELOG = {
    {
        version = "2.1.9.0",
        date    = "2026",
        changes = {
            "Storage: historical peak price tracking — saved per savegame",
            "Storage: peak shown under each crop (orange = below peak, green = at peak)",
            "Storage: price comparison section — all stations sorted best-first",
        },
    },
    {
        version = "2.1.8.0",
        date    = "2026",
        changes = {
            "New: Time Controls app — time scale presets + skip to time of day",
            "New: Hotspot Manager — list/remove map pins, clear all (confirm)",
            "New: Notes app — checkbox todo list, saves per savegame",
            "New: Farm Admin — money, time, repair all, fill all fuel",
            "Fix: tablet content refreshes every 4s while open",
        },
    },
    {
        version = "2.1.7.0",
        date    = "2026",
        changes = {
            "New: Storage app — silo inventory and current sell prices",
            "New: Invoices app with in-tablet creation form",
            "New: RoleplayPhone integration foundation",
            "New: UsedPlus integration app",
            "Fix: camera lock and mouse cursor while tablet open",
        },
    },
    {
        version = "2.1.5.0",
        date    = "2026",
        changes = {
            "Fix: App Store now scrolls (all mod apps visible)",
            "Fix: Updates app now scrolls (all entries visible)",
            "New: About section in Settings with version + links",
        },
    },
    {
        version = "2.1.4.0",
        date    = "2026",
        changes = {
            "New: Market Dynamics integration app",
            "New: Worker Costs integration app",
            "New: Random World Events integration app",
            "Fix: cross-mod detection for NPC/Soil/CropStress apps",
        },
    },
    {
        version = "2.1.3.0",
        date    = "2025",
        changes = {
            "Added background color picker in Settings",
            "Fix: translations missing from zip package",
            "Fix: SettingsUI key name alignment",
            "Fix: companion mod setting changes server-only in MP",
        },
    },
    {
        version = "2.1.2.1",
        date    = "2025",
        changes = {
            "Fix: app name translation keys in AppRegistry",
            "Fix: remove broken texture atlas causing overlay warnings on every open",
            "Fix: use getfenv(0) to detect cross-mod globals in autoDetect()",
            "Fix: updated the UpdateApp to latest changelogs",
        },
    },
    {
        version = "2.1.2.0",
        date    = "2025",
        changes = {
            "Added translations for 26 languages",
            "Added info icon per app (bottom right corner)",
            "Added help section to pause menu",
            "Added multiplayer support",
            "Added dedicated server support",
        },
    },
    {
        version = "2.1.0.0",
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
    local AC = FT.appColor(FT.APP.UPDATES)

    if self:drawHelpPage("_updatesHelp", FT.APP.UPDATES, "Updates", AC, {
        { title = "WHAT IS THIS APP",
          body  = "Shows the changelog for Farm Tablet — what changed\n" ..
                  "in each version, newest first." },
        { title = "VERSION ENTRIES",
          body  = "Each block shows the version number on the left and\n" ..
                  "the release date on the right.\n" ..
                  "Bullet points below list individual changes." },
        { title = "KEEPING UP TO DATE",
          body  = "Download the latest version from the mod page on\n" ..
                  "GitHub or KingMods to get new features and fixes." },
    }) then return end

    local scrollY  = self:getContentScrollY()
    local afterHdr = self:drawAppHeader("Updates", "Changelog")
    local x, contentY, cw, _ = self:contentInner()
    local y = afterHdr + scrollY

    for _, entry in ipairs(CHANGELOG) do
        self.r:appRect(x - FT.px(4), y - FT.py(2), cw + FT.px(8), FT.py(18), FT.C.BG_CARD)
        self.r:appText(x + FT.px(6),      y + FT.py(4), FT.FONT.BODY, "v" .. entry.version, RenderText.ALIGN_LEFT,  FT.C.BRAND)
        self.r:appText(x + cw - FT.px(4), y + FT.py(4), FT.FONT.TINY, entry.date,           RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
        y = y - FT.py(22)
        for _, change in ipairs(entry.changes) do
            self.r:appRect(x + FT.px(6), y + FT.py(5), FT.px(4), FT.px(4), FT.C.BRAND_DIM)
            local txt = change
            if #txt > 46 then txt = txt:sub(1,44) .. ">" end
            self.r:appText(x + FT.px(16), y, FT.FONT.SMALL, txt, RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
            y = y - FT.py(16)
        end
        y = y - FT.py(6)
    end

    self:setContentHeight(afterHdr - y)
    self:drawInfoIcon("_updatesHelp", AC)

    -- ── Scroll indicator bar ──────────────────────────────
    self:drawScrollBar()
end)
