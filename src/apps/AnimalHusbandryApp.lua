-- =========================================================
-- FarmTablet v2 – Animal Husbandry App
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.ANIMALS, function(self)
    local AC = FT.appColor(FT.APP.ANIMALS)

    if self:drawHelpPage("_animalsHelp", FT.APP.ANIMALS, FT.l10n("ft_ui_app_animals", "Animals"), AC, {
        { title = FT.l10n("ft_animals_help_pen_cards_title", "PEN CARDS"),
          body  = FT.l10n("ft_animals_help_pen_cards_body", "Each card shows the animal type, current count, and the\npen capacity (e.g. Cows  (12 / 20)).\nEmpty pens are shown dimmed.") },
        { title = FT.l10n("ft_animals_help_food_title", "FOOD BAR"),
          body  = FT.l10n("ft_animals_help_food_body", "Percentage of the food trough that is filled.\nGreen >= 60%  |  Yellow >= 25%  |  Red < 25%.\nRefill before hitting red to maintain productivity.") },
        { title = FT.l10n("ft_animals_help_water_title", "WATER BAR"),
          body  = FT.l10n("ft_animals_help_water_body", "Percentage of the water trough that is filled.\nSame colour thresholds as food.\nAnimals without water lose productivity quickly.") },
        { title = FT.l10n("ft_animals_help_straw_title", "STRAW / CLEANLINESS BAR"),
          body  = FT.l10n("ft_animals_help_straw_body", "How clean the pen is — straw level for pigs and cows,\ncleanliness percentage for chickens and sheep.\nLow cleanliness reduces output and animal happiness.") },
        { title = FT.l10n("ft_animals_help_productivity_title", "PRODUCTIVITY"),
          body  = FT.l10n("ft_animals_help_productivity_body", "Overall animal productivity is driven by food, water,\nand cleanliness together. Keeping all three bars green\nmaximises milk, eggs, wool, and manure output.") },
    }) then return end

    local data   = self.system.data
    local farmId = data:getPlayerFarmId()
    local pens   = data:getAnimalPens(farmId)

    local startY = self:drawAppHeader(FT.l10n("ft_ui_app_animals", "Animals"), FT.l10nFormat(#pens == 1 and "ft_count_pen" or "ft_count_pens", "%d pens", #pens))
    local x, contentY, cw, contentH = self:contentInner()

    if #pens == 0 then
        self.r:appText(x, startY - FT.py(12), FT.FONT.BODY,
            FT.l10n("ft_animals_no_pens", "No animal pens owned."), RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, startY - FT.py(30), FT.FONT.SMALL,
            FT.l10n("ft_animals_purchase_pen", "Purchase a pen to start raising animals."), RenderText.ALIGN_LEFT, FT.C.MUTED)
        self:drawInfoIcon("_animalsHelp", AC)
        return
    end

    local scrollY = self:getContentScrollY()
    local y = startY + scrollY
    local pad = FT.px(FT.SP.MD)   -- inner card pad (14), so the pens read as cards

    local function barColor(pct)
        if pct >= 60 then return FT.C.POSITIVE
        elseif pct >= 25 then return FT.C.WARNING
        else return FT.C.NEGATIVE end
    end

    -- One shared left edge for title, labels, and bars so rows line up.
    -- Label left + percent right, bar on the next line (same pattern as Soil cards).
    local function drawMetric(rowY, label, pct)
        local p = math.max(0, math.min(100, tonumber(pct) or 0))
        self.r:appText(x + pad, rowY, FT.FONT.TINY, label,
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x + cw - pad, rowY, FT.FONT.TINY, string.format("%d%%", p),
            RenderText.ALIGN_RIGHT, FT.C.TEXT_NORMAL)
        local barY = rowY - FT.py(12)
        self.r:progressBar(x + pad, barY, cw - pad * 2, p, 100, barColor(p))
        return barY - FT.py(8)
    end

    for _, pen in ipairs(pens) do
        local metrics = {}
        if pen.hasFood and pen.foodPct ~= nil then
            metrics[#metrics + 1] = { label = FT.l10nAuto("FOOD"), pct = pen.foodPct }
        end
        if pen.hasWater and pen.waterPct ~= nil then
            metrics[#metrics + 1] = { label = FT.l10nAuto("WATER"), pct = pen.waterPct }
        end
        if pen.hasCleanliness and pen.cleanPct ~= nil then
            metrics[#metrics + 1] = { label = FT.l10nAuto("STRAW/CLEAN"), pct = pen.cleanPct }
        end

        local headerH = FT.py(24)
        local metricH = #metrics * FT.py(20)
        local cardH = headerH + metricH + FT.py(12)
        if #metrics == 0 then cardH = FT.py(32) end
        local cardBottom = y - cardH

        self.r:appRect(x - FT.px(4), cardBottom, cw + FT.px(8), cardH, FT.C.BG_CARD)

        local header = tostring(pen.typeName or FT.l10n("ft_auto_unknown", "Unknown"))
        if pen.numAnimals > 0 then
            header = header .. "  (" .. pen.numAnimals .. " / " .. pen.maxAnimals .. ")"
        else
            header = header .. "  (" .. FT.l10n("ft_common_empty_lower", "empty") .. ")"
        end
        self.r:appText(x + pad, y - FT.py(9), FT.FONT.BODY, header, RenderText.ALIGN_LEFT,
            pen.numAnimals > 0 and FT.C.TEXT_BRIGHT or FT.C.TEXT_DIM)

        local rowY = y - headerH
        for _, m in ipairs(metrics) do
            rowY = drawMetric(rowY, m.label, m.pct)
        end

        -- Pin to pre-sized card bottom, then a card gap (14) before the next pen.
        y = cardBottom - FT.py(FT.SP.MD)
    end

    self:setContentHeight(startY - y + scrollY)
    self:drawInfoIcon("_animalsHelp", AC)
    self:drawScrollBar()
end)