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

    y = y - FT.py(8)
    y = self:drawRule(y, 0.3)

    local minY = contentY + FT.py(8)
    if y > minY + FT.py(26) then
        self:drawButtonPair(
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
        self:drawButtonPair(
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
-- FarmTablet v2 – NPC Favor App  (FIXED)
-- ──────────────────────────────────────────────────────────
-- Correct access path (from NPCFavor main.lua):
--   g_NPCSystem           → the NPCSystem instance (global)
--   mission.npcFavorSystem→ same object, cross-mod bridge alias
--
-- NPCSystem fields used:
--   .activeNPCs           → array of NPC tables
--   .favorSystem          → NPCFavorSystem instance
--   .townReputation       → number 0–100
--
-- NPC table fields:
--   .name                 → string
--   .relationship         → number 0–100
--   .personality          → string
--   .role                 → string
--   .isActive             → bool
--
-- NPCFavorSystem fields:
--   .activeFavors         → array of favor tables
--   .stats.totalFavorsCompleted
--   .stats.totalMoneyEarned
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.NPC_FAVOR, function(self)
    local startY = self:drawAppHeader("NPC Favor", "")
    local x, contentY, cw, _ = self:contentInner()
    local y = startY
    local minY = contentY + FT.py(8)

    -- Locate the NPCSystem via both known paths
    local npcSys = g_NPCSystem
                or (g_currentMission and g_currentMission.npcFavorSystem)

    if not npcSys then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "NPC Favor mod not detected.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, y - FT.py(30), FT.FONT.SMALL,
            "Install FS25_NPCFavor to use this app.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    local npcs       = npcSys.activeNPCs  or {}
    local favorSys   = npcSys.favorSystem
    local townRep    = npcSys.townReputation or 0

    -- ── Town reputation hero row ───────────────────────────
    local accent = FT.appColor(FT.APP.NPC_FAVOR)
    local repColor = townRep >= 70 and FT.C.POSITIVE
                  or townRep >= 40 and FT.C.WARNING
                  or FT.C.NEGATIVE
    local repLabel = townRep >= 70 and "Respected"
                  or townRep >= 40 and "Neutral"
                  or "Poor"

    self.r:appRect(x - FT.px(4), y - FT.py(22),
        cw + FT.px(8), FT.py(20),
        {repColor[1]*0.12, repColor[2]*0.12, repColor[3]*0.12, 0.95})
    self.r:appText(x, y - FT.py(18), FT.FONT.BODY,
        "Town Reputation: " .. repLabel,
        RenderText.ALIGN_LEFT, repColor)
    self.r:appText(x + cw, y - FT.py(18), FT.FONT.SMALL,
        tostring(math.floor(townRep)) .. " / 100",
        RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
    y = y - FT.py(26)
    y = y + FT.py(FT.SP.ROW) - FT.py(8)
    y = self:drawBar(y, townRep, 100, repColor)
    y = y - FT.py(8)

    -- ── Active favors summary ──────────────────────────────
    if favorSys then
        local active    = favorSys.activeFavors or {}
        local stats     = favorSys.stats or {}
        y = self:drawRule(y, 0.3)
        y = self:drawSection(y, "FAVORS")
        y = self:drawRow(y, "Active Favors",    tostring(#active))
        y = self:drawRow(y, "Completed",        tostring(stats.totalFavorsCompleted or 0))
        y = self:drawRow(y, "Total Earned",
            (g_i18n and g_i18n:formatMoney(stats.totalMoneyEarned or 0, 0, true, true))
            or ("$" .. tostring(stats.totalMoneyEarned or 0)),
            nil, FT.C.POSITIVE)

        -- Show up to 3 active favors
        if #active > 0 then
            y = y - FT.py(4)
            y = self:drawRule(y, 0.2)
            y = self:drawSection(y, "ACTIVE")
            for i = 1, math.min(3, #active) do
                local f = active[i]
                if f and y > minY + FT.py(16) then
                    local hoursLeft = math.floor((f.timeRemaining or 0) / 3600000)
                    local pctColor = f.progress >= 66 and FT.C.POSITIVE
                                  or f.progress >= 33 and FT.C.WARNING
                                  or FT.C.TEXT_DIM
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

    -- ── NPC relationship list ──────────────────────────────
    y = self:drawSection(y, "RELATIONSHIPS  (" .. #npcs .. ")")

    if #npcs == 0 then
        self.r:appText(x, y - FT.py(10), FT.FONT.SMALL,
            "No NPCs spawned yet.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    -- Sort NPCs by relationship descending
    local sorted = {}
    for _, npc in ipairs(npcs) do
        if npc and npc.isActive ~= false then
            table.insert(sorted, npc)
        end
    end
    table.sort(sorted, function(a, b)
        return (a.relationship or 0) > (b.relationship or 0)
    end)

    for _, npc in ipairs(sorted) do
        if y <= minY + FT.py(16) then break end

        local rel = math.floor(math.min(math.max(npc.relationship or 0, 0), 100))
        local relColor = rel >= 70 and FT.C.POSITIVE
                      or rel >= 40 and FT.C.WARNING
                      or FT.C.NEGATIVE
        local relLabel = rel >= 70 and "Friend"
                      or rel >= 40 and "Neutral"
                      or "Cold"

        local nm = tostring(npc.name or "Unknown")
        if #nm > 16 then nm = nm:sub(1, 14) .. ">" end

        -- Role badge
        local role = npc.role or "?"
        self.r:appText(x, y, FT.FONT.SMALL,
            nm .. "  [" .. role .. "]",
            RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
        self.r:appText(x + cw, y, FT.FONT.SMALL,
            rel .. "  " .. relLabel,
            RenderText.ALIGN_RIGHT, relColor)

        y = y - FT.py(14)
        y = self:drawBar(y, rel, 100, relColor)
        y = y - FT.py(4)
    end
end)


-- =========================================================
-- FarmTablet v2 – Seasonal Crop Stress App  (FIXED)
-- ──────────────────────────────────────────────────────────
-- Correct access path (from SeasonalCropStress main.lua):
--   g_cropStressManager   → CropStressManager global
--
-- CropStressManager sub-systems (defensive probing):
--   .soilMoistureSystem   → SoilMoistureSystem
--     .fieldMoisture      → table [fieldId] = 0.0–1.0
--     .getMoisture(fid)   → number (if method exists)
--   .cropStressModifier   → CropStressModifier
--     .fieldStress        → table [fieldId] = 0.0–1.0
--
-- We cross-reference owned fields from DataProvider so we
-- can display named fields rather than bare IDs.
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.CROP_STRESS, function(self)
    local startY = self:drawAppHeader("Crop Stress", "Seasonal")
    local x, contentY, cw, _ = self:contentInner()
    local y = startY
    local minY = contentY + FT.py(8)
    local accent = FT.appColor(FT.APP.CROP_STRESS)

    local mgr = g_cropStressManager
    if not mgr then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Crop Stress mod not detected.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, y - FT.py(30), FT.FONT.SMALL,
            "Install FS25_SeasonalCropStress to use this app.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    -- ── Resolve sub-system references (probe several likely names) ──
    local moistureSys = mgr.soilMoistureSystem
                     or mgr.moistureSystem
                     or mgr.moisture

    local stressMod   = mgr.cropStressModifier
                     or mgr.stressModifier
                     or mgr.stress

    -- ── Resolve field moisture table ──────────────────────
    local moistureData = nil
    if moistureSys then
        moistureData = moistureSys.fieldMoisture
                    or moistureSys.moistureData
                    or moistureSys.fields
    end
    if not moistureData then
        moistureData = mgr.fieldMoisture or mgr.moistureData
    end

    -- ── Resolve field stress table ─────────────────────────
    local stressData = nil
    if stressMod then
        stressData = stressMod.fieldStress
                  or stressMod.stressData
                  or stressMod.fields
    end
    if not stressData then
        stressData = mgr.fieldStress or mgr.stressData
    end

    -- ── Settings summary ───────────────────────────────────
    local settings = mgr.settings
    if settings and settings.enabled ~= nil then
        local en = settings.enabled
        local diff = settings.difficulty or "Normal"
        self.r:appRect(x - FT.px(4), y - FT.py(22),
            cw + FT.px(8), FT.py(20),
            {accent[1]*0.10, accent[2]*0.10, accent[3]*0.10, 0.95})
        self.r:appText(x, y - FT.py(18), FT.FONT.SMALL,
            en and ("Active  |  Difficulty: " .. tostring(diff)) or "DISABLED",
            RenderText.ALIGN_LEFT,
            en and FT.C.POSITIVE or FT.C.WARNING)
        y = y - FT.py(26)
    end

    -- ── No data fallback ───────────────────────────────────
    if not moistureData and not stressData then
        self.r:appText(x, y - FT.py(10), FT.FONT.BODY,
            "Moisture data not yet available.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, y - FT.py(28), FT.FONT.SMALL,
            "Wait for fields to initialize.",
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        return
    end

    -- ── Gather field IDs from moisture or stress tables ────
    local fieldIds = {}
    local seen = {}
    local function addIds(tbl)
        if type(tbl) ~= "table" then return end
        for k, _ in pairs(tbl) do
            if type(k) == "number" and not seen[k] then
                seen[k] = true
                table.insert(fieldIds, k)
            end
        end
    end
    addIds(moistureData)
    addIds(stressData)
    table.sort(fieldIds)

    if #fieldIds == 0 then
        self.r:appText(x, y - FT.py(10), FT.FONT.BODY,
            "No crop stress data yet.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    -- ── Cross-reference owned fields for crop names ────────
    local farmId = self.system.data:getPlayerFarmId()
    local ownedFields = self.system.data:getOwnedFields(farmId)
    local fieldCrop = {}
    for _, f in ipairs(ownedFields) do
        fieldCrop[f.id] = f.cropName or "Empty"
    end

    -- ── Section header with count ──────────────────────────
    y = self:drawSection(y, "FIELDS  (" .. #fieldIds .. ")")

    for _, fid in ipairs(fieldIds) do
        if y <= minY + FT.py(16) then break end

        -- Moisture: value is typically 0.0–1.0, display as %
        local rawMoist = nil
        if moistureData and moistureData[fid] ~= nil then
            rawMoist = moistureData[fid]
        elseif moistureSys and moistureSys.getMoisture then
            rawMoist = moistureSys:getMoisture(fid)
        end
        local moistPct = rawMoist and math.floor(
            (rawMoist > 1.0 and rawMoist or rawMoist * 100)   -- handle both 0-1 and 0-100
        ) or nil

        -- Stress: value is typically 0.0–1.0
        local rawStress = stressData and stressData[fid]
        local stressPct = rawStress and math.floor(
            (rawStress > 1.0 and rawStress or rawStress * 100)
        ) or 0

        local crop = fieldCrop[fid] or "?"
        local label = "Field " .. fid .. "  [" .. crop .. "]"

        -- Color moisture: green>=40, yellow>=25, red<25
        local moistColor = FT.C.TEXT_DIM
        if moistPct then
            moistColor = moistPct >= 40 and FT.C.POSITIVE
                      or moistPct >= 25 and FT.C.WARNING
                      or FT.C.NEGATIVE
        end

        -- Stress indicator
        local stressColor = stressPct <= 20 and FT.C.POSITIVE
                         or stressPct <= 50 and FT.C.WARNING
                         or FT.C.NEGATIVE

        local valStr = moistPct and string.format("%d%% moisture", moistPct) or "--"
        if stressPct > 5 then
            valStr = valStr .. "  !" .. stressPct .. "%"
        end

        y = self:drawRow(y, label, valStr, nil, moistPct and moistColor or FT.C.TEXT_DIM)

        if moistPct then
            y = y + FT.py(FT.SP.ROW) - FT.py(8)
            y = self:drawBar(y, moistPct, 100, moistColor)
            y = y - FT.py(2)
        end
    end
end)


-- =========================================================
-- FarmTablet v2 – Soil Fertilizer App  (FIXED)
-- ──────────────────────────────────────────────────────────
-- Correct access path (from SoilFertilizer main.lua):
--   g_SoilFertilityManager   → SoilFertilityManager global
--
-- SoilFertilityManager fields:
--   .soilSystem              → SoilFertilitySystem
--   .settings                → Settings
--
-- SoilFertilitySystem methods used:
--   :getFieldInfo(fieldId)   → {
--       fieldId, nitrogen{value,status}, phosphorus{value,status},
--       potassium{value,status}, organicMatter, pH,
--       lastCrop, daysSinceHarvest, needsFertilization }
--   :getFieldCount()         → number
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.SOIL_FERT, function(self)
    local startY = self:drawAppHeader("Soil Fertilizer", "")
    local x, contentY, cw, _ = self:contentInner()
    local y = startY
    local minY = contentY + FT.py(8)
    local accent = FT.appColor(FT.APP.SOIL_FERT)

    -- Locate the manager via the correct global (set in SoilFertilizer main.lua)
    local mgr = g_SoilFertilityManager
    -- Fallback to old guesses for resilience
    if not mgr then
        mgr = g_soilFertilizerManager
           or (g_currentMission and (
               g_currentMission.soilFertilityManager
            or g_currentMission.soilFertilizerManager))
    end

    if not mgr then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Soil Fertilizer mod not detected.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, y - FT.py(30), FT.FONT.SMALL,
            "Install FS25_SoilFertilizer to use this app.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    local soilSys  = mgr.soilSystem
    local settings = mgr.settings

    if not soilSys or not soilSys.isInitialized then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Soil system is initializing...",
            RenderText.ALIGN_LEFT, FT.C.WARNING)
        return
    end

    -- ── Settings status banner ─────────────────────────────
    if settings then
        local en = settings.enabled ~= false
        self.r:appRect(x - FT.px(4), y - FT.py(22),
            cw + FT.px(8), FT.py(20),
            {accent[1]*0.10, accent[2]*0.10, accent[3]*0.10, 0.95})
        self.r:appText(x, y - FT.py(18), FT.FONT.SMALL,
            en and "Active" or "DISABLED",
            RenderText.ALIGN_LEFT,
            en and FT.C.POSITIVE or FT.C.WARNING)
        if soilSys.PFActive then
            self.r:appText(x + cw, y - FT.py(18), FT.FONT.TINY,
                "PF DLC active",
                RenderText.ALIGN_RIGHT, FT.C.INFO)
        end
        y = y - FT.py(26)
    end

    -- ── Which fields to show: owned by player ─────────────
    local farmId = self.system.data:getPlayerFarmId()
    local ownedFields = self.system.data:getOwnedFields(farmId)

    if #ownedFields == 0 then
        self.r:appText(x, y - FT.py(10), FT.FONT.BODY,
            "No owned fields found.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    -- ── Field selector (show field index of selected) ──────
    -- Use workshopSelectedVehicle slot pattern - reuse system.soilSelectedField
    if not self.system.soilSelectedField then
        self.system.soilSelectedField = ownedFields[1] and ownedFields[1].id
    end
    local selFieldId = self.system.soilSelectedField

    -- ── Field list (compact, just ID + needs-fertilizer flag) ─
    y = self:drawSection(y, "FIELDS  (" .. #ownedFields .. ")")

    local btnW = FT.px(46)
    local btnH = FT.py(18)

    for i, f in ipairs(ownedFields) do
        if y - btnH < minY + FT.py(60) then break end  -- leave room for detail panel

        local isSel = (f.id == selFieldId)
        local info  = soilSys:getFieldInfo(f.id)
        local needsFert = info and info.needsFertilization

        local rowColor = isSel
            and {accent[1]*0.14, accent[2]*0.14, accent[3]*0.14, 0.95}
            or  nil
        if rowColor then
            self.r:appRect(x - FT.px(4), y - FT.py(4),
                cw + FT.px(8), btnH + FT.py(6), rowColor)
        end

        local crop = (info and info.lastCrop) or f.cropName or "Empty"
        local nm = "Field " .. f.id .. "  " .. crop
        if #nm > 22 then nm = nm:sub(1, 20) .. ">" end

        self.r:appText(x, y, FT.FONT.SMALL, nm,
            RenderText.ALIGN_LEFT,
            isSel and FT.C.TEXT_BRIGHT or FT.C.TEXT_NORMAL)

        if needsFert then
            self.r:appText(x + cw - btnW - FT.px(48), y,
                FT.FONT.TINY, "[FERT!]",
                RenderText.ALIGN_LEFT, FT.C.WARNING)
        end

        local fid = f.id
        local btn = self.r:button(x + cw - btnW, y - FT.py(2), btnW, btnH,
            isSel and "DESEL" or "SELECT",
            isSel and FT.C.BTN_ACTIVE or FT.C.BTN_NEUTRAL,
            { onClick = function()
                self.system.soilSelectedField = isSel and nil or fid
                self:switchApp(FT.APP.SOIL_FERT)
            end })
        table.insert(self._contentBtns, btn)

        y = y - FT.py(24)
    end

    -- ── Detail panel for selected field ───────────────────
    if not selFieldId then
        self.r:appText(x, y - FT.py(6), FT.FONT.SMALL,
            "Select a field above for soil details.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    local info = soilSys:getFieldInfo(selFieldId)
    if not info then
        self.r:appText(x, y - FT.py(6), FT.FONT.SMALL,
            "No data for Field " .. selFieldId,
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
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

    if info.nitrogen then
        y = self:drawRow(y, "Nitrogen",
            info.nitrogen.value .. "  (" .. info.nitrogen.status .. ")",
            nil, nutrientColor(info.nitrogen.status))
    end
    if info.phosphorus then
        y = self:drawRow(y, "Phosphorus",
            info.phosphorus.value .. "  (" .. info.phosphorus.status .. ")",
            nil, nutrientColor(info.phosphorus.status))
    end
    if info.potassium then
        y = self:drawRow(y, "Potassium",
            info.potassium.value .. "  (" .. info.potassium.status .. ")",
            nil, nutrientColor(info.potassium.status))
    end
    if info.pH then
        local phColor = (info.pH >= 6.0 and info.pH <= 7.5) and FT.C.POSITIVE
                     or FT.C.WARNING
        y = self:drawRow(y, "pH",
            string.format("%.1f", info.pH),
            nil, phColor)
    end
    if info.organicMatter then
        y = self:drawRow(y, "Organic Matter",
            string.format("%.1f%%", info.organicMatter))
    end
    if info.lastCrop and info.lastCrop ~= "" then
        y = self:drawRow(y, "Last Crop", info.lastCrop)
    end
    if info.daysSinceHarvest and info.daysSinceHarvest > 0 then
        y = self:drawRow(y, "Days Since Harvest",
            tostring(info.daysSinceHarvest))
    end
    if info.needsFertilization then
        y = self:drawRow(y, "Needs Fertilizer", "YES", nil, FT.C.WARNING)
    end
end)
