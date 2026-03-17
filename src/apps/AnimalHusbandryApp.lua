-- =========================================================
-- FarmTablet v2 – Animal Husbandry App  (FIXED)
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.ANIMALS, function(self)
    local data   = self.system.data
    local farmId = data:getPlayerFarmId()
    local pens   = data:getAnimalPens(farmId)

    local startY = self:drawAppHeader("Animals", #pens .. " pens")

    local x, contentY, cw, contentH = self:contentInner()

    if #pens == 0 then
        self.r:appText(x, startY - FT.py(12), FT.FONT.BODY,
            "No animal pens owned.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, startY - FT.py(30), FT.FONT.SMALL,
            "Purchase a pen to start raising animals.",
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        return
    end

    local y    = startY
    local minY = contentY + FT.py(8)

    local function barColor(pct)
        if pct >= 60 then return FT.C.POSITIVE
        elseif pct >= 25 then return FT.C.WARNING
        else return FT.C.NEGATIVE
        end
    end

    for _, pen in ipairs(pens) do
        if y < minY + FT.py(40) then break end

        -- Card height based on which info bars we'll show
        local cardH = FT.py(10)
            + (pen.hasFood        and pen.foodPct  ~= nil and FT.py(24) or 0)
            + (pen.hasWater       and pen.waterPct ~= nil and FT.py(24) or 0)
            + (pen.hasCleanliness and pen.cleanPct ~= nil and FT.py(24) or 0)
            + FT.py(18)  -- header row
        cardH = math.max(cardH, FT.py(30))

        self.r:appRect(x - FT.px(4), y - cardH,
            cw + FT.px(8), cardH, FT.C.BG_CARD)

        -- Header: type name + count
        local header = pen.typeName
        if pen.numAnimals > 0 then
            header = header .. "  (" .. pen.numAnimals .. " / " .. pen.maxAnimals .. ")"
        else
            header = header .. "  (empty)"
        end

        y = y - FT.py(4)
        self.r:appText(x + FT.px(8), y, FT.FONT.BODY,
            header, RenderText.ALIGN_LEFT,
            pen.numAnimals > 0 and FT.C.TEXT_BRIGHT or FT.C.TEXT_DIM)
        y = y - FT.py(18)

        -- Food bar
        if pen.hasFood and pen.foodPct ~= nil then
            local pct = math.max(0, math.min(100, pen.foodPct))
            local bc  = barColor(pct)
            self.r:appText(x + FT.px(8), y, FT.FONT.TINY,
                string.format("FOOD  %d%%", pct),
                RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            y = y - FT.py(10)
            y = self.r:progressBar(x + FT.px(4), y, cw - FT.px(8), pct, 100, bc)
        end

        -- Water bar
        if pen.hasWater and pen.waterPct ~= nil then
            local pct = math.max(0, math.min(100, pen.waterPct))
            local bc  = barColor(pct)
            self.r:appText(x + FT.px(8), y, FT.FONT.TINY,
                string.format("WATER  %d%%", pct),
                RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            y = y - FT.py(10)
            y = self.r:progressBar(x + FT.px(4), y, cw - FT.px(8), pct, 100, bc)
        end

        -- Cleanliness/straw bar
        if pen.hasCleanliness and pen.cleanPct ~= nil then
            local pct = math.max(0, math.min(100, pen.cleanPct))
            local bc  = barColor(pct)
            self.r:appText(x + FT.px(8), y, FT.FONT.TINY,
                string.format("STRAW/CLEAN  %d%%", pct),
                RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            y = y - FT.py(10)
            y = self.r:progressBar(x + FT.px(4), y, cw - FT.px(8), pct, 100, bc)
        end

        y = y - FT.py(6)
    end
end)
