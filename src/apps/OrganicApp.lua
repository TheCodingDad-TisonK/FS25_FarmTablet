-- =========================================================
-- FarmTablet - Organic Management (Arissani brief)
-- =========================================================
-- Read-only hub over Soil Fertilizer organic certification.
-- CERTIFICATION + PRACTICES + COMPOST display built; LIVESTOCK / MARKET stub.
-- Opt-in / opt-out via SF requestOptIn / requestOptOut only.
-- =========================================================

local STATE_LABEL = {
    conventional   = "Conventional",
    in_transition  = "In transition",
    certified      = "Certified",
}

local STATE_COLOR = {
    conventional   = FT.C.TEXT_DIM,
    in_transition  = FT.C.WARNING,
    certified      = FT.C.POSITIVE,
}

local function _mgr()
    return (g_currentMission and g_currentMission.soilFertilityManager)
        or getfenv(0)["g_SoilFertilityManager"]
end

local function _pcall(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c
end

local function _stateKey(st)
    if st == nil then return "conventional" end
    local s = tostring(st.state or "")
    if s == "certified" or st.certified == true then return "certified" end
    if s == "in_transition" or s == "transition" then return "in_transition" end
    -- SoilConstants may use uppercase / numeric enums; treat certified flag first.
    if type(s) == "string" and s:lower():find("cert", 1, true) then return "certified" end
    if type(s) == "string" and s:lower():find("trans", 1, true) then return "in_transition" end
    return "conventional"
end

local function _practiceLines(info)
    local lines = {}
    if info == nil then
        return { "No soil data for this field yet." }
    end
    local om = tonumber(info.organicMatter) or 0
    if om < 3.0 then
        lines[#lines + 1] = "OM low - plow in manure/compost or chop straw."
    elseif om < 4.0 then
        lines[#lines + 1] = "OM fair - keep organic inputs coming."
    else
        lines[#lines + 1] = "OM healthy - maintain cover and residues."
    end

    local rot = tostring(info.rotationStatus or "OK")
    local last = tostring(info.lastCrop or "-")
    local last2 = tostring(info.lastCrop2 or "-")
    if rot == "Fatigue" then
        lines[#lines + 1] = string.format(
            "Rotation fatigue after %s / %s - plant a legume next.", last, last2)
    elseif rot == "Bonus" then
        lines[#lines + 1] = string.format(
            "Rotation bonus active (%s / %s) - protect it with diversity.", last, last2)
    else
        lines[#lines + 1] = string.format(
            "Rotation %s (%s / %s) - keep a legume in the cycle.", rot, last, last2)
    end

    if info.needsFertilization then
        lines[#lines + 1] = "Needs fertility - prefer approved organic inputs."
    end
    return lines
end

FarmTabletUI:registerDrawer(FT.APP.ORGANIC, function(self)
    local AC = FT.appColor(FT.APP.ORGANIC)

    if self:drawHelpPage("_organicHelp", FT.APP.ORGANIC, "Organic", AC, {
        { title = "WHAT THIS IS",
          body  = "Organic certification and practice advice for your\n" ..
                  "fields. Reads Soil Fertilizer. Owns no organic state." },
        { title = "CERTIFICATION",
          body  = "Per-field state: Conventional, In transition, or\n" ..
                  "Certified, plus the transition countdown. OPT IN /\n" ..
                  "OPT OUT asks Soil Fertilizer (admin-gated there)." },
        { title = "PRACTICES",
          body  = "Cover-crop and rotation tips framed for organic,\n" ..
                  "from the same soil data as the Soil Fertilizer app." },
        { title = "COMING LATER",
          body  = "Compost, livestock feed, and market premium sections\n" ..
                  "stay stubs until those sims expose read APIs." },
    }) then return end

    local startY = self:drawAppHeader("Organic", "Management")
    local x, cyBottom, cw, _ = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y = startY + scrollY
    local bottomPad = FT.py(28)

    local mgr = _mgr()
    if mgr == nil or mgr.soilSystem == nil then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Soil Fertilizer not detected.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, y - FT.py(30), FT.FONT.SMALL,
            "Install FS25_SoilFertilizer to use this app.",
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        self:drawInfoIcon("_organicHelp", AC)
        return
    end

    local organic = mgr.organic
    local soil = mgr.soilSystem
    local farmId = self.system.data:getPlayerFarmId()
    local fields = self.system.data:getOwnedFields(farmId) or {}

    ------------------------------------------------------------------
    -- CERTIFICATION
    ------------------------------------------------------------------
    y = self:drawSection(y, "CERTIFICATION")
    if organic == nil or type(organic.getFieldOrganicState) ~= "function" then
        self.r:appText(x, y - FT.py(4), FT.FONT.SMALL,
            "Organic certification not available on this Soil build.",
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        y = y - FT.py(22)
    elseif #fields == 0 then
        self.r:appText(x, y - FT.py(4), FT.FONT.SMALL,
            "No owned fields yet.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        y = y - FT.py(22)
    else
        local selected = self.system.organicSelectedField
        if selected == nil then
            selected = fields[1].id
            self.system.organicSelectedField = selected
        end

        local btnW = FT.px(64)
        local btnH = FT.py(16)
        local rowH = FT.py(34)

        for _, field in ipairs(fields) do
            local st = _pcall(function() return organic:getFieldOrganicState(field.id) end)
            local key = _stateKey(st)
            local label = STATE_LABEL[key] or "Unknown"
            local col = STATE_COLOR[key] or FT.C.MUTED
            local isSel = (field.id == selected)

            if isSel then
                self.r:appRect(x - FT.px(2), y - rowH + FT.py(6), cw + FT.px(4), rowH,
                    { AC[1] * 0.12, AC[2] * 0.12, AC[3] * 0.12, 0.95 })
            end

            self.r:appText(x, y - FT.py(2), FT.FONT.SMALL,
                string.format("Field #%s", tostring(field.id)),
                RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)
            self.r:appText(x + cw - btnW - FT.px(8), y - FT.py(2), FT.FONT.SMALL,
                label, RenderText.ALIGN_RIGHT, col)
            y = y - FT.py(14)

            local countdown = ""
            if key == "in_transition" and st ~= nil then
                local accrued = tonumber(st.daysAccrued) or 0
                local need = tonumber(st.transitionDaysNeeded) or 0
                local left = math.max(0, need - accrued)
                countdown = string.format("%d / %d days  (%d left)",
                    math.floor(accrued + 0.5), math.floor(need + 0.5), math.floor(left + 0.5))
            elseif key == "certified" then
                local breaches = st and tonumber(st.breaches) or 0
                countdown = string.format("Breaches: %d", breaches)
            else
                countdown = "Not in the organic programme"
            end
            self.r:appText(x, y - FT.py(1), FT.FONT.TINY, countdown,
                RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)

            local selBtn = self.r:button(x + cw - btnW, y - FT.py(2), btnW, btnH,
                isSel and "VIEW" or "SELECT", isSel and AC or FT.C.BTN_NEUTRAL, {
                    onClick = function()
                        self.system.organicSelectedField = field.id
                    end
                })
            table.insert(self._contentBtns, selBtn)
            y = y - FT.py(20)
        end

        -- Actions for selected field
        local selSt = _pcall(function() return organic:getFieldOrganicState(selected) end)
        local selKey = _stateKey(selSt)
        y = y - FT.py(4)
        self.r:appText(x, y - FT.py(2), FT.FONT.TINY,
            string.format("Selected field #%s", tostring(selected)),
            RenderText.ALIGN_LEFT, FT.C.TEXT_ACCENT)
        y = y - FT.py(16)

        local gap = FT.px(6)
        local half = (cw - gap) / 2
        local canIn = (selKey == "conventional")
        local canOut = (selKey == "in_transition" or selKey == "certified")
        if type(organic.requestOptIn) == "function" and canIn then
            local bIn = self.r:button(x, y - FT.py(20), half, FT.py(20), "OPT IN",
                FT.C.BTN_PRIMARY, {
                    onClick = function()
                        pcall(function() organic:requestOptIn(selected) end)
                    end
                })
            table.insert(self._contentBtns, bIn)
        else
            self.r:appText(x, y - FT.py(8), FT.FONT.TINY,
                canIn and "Opt-in unavailable" or "Already opted in",
                RenderText.ALIGN_LEFT, FT.C.MUTED)
        end
        if type(organic.requestOptOut) == "function" and canOut then
            local bOut = self.r:button(x + half + gap, y - FT.py(20), half, FT.py(20),
                "OPT OUT", FT.C.BTN_DANGER, {
                    onClick = function()
                        pcall(function() organic:requestOptOut(selected) end)
                    end
                })
            table.insert(self._contentBtns, bOut)
        end
        y = y - FT.py(28)
    end

    ------------------------------------------------------------------
    -- PRACTICES
    ------------------------------------------------------------------
    y = self:drawRule(y, 0.3)
    y = self:drawSection(y, "PRACTICES")
    local sel = self.system.organicSelectedField
    if sel == nil and #fields > 0 then sel = fields[1].id end
    if sel == nil then
        self.r:appText(x, y - FT.py(4), FT.FONT.SMALL,
            "Select a field to see practice advice.", RenderText.ALIGN_LEFT, FT.C.MUTED)
        y = y - FT.py(20)
    else
        local info = _pcall(function() return soil:getFieldInfo(sel) end)
        self.r:appText(x, y - FT.py(2), FT.FONT.TINY,
            string.format("Field #%s", tostring(sel)),
            RenderText.ALIGN_LEFT, FT.C.TEXT_ACCENT)
        y = y - FT.py(14)
        for _, line in ipairs(_practiceLines(info)) do
            self.r:appText(x, y - FT.py(1), FT.FONT.SMALL, line,
                RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
            y = y - FT.py(14)
        end
        y = y - FT.py(6)
    end

    ------------------------------------------------------------------
    -- STUBS
    ------------------------------------------------------------------
    y = self:drawRule(y, 0.3)
    y = self:drawSection(y, "COMPOST")
    local compost = (g_currentMission ~= nil and g_currentMission.compostManager) or nil
    if compost == nil or type(compost.getBatchRows) ~= "function" then
        self.r:appText(x, y - FT.py(4), FT.FONT.SMALL,
            "not available - install SoilFertilizer", RenderText.ALIGN_LEFT, FT.C.MUTED)
        y = y - FT.py(22)
    else
        local rows = _pcall(function() return compost:getBatchRows(farmId) end) or {}
        if #rows == 0 then
            self.r:appText(x, y - FT.py(4), FT.FONT.SMALL,
                "No compost batches. Start one from the SoilFertilizer console.",
                RenderText.ALIGN_LEFT, FT.C.MUTED)
            -- Advance past the line (same step as the not-available branch) so the
            -- LIVESTOCK header does not land on top of it.
            y = y - FT.py(22)
        else
            for _, b in ipairs(rows) do
                local state = b.ready
                    and string.format("READY - %d L", math.floor(b.outputLitres or 0))
                    or  string.format("%d day(s) left", math.floor(b.daysRemaining or 0))
                local tag = b.organicSafe and "organic-safe" or "not organic-safe"
                self.r:appText(x, y - FT.py(2), FT.FONT.TINY,
                    string.format("Batch #%d: %s  (%s)", b.batchId, state, tag),
                    RenderText.ALIGN_LEFT, b.ready and FT.C.POSITIVE or FT.C.TEXT_DIM)
                y = y - FT.py(14)
            end
        end
        y = y - FT.py(8)
    end

    y = self:drawSection(y, "LIVESTOCK")
    local dcMgr = (g_currentMission and g_currentMission.dairyCoreManager)
        or getfenv(0)["g_dairyCoreManager"]
    if dcMgr == nil then
        self.r:appText(x, y - FT.py(4), FT.FONT.SMALL,
            "not available - install DairyCore",
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        y = y - FT.py(22)
    else
        local barnRows = {}
        if type(dcMgr.getBarnRows) == "function" then
            local ok, result = pcall(function() return dcMgr:getBarnRows() end)
            if ok and type(result) == "table" then barnRows = result end
        end
        local farmBarns = {}
        for _, row in ipairs(barnRows) do
            if row.farmId == farmId then farmBarns[#farmBarns + 1] = row end
        end

        if #farmBarns == 0 then
            self.r:appText(x, y - FT.py(4), FT.FONT.SMALL,
                "No dairy barns on this farm.",
                RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            y = y - FT.py(22)
        else
            local fp = dcMgr.feedProvenance
            local farmOrgFrac = 0
            if fp ~= nil and type(fp.organicFeedFraction) == "function" then
                local ok2, frac = pcall(function() return fp:organicFeedFraction(farmId) end)
                if ok2 and type(frac) == "number" then farmOrgFrac = frac end
            end

            local orgPct = math.floor(farmOrgFrac * 100 + 0.5)
            local orgCol = orgPct >= 80 and FT.C.POSITIVE
                or orgPct >= 40 and FT.C.WARNING or FT.C.TEXT_DIM
            self.r:appText(x, y - FT.py(2), FT.FONT.TINY,
                "Farm organic feed share", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            self.r:appText(x + cw, y - FT.py(2), FT.FONT.TINY,
                string.format("%d%%", orgPct), RenderText.ALIGN_RIGHT, orgCol)
            y = y - FT.py(14)

            for _, barn in ipairs(farmBarns) do
                local health = math.floor(tonumber(barn.herdHealth) or 0)
                local hCol = health >= 85 and FT.C.POSITIVE
                    or health >= 60 and FT.C.TEXT_NORMAL
                    or health >= 35 and FT.C.WARNING or FT.C.NEGATIVE
                local myc = tonumber(barn.mycotoxin) or 0
                local feedFlag = barn.feedDiseaseFlag == true

                self.r:appText(x, y - FT.py(2), FT.FONT.SMALL,
                    string.format("Barn %s", tostring(barn.barnId)),
                    RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)
                y = y - FT.py(14)

                self.r:appText(x, y - FT.py(1), FT.FONT.TINY,
                    "Herd health", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
                self.r:appText(x + cw, y - FT.py(1), FT.FONT.TINY,
                    string.format("%d", health), RenderText.ALIGN_RIGHT, hCol)
                y = y - FT.py(12)

                if myc > 0 then
                    self.r:appText(x, y - FT.py(1), FT.FONT.TINY,
                        "Mycotoxin penalty", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
                    self.r:appText(x + cw, y - FT.py(1), FT.FONT.TINY,
                        string.format("-%d", myc), RenderText.ALIGN_RIGHT, FT.C.NEGATIVE)
                    y = y - FT.py(12)
                end

                if feedFlag then
                    local feedLabel = barn.feedDiseaseCropName or "Elevated risk"
                    self.r:appText(x, y - FT.py(1), FT.FONT.TINY,
                        "Feed disease", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
                    self.r:appText(x + cw, y - FT.py(1), FT.FONT.TINY,
                        tostring(feedLabel), RenderText.ALIGN_RIGHT, FT.C.NEGATIVE)
                    y = y - FT.py(12)
                end
                y = y - FT.py(4)
            end

            if orgPct < 80 then
                self.r:appText(x, y - FT.py(1), FT.FONT.TINY,
                    "Tip: certify more feed fields organic to raise the share above 80%.",
                    RenderText.ALIGN_LEFT, FT.C.MUTED)
                y = y - FT.py(14)
            end
        end
        y = y - FT.py(6)
    end

    ------------------------------------------------------------------
    -- TRACEABILITY (read-only chain: field -> storage -> sale)
    ------------------------------------------------------------------
    y = self:drawRule(y, 0.3)
    y = self:drawSection(y, "TRACEABILITY")
    if organic == nil then
        self.r:appText(x, y - FT.py(4), FT.FONT.SMALL,
            "not available - organic certification not loaded",
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        y = y - FT.py(22)
    elseif #fields == 0 then
        self.r:appText(x, y - FT.py(4), FT.FONT.SMALL,
            "No owned fields.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        y = y - FT.py(22)
    else
        self.r:appText(x, y - FT.py(2), FT.FONT.TINY,
            "FIELD", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x + cw * 0.35, y - FT.py(2), FT.FONT.TINY,
            "CROP", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x + cw, y - FT.py(2), FT.FONT.TINY,
            "STATUS", RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
        y = y - FT.py(12)

        for _, field in ipairs(fields) do
            local st = _pcall(function() return organic:getFieldOrganicState(field.id) end)
            local key = _stateKey(st)
            local col = STATE_COLOR[key] or FT.C.MUTED
            local info = _pcall(function() return soil:getFieldInfo(field.id) end)
            local crop = (info and tostring(info.lastCrop)) or "-"

            self.r:appText(x, y - FT.py(1), FT.FONT.TINY,
                string.format("#%s", tostring(field.id)),
                RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
            self.r:appText(x + cw * 0.35, y - FT.py(1), FT.FONT.TINY,
                crop, RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
            self.r:appText(x + cw, y - FT.py(1), FT.FONT.TINY,
                STATE_LABEL[key] or "?", RenderText.ALIGN_RIGHT, col)
            y = y - FT.py(12)
        end
        y = y - FT.py(4)

        local dcMgrTrace = (g_currentMission and g_currentMission.dairyCoreManager)
            or getfenv(0)["g_dairyCoreManager"]
        local fpTrace = dcMgrTrace and dcMgrTrace.feedProvenance
        if fpTrace and type(fpTrace.organicFeedFraction) == "function" then
            local okF, frac = pcall(function() return fpTrace:organicFeedFraction(farmId) end)
            if okF and type(frac) == "number" then
                local pct = math.floor(frac * 100 + 0.5)
                local fCol = pct >= 80 and FT.C.POSITIVE
                    or pct >= 40 and FT.C.WARNING or FT.C.TEXT_DIM
                self.r:appText(x, y - FT.py(2), FT.FONT.TINY,
                    "Storage organic fraction", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
                self.r:appText(x + cw, y - FT.py(2), FT.FONT.TINY,
                    string.format("%d%%", pct), RenderText.ALIGN_RIGHT, fCol)
                y = y - FT.py(14)
            end
        end

        self.r:appText(x, y - FT.py(2), FT.FONT.TINY,
            "Sale premium: pending MDM contract",
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        y = y - FT.py(14)
    end

    y = self:drawSection(y, "MARKET")
    self.r:appText(x, y - FT.py(4), FT.FONT.SMALL,
        "not available - waiting on organic premium / MDM contract",
        RenderText.ALIGN_LEFT, FT.C.MUTED)
    y = y - FT.py(22)

    self:setContentHeight(startY - y + scrollY + bottomPad)
    self:drawInfoIcon("_organicHelp", AC)
    self:drawScrollBar()
end)
