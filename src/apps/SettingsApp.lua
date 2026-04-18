-- =========================================================
-- FarmTablet v2 – Settings App  (scrollable, expanded)
-- =========================================================
-- Sections:
--   DISPLAY  – tablet position / scale / edit-mode entry
--   SOUND    – master toggle, app-select click, help-open paging
--   GENERAL  – notifications, startup app, debug
--   INFO     – version, author, app count, open key
--   DANGER   – reset to defaults
--
-- Scroll: mouse wheel over content area scrolls the page.
-- A scroll indicator bar is drawn on the right edge.
-- =========================================================

-- ── helpers ───────────────────────────────────────────────

local function playClickSound(settings)
    if not (settings and settings.soundEffects) then return end
    pcall(function()
        if g_gui and g_gui.guiSoundPlayer then
            g_gui.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
        end
    end)
end

local function refresh(ui)
    ui:switchApp(FT.APP.SETTINGS)
end

-- ── drawer ────────────────────────────────────────────────

FarmTabletUI:registerDrawer(FT.APP.SETTINGS, function(self)
    local AC = FT.appColor(FT.APP.SETTINGS)

    if self:drawHelpPage("_settingsHelp", FT.APP.SETTINGS, "Settings", AC, {
        { title = "DISPLAY — POSITION & SCALE",
          body  = "Shows the current tablet position (X/Y) and scale.\n" ..
                  "Use ENTER EDIT MODE for visual drag-and-resize,\n" ..
                  "or RESET POSITION & SCALE to restore defaults." },
        { title = "ENTER EDIT MODE",
          body  = "Activates visual editing of the tablet.\n" ..
                  "Drag the body to reposition it anywhere on screen.\n" ..
                  "Drag a corner handle to scale the whole tablet.\n" ..
                  "Drag left or right edge to adjust width only.\n" ..
                  "Right-click or press Esc to exit." },
        { title = "BACKGROUND COLOR",
          body  = "Changes the screen background of the tablet.\n" ..
                  "Click to cycle through 6 preset dark themes:\n" ..
                  "Deep Space, Ocean Blue, Forest Green,\n" ..
                  "Midnight Purple, Warm Dark, Slate Grey." },
        { title = "SOUND EFFECTS",
          body  = "Master toggle for all tablet sounds.\n" ..
                  "When off all sub-toggles are also silenced.\n" ..
                  "App Select Sound: click when switching sidebar apps.\n" ..
                  "Help Panel Sound: paging when the FS25 help opens.\n" ..
                  "Tablet Open/Close Sound: plays on the T key." },
        { title = "STARTUP APP",
          body  = "The app shown first every time you open the tablet.\n" ..
                  "Click the button to cycle through available options.\n" ..
                  "Or set it via console: TabletSetStartupApp weather" },
        { title = "NOTIFICATIONS",
          body  = "Shows a welcome message in the top-left corner\n" ..
                  "whenever a savegame loads. Turn off to keep things\n" ..
                  "quiet if you already know the open key." },
        { title = "DEBUG MODE",
          body  = "Writes verbose diagnostic messages to the developer\n" ..
                  "console. Useful for troubleshooting. Leave off during\n" ..
                  "normal play to keep the console clean." },
        { title = "RESET ALL TO DEFAULTS",
          body  = "Restores every setting to its factory value,\n" ..
                  "including position, scale, key, sounds, and startup\n" ..
                  "app. Cannot be undone." },
    }) then return end

    local s   = self.settings

    -- ── Layout ────────────────────────────────────────────
    local cx, cy, cw, ch = self:contentInner()
    -- scrollY > 0 means the user has scrolled down: shift drawn items UP by scrollY
    local scrollY = self:getContentScrollY()

    -- We draw everything as if scrollY == 0, then shift all Y values by +scrollY
    -- (moving content upward so lower items become visible).
    -- startY is the top of the content area (highest normalised Y = cy + ch).
    local topY = cy + ch   -- logical top of content (highest on screen)

    -- ── App header (fixed – not scrolled, always visible) ─
    -- We draw the header outside the scrolled region so it stays pinned.
    local headerH   = FT.py(28)  -- height consumed by drawAppHeader
    local dividerH  = FT.py(8)   -- gap below divider
    local contentStartY = topY - headerH - dividerH  -- where scrollable content begins

    -- drawAppHeader returns the Y where content should start (below divider)
    -- We call it normally; it draws into the persistent text layer (not scrolled).
    local afterHeader = self:drawAppHeader("Settings", "FarmTablet v" .. FT.VERSION)

    -- ── Scrollable content ────────────────────────────────
    -- All items below the header are offset by +scrollY so scrolling works.
    -- y decrements as we add items (FS25 Y=0 is bottom, Y=1 is top).

    local y = afterHeader + scrollY   -- apply scroll: positive scrollY shifts items upward

    local ROW_H    = FT.py(FT.SP.ROW)
    local BTN_H    = FT.py(22)
    local BTN_GAP  = FT.py(6)   -- gap between button bottom and next element
    local HINT_H   = FT.py(14)  -- height of a hint line below a button
    local SECT_GAP = FT.py(8)   -- gap after a section header

    -- ── DISPLAY ──────────────────────────────────────────
    y = self:drawSection(y, "DISPLAY")
    y = y - SECT_GAP

    local posStr   = string.format("X: %.2f  Y: %.2f", s.tabletPosX or 0.5, s.tabletPosY or 0.5)
    y = self:drawRow(y, "Position", posStr)

    local scaleStr = string.format("%.0f%%  (width: %.0f%%)",
        (s.tabletScale or 1.0) * 100, (s.tabletWidthMult or 1.0) * 100)
    y = self:drawRow(y, "Scale", scaleStr)

    local editActive = (g_FarmTablet and g_FarmTablet.ui and g_FarmTablet.ui._editModeActive) or false
    local editLabel  = editActive and "EXIT EDIT MODE" or "ENTER EDIT MODE"
    local editColor  = editActive and FT.C.POSITIVE or FT.C.BTN_NEUTRAL
    y = y - BTN_H
    self:drawButton(y, editLabel, editColor, {
        onClick = function()
            playClickSound(s)
            if g_FarmTablet and g_FarmTablet.ui then
                g_FarmTablet.ui:toggleEditMode()
            end
            refresh(self)
        end
    })
    y = y - BTN_GAP

    y = y - BTN_H
    self:drawButton(y, "RESET POSITION & SCALE", FT.C.BTN_NEUTRAL, {
        onClick = function()
            playClickSound(s)
            s.tabletPosX = 0.5; s.tabletPosY = 0.5
            s.tabletScale = 1.0; s.tabletWidthMult = 1.0
            s:save()
            if g_FarmTablet and g_FarmTablet.ui then
                g_FarmTablet.ui:applyPositionFromSettings()
            end
            refresh(self)
        end
    })
    y = y - BTN_GAP

    y = self:drawRule(y - FT.py(4), 0.3)
    y = y - FT.py(6)

    -- ── APPEARANCE ────────────────────────────────────────
    y = self:drawSection(y, "APPEARANCE")
    y = y - SECT_GAP

    local BG_PALETTE = FT.BG_PALETTE
    local bgIdx   = s.tabletBgColorIndex or 1
    local bgEntry = BG_PALETTE[bgIdx] or BG_PALETTE[1]

    y = y - BTN_H
    self:drawButton(y, "BACKGROUND: " .. string.upper(bgEntry.label), FT.C.BTN_NEUTRAL, {
        onClick = function()
            playClickSound(s)
            local next = (bgIdx % #BG_PALETTE) + 1
            s.tabletBgColorIndex = next
            s:save()
            refresh(self)
        end
    })
    self.r:appText(cx + FT.px(2), y - FT.py(2),
        FT.FONT.TINY, "Click to cycle  |  Screen background color",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - HINT_H - BTN_GAP

    y = self:drawRule(y - FT.py(4), 0.3)
    y = y - FT.py(6)

    -- ── SOUND ─────────────────────────────────────────────
    y = self:drawSection(y, "SOUND")
    y = y - SECT_GAP

    -- Master toggle
    local sfxLabel = s.soundEffects and "SOUND EFFECTS: ON" or "SOUND EFFECTS: OFF"
    y = y - BTN_H
    self:drawButton(y, sfxLabel, s.soundEffects and FT.C.POSITIVE or FT.C.MUTED, {
        onClick = function()
            s.soundEffects = not s.soundEffects
            s:save()
            refresh(self)
        end
    })
    y = y - BTN_GAP

    -- App select sound
    local asLabel = s.soundOnAppSelect and "APP SELECT SOUND: ON" or "APP SELECT SOUND: OFF"
    local asActive = s.soundEffects and s.soundOnAppSelect
    y = y - BTN_H
    self:drawButton(y, asLabel, asActive and FT.C.POSITIVE or FT.C.MUTED, {
        onClick = function()
            playClickSound(s)
            s.soundOnAppSelect = not s.soundOnAppSelect
            s:save()
            refresh(self)
        end
    })
    self.r:appText(cx + FT.px(2), y - FT.py(2),
        FT.FONT.TINY, "Plays a click when switching apps in the sidebar",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - HINT_H - BTN_GAP

    -- Help panel sound
    local hpLabel  = s.soundOnHelpOpen and "HELP PANEL SOUND: ON" or "HELP PANEL SOUND: OFF"
    local hpActive = s.soundEffects and s.soundOnHelpOpen
    y = y - BTN_H
    self:drawButton(y, hpLabel, hpActive and FT.C.POSITIVE or FT.C.MUTED, {
        onClick = function()
            playClickSound(s)
            s.soundOnHelpOpen = not s.soundOnHelpOpen
            s:save()
            refresh(self)
        end
    })
    self.r:appText(cx + FT.px(2), y - FT.py(2),
        FT.FONT.TINY, "Plays a paging sound when the in-game help panel opens/closes",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - HINT_H - BTN_GAP

    -- Tablet open/close sound
    local tcLabel  = s.soundOnTabletToggle and "TABLET OPEN/CLOSE SOUND: ON" or "TABLET OPEN/CLOSE SOUND: OFF"
    local tcActive = s.soundEffects and (s.soundOnTabletToggle ~= false)
    y = y - BTN_H
    self:drawButton(y, tcLabel, tcActive and FT.C.POSITIVE or FT.C.MUTED, {
        onClick = function()
            playClickSound(s)
            s.soundOnTabletToggle = not (s.soundOnTabletToggle ~= false)
            s:save()
            refresh(self)
        end
    })
    self.r:appText(cx + FT.px(2), y - FT.py(2),
        FT.FONT.TINY, "Plays a sound when you open or close the tablet (T key)",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - HINT_H - BTN_GAP

    y = self:drawRule(y - FT.py(4), 0.3)
    y = y - FT.py(6)

    -- ── GENERAL ───────────────────────────────────────────
    y = self:drawSection(y, "GENERAL")
    y = y - SECT_GAP

    -- Notifications
    local nLabel = s.showTabletNotifications and "NOTIFICATIONS: ON" or "NOTIFICATIONS: OFF"
    y = y - BTN_H
    self:drawButton(y, nLabel, s.showTabletNotifications and FT.C.POSITIVE or FT.C.MUTED, {
        onClick = function()
            playClickSound(s)
            s.showTabletNotifications = not s.showTabletNotifications
            s:save()
            refresh(self)
        end
    })
    self.r:appText(cx + FT.px(2), y - FT.py(2),
        FT.FONT.TINY, "Shows a welcome notification when a savegame loads",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - HINT_H - BTN_GAP

    -- Startup app (cycle)
    local ALL_STARTUP = {
        { id = "dashboard",    label = "Dashboard"  },
        { id = "app_store",    label = "App Store"  },
        { id = "weather",      label = "Weather"    },
        { id = "field_status", label = "Field Mgr"  },
        { id = "animals",      label = "Animals"    },
        { id = "workshop",     label = "Workshop"   },
        { id = "digging",      label = "Digging"    },
    }
    local curStartup = s.startupApp or "dashboard"
    local sIdx = 1
    for i, e in ipairs(ALL_STARTUP) do
        if e.id == curStartup then sIdx = i; break end
    end
    local sEntry = ALL_STARTUP[sIdx] or ALL_STARTUP[1]
    y = y - BTN_H
    self:drawButton(y, "STARTUP APP: " .. string.upper(sEntry.label), FT.C.BTN_NEUTRAL, {
        onClick = function()
            playClickSound(s)
            local next = (sIdx % #ALL_STARTUP) + 1
            s.startupApp = ALL_STARTUP[next].id
            s:save()
            refresh(self)
        end
    })
    self.r:appText(cx + FT.px(2), y - FT.py(2),
        FT.FONT.TINY, "Click to cycle  |  App opened first when tablet starts",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - HINT_H - BTN_GAP

    -- Debug mode
    local dLabel = s.debugMode and "DEBUG MODE: ON" or "DEBUG MODE: OFF"
    y = y - BTN_H
    self:drawButton(y, dLabel, s.debugMode and FT.C.WARNING or FT.C.MUTED, {
        onClick = function()
            playClickSound(s)
            s.debugMode = not s.debugMode
            s:save()
            refresh(self)
        end
    })
    self.r:appText(cx + FT.px(2), y - FT.py(2),
        FT.FONT.TINY, "Enables verbose console logging for troubleshooting",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - HINT_H - BTN_GAP

    y = self:drawRule(y - FT.py(4), 0.3)
    y = y - FT.py(6)

    -- ── INFO ──────────────────────────────────────────────
    y = self:drawSection(y, "INFO")
    y = y - SECT_GAP
    y = self:drawRow(y, "Version",     "v" .. FT.VERSION)
    y = self:drawRow(y, "Author",      "TisonK")
    y = self:drawRow(y, "Apps Loaded", tostring(#self.system.registry:getAll()))
    y = self:drawRow(y, "Open Key",    tostring(s.tabletKeybind or "T"))

    -- Console hint card
    y = y - FT.py(6)
    local cardH = FT.py(38)
    self.r:appRect(cx - FT.px(4), y - cardH, cw + FT.px(8), cardH, FT.C.BG_CARD)
    self.r:appText(cx + FT.px(8), y - FT.py(8),
        FT.FONT.TINY, "Type  tablet  in console for all commands.",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    self.r:appText(cx + FT.px(8), y - FT.py(22),
        FT.FONT.TINY, "Right-click tablet while open to enter resize / move mode.",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    self.r:appText(cx + FT.px(8), y - FT.py(34),
        FT.FONT.TINY, "Scroll wheel over this panel to scroll settings.",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - cardH - FT.py(8)

    y = self:drawRule(y, 0.3)
    y = y - FT.py(6)

    -- ── RESET DEFAULTS ────────────────────────────────────
    y = y - BTN_H
    self:drawButton(y, "RESET ALL TO DEFAULTS", FT.C.BTN_DANGER, {
        onClick = function()
            playClickSound(s)
            self.settings:resetToDefaults(true)
            if g_FarmTablet and g_FarmTablet.ui then
                g_FarmTablet.ui:applyPositionFromSettings()
            end
            refresh(self)
        end
    })
    y = y - BTN_GAP

    -- ── ABOUT ─────────────────────────────────────────────
    y = y - FT.py(10)
    y = self:drawRule(y, 0.3)
    y = self:drawSection(y, "ABOUT")

    y = self:drawRow(y, "Version", "v" .. FT.VERSION)
    y = self:drawRow(y, "Author",  "TisonK")
    y = y - FT.py(4)
    self.r:appText(x, y, FT.FONT.SMALL, "Docs / Releases:", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - FT.py(14)
    self.r:appText(x, y, FT.FONT.SMALL,
        "github.com/TheCodingDad-TisonK/FS25_FarmTablet",
        RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
    y = y - FT.py(18)
    self.r:appText(x, y, FT.FONT.SMALL, "Bug Reports / Issues:", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - FT.py(14)
    self.r:appText(x, y, FT.FONT.SMALL,
        "github.com/TheCodingDad-TisonK/FS25_FarmTablet/issues",
        RenderText.ALIGN_LEFT, FT.C.BRAND)
    y = y - FT.py(6)

    -- ── Tell the system total content height so it can enable scrolling ──
    local totalH = contentStartY - y
    self:setContentHeight(totalH)

    -- Info icon (drawn outside scroll so it's always visible)
    self:drawInfoIcon("_settingsHelp", FT.appColor(FT.APP.SETTINGS))

    -- ── Scroll indicator bar ──────────────────────────────
    self:drawScrollBar()
end)
