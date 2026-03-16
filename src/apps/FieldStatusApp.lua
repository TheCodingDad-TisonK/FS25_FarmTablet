-- =========================================================
-- FarmTablet v2 – Field Status App
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.FIELDS, function(self)
    local data    = self.system.data
    local farmId  = data:getPlayerFarmId()
    local fields  = data:getOwnedFields(farmId)

    local startY = self:drawAppHeader("Field Manager",
        #fields .. " fields")

    if #fields == 0 then
        local x, _, _, _ = self:contentInner()
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

    local y = startY - FT.py(2)
    local x, _, cw, _ = self:contentInner()

    -- Summary row
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
    self.r:appText(x + cw,        y, FT.FONT.TINY, "STATE", RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
    y = y - FT.py(16)

    local rowH  = FT.py(19)
    local altBg = {0.09, 0.11, 0.16, 0.50}

    local _, contentY, _, contentH = self:contentInner()
    local minY = contentY + FT.py(8)

    for i, field in ipairs(fields) do
        if y < minY then break end

        -- Alternating row highlight
        if i % 2 == 0 then
            self.r:appRect(x - FT.px(4), y - FT.py(4),
                cw + FT.px(8), rowH, altBg)
        end

        -- Phase dot
        local dotColor = field.stateColor or FT.C.MUTED
        self.r:appRect(x + FT.px(2), y + FT.py(4),
            FT.px(6), FT.py(6), dotColor)

        -- Field ID
        self.r:appText(x + FT.px(12), y, FT.FONT.SMALL,
            tostring(field.id),
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)

        -- Crop name
        local cropDisp = field.cropName
        if #cropDisp > 14 then cropDisp = cropDisp:sub(1,12) .. "…" end
        self.r:appText(x + FT.px(28), y, FT.FONT.SMALL,
            cropDisp, RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)

        -- State
        self.r:appText(x + cw, y, FT.FONT.SMALL,
            field.stateName, RenderText.ALIGN_RIGHT, dotColor)

        y = y - rowH
    end

    -- "More fields" indicator if overflow
    if y < minY and #fields > 15 then
        self.r:appText(x + cw/2, minY + FT.py(4), FT.FONT.TINY,
            "… " .. (#fields - 15) .. " more fields",
            RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)
    end
end)
