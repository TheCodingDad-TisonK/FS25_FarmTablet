-- =========================================================
-- FarmTablet v2 – FarmTabletUI
-- Complete UI overhaul:
--   • Sidebar navigation with icon grid (not tiny button strip)
--   • Top status bar with clock/farm info
--   • Rich content area with structured layout
--   • All drawing through FT_Renderer
--   • Hover states tracked per-frame
-- =========================================================
---@class FarmTabletUI
FarmTabletUI = {}
local FarmTabletUI_mt = Class(FarmTabletUI)

-- ── Sidebar app icon grid constants ──────────────────────
local SIDEBAR_W_REF  = 100  -- ref px (wider for text labels)
local TOPBAR_H_REF   = 34
local ICON_SIZE_REF  = 60
local ICON_GAP_REF   = 5
local ICON_PAD_REF   = 8

function FarmTabletUI.new(settings, system, modDirectory)
    local self = setmetatable({}, FarmTabletUI_mt)
    self.settings     = settings
    self.system       = system
    self.modDirectory = modDirectory or ""
    self.r        = FT_Renderer.new()
    self.isOpen   = false

    -- Per-frame hover tracking
    self._mouseX  = 0
    self._mouseY  = 0
    self._hovered = nil

    -- Named persistent hitboxes
    self._closeBtn    = nil
    self._iconBtns    = {}  -- {appId, x,y,w,h}
    self._contentBtns = {}  -- app-specific, cleared per switch

    -- Sidebar scroll state
    self._sidebarScrollOffset = 0   -- in icon slots (integer)
    self._sidebarMaxScroll    = 0   -- set in _drawSidebar

    -- Content area scroll state (per-app, reset on app switch)
    self._contentScrollY      = 0   -- current scroll in normalized units
    self._contentScrollMax    = 0   -- set by apps that overflow
    self._contentScrollStep   = FT.py and FT.py(22) or 0.018 -- pixels per wheel tick

    -- Backdrop overlay (separate from renderer for ordering)
    self._backdrop = nil

    -- ── Resize / Move (edit mode) ─────────────────────────
    -- Drag/resize/position approach inspired by NPCFavorHUD from FS25_NPCFavor
    self._editModeActive  = false
    self._editBgOverlay   = nil
    self._editAnimTimer   = 0

    -- Drag state
    self._emDragging      = false
    self._emDragOffX      = 0
    self._emDragOffY      = 0

    -- Corner-resize state
    self._emResizing      = false
    self._emResizeStartX  = 0
    self._emResizeStartY  = 0
    self._emResizeStartS  = 1.0
    self._emHoverCorner   = nil

    -- Edge (width) drag state
    self._emEdgeDragging  = nil
    self._emEdgeStartX    = 0
    self._emEdgeStartW    = 1.0

    -- Camera lock while tablet is open (normal mode)
    self._tabletCamRotX = nil
    self._tabletCamRotY = nil
    self._tabletCamRotZ = nil

    -- Camera lock for edit mode
    self._emCamRotX = nil
    self._emCamRotY = nil
    self._emCamRotZ = nil

    -- Edit-mode constants
    self.EM_HANDLE_SIZE  = 0.010
    self.EM_MIN_SCALE    = 0.5
    self.EM_MAX_SCALE    = 2.0
    self.EM_MIN_WIDTH    = 0.5
    self.EM_MAX_WIDTH    = 2.0


    return self
end

-- ─────────────────────────────────────────────────────────
-- OPEN / CLOSE / TOGGLE
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:openTablet()
    if not self.settings.enabled or self.isOpen then return end
    self.isOpen = true
    self.system.isTabletOpen = true
    self.system.registry:autoDetect()
    self:_build()

    -- Play open sound
    if self.settings.soundOnTabletToggle ~= false then
        self:playUISound("paging")
    end

    if g_currentMission then
        g_currentMission:addDrawable(self)
    end

    if g_inputBinding then
        g_inputBinding:setShowMouseCursor(true)
        self._mouseListener = {_ui = self}
        function self._mouseListener:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
            if not eventUsed and self._ui:_onMouse(posX, posY, isDown, isUp, button) then
                return true
            end
            return eventUsed
        end
        addModEventListener(self._mouseListener)
    end

    -- Capture camera rotation so we can freeze it every frame while open
    if g_cameraManager and getRotation then
        local cam = g_cameraManager:getActiveCamera()
        if cam and cam ~= 0 then
            self._tabletCamRotX, self._tabletCamRotY, self._tabletCamRotZ = getRotation(cam)
        end
    end

    FT_EventBus:emit(FT_EventBus.EVENTS.TABLET_OPENED)
end

function FarmTabletUI:closeTablet()
    if not self.isOpen then return end

    -- Play close sound before teardown (while soundPlayer still reachable)
    if self.settings.soundOnTabletToggle ~= false then
        self:playUISound("back")
    end

    self.isOpen = false
    self.system.isTabletOpen = false
    self:_destroy()

    -- notify system so it can reset stale state (e.g. workshop selection)
    if self.system.onTabletClosed then
        self.system:onTabletClosed()
    end

    if g_currentMission then
        g_currentMission:removeDrawable(self)
        if self._mouseListener then
            removeModEventListener(self._mouseListener)
            self._mouseListener = nil
        end
    end
    if g_inputBinding then
        g_inputBinding:setShowMouseCursor(false)
    end

    self._tabletCamRotX = nil
    self._tabletCamRotY = nil
    self._tabletCamRotZ = nil

    FT_EventBus:emit(FT_EventBus.EVENTS.TABLET_CLOSED)
end

function FarmTabletUI:toggleTablet()
    if self.isOpen then self:closeTablet() else self:openTablet() end
end

-- ─────────────────────────────────────────────────────────
-- BUILD  (called once on open)
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_build()
    self.r:destroyAll()
    self._iconBtns    = {}
    self._contentBtns = {}
    self._sidebarScrollOffset = self._sidebarScrollOffset or 0

    -- Initialise edit-mode scale trackers from settings (first open or after reset)
    if not self._emCurrentScale then
        self._emCurrentScale = self.settings.tabletScale or 1.0
    end
    if not self._emCurrentWidthMult then
        self._emCurrentWidthMult = self.settings.tabletWidthMult or 1.0
    end

    -- 1. Compute layout in normalized coords
    -- Apply scale multiplier from settings
    local scaleMultW = (self.settings.tabletScale or 1.0) * (self.settings.tabletWidthMult or 1.0)
    local scaleMultH = self.settings.tabletScale or 1.0
    local tw, th = getNormalizedScreenValues(
        FT.REF_W * scaleMultW,
        FT.REF_H * scaleMultH)

    -- Position: settings store the centre in 0-1 space
    local centreX = self.settings.tabletPosX or 0.5
    local centreY = self.settings.tabletPosY or 0.5
    local tx = centreX - tw/2
    local ty = centreY - th/2

    -- Clamp to screen
    tx = math.max(0, math.min(1 - tw, tx))
    ty = math.max(0, math.min(1 - th, ty))

    -- Scale factors for ref->normalized
    FT.LAYOUT.scaleX = tw / FT.REF_W
    FT.LAYOUT.scaleY = th / FT.REF_H
    FT.LAYOUT.tabletX = tx;  FT.LAYOUT.tabletY = ty
    FT.LAYOUT.tabletW = tw;  FT.LAYOUT.tabletH = th

    -- Programmatic Bezel (modern thin design, replaces old DDS-based insets)
    local BEZEL_SIZE = 48
    local BEZEL_L = FT.px(BEZEL_SIZE)
    local BEZEL_R = FT.px(BEZEL_SIZE)
    local BEZEL_T = FT.py(BEZEL_SIZE)
    local BEZEL_B = FT.py(BEZEL_SIZE)

    -- Inner screen origin and size
    local sx = tx + BEZEL_L
    local sy = ty + BEZEL_B
    local sw = tw - BEZEL_L - BEZEL_R
    local sh = th - BEZEL_T  - BEZEL_B

    local sideW = FT.px(SIDEBAR_W_REF)
    local topH  = FT.py(TOPBAR_H_REF)

    FT.LAYOUT.sidebarX = sx;            FT.LAYOUT.sidebarY = sy
    FT.LAYOUT.sidebarW = sideW;         FT.LAYOUT.sidebarH = sh
    FT.LAYOUT.topbarX  = sx + sideW;    FT.LAYOUT.topbarY  = sy + sh - topH
    FT.LAYOUT.topbarW  = sw - sideW;    FT.LAYOUT.topbarH  = topH
    FT.LAYOUT.contentX = sx + sideW;    FT.LAYOUT.contentY = sy
    FT.LAYOUT.contentW = sw - sideW;    FT.LAYOUT.contentH = sh - topH

    -- 2. Draw chrome (persistent)
    self:_drawChrome()

    -- 3. Draw app icons in sidebar
    self:_drawSidebar()

    -- 4. Draw content area for current app
    self:_drawContent()
end

-- ─────────────────────────────────────────────────────────
-- CHROME  (tablet body + topbar)
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_drawChrome()
    local L = FT.LAYOUT
    local r = self.r

    -- Rebuild cover layer fresh (cover strips depend on computed layout)
    r:clearCoverLayer()

    -- === 1. Drop Shadow (layered for softness) ===
    local sh = FT.px(2)
    r:rect(L.tabletX + sh,   L.tabletY - sh,   L.tabletW, L.tabletH, {0,0,0, 0.25})
    r:rect(L.tabletX + sh*2, L.tabletY - sh*2, L.tabletW, L.tabletH, {0,0,0, 0.15})
    r:rect(L.tabletX + sh*3, L.tabletY - sh*3, L.tabletW, L.tabletH, {0,0,0, 0.05})

    r:rect(L.tabletX, L.tabletY, L.tabletW, L.tabletH, FT.C.BG_DEEP)

    -- === Add a distinct border around the tablet frame ===
    local tabletBorderWidth = FT.px(2)
    r:rect(L.tabletX - tabletBorderWidth, L.tabletY - tabletBorderWidth, L.tabletW + tabletBorderWidth * 2, L.tabletH + tabletBorderWidth * 2, {0, 0, 0, 1.0})

    -- === 3. Bezel Highlight (Chamfered edge glints) ===
    local hiColor = {1, 1, 1, 0.04}
    r:rect(L.tabletX, L.tabletY + L.tabletH - FT.py(1), L.tabletW, FT.py(1), hiColor) -- Top edge glint
    r:rect(L.tabletX, L.tabletY, FT.px(1), L.tabletH, hiColor) -- Left edge glint

    -- === 4. Camera Lens Detail (centered in top bezel) ===
    local camSize = FT.px(8)
    local camX = L.tabletX + L.tabletW/2 - camSize/2
    local camY = L.tabletY + L.tabletH - FT.py(16)
    r:rect(camX, camY, camSize, camSize, {0.02, 0.02, 0.03, 1}) -- Lens housing
    r:rect(camX + FT.px(2), camY + FT.py(4), FT.px(2), FT.py(2), {1, 1, 1, 0.10}) -- Lens reflection

    -- === 5. Screen Backdrop (OLED deep-black effect) ===
    -- Draw a solid backing to ensure screen is fully opaque
    r:rect(L.sidebarX, L.sidebarY, L.sidebarW + L.contentW, L.sidebarH, {0.0, 0.0, 0.0, 1.0})
    -- Draw user-selected background color from the palette
    local _bgPal = FT.BG_PALETTE[self.settings.tabletBgColorIndex or 1] or FT.BG_PALETTE[1]
    r:rect(L.sidebarX, L.sidebarY, L.sidebarW + L.contentW, L.sidebarH, _bgPal.color)

    -- === 5a. Screen Border ===
    local bx, by = L.sidebarX, L.sidebarY
    local bw, bh = L.sidebarW + L.contentW, L.sidebarH
    local stroke = FT.px(1)
    r:rect(bx, by, bw, stroke, FT.C.BORDER_BRIGHT) -- Top
    r:rect(bx, by + bh - stroke, bw, stroke, FT.C.BORDER_BRIGHT) -- Bottom
    r:rect(bx, by, stroke, bh, FT.C.BORDER_BRIGHT) -- Left
    r:rect(bx + bw - stroke, by, stroke, bh, FT.C.BORDER_BRIGHT) -- Right

    -- === 6. Sidebar background (distinctly darker than content) ===
    r:rect(L.sidebarX, L.sidebarY, L.sidebarW, L.sidebarH, {FT.C.BG_NAV[1], FT.C.BG_NAV[2], FT.C.BG_NAV[3], 0.35})

    -- Sidebar right edge — bright separator line
    local sepX = L.sidebarX + L.sidebarW - FT.px(1)
    r:rect(sepX, L.sidebarY, FT.px(1), L.sidebarH,
           {FT.C.BRAND[1], FT.C.BRAND[2], FT.C.BRAND[3], 0.35})

    -- === 7. Top status bar ===
    r:rect(L.topbarX, L.topbarY, L.topbarW, L.topbarH, {FT.C.BG_NAV[1], FT.C.BG_NAV[2], FT.C.BG_NAV[3], 0.35})

    -- Per-app color tint on topbar
    local appAccent = FT.appColor(self.system.currentApp)
    r:rect(L.topbarX, L.topbarY, L.topbarW, L.topbarH,
           {appAccent[1], appAccent[2], appAccent[3], 0.06})

    -- Topbar bottom border (uses current app accent)
    r:rect(L.topbarX, L.topbarY, L.topbarW, FT.py(1),
           {appAccent[1], appAccent[2], appAccent[3], 0.55})

    -- === Brand logo block at bottom of sidebar ===
    local logoH = FT.py(38)
    r:rect(L.sidebarX, L.sidebarY, L.sidebarW, logoH, {0.1, 0.3, 0.6, 1.0})

    -- Brand text (ASCII only)
    r:text(L.sidebarX + L.sidebarW/2,
           L.sidebarY + logoH - FT.py(24),
           FT.FONT.TINY, "FARM",
           RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
    r:text(L.sidebarX + L.sidebarW/2,
           L.sidebarY + logoH - FT.py(12),
           FT.FONT.TINY, "TABLET",
           RenderText.ALIGN_CENTER,
           {FT.C.BRAND[1], FT.C.BRAND[2], FT.C.BRAND[3], 1.0})
    r:text(L.sidebarX + L.sidebarW/2,
           L.sidebarY + logoH - FT.py(3),
           FT.FONT.TINY, "v" .. FT.VERSION,
           RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)

    -- === Topbar content ===
    self:_drawTopbar()

    -- === Close button — ASCII "X" ===
    local cbH   = FT.py(20)
    local cbW   = FT.px(28)
    local cbX   = L.topbarX + L.topbarW - FT.px(6) - cbW
    local cbY   = L.topbarY + (L.topbarH - cbH)/2

    r:rect(cbX, cbY, cbW, cbH, FT.C.BTN_DANGER)
    r:text(cbX + cbW/2, cbY + cbH/2 - FT.py(3),
           FT.FONT.SMALL, "X",
           RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)

    self._closeBtn = { x=cbX, y=cbY, w=cbW, h=cbH }

    -- === Side hardware buttons (right side of tablet bezel) ===
    local btnSideW  = FT.px(6)
    local btnSideH  = FT.py(32)
    local sideX     = L.tabletX + L.tabletW   -- right bezel outer edge
    local btnGap    = FT.py(8)

    -- Power button (top-right)
    local pwrY = L.tabletY + L.tabletH - FT.py(120)
    r:rect(sideX - FT.px(3), pwrY, btnSideW, btnSideH, {0.22, 0.24, 0.30, 1.0})
    r:rect(sideX - FT.px(2), pwrY + FT.py(1), FT.px(4), btnSideH - FT.py(2), {0.14, 0.15, 0.20, 1.0})

    -- Volume Up button
    local volUpY = L.tabletY + L.tabletH - FT.py(68)
    r:rect(sideX - FT.px(3), volUpY, btnSideW, btnSideH, {0.22, 0.24, 0.30, 1.0})
    r:rect(sideX - FT.px(2), volUpY + FT.py(1), FT.px(4), btnSideH - FT.py(2), {0.14, 0.15, 0.20, 1.0})

    -- Volume Down button
    local volDnY = volUpY + btnSideH + btnGap
    r:rect(sideX - FT.px(3), volDnY, btnSideW, btnSideH * 0.9, {0.22, 0.24, 0.30, 1.0})
    r:rect(sideX - FT.px(2), volDnY + FT.py(1), FT.px(4), btnSideH * 0.9 - FT.py(2), {0.14, 0.15, 0.20, 1.0})

    -- Small speaker grille dots on left bezel
    local grY = L.tabletY + FT.py(30)
    local grX = L.tabletX + FT.px(6)
    for i = 0, 5 do
        r:rect(grX, grY + i * FT.py(8), FT.px(2), FT.py(3), {0.08, 0.09, 0.12, 1.0})
    end
    grX = L.tabletX + FT.px(10)
    for i = 0, 5 do
        r:rect(grX, grY + i * FT.py(8) + FT.py(2), FT.px(2), FT.py(3), {0.08, 0.09, 0.12, 1.0})
    end

    -- === Cover strips: clip scrolled content at content-area boundaries ===
    -- These are drawn AFTER the app-layer (via coverRect) so scrolled items
    -- that extend past the content zone edges are hidden behind the tablet chrome.
    local coverColor = FT.C.BG_DEEP
    local bottomGap  = L.contentY - L.sidebarY
    if bottomGap > 0 then
        r:coverRect(L.contentX, L.sidebarY, L.contentW, bottomGap, coverColor)
    end
    local topCoverY = L.contentY + L.contentH
    local topGap    = L.topbarY - topCoverY
    if topGap > 0 then
        r:coverRect(L.contentX, topCoverY, L.contentW, topGap, coverColor)
    end

end

function FarmTabletUI:_drawTopbar()
    local L = FT.LAYOUT
    local r = self.r
    local data = self.system.data

    -- Farm name
    local farmId = data:getPlayerFarmId()
    local farmName = data:getFarmName(farmId)
    local displayName = farmName or "My Farm"
    r:text(L.topbarX + FT.px(14),
           L.topbarY + L.topbarH/2 - FT.py(3),
           FT.FONT.BODY, displayName,
           RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)

    -- Current app name
    local app = self.system.registry:get(self.system.currentApp)
    local appName = (app and g_i18n and g_i18n:getText(app.name)) or
                    (app and app.navLabel) or ""
    r:text(L.topbarX + L.topbarW/2,
           L.topbarY + L.topbarH/2 - FT.py(3),
           FT.FONT.SMALL, appName,
           RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)

    -- Clock
    local world = data:getWorldInfo()
    if world then
        local timeStr   = string.format("%02d:%02d", world.hour % 24, world.minute)
        local seasonStr = data:getSeasonName(world.season) .. " - Day " .. world.day
        r:text(L.topbarX + L.topbarW - FT.px(80),
               L.topbarY + L.topbarH - FT.py(16),
               FT.FONT.SMALL, timeStr,
               RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)
        r:text(L.topbarX + L.topbarW - FT.px(80),
               L.topbarY + L.topbarH/2 - FT.py(10),
               FT.FONT.TINY, seasonStr,
               RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    end
end

-- ─────────────────────────────────────────────────────────
-- SIDEBAR ICON GRID
-- ─────────────────────────────────────────────────────────

-- App icon labels — ASCII only (FS25 renderText has no unicode support)
-- Two-line: top row = short icon-like symbol, bottom = nav label
local APP_ICONS = {
    [FT.APP.DASHBOARD]  = "##",
    [FT.APP.WEATHER]    = "~~",
    [FT.APP.FIELDS]     = "[]",
    [FT.APP.ANIMALS]    = "**",
    [FT.APP.WORKSHOP]   = "::",
    [FT.APP.DIGGING]    = "vv",
    [FT.APP.BUCKET]     = "())",
    [FT.APP.APP_STORE]  = "++",
    [FT.APP.SETTINGS]   = "==",
    [FT.APP.UPDATES]    = "^^",
    [FT.APP.INCOME]     = "$$",
    [FT.APP.TAX]        = "%%",
    [FT.APP.NPC_FAVOR]  = "NP",
    [FT.APP.CROP_STRESS]= "CS",
    [FT.APP.SOIL_FERT]  = "SF",
}

function FarmTabletUI:_drawSidebar()
    local L     = FT.LAYOUT
    local r     = self.r
    local apps  = self.system.registry:getAll()

    local iconW  = L.sidebarW - FT.px(10)
    local iconH  = FT.py(ICON_SIZE_REF * 0.72)
    local gap    = FT.py(ICON_GAP_REF)
    local ix     = L.sidebarX + FT.px(5)
    local logoH  = FT.py(38)

    -- Available vertical space for icons (between logo block and top of sidebar)
    local availH     = L.sidebarH - logoH - FT.py(10)
    local slotH      = iconH + gap
    local visibleMax = math.floor(availH / slotH)

    -- Compute max scroll
    local totalApps = #apps
    self._sidebarMaxScroll = math.max(0, totalApps - visibleMax)
    self._sidebarScrollOffset = math.max(0,
        math.min(self._sidebarScrollOffset or 0, self._sidebarMaxScroll))

    local startY    = L.sidebarY + logoH + FT.py(6)
    local currentApp = self.system.currentApp

    -- Draw scroll indicator if needed
    if self._sidebarMaxScroll > 0 then
        local indX = L.sidebarX + L.sidebarW - FT.px(5)
        local indY = startY
        local indH = availH - FT.py(4)
        -- Track
        r:rect(indX, indY, FT.px(3), indH, {0.12, 0.14, 0.20, 0.8})
        -- Thumb
        local thumbRatio = visibleMax / totalApps
        local thumbH     = math.max(FT.py(12), indH * thumbRatio)
        local thumbOffsetRatio = self._sidebarScrollOffset / totalApps
        local thumbY = indY + indH * thumbOffsetRatio
        r:rect(indX, thumbY, FT.px(3), thumbH,
               {FT.C.BRAND[1], FT.C.BRAND[2], FT.C.BRAND[3], 0.70})
        -- Up/down arrows
        if self._sidebarScrollOffset > 0 then
            r:text(indX + FT.px(1), indY + indH - FT.py(4),
                   FT.FONT.TINY, "^", RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)
        end
        if self._sidebarScrollOffset < self._sidebarMaxScroll then
            r:text(indX + FT.px(1), indY + FT.py(4),
                   FT.FONT.TINY, "v", RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)
        end
    end

    self._iconBtns = {}

    for i, app in ipairs(apps) do
        local slot = i - 1 - (self._sidebarScrollOffset or 0)
        if slot >= 0 and slot < visibleMax then
            local iy = startY + slot * slotH
            local isActive = (app.id == currentApp)
            local accent   = FT.appColor(app.id)

            -- Icon tile background
            local bgColor = isActive
                and {accent[1]*0.25, accent[2]*0.25, accent[3]*0.25, 0.95}
                or  FT.C.BG_CARD
            r:rect(ix, iy, iconW, iconH, bgColor)

            -- Active indicator: colored left edge bar
            if isActive then
                r:rect(L.sidebarX, iy, FT.px(4), iconH, accent)
            else
                -- Subtle color dot on inactive
                r:rect(L.sidebarX, iy + iconH/2 - FT.py(3),
                       FT.px(2), FT.py(6),
                       {accent[1], accent[2], accent[3], 0.35})
            end

            -- Nav label — centered in tile
            local label  = app.navLabel or string.upper(string.sub(app.id, 1, 4))
            local tColor = isActive and FT.C.TEXT_BRIGHT or FT.C.TEXT_DIM
            r:text(ix + iconW/2, iy + iconH/2 - FT.py(3),
                   FT.FONT.SMALL, label,
                   RenderText.ALIGN_CENTER, tColor)

            table.insert(self._iconBtns, {
                appId = app.id,
                x = ix, y = iy, w = iconW, h = iconH
            })
        end
    end
end

-- ─────────────────────────────────────────────────────────
-- CONTENT AREA
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_drawContent()
    self.r:clearAppLayer()
    self._contentBtns = {}

    local appId = self.system.currentApp
    local fn = self._appDrawers and self._appDrawers[appId]
    if fn then
        local ok, err = pcall(fn, self)
        if not ok then
            self:_drawError(err)
        end
    else
        self:_drawWelcome()
    end
end

-- Register an app drawer function (called by app files)
FarmTabletUI._appDrawers = {}
function FarmTabletUI:registerDrawer(appId, fn)
    FarmTabletUI._appDrawers[appId] = fn
end

-- ─────────────────────────────────────────────────────────
-- CONTENT LAYOUT HELPERS  (for app drawer functions)
-- All coordinates are in FS25 normalised screen space (0–1).
-- Y increases upward (bottom = 0, top = 1).
-- ─────────────────────────────────────────────────────────

--- Returns the current content scroll offset in normalised units.
--- App drawers add this to their starting Y so scrolled content
--- moves upward as the user scrolls down.
function FarmTabletUI:getContentScrollY()
    return self._contentScrollY or 0
end

-- ─────────────────────────────────────────────────────────
-- SHARED INFO ICON + HELP PAGE HELPERS
-- ─────────────────────────────────────────────────────────

--- Draws a small "i" icon button in the bottom-right corner of the content area.
--- Clicking it sets self[stateKey] = true and re-switches to the current app,
--- which will then route through drawHelpPage() and render the help overlay.
---
---@param stateKey    string  A unique key on self (e.g. "_dashHelpOpen").
---                           Must be distinct per app to avoid state collisions.
---@param accentColor table?  RGBA color matching the app accent; defaults to FT.C.BRAND.
---@return table  The registered button descriptor (already in _contentBtns).
function FarmTabletUI:drawInfoIcon(stateKey, accentColor)
    local x, contentY, w, _ = self:contentInner()
    local ac = accentColor or FT.C.BRAND

    local iSz = FT.px(18)
    local iX  = x + w - iSz
    local iY  = contentY

    -- Background tint
    self.r:appRect(iX, iY, iSz, iSz, {ac[1], ac[2], ac[3], 0.18})

    -- Border (four thin edge rects)
    local bdr = FT.px(1.2)
    local bc  = {ac[1], ac[2], ac[3], 0.65}
    self.r:appRect(iX,             iY,              iSz, bdr, bc)
    self.r:appRect(iX,             iY + iSz - bdr,  iSz, bdr, bc)
    self.r:appRect(iX,             iY,              bdr, iSz, bc)
    self.r:appRect(iX + iSz - bdr, iY,              bdr, iSz, bc)

    -- "i" dot (small square near top)
    local dotW = FT.px(3)
    local dotH = FT.py(3)
    self.r:appRect(iX + (iSz - dotW) * 0.5,
                   iY + iSz - FT.py(5) - dotH,
                   dotW, dotH, {ac[1], ac[2], ac[3], 1.00})

    -- "i" stem (taller rect below dot)
    local stW = FT.px(2.5)
    local stH = FT.py(5.5)
    self.r:appRect(iX + (iSz - stW) * 0.5,
                   iY + FT.py(3.5),
                   stW, stH, {ac[1], ac[2], ac[3], 1.00})

    -- Clickable hit-box
    local sk   = stateKey
    local appId = self.system.currentApp
    local btn = {
        x = iX, y = iY, w = iSz, h = iSz,
        meta = { onClick = function()
            self[sk] = true
            self:switchApp(appId)
        end }
    }
    table.insert(self._contentBtns, btn)
    return btn
end

--- Renders a full-screen help sub-page for an app.
--- Call this at the TOP of a drawer function, before any other drawing.
--- If self[stateKey] is false the function returns false immediately and
--- the caller should fall through to its normal render path.
--- If self[stateKey] is true the help page is rendered and the function
--- returns true — the caller should `return` immediately after.
---
---@param stateKey    string  Same key passed to drawInfoIcon.
---@param appId       string  FT.APP.xxx constant — used by the BACK button to return.
---@param headerTitle string  Title shown in the app header.
---@param accentColor table   RGBA accent color for entry title bars.
---@param entries     table   Array of { title=string, body=string } tables.
---                           Body supports "\n" for multiple lines.
---@return boolean  true when the help page was rendered (caller must return).
function FarmTabletUI:drawHelpPage(stateKey, appId, headerTitle, accentColor, entries)
    if not self[stateKey] then return false end

    local ac     = accentColor or FT.C.BRAND
    local startY = self:drawAppHeader(headerTitle, "Help")
    local x, contentY, w, _ = self:contentInner()
    local y = startY

    -- BACK button
    local bw = FT.px(52)
    local bh = FT.py(18)
    local backBtn = self.r:button(
        x + w - bw, startY + FT.py(2), bw, bh, "< BACK", FT.C.BTN_NEUTRAL,
        { onClick = function()
            self[stateKey] = false
            self:switchApp(appId)
        end }
    )
    table.insert(self._contentBtns, backBtn)

    y = y - FT.py(10)

    for _, entry in ipairs(entries) do
        if y < contentY + FT.py(12) then break end

        -- Tinted title bar
        self.r:appRect(x - FT.px(4), y - FT.py(1),
            w + FT.px(8), FT.py(14),
            {ac[1], ac[2], ac[3], 0.12})
        self.r:appText(x, y, FT.FONT.SMALL, entry.title,
            RenderText.ALIGN_LEFT, FT.C.TEXT_ACCENT)
        y = y - FT.py(16)

        -- Body lines
        for line in ((entry.body or "") .. "\n"):gmatch("([^\n]*)\n") do
            if y < contentY + FT.py(8) then break end
            self.r:appText(x + FT.px(8), y, FT.FONT.TINY,
                line, RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
            y = y - FT.py(13)
        end
        y = y - FT.py(5)
    end

    return true
end

--- Registers the total rendered height of a scrollable app so the system
--- can compute how much overflow exists and enable the scroll wheel.
--- Call this at the end of a drawer function that renders more content
--- than the content area can display at once.
---@param totalH number  Distance from content top to the lowest drawn element (normalised units)
function FarmTabletUI:setContentHeight(totalH)
    local _, _, _, ch = self:contentInner()
    self._contentScrollMax  = math.max(0, totalH - ch)
    self._contentScrollStep = FT.py(22)
    -- Clamp current scroll in case content shrank (e.g. after a filter change)
    self._contentScrollY = math.min(self._contentScrollY or 0, self._contentScrollMax)
end

--- Draws a vertical scroll bar indicator on the right edge of the content area.
--- Call this at the end of a drawer function if the app supports scrolling.
function FarmTabletUI:drawScrollBar()
    local scrollMax = self._contentScrollMax or 0
    if scrollMax <= 0 then return end

    local cx, cy, cw, ch = self:contentInner()
    local barX     = cx + cw + FT.px(4)
    local barY     = cy
    local barH     = ch
    local barW     = FT.px(4)

    -- Track (dark background)
    self.r:appRect(barX, barY, barW, barH, {0.12, 0.14, 0.20, 0.85})

    -- Thumb — height represents the ratio of visible content to total content
    local total    = ch + scrollMax
    local thumbH   = math.max(FT.py(14), barH * (ch / total))
    local scrolled = self._contentScrollY or 0
    local thumbY   = barY + barH - thumbH - (barH - thumbH) * (scrolled / scrollMax)

    -- Draw thumb with brand color
    self.r:appRect(barX, thumbY, barW, thumbH,
        {FT.C.BRAND[1], FT.C.BRAND[2], FT.C.BRAND[3], 0.80})

    -- Tiny "scroll" label hint
    self.r:appText(barX + barW + FT.px(4), barY + barH - FT.py(10),
        FT.FONT.TINY, "scroll", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
end

--- Returns the raw content area (x, y, w, h) with no padding applied.
function FarmTabletUI:content()
    return FT.LAYOUT.contentX, FT.LAYOUT.contentY,
           FT.LAYOUT.contentW, FT.LAYOUT.contentH
end

--- Returns the content area inset by the standard padding (x, y, w, h).
--- App drawers should use this rather than FT.LAYOUT directly so padding
--- stays consistent across all apps.
function FarmTabletUI:contentInner()
    local px = FT.px(16)
    local py = FT.py(12)
    return FT.LAYOUT.contentX + px,
           FT.LAYOUT.contentY + py,
           FT.LAYOUT.contentW - px*2,
           FT.LAYOUT.contentH - py*2
end

--- Draws the standard two-line app title bar (title + optional right-aligned subtitle)
--- with a coloured divider below it.
--- Returns the Y coordinate where scrollable content should begin (just below the divider).
---@param title    string  Primary app title
---@param subtitle string? Optional right-aligned secondary label
function FarmTabletUI:drawAppHeader(title, subtitle)
    local x, y, w, h = self:contentInner()
    local topY = y + h - FT.py(2)

    local accent = FT.appColor(self.system.currentApp)

    self.r:appText(x, topY, FT.FONT.TITLE, title,
        RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)

    if subtitle then
        self.r:appText(x + w, topY, FT.FONT.SMALL, subtitle,
            RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
    end

    -- Coloured divider line
    local divY = topY - FT.py(18)
    self.r:appRect(x, divY, w, math.max(FT.py(1.5), 0.001),
        {accent[1], accent[2], accent[3], 0.80})
    -- Soft glow beneath the divider
    self.r:appRect(x, divY - FT.py(2), w, FT.py(3),
        {accent[1], accent[2], accent[3], 0.12})

    return divY - FT.py(6)
end

--- Draws a label/value row and returns the next Y below it.
---@param y       number   Starting Y coordinate
---@param label   string   Left-aligned label text
---@param value   string   Right-aligned value text
---@param labelC  table?   RGBA color for label  (default: FT.C.TEXT_NORMAL)
---@param valueC  table?   RGBA color for value  (default: FT.C.TEXT_ACCENT)
function FarmTabletUI:drawRow(y, label, value, labelC, valueC)
    local x, _, w, _ = self:contentInner()
    self.r:row(x, y, w, label, value, labelC, valueC)
    return y - FT.py(FT.SP.ROW)
end

--- Draws a section header with a coloured left accent bar.
--- Returns the next Y below the header.
function FarmTabletUI:drawSection(y, label)
    local x, _, w, _ = self:contentInner()
    self.r:sectionHeader(x, y, w, label)
    return y - FT.py(18)
end

--- Draws a thin horizontal divider rule.
--- Returns the next Y below the rule.
---@param alpha number? Opacity (default 0.6)
function FarmTabletUI:drawRule(y, alpha)
    local x, _, w, _ = self:contentInner()
    self.r:rule(x, y, w, alpha)
    return y - FT.py(4)
end

--- Draws a horizontal progress bar spanning the full content width.
--- Returns the next Y below the bar.
---@param value  number  Current value
---@param maxVal number  Maximum value
---@param color  table?  RGBA bar fill color (default: FT.C.BRAND)
function FarmTabletUI:drawBar(y, value, maxVal, color)
    local x, _, w, _ = self:contentInner()
    return self.r:progressBar(x, y, w, value, maxVal, color)
end

--- Draws a single action button and registers it for click handling.
--- Returns (nextY, buttonDescriptor).
---@param y     number  Y coordinate for the button top
---@param label string  Button label text
---@param color table   Background RGBA color
---@param meta  table   Table with onClick callback: { onClick = function() ... end }
function FarmTabletUI:drawButton(y, label, color, meta)
    local x, _, w, _ = self:contentInner()
    local bw = FT.px(90)
    local bh = FT.py(22)
    local btn = self.r:button(x, y, bw, bh, label, color, meta)
    table.insert(self._contentBtns, btn)
    return y - bh - FT.py(4), btn
end

--- Draws two action buttons side by side and registers both for click handling.
--- Returns (nextY, btnA, btnB).
function FarmTabletUI:drawButtonPair(y, labelA, colorA, metaA, labelB, colorB, metaB)
    local x, _, w, _ = self:contentInner()
    local bw = FT.px(100)
    local bh = FT.py(22)
    local gap = FT.px(8)
    local btnA = self.r:button(x,        y, bw, bh, labelA, colorA, metaA)
    local btnB = self.r:button(x+bw+gap, y, bw, bh, labelB, colorB, metaB)
    table.insert(self._contentBtns, btnA)
    table.insert(self._contentBtns, btnB)
    return y - bh - FT.py(4), btnA, btnB
end

-- ─────────────────────────────────────────────────────────
-- DEFAULT SCREENS
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_drawWelcome()
    local startY = self:drawAppHeader("Farm Tablet", "v" .. FT.VERSION)
    local y = startY
    local x, _, w, _ = self:contentInner()

    y = y - FT.py(10)
    self.r:appText(x, y, FT.FONT.BODY,
        "Welcome! Select an app from the sidebar.",
        RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
    y = y - FT.py(22)
    self.r:appText(x, y, FT.FONT.SMALL,
        "Press  " .. self.settings.tabletKeybind .. "  to close.",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
end

function FarmTabletUI:_drawError(msg)
    local startY = self:drawAppHeader("App Error", "")
    local x, _, _, _ = self:contentInner()
    self.r:appText(x, startY - FT.py(8), FT.FONT.SMALL,
        tostring(msg), RenderText.ALIGN_LEFT, FT.C.NEGATIVE)
end

-- ─────────────────────────────────────────────────────────
-- SWITCH APP
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:switchApp(appId)
    if not self.system.registry:has(appId) then return false end
    local app = self.system.registry:get(appId)
    if not app or not app.enabled then return false end

    -- Play click sound when switching apps (if enabled)
    local s = self.settings
    if s and s.soundEffects and s.soundOnAppSelect and appId ~= self.system.currentApp then
        self:playUISound("click")
    end

    self.system.currentApp = appId
    -- Reset content scroll on every app switch
    self._contentScrollY   = 0
    self._contentScrollMax = 0

    if self.isOpen then
        -- Refresh sidebar active states (persistent overlays must be rebuilt)
        self.r:destroyAll()
        self._iconBtns    = {}
        self._contentBtns = {}
        self:_drawChrome()
        self:_drawSidebar()
        self:_drawContent()
    end

    FT_EventBus:emit(FT_EventBus.EVENTS.APP_SWITCHED, appId)
    return true
end

-- ─────────────────────────────────────────────────────────
-- DRAW / UPDATE (FS25 drawable interface)
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:draw()
    if not self.isOpen then return end
    -- Pass content-area bounds for vertical clip culling of scrolled items
    local clipY = FT.LAYOUT.contentY
    local clipH = FT.LAYOUT.contentH
    self.r:flush(clipY, clipH)
    -- Render the edit-mode chrome overlay on top of everything
    self:_drawEditOverlay()
end

function FarmTabletUI:update(dt)
    if not self.isOpen then return end

    -- Edit mode per-frame logic (camera freeze, cursor assert, auto-exit)
    self:_updateEditMode(dt)

    -- Freeze camera while tablet is open (edit mode handles its own freeze)
    -- Must re-assert cursor every frame — the engine resets it otherwise,
    -- which re-enables mouse camera rotation.
    if not self._editModeActive then
        if g_inputBinding and g_inputBinding.setShowMouseCursor then
            g_inputBinding:setShowMouseCursor(true)
        end
        if self._tabletCamRotX and g_cameraManager and setRotation then
            local cam = g_cameraManager:getActiveCamera()
            if cam and cam ~= 0 then
                setRotation(cam, self._tabletCamRotX, self._tabletCamRotY, self._tabletCamRotZ)
            end
        end
    end

    -- Poll scroll wheel for sidebar navigation (FS25 has no mouseWheelEvent callback)
    self:_pollSidebarScroll()

    -- Poll scroll wheel for content area (Settings and other tall apps)
    self:_pollContentScroll()

    -- Forward to app-specific updaters
    local appId = self.system.currentApp
    if appId == FT.APP.DIGGING then
        if self.updateDiggingApp then self:updateDiggingApp(dt) end
    end

    -- Refresh topbar each frame (clock ticks)
    -- We do a lightweight refresh: clear just the text entries for topbar
    -- by rebuilding the whole chrome text. Cheap in Lua.
    -- (Only if visible and timer allows)
    self._clockTimer = (self._clockTimer or 0) + dt
    if self._clockTimer >= 2000 then
        self._clockTimer = 0
        -- Remove old topbar texts by rebuilding chrome's text pass
        -- Cheapest approach: flush rebuild topbar only
        self:_refreshTopbar()
    end

    -- Live content refresh — re-draw app content on a timer so data
    -- stays current while the tablet is open (field levels, animals, etc.)
    -- Skip during edit mode (dragging/resizing) to avoid visual noise.
    self._contentTimer = (self._contentTimer or 0) + dt
    if self._contentTimer >= 4000 and not self._editModeActive then
        self._contentTimer = 0
        self:_drawContent()
    end
end

function FarmTabletUI:_refreshTopbar()
    if not self.isOpen then return end
    -- NOTE: This wipes ALL persistent text (self.r._texts) and re-adds only the chrome
    -- text entries. Any persistent r:text() calls made outside of _drawChrome() /
    -- _drawSidebar() will be silently lost until the next full rebuild.
    -- This is intentional and acceptable because the only persistent text is chrome text.
    -- Do NOT add permanent r:text() calls in app drawers — use r:appText() instead.
    self.r._texts = {}
    -- Re-draw brand labels in sidebar (positions match _drawChrome)
    local L = FT.LAYOUT
    local logoH = FT.py(38)
    self.r:text(L.sidebarX + L.sidebarW/2,
               L.sidebarY + logoH - FT.py(24),
               FT.FONT.TINY, "FARM", RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
    self.r:text(L.sidebarX + L.sidebarW/2,
               L.sidebarY + logoH - FT.py(12),
               FT.FONT.TINY, "TABLET", RenderText.ALIGN_CENTER,
               {FT.C.BRAND[1], FT.C.BRAND[2], FT.C.BRAND[3], 1.0})
    self.r:text(L.sidebarX + L.sidebarW/2,
               L.sidebarY + logoH - FT.py(3),
               FT.FONT.TINY, "v" .. FT.VERSION,
               RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)
    -- Sidebar icon labels
    local apps = self.system.registry:getAll()
    local iconW  = L.sidebarW - FT.px(10)
    local iconH  = FT.py(ICON_SIZE_REF * 0.72)
    local gap    = FT.py(ICON_GAP_REF)
    local ix     = L.sidebarX + FT.px(5)
    local logoH  = FT.py(38)
    local availH = L.sidebarH - logoH - FT.py(10)
    local slotH  = iconH + gap
    local visibleMax = math.floor(availH / slotH)
    local startY = L.sidebarY + logoH + FT.py(6)
    local currentApp = self.system.currentApp
    for i, app in ipairs(apps) do
        local slot = i - 1 - (self._sidebarScrollOffset or 0)
        if slot >= 0 and slot < visibleMax then
            local iy = startY + slot * slotH
            local isActive = (app.id == currentApp)
            local label = app.navLabel or string.upper(string.sub(app.id, 1, 4))
            self.r:text(ix + iconW/2, iy + iconH/2 - FT.py(3),
                   FT.FONT.SMALL, label, RenderText.ALIGN_CENTER,
                   isActive and FT.C.TEXT_BRIGHT or FT.C.TEXT_DIM)
        end
    end
    -- Close button label
    if self._closeBtn then
        local cb = self._closeBtn
        self.r:text(cb.x + cb.w/2, cb.y + cb.h/2 - FT.py(3),
                   FT.FONT.SMALL, "X", RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
    end
    -- Topbar dynamic content
    self:_drawTopbar()
end

-- ─────────────────────────────────────────────────────────
-- SCROLL INPUT (sidebar — polled each frame via update)
-- FS25 exposes scroll wheel as Input.isMouseButtonPressed,
-- NOT as a mouseWheelEvent callback. We poll in update().
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_pollSidebarScroll()
    if not self.isOpen then return end
    local L = FT.LAYOUT

    -- Only scroll when cursor is over the sidebar
    local px, py = self._mouseX, self._mouseY
    if not (px >= L.sidebarX and px <= L.sidebarX + L.sidebarW and
            py >= L.sidebarY and py <= L.sidebarY + L.sidebarH) then
        self._wheelUpWas   = false
        self._wheelDownWas = false
        return
    end

    -- Edge-detect: only fire once per physical wheel tick
    local upNow   = Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP)
    local downNow = Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN)

    local dir = nil
    if upNow   and not self._wheelUpWas   then dir = -1 end  -- scroll up → earlier apps
    if downNow and not self._wheelDownWas then dir =  1 end  -- scroll down → later apps

    self._wheelUpWas   = upNow
    self._wheelDownWas = downNow

    if dir == nil then return end

    local newOffset = math.max(0,
        math.min((self._sidebarScrollOffset or 0) + dir,
                 self._sidebarMaxScroll or 0))

    if newOffset ~= self._sidebarScrollOffset then
        self._sidebarScrollOffset = newOffset
        self.r:destroyAll()
        self._iconBtns    = {}
        self._contentBtns = {}
        self:_drawChrome()
        self:_drawSidebar()
        self:_drawContent()
    end
end

-- ─────────────────────────────────────────────────────────
-- CONTENT AREA SCROLL  (Settings and other tall apps)
-- Uses separate wheel-state trackers so sidebar and content
-- scroll don't interfere with each other.
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_pollContentScroll()
    if not self.isOpen then return end
    -- Only scroll when cursor is over the content area (not sidebar)
    local L  = FT.LAYOUT
    local px = self._mouseX
    local py = self._mouseY
    if not (L.contentX and L.contentW) then return end
    if not (px >= L.contentX and px <= L.contentX + L.contentW and
            py >= L.contentY and py <= L.contentY + L.contentH) then
        self._cWheelUpWas   = false
        self._cWheelDownWas = false
        return
    end

    -- No scrollable content for this app → bail early
    if (self._contentScrollMax or 0) <= 0 then
        self._cWheelUpWas   = false
        self._cWheelDownWas = false
        return
    end

    local upNow   = Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP)
    local downNow = Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN)

    local dir = nil
    if upNow   and not self._cWheelUpWas   then dir =  1 end  -- wheel up   → scroll content up (reveal top)
    if downNow and not self._cWheelDownWas then dir = -1 end  -- wheel down → scroll content down (reveal bottom)

    self._cWheelUpWas   = upNow
    self._cWheelDownWas = downNow

    if dir == nil then return end

    local step    = self._contentScrollStep or FT.py(22)
    local newScroll = math.max(0,
        math.min((self._contentScrollY or 0) + dir * step,
                 self._contentScrollMax or 0))

    if math.abs(newScroll - (self._contentScrollY or 0)) > 0.0001 then
        self._contentScrollY = newScroll
        -- Rebuild only the content layer (cheap — no chrome rebuild needed)
        self.r:clearAppLayer()
        self._contentBtns = {}
        self:_drawContent()
    end
end

-- ─────────────────────────────────────────────────────────
-- MOUSE INPUT
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_onMouse(px, py, isDown, isUp, btn)
    if not self.isOpen then return false end

    -- Always track cursor position (needed for scroll hover detection)
    self._mouseX = px
    self._mouseY = py

    if not isDown then return false end

    -- Close button
    if self._closeBtn then
        local c = self._closeBtn
        if px >= c.x and px <= c.x+c.w and py >= c.y and py <= c.y+c.h then
            self:closeTablet()
            return true
        end
    end

    -- Sidebar icons
    for _, ib in ipairs(self._iconBtns) do
        if px >= ib.x and px <= ib.x+ib.w and py >= ib.y and py <= ib.y+ib.h then
            self:switchApp(ib.appId)
            return true
        end
    end

    -- Content-area buttons (registered by app drawers)
    for _, cb in ipairs(self._contentBtns) do
        if not cb._isText and
           px >= cb.x and px <= cb.x+cb.w and
           py >= cb.y and py <= cb.y+cb.h then
            if cb.meta and cb.meta.onClick then
                cb.meta.onClick()
            end
            return true
        end
    end

    return false
end

-- ─────────────────────────────────────────────────────────
-- CLEANUP
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_destroy()
    -- Exit edit mode cleanly before tearing down
    if self._editModeActive then
        self:_exitEditMode()
    end
    if self._editBgOverlay then
        delete(self._editBgOverlay)
        self._editBgOverlay = nil
    end
    self.r:destroyAll()
    self._iconBtns    = {}
    self._contentBtns = {}
    self._closeBtn    = nil
end

function FarmTabletUI:delete()
    self:_destroy()
end

function FarmTabletUI:log(msg, ...)
    if self.settings.debugMode then
        Logging.info("[FarmTablet UI] " .. string.format(msg, ...))
    end
end


-- ── Sound helpers ─────────────────────────────────────────

function FarmTabletUI:playUISound(soundType)
    -- soundType: "click" | "paging" | "back"
    local s = self.settings
    if not (s and s.soundEffects) then return end
    pcall(function()
        if not (g_gui and g_gui.guiSoundPlayer) then return end
        if soundType == "click" then
            g_gui.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
        elseif soundType == "paging" then
            g_gui.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.PAGING)
        elseif soundType == "back" then
            g_gui.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.BACK)
        end
    end)
end