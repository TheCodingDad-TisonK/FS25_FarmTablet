-- =========================================================
-- FarmTablet v2 – Renderer
-- Centralized drawing API. All visual output goes through here.
-- =========================================================
---@class FT_Renderer
FT_Renderer = {}
local FT_Renderer_mt = Class(FT_Renderer)

function FT_Renderer.new()
    local self = setmetatable({}, FT_Renderer_mt)
    self._overlays   = {}      -- {overlay, layer}
    self._texts      = {}      -- {x,y,size,align,color,text}
    self._buttons    = {}      -- managed hitboxes (cleared per-app)
    self._appLayer   = {}      -- sub-list cleared on app switch
    self._coverLayer = {}      -- drawn LAST to clip scrolled content (rebuilt with chrome)
    return self
end

-- ── Internal helpers ──────────────────────────────────────
function FT_Renderer:_newOverlay(x, y, w, h, color, sliceId)
    local ov
    if sliceId and sliceId ~= "" then
        ov = g_overlayManager:createOverlay(sliceId, x, y, w, h)
    else
        ov = g_overlayManager:createOverlay(g_plainColorSliceId, x, y, w, h)
    end

    if ov ~= nil then
        if color then ov:setColor(unpack(color)) end
        ov:setVisible(true)
    else
        Logging.warning("FarmTablet: Could not create overlay for sliceId: %s", tostring(sliceId))
    end
    return ov
end

-- ── Public drawing functions ──────────────────────────────

--- Draws a persistent overlay rectangle (lives until destroyAll).
--- Use for chrome elements that should survive app switches.
function FT_Renderer:rect(x, y, w, h, color, sliceId)
    local ov = self:_newOverlay(x, y, w, h, color, sliceId)
    table.insert(self._overlays, ov)
    return ov
end

--- Draws a cover overlay — rendered AFTER the app layer so it clips any
--- content that scrolls past the content-area boundaries. Rebuilt alongside
--- chrome; do NOT use inside app drawers.
function FT_Renderer:coverRect(x, y, w, h, color)
    local ov = self:_newOverlay(x, y, w, h, color)
    table.insert(self._coverLayer, ov)
    return ov
end

--- Draws an app-scoped overlay rectangle.
--- Cleared automatically on every app switch via clearAppLayer().
--- Stores y and h on the overlay for clip-culling during flush().
function FT_Renderer:appRect(x, y, w, h, color, sliceId)
    local ov = self:_newOverlay(x, y, w, h, color, sliceId)
    if ov then
        ov.y = y   -- stored for vertical clip culling in flush()
        ov.h = h
    end
    table.insert(self._appLayer, ov)
    return ov
end

--- Queues a persistent text entry (survives app switches, cleared only by destroyAll).
--- Use only for chrome-layer text (topbar, sidebar labels).
--- App drawers must use appText() instead.
function FT_Renderer:text(x, y, size, txt, align, color)
    table.insert(self._texts, {
        x = x, y = y, size = size or FT.FONT.BODY,
        text = tostring(txt),
        align = align or RenderText.ALIGN_LEFT,
        color = color or FT.C.TEXT_NORMAL,
    })
end

--- Queues an app-scoped text entry.
--- Stored in the _buttons table (which holds mixed text+button entries)
--- so both are cleared together on app switch.
function FT_Renderer:appText(x, y, size, txt, align, color)
    table.insert(self._buttons, {   -- mixed table: text entries have _isText=true
        _isText = true,
        x = x, y = y, size = size or FT.FONT.BODY,
        text = tostring(txt),
        align = align or RenderText.ALIGN_LEFT,
        color = color or FT.C.TEXT_NORMAL,
    })
end

--- Draws a clickable button (background rect + centred label).
--- Returns a descriptor table {ov, x, y, w, h, meta} for hit-testing.
--- The descriptor is NOT automatically inserted into FarmTabletUI._contentBtns;
--- callers must do that themselves if they want click handling.
function FT_Renderer:button(x, y, w, h, label, color, meta)
    local ov = self:appRect(x, y, w, h, color or FT.C.BTN_NEUTRAL)
    self:appText(x + w/2, y + h/2 - FT.py(3), FT.FONT.SMALL, label,
        RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
    local btn = { ov=ov, x=x, y=y, w=w, h=h, meta=meta }
    table.insert(self._buttons, btn)
    return btn
end

--- Draws a thin horizontal divider rule.
--- alpha: opacity of the rule line (default 0.6).
function FT_Renderer:rule(x, y, w, alpha)
    self:appRect(x, y, w, math.max(FT.py(1), 0.0009),
        {FT.C.RULE[1], FT.C.RULE[2], FT.C.RULE[3], alpha or 0.6})
end

--- Draws a horizontal progress bar.
--- Returns the Y coordinate immediately below the bar for chaining.
---@param value  number  current value
---@param maxVal number  maximum value (bar is full when value == maxVal)
---@param barColor table  RGBA color table; defaults to FT.C.BRAND
function FT_Renderer:progressBar(x, y, w, value, maxVal, barColor)
    local h = math.max(FT.py(5), 0.005)
    -- Track (dark background)
    self:appRect(x, y, w, h, FT.C.BG_PANEL)
    -- Fill
    local ratio = (maxVal and maxVal > 0) and math.min(value/maxVal, 1) or 0
    if ratio > 0 then
        self:appRect(x, y, w*ratio, h, barColor or FT.C.BRAND)
    end
    -- Subtle glow overlay when nearly full (> 90%)
    if ratio > 0.9 then
        self:appRect(x, y, w*ratio, h,
            {barColor and barColor[1] or FT.C.BRAND[1],
             barColor and barColor[2] or FT.C.BRAND[2],
             barColor and barColor[3] or FT.C.BRAND[3], 0.15})
    end
    return y - h - FT.py(2)
end

--- Draws a section heading with a coloured left accent bar.
function FT_Renderer:sectionHeader(x, y, contentW, label)
    self:appRect(x, y - FT.py(2), FT.px(3), FT.py(13), FT.C.BRAND)
    self:appText(x + FT.px(8), y, FT.FONT.SMALL, label,
        RenderText.ALIGN_LEFT, FT.C.TEXT_ACCENT)
end

--- Draws a label/value row with the label left-aligned and value right-aligned.
--- Pass nil for value to draw the label only.
function FT_Renderer:row(x, y, contentW, label, value, labelColor, valueColor)
    local padX = FT.px(14)
    self:appText(x + padX, y, FT.FONT.BODY, label,
        RenderText.ALIGN_LEFT, labelColor or FT.C.TEXT_NORMAL)
    if value ~= nil then
        self:appText(x + contentW - padX, y, FT.FONT.BODY, tostring(value),
            RenderText.ALIGN_RIGHT, valueColor or FT.C.TEXT_ACCENT)
    end
end

--- Draws a small filled badge/chip with a centred label.
--- Returns the badge width so callers can advance their X cursor.
function FT_Renderer:badge(x, y, label, color)
    local w = FT.px(36)
    local h = FT.py(13)
    self:appRect(x, y - FT.py(1), w, h, color or FT.C.BRAND_DIM)
    self:appText(x + w/2, y + h/2 - FT.py(2), FT.FONT.TINY, label,
        RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
    return w
end

-- ── Lifecycle ─────────────────────────────────────────────

--- Destroys all app-scoped overlays and clears the mixed buttons/text table.
--- Called automatically on every app switch.
function FT_Renderer:clearAppLayer()
    for _, item in ipairs(self._appLayer) do
        if item.delete then item:delete() end
    end
    self._appLayer = {}
    -- Remove text and buttons too
    self._buttons = {}
end

--- Destroys cover-layer overlays (chrome clip strips).
--- Called at the start of _drawChrome() so old strips are replaced cleanly.
function FT_Renderer:clearCoverLayer()
    for _, ov in ipairs(self._coverLayer) do
        if ov and ov.delete then ov:delete() end
    end
    self._coverLayer = {}
end

--- Full cleanup — destroys every overlay and clears all tables.
--- Called on tablet close and before a full layout rebuild.
function FT_Renderer:destroyAll()
    self:clearAppLayer()
    for _, ov in ipairs(self._overlays) do
        if ov and ov.delete then ov:delete() end
    end
    for _, ov in ipairs(self._coverLayer) do
        if ov and ov.delete then ov:delete() end
    end
    self._overlays   = {}
    self._coverLayer = {}
    self._texts      = {}
    self._buttons    = {}
end

--- Renders all queued drawables for the current frame.
--- Draw order: chrome overlays → app overlays (clipped) → cover strips → text.
--- clipY / clipH: content-area bounds used for vertical culling of app-layer items.
--- Items whose Y range does not intersect [clipY, clipY+clipH] are skipped.
function FT_Renderer:flush(clipY, clipH)
    local doClip = (clipY ~= nil and clipH ~= nil)
    local clipTop    = doClip and (clipY + clipH) or nil
    local clipBottom = doClip and clipY or nil

    local function inView(oy, oh)
        if not doClip then return true end
        return (oy + oh) >= clipBottom and oy <= clipTop
    end

    -- 1. Persistent base overlays (chrome body, background)
    for _, ov in ipairs(self._overlays) do
        if ov and ov.render then ov:render() end
    end
    -- 2. App overlays (scrolled content, clipped)
    for _, ov in ipairs(self._appLayer) do
        if ov and ov.render and not ov._isText then
            if not doClip or inView(ov.y or 0, ov.h or 0) then
                ov:render()
            end
        end
    end
    -- 3. Cover overlays (drawn on top of app-layer to clip overflow)
    for _, ov in ipairs(self._coverLayer) do
        if ov and ov.render then ov:render() end
    end
    -- 4. Persistent text
    for _, t in ipairs(self._texts) do
        setTextAlignment(t.align)
        setTextColor(unpack(t.color))
        renderText(t.x, t.y, t.size, t.text)
    end
    -- 5. App text (mixed in _buttons, clipped)
    for _, t in ipairs(self._buttons) do
        if t._isText then
            if not doClip or inView(t.y or 0, t.size or 0) then
                setTextAlignment(t.align)
                setTextColor(unpack(t.color))
                renderText(t.x, t.y, t.size, t.text)
            end
        end
    end
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
end

--- Hit-tests screen position (px, py) against all registered button descriptors.
--- Returns the first matching button table, or nil if no button was hit.
--- Text entries (_isText == true) are excluded from hit-testing.
function FT_Renderer:hitTest(px, py)
    for _, b in ipairs(self._buttons) do
        if not b._isText then
            if px >= b.x and px <= b.x + b.w and
               py >= b.y and py <= b.y + b.h then
                return b
            end
        end
    end
    return nil
end
