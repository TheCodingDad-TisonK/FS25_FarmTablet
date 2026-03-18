-- =========================================================
-- FarmTablet v2 – Companion Mod Integration Apps
-- Registers drawers for four companion mods:
--   • FT.APP.INCOME     → FS25_IncomeMod
--   • FT.APP.TAX        → FS25_TaxMod
--   • FT.APP.NPC_FAVOR  → FS25_NPCFavor
--   • FT.APP.CROP_STRESS→ FS25_SeasonalCropStress
--   • FT.APP.SOIL_FERT  → FS25_SoilFertilizer
-- Each drawer guards itself: if the companion mod's global
-- manager is nil the app shows a "mod not installed" banner
-- rather than erroring. The apps are only visible in the
-- sidebar when autoDetect() has confirmed the mod is loaded.
-- =========================================================

-- ── INCOME MOD ────────────────────────────────────────────
FarmTabletUI:registerDrawer(FT.APP.INCOME, function(self)
    local AC = FT.appColor(FT.APP.INCOME)

    if self:drawHelpPage("_incomeHelp", FT.APP.INCOME, "Income Mod", AC, {
        { title = "WHAT THIS APP SHOWS",
          body  = "Displays the current status of FS25_IncomeMod.\n" ..
                  "The mod adds configurable periodic income payments\n" ..
                  "to supplement your farm earnings." },
        { title = "PAYMENT MODE",
          body  = "Controls when income is paid out:\n" ..
                  "Hourly = every in-game hour.\n" ..
                  "Daily = once per in-game day.\n" ..
                  "Weekly = once per in-game week." },
        { title = "AMOUNT",
          body  = "The money added to your balance per payment cycle.\n" ..
                  "Configure this in the Income Mod settings." },
        { title = "ENABLE / DISABLE",
          body  = "Toggles the mod on or off without uninstalling it.\n" ..
                  "Changes take effect immediately." },
    }) then return end

    local startY = self:drawAppHeader("Income Mod", "Integration")
    local x, contentY, cw, _ = self:contentInner()
    local y = startY
    local inst = g_currentMission and g_currentMission.incomeManager

    if not inst then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Income Mod is not installed.", RenderText.ALIGN_LEFT, FT.C.NEGATIVE)
        self.r:appText(x, y - FT.py(30), FT.FONT.SMALL,
            "Install FS25_IncomeMod to use this app.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self:drawInfoIcon("_incomeHelp", AC)
        return
    end

    local enabled = inst.settings and inst.settings.enabled or false
    local mode    = (inst.settings and inst.settings.getPayModeName and inst.settings:getPayModeName()) or "Unknown"
    local amount  = (inst.settings and inst.settings.getPaymentAmount and inst.settings:getPaymentAmount()) or 0

    y = self:drawSection(y, "STATUS")
    y = self:drawRow(y, "Status", enabled and "Enabled" or "Disabled", nil,
        enabled and FT.C.POSITIVE or FT.C.NEGATIVE)
    y = self:drawRow(y, "Payment Mode", mode)
    y = self:drawRow(y, "Amount",
        (g_i18n and g_i18n:formatMoney(amount, 0, true, true)) or tostring(amount))

    y = y - FT.py(8)
    y = self:drawRule(y, 0.3)

    local minY = contentY + FT.py(8)
    if y > minY + FT.py(26) then
        self:drawButtonPair(minY + FT.py(2),
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
            end })
    end

    self:drawInfoIcon("_incomeHelp", AC)
end)


-- ── TAX MOD ───────────────────────────────────────────────
FarmTabletUI:registerDrawer(FT.APP.TAX, function(self)
    local AC = FT.appColor(FT.APP.TAX)

    if self:drawHelpPage("_taxHelp", FT.APP.TAX, "Tax Mod", AC, {
        { title = "WHAT THIS APP SHOWS",
          body  = "Displays the status of FS25_TaxMod.\n" ..
                  "The mod deducts periodic tax from your balance\n" ..
                  "and returns a configurable percentage as a rebate." },
        { title = "TAX RATE",
          body  = "How much tax is charged per cycle.\n" ..
                  "Low / Medium / High tiers are set in the mod settings.\n" ..
                  "Shown here so you can plan your cash flow." },
        { title = "RETURN %",
          body  = "Percentage of tax paid that is returned as a rebate.\n" ..
                  "A 20% return means you effectively pay 80% of the\n" ..
                  "stated tax rate." },
        { title = "TOTAL PAID",
          body  = "Cumulative tax paid across the current session.\n" ..
                  "Shown in orange as it represents an ongoing cost." },
        { title = "ENABLE / DISABLE",
          body  = "Toggles the mod on or off without uninstalling it.\n" ..
                  "Changes take effect immediately." },
    }) then return end

    local data   = self.system.data
    local startY = self:drawAppHeader("Tax Mod", "Integration")
    local x, contentY, cw, _ = self:contentInner()
    local y    = startY
    local inst = g_currentMission and g_currentMission.taxManager

    if not inst then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Tax Mod is not installed.", RenderText.ALIGN_LEFT, FT.C.NEGATIVE)
        self.r:appText(x, y - FT.py(30), FT.FONT.SMALL,
            "Install FS25_TaxMod to use this app.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self:drawInfoIcon("_taxHelp", AC)
        return
    end

    local enabled = inst.settings and inst.settings.enabled or false
    local rate    = (inst.settings and inst.settings.taxRate) or "medium"
    local retPct  = (inst.settings and inst.settings.returnPercentage) or 20
    local total   = inst.stats and inst.stats.totalTaxesPaid

    y = self:drawSection(y, "STATUS")
    y = self:drawRow(y, "Status", enabled and "Enabled" or "Disabled", nil,
        enabled and FT.C.POSITIVE or FT.C.NEGATIVE)
    y = self:drawRow(y, "Tax Rate",   rate)
    y = self:drawRow(y, "Return %",   tostring(retPct) .. "%")
    if total then
        y = self:drawRow(y, "Total Paid", data:formatMoney(total), nil, FT.C.WARNING)
    end

    y = y - FT.py(8)
    y = self:drawRule(y, 0.3)

    local minY = contentY + FT.py(8)
    if y > minY + FT.py(26) then
        self:drawButtonPair(minY + FT.py(2),
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
            end })
    end

    self:drawInfoIcon("_taxHelp", AC)
end)


-- ── NPC FAVOR ─────────────────────────────────────────────
FarmTabletUI:registerDrawer(FT.APP.NPC_FAVOR, function(self)
    local AC = FT.appColor(FT.APP.NPC_FAVOR)

    if self:drawHelpPage("_npcHelp", FT.APP.NPC_FAVOR, "NPC Favor", AC, {
        { title = "TOWN REPUTATION",
          body  = "Overall standing with the local community (0-100).\n" ..
                  "Respected >= 70  |  Neutral >= 40  |  Poor < 40.\n" ..
                  "Higher reputation unlocks better favor rewards." },
        { title = "ACTIVE FAVORS",
          body  = "Number of favors currently in progress.\n" ..
                  "Each favor shows NPC name, description, completion\n" ..
                  "percentage, and hours remaining." },
        { title = "RELATIONSHIPS",
          body  = "Lists every active NPC with their relationship score\n" ..
                  "and a colour-coded bar.\n" ..
                  "Friend >= 70  |  Neutral >= 40  |  Cold < 40.\n" ..
                  "Their role (Agronomist, Mechanic, etc.) is shown in\n" ..
                  "square brackets next to their name." },
        { title = "BUILDING RELATIONSHIPS",
          body  = "Complete favors for an NPC to increase their\n" ..
                  "relationship score. Higher scores unlock exclusive\n" ..
                  "advice, discounts, and early warnings." },
    }) then return end

    local startY = self:drawAppHeader("NPC Favor", "")
    local x, contentY, cw, _ = self:contentInner()
    local y    = startY
    local minY = contentY + FT.py(8)

    local npcSys = g_NPCSystem or (g_currentMission and g_currentMission.npcFavorSystem)

    if not npcSys then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "NPC Favor mod not detected.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, y - FT.py(30), FT.FONT.SMALL,
            "Install FS25_NPCFavor to use this app.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self:drawInfoIcon("_npcHelp", AC)
        return
    end

    local npcs     = npcSys.activeNPCs or {}
    local favorSys = npcSys.favorSystem
    local townRep  = npcSys.townReputation or 0
    local accent   = AC

    local repColor = townRep >= 70 and FT.C.POSITIVE or townRep >= 40 and FT.C.WARNING or FT.C.NEGATIVE
    local repLabel = townRep >= 70 and "Respected" or townRep >= 40 and "Neutral" or "Poor"

    self.r:appRect(x - FT.px(4), y - FT.py(22), cw + FT.px(8), FT.py(20),
        {repColor[1]*0.12, repColor[2]*0.12, repColor[3]*0.12, 0.95})
    self.r:appText(x, y - FT.py(18), FT.FONT.BODY,
        "Town Reputation: " .. repLabel, RenderText.ALIGN_LEFT, repColor)
    self.r:appText(x + cw, y - FT.py(18), FT.FONT.SMALL,
        tostring(math.floor(townRep)) .. " / 100", RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
    y = y - FT.py(26)
    y = y + FT.py(FT.SP.ROW) - FT.py(8)
    y = self:drawBar(y, townRep, 100, repColor)
    y = y - FT.py(8)

    if favorSys then
        local active = favorSys.activeFavors or {}
        local stats  = favorSys.stats or {}
        y = self:drawRule(y, 0.3)
        y = self:drawSection(y, "FAVORS")
        y = self:drawRow(y, "Active Favors", tostring(#active))
        y = self:drawRow(y, "Completed",     tostring(stats.totalFavorsCompleted or 0))
        y = self:drawRow(y, "Total Earned",
            (g_i18n and g_i18n:formatMoney(stats.totalMoneyEarned or 0, 0, true, true))
            or ("$" .. tostring(stats.totalMoneyEarned or 0)), nil, FT.C.POSITIVE)

        if #active > 0 then
            y = y - FT.py(4)
            y = self:drawRule(y, 0.2)
            y = self:drawSection(y, "ACTIVE")
            for i = 1, math.min(3, #active) do
                local f = active[i]
                if f and y > minY + FT.py(16) then
                    local hoursLeft = math.floor((f.timeRemaining or 0) / 3600000)
                    local pctColor  = f.progress >= 66 and FT.C.POSITIVE
                                   or f.progress >= 33 and FT.C.WARNING or FT.C.TEXT_DIM
                    y = self:drawRow(y,
                        (f.npcName or "?") .. "  " .. (f.description or f.type or ""),
                        string.format("%d%%  %dh left", math.floor(f.progress or 0), hoursLeft),
                        nil, pctColor)
                end
            end
        end
    end

    y = y - FT.py(4)
    y = self:drawRule(y, 0.3)
    y = self:drawSection(y, "RELATIONSHIPS  (" .. #npcs .. ")")

    if #npcs == 0 then
        self.r:appText(x, y - FT.py(10), FT.FONT.SMALL,
            "No NPCs spawned yet.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    else
        local sorted = {}
        for _, npc in ipairs(npcs) do
            if npc and npc.isActive ~= false then table.insert(sorted, npc) end
        end
        table.sort(sorted, function(a, b) return (a.relationship or 0) > (b.relationship or 0) end)

        for _, npc in ipairs(sorted) do
            if y <= minY + FT.py(16) then break end
            local rel      = math.floor(math.min(math.max(npc.relationship or 0, 0), 100))
            local relColor = rel >= 70 and FT.C.POSITIVE or rel >= 40 and FT.C.WARNING or FT.C.NEGATIVE
            local relLabel = rel >= 70 and "Friend" or rel >= 40 and "Neutral" or "Cold"
            local nm       = tostring(npc.name or "Unknown")
            if #nm > 16 then nm = nm:sub(1,14) .. ">" end
            self.r:appText(x, y, FT.FONT.SMALL,
                nm .. "  [" .. (npc.role or "?") .. "]", RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
            self.r:appText(x + cw, y, FT.FONT.SMALL,
                rel .. "  " .. relLabel, RenderText.ALIGN_RIGHT, relColor)
            y = y - FT.py(14)
            y = self:drawBar(y, rel, 100, relColor)
            y = y - FT.py(4)
        end
    end

    self:drawInfoIcon("_npcHelp", AC)
end)


-- ── SEASONAL CROP STRESS ──────────────────────────────────
FarmTabletUI:registerDrawer(FT.APP.CROP_STRESS, function(self)
    local AC = FT.appColor(FT.APP.CROP_STRESS)

    if self:drawHelpPage("_cropStressHelp", FT.APP.CROP_STRESS, "Crop Stress", AC, {
        { title = "WHAT THIS APP SHOWS",
          body  = "Integrates with FS25_SeasonalCropStress to display\n" ..
                  "soil moisture and drought stress per field.\n" ..
                  "Install that mod and open its own Help section for\n" ..
                  "full irrigation guidance." },
        { title = "STATUS BANNER",
          body  = "Shows whether Seasonal Crop Stress is enabled and\n" ..
                  "the current difficulty setting." },
        { title = "FIELD LIST",
          body  = "Each row shows field ID, crop type, moisture %,\n" ..
                  "and a colour-coded bar.\n" ..
                  "Green >= 40%  |  Yellow >= 25%  |  Red < 25%." },
        { title = "STRESS INDICATOR",
          body  = "If a field has more than 5% accumulated drought\n" ..
                  "stress, the value row ends with  !XX%  in red.\n" ..
                  "Irrigate those fields immediately to stop yield loss." },
        { title = "MOISTURE BAR",
          body  = "Visual fill bar below each row.\n" ..
                  "Longer bar = more moisture in the soil.\n" ..
                  "An empty bar means the field is critically dry." },
    }) then return end

    local startY = self:drawAppHeader("Crop Stress", "Seasonal")
    local x, contentY, cw, _ = self:contentInner()
    local y    = startY
    local minY = contentY + FT.py(8)
    local accent = AC

    local mgr = g_cropStressManager
    if not mgr then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Crop Stress mod not detected.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, y - FT.py(30), FT.FONT.SMALL,
            "Install FS25_SeasonalCropStress to use this app.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self:drawInfoIcon("_cropStressHelp", AC)
        return
    end

    local moistureSys = mgr.soilMoistureSystem or mgr.moistureSystem or mgr.moisture
    local stressMod   = mgr.cropStressModifier  or mgr.stressModifier  or mgr.stress

    local moistureData = nil
    if moistureSys then
        moistureData = moistureSys.fieldMoisture or moistureSys.moistureData or moistureSys.fields
    end
    if not moistureData then moistureData = mgr.fieldMoisture or mgr.moistureData end

    local stressData = nil
    if stressMod then
        stressData = stressMod.fieldStress or stressMod.stressData or stressMod.fields
    end
    if not stressData then stressData = mgr.fieldStress or mgr.stressData end

    local settings = mgr.settings
    if settings and settings.enabled ~= nil then
        local en   = settings.enabled
        local diff = settings.difficulty or "Normal"
        self.r:appRect(x - FT.px(4), y - FT.py(22), cw + FT.px(8), FT.py(20),
            {accent[1]*0.10, accent[2]*0.10, accent[3]*0.10, 0.95})
        self.r:appText(x, y - FT.py(18), FT.FONT.SMALL,
            en and ("Active  |  Difficulty: " .. tostring(diff)) or "DISABLED",
            RenderText.ALIGN_LEFT, en and FT.C.POSITIVE or FT.C.WARNING)
        y = y - FT.py(26)
    end

    if not moistureData and not stressData then
        self.r:appText(x, y - FT.py(10), FT.FONT.BODY,
            "Moisture data not yet available.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, y - FT.py(28), FT.FONT.SMALL,
            "Wait for fields to initialize.", RenderText.ALIGN_LEFT, FT.C.MUTED)
        self:drawInfoIcon("_cropStressHelp", AC)
        return
    end

    local fieldIds = {}
    local seen = {}
    local function addIds(tbl)
        if type(tbl) ~= "table" then return end
        for k, _ in pairs(tbl) do
            if type(k) == "number" and not seen[k] then seen[k] = true; table.insert(fieldIds, k) end
        end
    end
    addIds(moistureData); addIds(stressData)
    table.sort(fieldIds)

    if #fieldIds == 0 then
        self.r:appText(x, y - FT.py(10), FT.FONT.BODY,
            "No crop stress data yet.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self:drawInfoIcon("_cropStressHelp", AC)
        return
    end

    local farmId     = self.system.data:getPlayerFarmId()
    local fieldCrop  = {}
    for _, f in ipairs(self.system.data:getOwnedFields(farmId)) do
        fieldCrop[f.id] = f.cropName or "Empty"
    end

    y = self:drawSection(y, "FIELDS  (" .. #fieldIds .. ")")

    for _, fid in ipairs(fieldIds) do
        if y <= minY + FT.py(16) then break end

        local rawMoist = nil
        if moistureData and moistureData[fid] ~= nil then rawMoist = moistureData[fid]
        elseif moistureSys and moistureSys.getMoisture then rawMoist = moistureSys:getMoisture(fid) end
        local moistPct = rawMoist and math.floor(rawMoist > 1.0 and rawMoist or rawMoist * 100) or nil

        local rawStress = stressData and stressData[fid]
        local stressPct = rawStress and math.floor(rawStress > 1.0 and rawStress or rawStress * 100) or 0

        local crop  = fieldCrop[fid] or "?"
        local label = "Field " .. fid .. "  [" .. crop .. "]"

        local moistColor = FT.C.TEXT_DIM
        if moistPct then
            moistColor = moistPct >= 40 and FT.C.POSITIVE or moistPct >= 25 and FT.C.WARNING or FT.C.NEGATIVE
        end

        local valStr = moistPct and string.format("%d%% moisture", moistPct) or "--"
        if stressPct > 5 then valStr = valStr .. "  !" .. stressPct .. "%" end

        y = self:drawRow(y, label, valStr, nil, moistPct and moistColor or FT.C.TEXT_DIM)

        if moistPct then
            y = y + FT.py(FT.SP.ROW) - FT.py(8)
            y = self:drawBar(y, moistPct, 100, moistColor)
            y = y - FT.py(2)
        end
    end

    self:drawInfoIcon("_cropStressHelp", AC)
end)


-- ── SOIL FERTILIZER ───────────────────────────────────────
FarmTabletUI:registerDrawer(FT.APP.SOIL_FERT, function(self)
    local AC = FT.appColor(FT.APP.SOIL_FERT)

    if self:drawHelpPage("_soilHelp", FT.APP.SOIL_FERT, "Soil Fertilizer", AC, {
        { title = "WHAT THIS APP SHOWS",
          body  = "Integrates with FS25_SoilFertilizer to display\n" ..
                  "nitrogen, phosphorus, potassium, pH, and organic\n" ..
                  "matter levels for each of your owned fields." },
        { title = "NEEDS FERTILIZER FLAG",
          body  = "Rows marked [FERT!] in yellow need fertilising.\n" ..
                  "Address these fields first to protect your harvest." },
        { title = "SELECT A FIELD",
          body  = "Click SELECT on any field row to open its detailed\n" ..
                  "soil profile in the panel below the list.\n" ..
                  "Click DESEL to close the detail view." },
        { title = "NUTRIENT COLOURS",
          body  = "Green = Good  |  Yellow = Fair  |  Red = Poor.\n" ..
                  "All four nutrients should be green for optimal yield.\n" ..
                  "Apply the correct fertiliser type to raise each one." },
        { title = "pH",
          body  = "Optimal pH range is 6.0 to 7.5.\n" ..
                  "Outside this range nutrient uptake is reduced even\n" ..
                  "if absolute nutrient levels look fine.\n" ..
                  "Apply lime to raise pH or sulphur to lower it." },
        { title = "ORGANIC MATTER",
          body  = "Higher organic matter improves water retention and\n" ..
                  "nutrient availability. Increased by crop rotation\n" ..
                  "and applying slurry or solid manure." },
    }) then return end

    local startY = self:drawAppHeader("Soil Fertilizer", "")
    local x, contentY, cw, _ = self:contentInner()
    local y    = startY
    local minY = contentY + FT.py(8)
    local accent = AC

    local mgr = g_SoilFertilityManager
        or g_soilFertilizerManager
        or (g_currentMission and (g_currentMission.soilFertilityManager or g_currentMission.soilFertilizerManager))

    if not mgr then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Soil Fertilizer mod not detected.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, y - FT.py(30), FT.FONT.SMALL,
            "Install FS25_SoilFertilizer to use this app.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self:drawInfoIcon("_soilHelp", AC)
        return
    end

    local soilSys  = mgr.soilSystem
    local settings = mgr.settings

    if not soilSys or not soilSys.isInitialized then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Soil system is initializing...", RenderText.ALIGN_LEFT, FT.C.WARNING)
        self:drawInfoIcon("_soilHelp", AC)
        return
    end

    if settings then
        local en = settings.enabled ~= false
        self.r:appRect(x - FT.px(4), y - FT.py(22), cw + FT.px(8), FT.py(20),
            {accent[1]*0.10, accent[2]*0.10, accent[3]*0.10, 0.95})
        self.r:appText(x, y - FT.py(18), FT.FONT.SMALL,
            en and "Active" or "DISABLED", RenderText.ALIGN_LEFT, en and FT.C.POSITIVE or FT.C.WARNING)
        if soilSys.PFActive then
            self.r:appText(x + cw, y - FT.py(18), FT.FONT.TINY,
                "PF DLC active", RenderText.ALIGN_RIGHT, FT.C.INFO)
        end
        y = y - FT.py(26)
    end

    local farmId      = self.system.data:getPlayerFarmId()
    local ownedFields = self.system.data:getOwnedFields(farmId)

    if #ownedFields == 0 then
        self.r:appText(x, y - FT.py(10), FT.FONT.BODY,
            "No owned fields found.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self:drawInfoIcon("_soilHelp", AC)
        return
    end

    if not self.system.soilSelectedField then
        self.system.soilSelectedField = ownedFields[1] and ownedFields[1].id
    end
    local selFieldId = self.system.soilSelectedField

    y = self:drawSection(y, "FIELDS  (" .. #ownedFields .. ")")

    local btnW = FT.px(46)
    local btnH = FT.py(18)

    for i, f in ipairs(ownedFields) do
        if y - btnH < minY + FT.py(60) then break end
        local isSel    = (f.id == selFieldId)
        local info     = soilSys:getFieldInfo(f.id)
        local needsFert = info and info.needsFertilization

        if isSel then
            self.r:appRect(x - FT.px(4), y - FT.py(4), cw + FT.px(8), btnH + FT.py(6),
                {accent[1]*0.14, accent[2]*0.14, accent[3]*0.14, 0.95})
        end

        local crop = (info and info.lastCrop) or f.cropName or "Empty"
        local nm   = "Field " .. f.id .. "  " .. crop
        if #nm > 22 then nm = nm:sub(1, 20) .. ">" end

        self.r:appText(x, y, FT.FONT.SMALL, nm, RenderText.ALIGN_LEFT,
            isSel and FT.C.TEXT_BRIGHT or FT.C.TEXT_NORMAL)

        if needsFert then
            self.r:appText(x + cw - btnW - FT.px(48), y, FT.FONT.TINY, "[FERT!]",
                RenderText.ALIGN_LEFT, FT.C.WARNING)
        end

        local fid = f.id
        local btn = self.r:button(x + cw - btnW, y - FT.py(2), btnW, btnH,
            isSel and "DESEL" or "SELECT", isSel and FT.C.BTN_ACTIVE or FT.C.BTN_NEUTRAL,
            { onClick = function()
                self.system.soilSelectedField = isSel and nil or fid
                self:switchApp(FT.APP.SOIL_FERT)
            end })
        table.insert(self._contentBtns, btn)
        y = y - FT.py(24)
    end

    if not selFieldId then
        self.r:appText(x, y - FT.py(6), FT.FONT.SMALL,
            "Select a field above for soil details.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self:drawInfoIcon("_soilHelp", AC)
        return
    end

    local info = soilSys:getFieldInfo(selFieldId)
    if not info then
        self.r:appText(x, y - FT.py(6), FT.FONT.SMALL,
            "No data for Field " .. selFieldId, RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self:drawInfoIcon("_soilHelp", AC)
        return
    end

    y = y - FT.py(4)
    y = self:drawRule(y, 0.4)
    y = self:drawSection(y, "SOIL DATA  — Field " .. selFieldId)

    local function nutrientColor(status)
        if status == "Good" then return FT.C.POSITIVE
        elseif status == "Fair" then return FT.C.WARNING
        else return FT.C.NEGATIVE end
    end

    if info.nitrogen   then y = self:drawRow(y, "Nitrogen",   info.nitrogen.value   .. "  (" .. info.nitrogen.status   .. ")", nil, nutrientColor(info.nitrogen.status))   end
    if info.phosphorus then y = self:drawRow(y, "Phosphorus", info.phosphorus.value .. "  (" .. info.phosphorus.status .. ")", nil, nutrientColor(info.phosphorus.status)) end
    if info.potassium  then y = self:drawRow(y, "Potassium",  info.potassium.value  .. "  (" .. info.potassium.status  .. ")", nil, nutrientColor(info.potassium.status))  end
    if info.pH then
        local phColor = (info.pH >= 6.0 and info.pH <= 7.5) and FT.C.POSITIVE or FT.C.WARNING
        y = self:drawRow(y, "pH", string.format("%.1f", info.pH), nil, phColor)
    end
    if info.organicMatter  then y = self:drawRow(y, "Organic Matter",    string.format("%.1f%%", info.organicMatter)) end
    if info.lastCrop and info.lastCrop ~= "" then y = self:drawRow(y, "Last Crop", info.lastCrop) end
    if info.daysSinceHarvest and info.daysSinceHarvest > 0 then y = self:drawRow(y, "Days Since Harvest", tostring(info.daysSinceHarvest)) end
    if info.needsFertilization then y = self:drawRow(y, "Needs Fertilizer", "YES", nil, FT.C.WARNING) end

    self:drawInfoIcon("_soilHelp", AC)
end)
