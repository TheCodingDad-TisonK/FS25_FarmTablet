-- =========================================================
-- FarmTablet v2 – Renderer
-- Centralized drawing API. All visual output goes through here.
-- =========================================================
---@class FT_Renderer
FT_Renderer = {}
local FT_Renderer_mt = Class(FT_Renderer)

function FT_Renderer.new()
    local self = setmetatable({}, FT_Renderer_mt)
    self._overlays = {}      -- {overlay, layer}
    self._texts    = {}      -- {x,y,size,align,color,text}
    self._buttons  = {}      -- managed hitboxes (cleared per-app)
    self._appLayer = {}      -- sub-list cleared on app switch
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

-- Persistent overlay (lives until destroyAll)
function FT_Renderer:rect(x, y, w, h, color, sliceId)
    local ov = self:_newOverlay(x, y, w, h, color, sliceId)
    table.insert(self._overlays, ov)
    return ov
end

-- App-scoped overlay (cleared on app switch)
function FT_Renderer:appRect(x, y, w, h, color, sliceId)
    local ov = self:_newOverlay(x, y, w, h, color, sliceId)
    table.insert(self._appLayer, ov)
    return ov
end

-- Text (persistent)
function FT_Renderer:text(x, y, size, txt, align, color)
    table.insert(self._texts, {
        x = x, y = y, size = size or FT.FONT.BODY,
        text = tostring(txt),
        align = align or RenderText.ALIGN_LEFT,
        color = color or FT.C.TEXT_NORMAL,
    })
end

-- App-scoped text (cleared on app switch)
function FT_Renderer:appText(x, y, size, txt, align, color)
    table.insert(self._buttons, {   -- reuse buttons table for mixed clearing
        _isText = true,
        x = x, y = y, size = size or FT.FONT.BODY,
        text = tostring(txt),
        align = align or RenderText.ALIGN_LEFT,
        color = color or FT.C.TEXT_NORMAL,
    })
end

-- Register a clickable button; returns descriptor for hit testing
function FT_Renderer:button(x, y, w, h, label, color, meta)
    local ov = self:appRect(x, y, w, h, color or FT.C.BTN_NEUTRAL)
    -- Button label
    self:appText(x + w/2, y + h/2 - FT.py(3), FT.FONT.SMALL, label,
        RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
    local btn = { ov=ov, x=x, y=y, w=w, h=h, meta=meta }
    table.insert(self._buttons, btn)
    return btn
end

-- Horizontal rule
function FT_Renderer:rule(x, y, w, alpha)
    self:appRect(x, y, w, math.max(FT.py(1), 0.0009),
        {FT.C.RULE[1], FT.C.RULE[2], FT.C.RULE[3], alpha or 0.6})
end

-- Progress bar (returns y below bar)
function FT_Renderer:progressBar(x, y, w, value, maxVal, barColor)
    local h = math.max(FT.py(5), 0.005)
    -- Track
    self:appRect(x, y, w, h, FT.C.BG_PANEL)
    -- Fill
    local ratio = (maxVal and maxVal > 0) and math.min(value/maxVal, 1) or 0
    if ratio > 0 then
        self:appRect(x, y, w*ratio, h, barColor or FT.C.BRAND)
    end
    -- Glow on high fill
    if ratio > 0.9 then
        self:appRect(x, y, w*ratio, h,
            {barColor and barColor[1] or FT.C.BRAND[1],
             barColor and barColor[2] or FT.C.BRAND[2],
             barColor and barColor[3] or FT.C.BRAND[3], 0.15})
    end
    return y - h - FT.py(2)
end

-- Section label with left accent bar
function FT_Renderer:sectionHeader(x, y, contentW, label)
    -- Accent bar
    self:appRect(x, y - FT.py(2), FT.px(3), FT.py(13), FT.C.BRAND)
    self:appText(x + FT.px(8), y, FT.FONT.SMALL, label,
        RenderText.ALIGN_LEFT, FT.C.TEXT_ACCENT)
end

-- Label + right-aligned value row
function FT_Renderer:row(x, y, contentW, label, value, labelColor, valueColor)
    local padX = FT.px(14)
    self:appText(x + padX, y, FT.FONT.BODY, label,
        RenderText.ALIGN_LEFT, labelColor or FT.C.TEXT_NORMAL)
    if value ~= nil then
        self:appText(x + contentW - padX, y, FT.FONT.BODY, tostring(value),
            RenderText.ALIGN_RIGHT, valueColor or FT.C.TEXT_ACCENT)
    end
end

-- Small badge/chip
function FT_Renderer:badge(x, y, label, color)
    local w = FT.px(36)
    local h = FT.py(13)
    self:appRect(x, y - FT.py(1), w, h, color or FT.C.BRAND_DIM)
    self:appText(x + w/2, y + h/2 - FT.py(2), FT.FONT.TINY, label,
        RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
    return w
end

-- ── Lifecycle ─────────────────────────────────────────────

-- Clear app-scoped drawables (called on app switch)
function FT_Renderer:clearAppLayer()
    for _, item in ipairs(self._appLayer) do
        if item.delete then item:delete() end
    end
    self._appLayer = {}
    -- Remove text and buttons too
    self._buttons = {}
end

-- Full cleanup (tablet close)
function FT_Renderer:destroyAll()
    self:clearAppLayer()
    for _, ov in ipairs(self._overlays) do
        if ov and ov.delete then ov:delete() end
    end
    self._overlays = {}
    self._texts    = {}
    self._buttons  = {}
end

-- Draw everything this frame
function FT_Renderer:flush()
    -- Persistent overlays
    for _, ov in ipairs(self._overlays) do
        if ov and ov.render then ov:render() end
    end
    -- App overlays
    for _, ov in ipairs(self._appLayer) do
        if ov and ov.render and not ov._isText then ov:render() end
    end
    -- Persistent text
    for _, t in ipairs(self._texts) do
        setTextAlignment(t.align)
        setTextColor(unpack(t.color))
        renderText(t.x, t.y, t.size, t.text)
    end
    -- App text (mixed in _buttons)
    for _, t in ipairs(self._buttons) do
        if t._isText then
            setTextAlignment(t.align)
            setTextColor(unpack(t.color))
            renderText(t.x, t.y, t.size, t.text)
        end
    end
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
end

-- Hit test against registered buttons. Returns first match or nil.
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
