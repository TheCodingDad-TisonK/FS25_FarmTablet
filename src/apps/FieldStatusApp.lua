-- =========================================================
-- FarmTablet v2 – Field Status App  (FIXED)
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.FIELDS, function(self)
    local data   = self.system.data
    local farmId = data:getPlayerFarmId()
    local fields = data:getOwnedFields(farmId)

    local startY = self:drawAppHeader("Field Manager",
        #fields .. " fields")

    local x, contentY, cw, contentH = self:contentInner()

    if #fields == 0 then
        self.r:appText(x, startY - FT.py(12), FT.FONT.BODY,
            "You don't own any fields yet.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, startY - FT.py(32), FT.FONT.SMALL,
            "Purchase land to start farming.",
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        return
    end

    -- Phase summary badges
    local countReady, countGrowing, countEmpty = 0, 0, 0
    for _, f in ipairs(fields) do
        if     f.phase == "ready"   then countReady   = countReady   + 1
        elseif f.phase == "growing" then countGrowing = countGrowing + 1
        else                             countEmpty   = countEmpty   + 1
        end
    end

    local y  = startY - FT.py(2)
    local bx = x

    if countReady > 0 then
        bx = bx + self.r:badge(bx, y, countReady.." READY",   FT.C.BTN_PRIMARY) + FT.px(4)
    end
    if countGrowing > 0 then
        bx = bx + self.r:badge(bx, y, countGrowing.." GROW",  FT.C.BTN_NEUTRAL) + FT.px(4)
    end
    if countEmpty > 0 then
        self.r:badge(bx, y, countEmpty.." EMPTY", {0.18,0.18,0.22,0.9})
    end

    y = y - FT.py(20)
    y = self:drawRule(y, 0.4)

    -- Column headers
    self.r:appText(x,             y, FT.FONT.TINY, "#",     RenderText.ALIGN_LEFT,  FT.C.TEXT_DIM)
    self.r:appText(x + FT.px(28), y, FT.FONT.TINY, "CROP",  RenderText.ALIGN_LEFT,  FT.C.TEXT_DIM)
    -- FIX: show area column header
    self.r:appText(x + cw*0.6,    y, FT.FONT.TINY, "HA",    RenderText.ALIGN_LEFT,  FT.C.TEXT_DIM)
    self.r:appText(x + cw,        y, FT.FONT.TINY, "STATE", RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
    y = y - FT.py(16)

    local rowH  = FT.py(19)
    local altBg = {0.09, 0.11, 0.16, 0.50}
    local minY  = contentY + FT.py(8)

    -- FIX: track how many rows we actually drew for the overflow indicator
    local rowsDrawn = 0

    for i, field in ipairs(fields) do
        if y < minY then break end

        if i % 2 == 0 then
            self.r:appRect(x - FT.px(4), y - FT.py(4),
                cw + FT.px(8), rowH, altBg)
        end

        local dotColor = field.stateColor or FT.C.MUTED
        self.r:appRect(x + FT.px(2), y + FT.py(4),
            FT.px(6), FT.py(6), dotColor)

        self.r:appText(x + FT.px(12), y, FT.FONT.SMALL,
            tostring(field.id),
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)

        local cropDisp = field.cropName
        if #cropDisp > 12 then cropDisp = cropDisp:sub(1,10) .. ".." end
        self.r:appText(x + FT.px(28), y, FT.FONT.SMALL,
            cropDisp, RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)

        -- FIX: display area in ha (areaInHa already in ha from Farmland.areaInHa)
        if field.area and field.area > 0 then
            self.r:appText(x + cw*0.6, y, FT.FONT.SMALL,
                string.format("%.1f", field.area),
                RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        end

        self.r:appText(x + cw, y, FT.FONT.SMALL,
            field.stateName, RenderText.ALIGN_RIGHT, dotColor)

        y = y - rowH
        rowsDrawn = rowsDrawn + 1
    end

    -- FIX: overflow count based on actual rows drawn vs total
    if rowsDrawn < #fields then
        local remaining = #fields - rowsDrawn
        self.r:appText(x + cw/2, minY + FT.py(4), FT.FONT.TINY,
            "... " .. remaining .. " more fields",
            RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)
    end
end)
