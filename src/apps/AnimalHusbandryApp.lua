-- =========================================================
-- FarmTablet v2 – Animal Husbandry App
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.ANIMALS, function(self)
    local AC = FT.appColor(FT.APP.ANIMALS)

    if self:drawHelpPage("_animalsHelp", FT.APP.ANIMALS, "Animals", AC, {
        { title = "PEN CARDS",
          body  = "Each card shows the animal type, current count, and the\n" ..
                  "pen capacity (e.g. Cows  (12 / 20)).\n" ..
                  "Empty pens are shown dimmed." },
        { title = "FOOD BAR",
          body  = "Percentage of the food trough that is filled.\n" ..
                  "Green >= 60%  |  Yellow >= 25%  |  Red < 25%.\n" ..
                  "Refill before hitting red to maintain productivity." },
        { title = "WATER BAR",
          body  = "Percentage of the water trough that is filled.\n" ..
                  "Same colour thresholds as food.\n" ..
                  "Animals without water lose productivity quickly." },
        { title = "STRAW / CLEANLINESS BAR",
          body  = "How clean the pen is — straw level for pigs and cows,\n" ..
                  "cleanliness percentage for chickens and sheep.\n" ..
                  "Low cleanliness reduces output and animal happiness." },
        { title = "PRODUCTIVITY",
          body  = "Overall animal productivity is driven by food, water,\n" ..
                  "and cleanliness together. Keeping all three bars green\n" ..
                  "maximises milk, eggs, wool, and manure output." },
    }) then return end

    local data   = self.system.data
    local farmId = data:getPlayerFarmId()
    local pens   = data:getAnimalPens(farmId)

    local startY = self:drawAppHeader("Animals", #pens .. " pens")
    local x, contentY, cw, contentH = self:contentInner()

    if #pens == 0 then
        self.r:appText(x, startY - FT.py(12), FT.FONT.BODY,
            "No animal pens owned.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, startY - FT.py(30), FT.FONT.SMALL,
            "Purchase a pen to start raising animals.", RenderText.ALIGN_LEFT, FT.C.MUTED)
        self:drawInfoIcon("_animalsHelp", AC)
        return
    end

    local y    = startY
    local minY = contentY + FT.py(8)

    local function barColor(pct)
        if pct >= 60 then return FT.C.POSITIVE
        elseif pct >= 25 then return FT.C.WARNING
        else return FT.C.NEGATIVE end
    end

    for _, pen in ipairs(pens) do
        if y < minY + FT.py(40) then break end
        local cardH = FT.py(10)
            + (pen.hasFood        and pen.foodPct  ~= nil and FT.py(24) or 0)
            + (pen.hasWater       and pen.waterPct ~= nil and FT.py(24) or 0)
            + (pen.hasCleanliness and pen.cleanPct ~= nil and FT.py(24) or 0)
            + FT.py(18)
        cardH = math.max(cardH, FT.py(30))

        self.r:appRect(x - FT.px(4), y - cardH, cw + FT.px(8), cardH, FT.C.BG_CARD)

        local header = pen.typeName
        if pen.numAnimals > 0 then
            header = header .. "  (" .. pen.numAnimals .. " / " .. pen.maxAnimals .. ")"
        else
            header = header .. "  (empty)"
        end
        y = y - FT.py(4)
        self.r:appText(x + FT.px(8), y, FT.FONT.BODY, header, RenderText.ALIGN_LEFT,
            pen.numAnimals > 0 and FT.C.TEXT_BRIGHT or FT.C.TEXT_DIM)
        y = y - FT.py(18)

        if pen.hasFood and pen.foodPct ~= nil then
            local pct = math.max(0, math.min(100, pen.foodPct))
            self.r:appText(x + FT.px(8), y, FT.FONT.TINY,
                string.format("FOOD  %d%%", pct), RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            y = y - FT.py(10)
            y = self.r:progressBar(x + FT.px(4), y, cw - FT.px(8), pct, 100, barColor(pct))
        end
        if pen.hasWater and pen.waterPct ~= nil then
            local pct = math.max(0, math.min(100, pen.waterPct))
            self.r:appText(x + FT.px(8), y, FT.FONT.TINY,
                string.format("WATER  %d%%", pct), RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            y = y - FT.py(10)
            y = self.r:progressBar(x + FT.px(4), y, cw - FT.px(8), pct, 100, barColor(pct))
        end
        if pen.hasCleanliness and pen.cleanPct ~= nil then
            local pct = math.max(0, math.min(100, pen.cleanPct))
            self.r:appText(x + FT.px(8), y, FT.FONT.TINY,
                string.format("STRAW/CLEAN  %d%%", pct), RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            y = y - FT.py(10)
            y = self.r:progressBar(x + FT.px(4), y, cw - FT.px(8), pct, 100, barColor(pct))
        end
        y = y - FT.py(6)
    end

    self:drawInfoIcon("_animalsHelp", AC)
end)
