-- =========================================================
-- FarmTablet v2 – FarmTabletUIEditMode
-- Edit mode: drag, resize, and position for the tablet HUD.
-- Extends FarmTabletUI — must be sourced AFTER FarmTabletUI.lua
-- =========================================================

-- ── Entry / Exit ─────────────────────────────────────────

function FarmTabletUI:toggleEditMode()
    if self._editModeActive then
        self:_exitEditMode()
    else
        self:_enterEditMode()
    end
end

function FarmTabletUI:_enterEditMode()
    self._editModeActive = true
    self._emDragging     = false
    self._emResizing     = false
    self._emEdgeDragging = nil

    -- Create pixel overlay if not already present
    if not self._editBgOverlay and createImageOverlay then
        self._editBgOverlay = createImageOverlay("dataS/menu/base/graph_pixel.dds")
    end

    -- Show cursor
    if g_inputBinding and g_inputBinding.setShowMouseCursor then
        g_inputBinding:setShowMouseCursor(true)
    end

    -- Freeze camera
    if g_cameraManager and getRotation then
        local cam = g_cameraManager:getActiveCamera()
        if cam and cam ~= 0 then
            self._emCamRotX, self._emCamRotY, self._emCamRotZ = getRotation(cam)
        end
    end

    -- Hook right-click into the mouse handler to exit edit mode
    self:_registerEditMouseHandler()

    Logging.info("[FarmTablet] Edit mode ON — drag to move, corners to resize, right-click to exit")
end

function FarmTabletUI:_exitEditMode()
    self._editModeActive = false
    self._emDragging     = false
    self._emResizing     = false
    self._emEdgeDragging = nil
    self._emHoverCorner  = nil
    self._emCamRotX      = nil
    self._emCamRotY      = nil
    self._emCamRotZ      = nil

    if g_inputBinding and g_inputBinding.setShowMouseCursor then
        g_inputBinding:setShowMouseCursor(false)
    end

    self:_saveEditPosition()
    self:_unregisterEditMouseHandler()

    Logging.info("[FarmTablet] Edit mode OFF — position/scale saved")
end

-- ── Settings sync ─────────────────────────────────────────

function FarmTabletUI:applyPositionFromSettings()
    local s = self.settings
    -- The tablet is re-centred inside _build() from tabletPosX/Y,
    -- so we just need to trigger a rebuild if the tablet is open.
    if self.isOpen then
        self.r:destroyAll()
        self._iconBtns    = {}
        self._contentBtns = {}
        self:_build()
    end
end

function FarmTabletUI:_saveEditPosition()
    -- tabletPosX/Y is stored as the normalized screen position of the tablet centre.
    -- We derive it from FT.LAYOUT which is set during _build().
    local s = self.settings
    if FT.LAYOUT and FT.LAYOUT.tabletX and FT.LAYOUT.tabletW then
        s.tabletPosX = FT.LAYOUT.tabletX + FT.LAYOUT.tabletW * 0.5
        s.tabletPosY = FT.LAYOUT.tabletY + FT.LAYOUT.tabletH * 0.5
    end
    s.tabletScale     = self._emCurrentScale    or 1.0
    s.tabletWidthMult = self._emCurrentWidthMult or 1.0
    s:save()
end

-- ── Mouse handler registration ────────────────────────────

function FarmTabletUI:_registerEditMouseHandler()
    -- Inject our edit-mode mouse handler before the normal tablet handler
    -- We store it so we can remove it on exit
    self._editMouseHandler = function(mission, px, py, isDown, isUp, btn)
        if self:_onEditMouse(px, py, isDown, isUp, btn) then return true end
        return false
    end

    if g_currentMission then
        local prevHandler = g_currentMission.mouseEvent
        self._editPrevMouseEvent = prevHandler
        g_currentMission.mouseEvent = function(mission, px, py, isDown, isUp, btn)
            if self._editMouseHandler and self._editMouseHandler(mission, px, py, isDown, isUp, btn) then
                return true
            end
            if self._editPrevMouseEvent then
                return self._editPrevMouseEvent(mission, px, py, isDown, isUp, btn)
            end
            return false
        end
    end
end

function FarmTabletUI:_unregisterEditMouseHandler()
    if g_currentMission and self._editPrevMouseEvent then
        g_currentMission.mouseEvent = self._editPrevMouseEvent
    end
    self._editMouseHandler    = nil
    self._editPrevMouseEvent  = nil
end

-- ── Edit-mode mouse logic ─────────────────────────────────

function FarmTabletUI:_onEditMouse(px, py, isDown, isUp, btn)
    if not self._editModeActive then return false end

    -- Right-click exits edit mode (button == 2 is right mouse in FS25)
    if isDown and btn == 2 then
        self:_exitEditMode()
        return true
    end

    local hudX = FT.LAYOUT.tabletX
    local hudY = FT.LAYOUT.tabletY
    local hudW = FT.LAYOUT.tabletW
    local hudH = FT.LAYOUT.tabletH

    if not (hudX and hudW) then return false end

    if isDown and btn == 1 then
        -- 1) Corner resize handles
        local corner = self:_emHitTestCorner(px, py)
        if corner then
            self._emResizing      = true
            self._emDragging      = false
            self._emEdgeDragging  = nil
            self._emResizeStartX  = px
            self._emResizeStartY  = py
            self._emResizeStartS  = self._emCurrentScale or 1.0
            return true
        end

        -- 2) Edge width handles
        local edge = self:_emHitTestEdge(px, py)
        if edge then
            self._emEdgeDragging  = edge
            self._emDragging      = false
            self._emResizing      = false
            self._emEdgeStartX    = px
            self._emEdgeStartW    = self._emCurrentWidthMult or 1.0
            return true
        end

        -- 3) Body drag
        if px >= hudX and px <= hudX + hudW and py >= hudY and py <= hudY + hudH then
            self._emDragging     = true
            self._emResizing     = false
            self._emEdgeDragging = nil
            self._emDragOffX     = px - hudX
            self._emDragOffY     = py - hudY
            return true
        end
    end

    if isUp and btn == 1 then
        if self._emDragging or self._emResizing or self._emEdgeDragging then
            self._emDragging     = false
            self._emResizing     = false
            self._emEdgeDragging = nil
            self:_saveEditPosition()
            return true
        end
    end

    -- Mouse move (isDown == false, isUp == false)
    if not isDown and not isUp then
        if self._emDragging then
            local newX = px - self._emDragOffX
            local newY = py - self._emDragOffY
            self:_emApplyPosition(newX, newY)
            return true
        end

        if self._emResizing then
            local dx = px - self._emResizeStartX
            local dy = py - self._emResizeStartY
            local cx = hudX + hudW * 0.5
            local cy = hudY + hudH * 0.5
            local startDist = math.sqrt((self._emResizeStartX-cx)^2 + (self._emResizeStartY-cy)^2)
            local currDist  = math.sqrt((px-cx)^2 + (py-cy)^2)
            local delta = (currDist - startDist) * 2.0
            local newS = self._emResizeStartS + delta
            self._emCurrentScale = math.max(self.EM_MIN_SCALE, math.min(self.EM_MAX_SCALE, newS))
            self:_emRebuild()
            return true
        end

        if self._emEdgeDragging then
            local dx = px - self._emEdgeStartX
            if self._emEdgeDragging == "left" then dx = -dx end
            local newW = self._emEdgeStartW + dx * 3.0
            self._emCurrentWidthMult = math.max(self.EM_MIN_WIDTH, math.min(self.EM_MAX_WIDTH, newW))
            self:_emRebuild()
            return true
        end

        -- Hover detection
        self._emHoverCorner = self:_emHitTestCorner(px, py)
    end

    return false
end

-- ── Geometry helpers ──────────────────────────────────────

function FarmTabletUI:_emGetHandleRects()
    local x = FT.LAYOUT.tabletX or 0
    local y = FT.LAYOUT.tabletY or 0
    local w = FT.LAYOUT.tabletW or 0
    local h = FT.LAYOUT.tabletH or 0
    local hs = self.EM_HANDLE_SIZE
    return {
        bl = { x = x,         y = y,         w = hs, h = hs },
        br = { x = x+w-hs,    y = y,         w = hs, h = hs },
        tl = { x = x,         y = y+h-hs,    w = hs, h = hs },
        tr = { x = x+w-hs,    y = y+h-hs,    w = hs, h = hs },
    }
end

function FarmTabletUI:_emHitTestCorner(px, py)
    local rects = self:_emGetHandleRects()
    for key, r in pairs(rects) do
        if px >= r.x and px <= r.x+r.w and py >= r.y and py <= r.y+r.h then
            return key
        end
    end
    return nil
end

function FarmTabletUI:_emHitTestEdge(px, py)
    local x = FT.LAYOUT.tabletX or 0
    local y = FT.LAYOUT.tabletY or 0
    local w = FT.LAYOUT.tabletW or 0
    local h = FT.LAYOUT.tabletH or 0
    local ew = 0.009  -- edge hit zone width
    if px >= x-ew/2 and px <= x+ew/2 and py >= y and py <= y+h then return "left"  end
    if px >= x+w-ew/2 and px <= x+w+ew/2 and py >= y and py <= y+h then return "right" end
    return nil
end

-- ── Apply + Rebuild ───────────────────────────────────────

function FarmTabletUI:_emApplyPosition(newTabletX, newTabletY)
    -- Clamp so the tablet cannot leave the screen
    local w = FT.LAYOUT.tabletW or 0
    local h = FT.LAYOUT.tabletH or 0
    newTabletX = math.max(0, math.min(1 - w, newTabletX))
    newTabletY = math.max(0, math.min(1 - h, newTabletY))

    -- Store centre for settings
    local s = self.settings
    s.tabletPosX = newTabletX + w * 0.5
    s.tabletPosY = newTabletY + h * 0.5

    -- Shift all layout zones by the delta
    local dx = newTabletX - FT.LAYOUT.tabletX
    local dy = newTabletY - FT.LAYOUT.tabletY

    FT.LAYOUT.tabletX = newTabletX
    FT.LAYOUT.tabletY = newTabletY
    FT.LAYOUT.sidebarX = FT.LAYOUT.sidebarX + dx
    FT.LAYOUT.sidebarY = FT.LAYOUT.sidebarY + dy
    FT.LAYOUT.topbarX  = FT.LAYOUT.topbarX  + dx
    FT.LAYOUT.topbarY  = FT.LAYOUT.topbarY  + dy
    FT.LAYOUT.contentX = FT.LAYOUT.contentX + dx
    FT.LAYOUT.contentY = FT.LAYOUT.contentY + dy

    -- Rebuild all drawables with updated layout
    self:_emRebuild()
end

function FarmTabletUI:_emRebuild()
    -- Store current edit overrides before full rebuild wipes layout
    local posX = FT.LAYOUT.tabletX
    local posY = FT.LAYOUT.tabletY

    self.r:destroyAll()
    self._iconBtns    = {}
    self._contentBtns = {}

    -- Full build recomputes layout from settings values
    self.settings.tabletPosX = posX + (FT.LAYOUT.tabletW or 0) * 0.5
    self.settings.tabletPosY = posY + (FT.LAYOUT.tabletH or 0) * 0.5
    if self._emCurrentScale then
        self.settings.tabletScale = self._emCurrentScale
    end
    if self._emCurrentWidthMult then
        self.settings.tabletWidthMult = self._emCurrentWidthMult
    end

    self:_build()
end

-- ── Per-frame update + draw for edit mode ─────────────────

function FarmTabletUI:_updateEditMode(dt)
    if not self._editModeActive then return end

    self._editAnimTimer = self._editAnimTimer + dt * 0.001  -- dt is ms

    -- Keep cursor visible (engine may reset it)
    if g_inputBinding and g_inputBinding.setShowMouseCursor then
        g_inputBinding:setShowMouseCursor(true)
    end

    -- Freeze camera rotation
    if self._emCamRotX and g_cameraManager and setRotation then
        local cam = g_cameraManager:getActiveCamera()
        if cam and cam ~= 0 then
            setRotation(cam, self._emCamRotX, self._emCamRotY, self._emCamRotZ)
        end
    end

    -- Auto-exit if a dialog or GUI overlay opens
    if g_gui and (g_gui:getIsGuiVisible() or g_gui:getIsDialogVisible()) then
        self:_exitEditMode()
    end
end

function FarmTabletUI:_drawEditOverlay()
    if not self._editModeActive then return end
    if not self._editBgOverlay  then return end

    local x = FT.LAYOUT.tabletX or 0
    local y = FT.LAYOUT.tabletY or 0
    local w = FT.LAYOUT.tabletW or 0
    local h = FT.LAYOUT.tabletH or 0

    local pulse = 0.5 + 0.5 * math.sin(self._editAnimTimer * 4)
    local bAlpha = 0.4 + 0.4 * pulse
    local bw     = 0.0025

    -- Pulsing border: green during resize/edge-drag, blue otherwise
    local isResizingAny = self._emResizing or (self._emEdgeDragging ~= nil)
    local br, bg, bb = 0.30, 0.50, 0.90
    if isResizingAny then br, bg, bb = 0.30, 0.90, 0.30 end

    setOverlayColor(self._editBgOverlay, br, bg, bb, bAlpha)
    renderOverlay(self._editBgOverlay, x,       y+h-bw, w,  bw)  -- top
    renderOverlay(self._editBgOverlay, x,       y,      w,  bw)  -- bottom
    renderOverlay(self._editBgOverlay, x,       y,      bw, h )  -- left
    renderOverlay(self._editBgOverlay, x+w-bw,  y,      bw, h )  -- right

    -- Edge width handles (left and right mid-strips)
    local ehw    = 0.004
    local inset  = h * 0.15
    local eH     = h - inset * 2
    local eY     = y + inset
    local lcol   = (self._emEdgeDragging == "left")  and {0.30,0.90,0.30,0.80} or {0.30,0.50,0.90,0.60}
    local rcol   = (self._emEdgeDragging == "right") and {0.30,0.90,0.30,0.80} or {0.30,0.50,0.90,0.60}
    setOverlayColor(self._editBgOverlay, lcol[1],lcol[2],lcol[3],lcol[4])
    renderOverlay(self._editBgOverlay, x - ehw/2, eY, ehw, eH)
    setOverlayColor(self._editBgOverlay, rcol[1],rcol[2],rcol[3],rcol[4])
    renderOverlay(self._editBgOverlay, x+w - ehw/2, eY, ehw, eH)

    -- Corner resize handles
    local handles = self:_emGetHandleRects()
    for key, rect in pairs(handles) do
        local hcol
        if self._emResizing then
            hcol = {0.30,0.90,0.30,0.80}
        elseif self._emHoverCorner == key then
            hcol = {0.50,0.70,1.00,0.90}
        else
            hcol = {0.30,0.50,0.90,0.60}
        end
        setOverlayColor(self._editBgOverlay, hcol[1],hcol[2],hcol[3],hcol[4])
        renderOverlay(self._editBgOverlay, rect.x, rect.y, rect.w, rect.h)
    end

    -- Help label at bottom of screen
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(0.70, 0.85, 1.0, 0.90)
    renderText(0.5, 0.04, 0.010,
        "TABLET EDIT MODE  |  Drag: move  |  Corners: scale  |  Edges: width  |  Right-click: exit")
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1,1,1,1)
end
