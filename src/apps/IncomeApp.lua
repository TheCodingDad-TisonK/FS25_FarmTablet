-- =========================================================
-- FarmTablet v2 – Income Mod Integration App
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.INCOME, function(self)
    local startY = self:drawAppHeader("Income Mod", "Integration")

    local x, contentY, cw, _ = self:contentInner()
    local y = startY
    local inst = g_currentMission and g_currentMission.incomeManager

    if not inst then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Income Mod is not installed.",
            RenderText.ALIGN_LEFT, FT.C.NEGATIVE)
        self.r:appText(x, y - FT.py(30), FT.FONT.SMALL,
            "Install FS25_IncomeMod to use this app.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    local enabled = inst.settings and inst.settings.enabled or false
    local mode    = (inst.settings and inst.settings.getPayModeName and
                    inst.settings:getPayModeName()) or "Unknown"
    local amount  = (inst.settings and inst.settings.getPaymentAmount and
                    inst.settings:getPaymentAmount()) or 0

    y = self:drawSection(y, "STATUS")
    y = self:drawRow(y, "Status", enabled and "Enabled" or "Disabled",
        nil, enabled and FT.C.POSITIVE or FT.C.NEGATIVE)
    y = self:drawRow(y, "Payment Mode", mode)
    y = self:drawRow(y, "Amount",
        (g_i18n and g_i18n:formatMoney(amount, 0, true, true)) or tostring(amount))

    -- Toggle buttons
    y = y - FT.py(8)
    y = self:drawRule(y, 0.3)

    local minY = contentY + FT.py(8)
    if y > minY + FT.py(26) then
        local ny, btnA, btnB = self:drawButtonPair(
            minY + FT.py(2),
            "ENABLE",  enabled and FT.C.BTN_NEUTRAL or FT.C.BTN_PRIMARY,
            { onClick = function()
                if inst.settings then inst.settings.enabled = true end
                if inst.settings and inst.settings.save then inst.settings:save() end
                self:switchApp(FT.APP.INCOME)
            end },
            "DISABLE", enabled and FT.C.BTN_DANGER or FT.C.BTN_NEUTRAL,
            { onClick = function()
                if inst.settings then inst.settings.enabled = false end
                if inst.settings and inst.settings.save then inst.settings:save() end
                self:switchApp(FT.APP.INCOME)
            end }
        )
    end
end)


-- =========================================================
-- FarmTablet v2 – Tax Mod Integration App
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.TAX, function(self)
    local data = self.system.data
    local startY = self:drawAppHeader("Tax Mod", "Integration")

    local x, contentY, cw, _ = self:contentInner()
    local y = startY
    local inst = g_currentMission and g_currentMission.taxManager

    if not inst then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Tax Mod is not installed.",
            RenderText.ALIGN_LEFT, FT.C.NEGATIVE)
        self.r:appText(x, y - FT.py(30), FT.FONT.SMALL,
            "Install FS25_TaxMod to use this app.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    local enabled = inst.settings and inst.settings.enabled or false
    local rate    = (inst.settings and inst.settings.taxRate) or "medium"
    local retPct  = (inst.settings and inst.settings.returnPercentage) or 20
    local total   = inst.stats and inst.stats.totalTaxesPaid

    y = self:drawSection(y, "STATUS")
    y = self:drawRow(y, "Status", enabled and "Enabled" or "Disabled",
        nil, enabled and FT.C.POSITIVE or FT.C.NEGATIVE)
    y = self:drawRow(y, "Tax Rate",   rate)
    y = self:drawRow(y, "Return %",   tostring(retPct) .. "%")
    if total then
        y = self:drawRow(y, "Total Paid", data:formatMoney(total), nil, FT.C.WARNING)
    end

    y = y - FT.py(8)
    y = self:drawRule(y, 0.3)

    local minY = contentY + FT.py(8)
    if y > minY + FT.py(26) then
        local ny, btnA, btnB = self:drawButtonPair(
            minY + FT.py(2),
            "ENABLE",  enabled and FT.C.BTN_NEUTRAL or FT.C.BTN_PRIMARY,
            { onClick = function()
                if inst.settings then inst.settings.enabled = true end
                if inst.saveSettings then inst:saveSettings() end
                self:switchApp(FT.APP.TAX)
            end },
            "DISABLE", enabled and FT.C.BTN_DANGER or FT.C.BTN_NEUTRAL,
            { onClick = function()
                if inst.settings then inst.settings.enabled = false end
                if inst.saveSettings then inst:saveSettings() end
                self:switchApp(FT.APP.TAX)
            end }
        )
    end
end)


-- =========================================================
-- FarmTablet v2 – NPC Favor App
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.NPC_FAVOR, function(self)
    local startY = self:drawAppHeader("NPC Favor", "")

    local x, _, cw, _ = self:contentInner()
    local y = startY

    local inst = g_currentMission and g_currentMission.npcFavorSystem
    if not inst then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "NPC Favor system not found.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    y = self:drawSection(y, "NPC FAVOR LEVELS")

    local npcs = inst.npcs or inst.favorLevels or {}
    local hasData = false

    for name, favor in pairs(npcs) do
        hasData = true
        local pct = 0
        if type(favor) == "number" then
            pct = math.floor(math.min(math.max(favor, 0), 1) * 100)
        elseif favor and favor.level then
            pct = math.floor(math.min(math.max(favor.level, 0), 1) * 100)
        end

        local nm = tostring(name)
        if #nm > 18 then nm = nm:sub(1,16) .. "…" end

        y = self:drawRow(y, nm, pct .. "%",
            nil,
            pct >= 70 and FT.C.POSITIVE or
            pct >= 40 and FT.C.WARNING or FT.C.NEGATIVE)

        y = y + FT.py(FT.SP.ROW) - FT.py(8)
        y = self:drawBar(y,
            pct, 100,
            pct >= 70 and FT.C.POSITIVE or
            pct >= 40 and FT.C.WARNING or FT.C.NEGATIVE)
    end

    if not hasData then
        self.r:appText(x, y - FT.py(10), FT.FONT.SMALL,
            "No NPC favor data available.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    end
end)


-- =========================================================
-- FarmTablet v2 – Seasonal Crop Stress App
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.CROP_STRESS, function(self)
    local startY = self:drawAppHeader("Crop Stress", "Seasonal")

    local x, _, cw, _ = self:contentInner()
    local y = startY

    local inst = g_currentMission and g_currentMission.cropStressManager
    if not inst then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Crop Stress Manager not found.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    y = self:drawSection(y, "CURRENT STRESS LEVELS")

    local stressed  = inst.stressedCrops  or inst.stressData or {}
    local hasData   = false

    for cropName, stressVal in pairs(stressed) do
        hasData = true
        local pct = 0
        if type(stressVal) == "number" then
            pct = math.floor(stressVal * 100)
        end

        local nm = tostring(cropName)
        if #nm > 18 then nm = nm:sub(1,16) .. "…" end

        local stressColor = pct <= 20 and FT.C.POSITIVE
                         or pct <= 50 and FT.C.WARNING
                         or FT.C.NEGATIVE

        y = self:drawRow(y, nm, pct .. "% stress", nil, stressColor)
        y = y + FT.py(FT.SP.ROW) - FT.py(8)
        y = self:drawBar(y, pct, 100, stressColor)
    end

    if not hasData then
        self.r:appText(x, y - FT.py(10), FT.FONT.SMALL,
            "No crop stress data available.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    end
end)


-- =========================================================
-- FarmTablet v2 – Soil Fertilizer App
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.SOIL_FERT, function(self)
    local startY = self:drawAppHeader("Soil Fertilizer", "")

    local x, _, cw, _ = self:contentInner()
    local y = startY

    local mgr = g_soilFertilizerManager or
                (g_currentMission and g_currentMission.soilFertilizerManager)
    if not mgr then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Soil Fertilizer system not found.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    y = self:drawSection(y, "SOIL STATUS")

    -- Try common data access patterns
    local soilData = mgr.soilData or mgr.fieldData or mgr.stats or {}

    if mgr.getSoilStatus then
        local status = mgr:getSoilStatus()
        if status then
            for k, v in pairs(status) do
                if type(v) == "number" then
                    y = self:drawRow(y, tostring(k),
                        string.format("%.1f", v))
                elseif type(v) == "string" then
                    y = self:drawRow(y, tostring(k), v)
                end
            end
            return
        end
    end

    -- Generic display
    local hasAny = false
    for k, v in pairs(soilData) do
        if y < FT.LAYOUT.contentY + FT.py(20) then break end
        if type(v) == "number" or type(v) == "string" then
            hasAny = true
            y = self:drawRow(y, tostring(k), tostring(v))
        end
    end

    if not hasAny then
        self.r:appText(x, y - FT.py(10), FT.FONT.SMALL,
            "No soil data available.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    end
end)
