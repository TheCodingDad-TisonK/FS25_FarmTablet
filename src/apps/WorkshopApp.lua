-- =========================================================
-- FarmTablet v2 – Workshop App
-- Nearby vehicle diagnostics with selection
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.WORKSHOP, function(self)
    local data   = self.system.data
    local nearby = data:getNearbyVehicles(25)
    local sel    = self.system.workshopSelectedVehicle

    local startY = self:drawAppHeader("Workshop",
        #nearby .. " nearby")

    local x, contentY, cw, _ = self:contentInner()
    local y = startY
    local minY = contentY + FT.py(8)

    -- Validate selection still in range
    if sel then
        local found = false
        for _, v in ipairs(nearby) do
            if v.vehicle == sel then found = true; break end
        end
        if not found then
            self.system.workshopSelectedVehicle = nil
            sel = nil
        end
    end

    -- ── No vehicles ────────────────────────────────────────
    if #nearby == 0 then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "No vehicles within 25 m.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, y - FT.py(30), FT.FONT.SMALL,
            "Walk closer to a vehicle to inspect it.",
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        return
    end

    -- ── Vehicle list ───────────────────────────────────────
    y = self:drawSection(y, "NEARBY  (" .. #nearby .. ")")

    local btnW = FT.px(42)
    local btnH = FT.py(18)

    for i = 1, math.min(5, #nearby) do
        local v = nearby[i]
        if y - btnH < minY then break end

        local isSel   = (v.vehicle == sel)
        local nameColor = isSel and FT.C.TEXT_BRIGHT or FT.C.TEXT_NORMAL

        -- Row bg on hover / selected
        if isSel then
            self.r:appRect(x - FT.px(4), y - FT.py(4),
                cw + FT.px(8), btnH + FT.py(6), FT.C.BRAND_GLOW)
        end

        -- Name
        local nm = v.name
        if #nm > 22 then nm = nm:sub(1,20) .. "…" end
        self.r:appText(x, y, FT.FONT.SMALL, nm,
            RenderText.ALIGN_LEFT, nameColor)

        -- Distance
        self.r:appText(x + cw - btnW - FT.px(50), y, FT.FONT.TINY,
            v.distance .. " m",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)

        -- Select button
        local bColor  = isSel and FT.C.BTN_ACTIVE or FT.C.BTN_NEUTRAL
        local bLabel  = isSel and "SELECTED" or "SELECT"
        local vehicle = v.vehicle  -- capture for closure
        local btn = self.r:button(x + cw - btnW, y - FT.py(2), btnW, btnH,
            bLabel, bColor,
            { onClick = function()
                self.system.workshopSelectedVehicle = vehicle
                self:switchApp(FT.APP.WORKSHOP)
            end })
        table.insert(self._contentBtns, btn)

        y = y - FT.py(22)
    end

    -- ── Diagnostics panel ──────────────────────────────────
    if not sel then
        y = y - FT.py(6)
        self.r:appText(x, y, FT.FONT.SMALL,
            "Select a vehicle to see diagnostics.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    -- Find selected in nearby list
    local selData = nil
    for _, v in ipairs(nearby) do
        if v.vehicle == sel then selData = v; break end
    end
    if not selData then return end

    y = y - FT.py(4)
    y = self:drawRule(y, 0.4)
    y = self:drawSection(y, "DIAGNOSTICS")

    -- Full vehicle name
    local fullName = (sel.getFullName and sel:getFullName()) or selData.name
    if #fullName > 26 then fullName = fullName:sub(1,24) .. "…" end
    y = self:drawRow(y, "Vehicle", fullName)

    -- Fuel
    local fuelPct  = selData.fuelPct
    local fuelColor = fuelPct >= 50 and FT.C.POSITIVE
                   or fuelPct >= 20 and FT.C.WARNING
                   or FT.C.NEGATIVE
    y = self:drawRow(y, "Fuel",
        string.format("%.0f%%  (%.0fL / %.0fL)",
            fuelPct, selData.fuel, selData.fuelCap),
        nil, fuelColor)
    y = y + FT.py(FT.SP.ROW) - FT.py(8)
    y = self:drawBar(y, fuelPct, 100, fuelColor)

    -- Wear
    local wearPct  = selData.wearPct
    local wearColor = wearPct <= 30 and FT.C.POSITIVE
                   or wearPct <= 65 and FT.C.WARNING
                   or FT.C.NEGATIVE
    y = self:drawRow(y - FT.py(4), "Wear",
        string.format("%d%%", wearPct), nil, wearColor)
    y = y + FT.py(FT.SP.ROW) - FT.py(8)
    y = self:drawBar(y, wearPct, 100, wearColor)

    -- Hours
    y = self:drawRow(y - FT.py(4), "Operating Hours",
        selData.opHours .. " h")
end)
