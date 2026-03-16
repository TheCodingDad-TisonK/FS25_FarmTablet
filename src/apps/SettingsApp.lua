-- =========================================================
-- FarmTablet v2 – Settings App
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.SETTINGS, function(self)
    local s = self.settings

    local startY = self:drawAppHeader("Settings", "FarmTablet v" .. FT.VERSION)

    local x, contentY, cw, _ = self:contentInner()
    local y = startY
    local minY = contentY + FT.py(8)

    -- ── General ───────────────────────────────────────────
    y = self:drawSection(y, "GENERAL")

    -- Notifications toggle
    local nLabel = s.showTabletNotifications and "NOTIFICATIONS: ON" or "NOTIFICATIONS: OFF"
    local nColor = s.showTabletNotifications and FT.C.POSITIVE or FT.C.MUTED
    local _, nBtn = self:drawButton(y, nLabel, nColor, {
        onClick = function()
            s.showTabletNotifications = not s.showTabletNotifications
            s:save()
            self:switchApp(FT.APP.SETTINGS)
        end
    })
    y = y - FT.py(28)

    -- Sound Effects toggle
    local sLabel = s.soundEffects and "SOUND: ON" or "SOUND: OFF"
    local sColor = s.soundEffects and FT.C.POSITIVE or FT.C.MUTED
    local _, sBtn = self:drawButton(y, sLabel, sColor, {
        onClick = function()
            s.soundEffects = not s.soundEffects
            s:save()
            self:switchApp(FT.APP.SETTINGS)
        end
    })
    y = y - FT.py(28)

    -- Debug Mode toggle
    local dLabel = s.debugMode and "DEBUG: ON" or "DEBUG: OFF"
    local dColor = s.debugMode and FT.C.NEGATIVE or FT.C.MUTED
    local _, dBtn = self:drawButton(y, dLabel, dColor, {
        onClick = function()
            s.debugMode = not s.debugMode
            s:save()
            self:switchApp(FT.APP.SETTINGS)
        end
    })
    y = y - FT.py(28)

    y = y - FT.py(4)
    y = self:drawRule(y, 0.3)

    -- ── Info ──────────────────────────────────────────────
    y = self:drawSection(y, "INFO")
    y = self:drawRow(y, "Version",  "v" .. FT.VERSION)
    y = self:drawRow(y, "Author",   "TisonK")

    local appCount = #self.system.registry:getAll()
    y = self:drawRow(y, "Apps Loaded", tostring(appCount))

    -- ── Console hint ─────────────────────────────────────
    if y > minY + FT.py(28) then
        y = y - FT.py(8)
        self.r:appRect(x - FT.px(4), y - FT.py(26),
            cw + FT.px(8), FT.py(30), FT.C.BG_CARD)
        self.r:appText(x + FT.px(8), y - FT.py(4),
            FT.FONT.TINY, "Type  tablet  in console for all commands.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x + FT.px(8), y - FT.py(18),
            FT.FONT.TINY, "Full settings: Pause → Settings → Farm Tablet",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        y = y - FT.py(34)
    end

    -- ── Reset button ─────────────────────────────────────
    if y > minY then
        local _, resetBtn = self:drawButton(minY + FT.py(2), "RESET DEFAULTS",
            FT.C.BTN_DANGER,
            { onClick = function()
                self.settings:resetToDefaults(true)
                self:switchApp(FT.APP.SETTINGS)
            end })
    end
end)
