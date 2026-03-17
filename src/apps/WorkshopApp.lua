-- =========================================================
-- FarmTablet v2 – Workshop App  (FIXED v2)
-- • Detects workshop placeables owned by the player's farm
-- • Detects nearby vehicles (35 m radius)
-- • Shows diagnostics: fuel, wear, operating hours
-- • "REPAIR" button uses FS25 wear/repair APIs
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.WORKSHOP, function(self)
    local data      = self.system.data
    local farmId    = data:getPlayerFarmId()
    local nearby    = data:getNearbyVehicles(35)

    -- ── Locate owned workshop placeables ──────────────────
    local workshops = {}
    if g_currentMission and g_currentMission.placeableSystem then
        for _, p in pairs(g_currentMission.placeableSystem.placeables) do
            local isWorkshop = false
            -- spec_workshop is the authoritative FS25 indicator
            if p.spec_workshop then
                isWorkshop = true
            end
            -- Fallback: typeName / className contains "workshop"
            if not isWorkshop then
                local tn = (p.typeName or p.className or ""):lower()
                if tn:find("workshop") then isWorkshop = true end
            end
            if isWorkshop then
                local ownerOk = true
                if p.getOwnerFarmId then
                    ownerOk = (p:getOwnerFarmId() == farmId)
                end
                if ownerOk then
                    table.insert(workshops, p)
                end
            end
        end
    end

    local sel    = self.system.workshopSelectedVehicle
    local startY = self:drawAppHeader("Workshop",
        #workshops .. " shop / " .. #nearby .. " near")

    local x, contentY, cw, _ = self:contentInner()
    local y    = startY
    local minY = contentY + FT.py(8)

    -- Validate selection still in nearby list
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

    -- ── Workshop status banner ─────────────────────────────
    local accent = FT.appColor(FT.APP.WORKSHOP)
    if #workshops == 0 then
        self.r:appRect(x - FT.px(4), y - FT.py(18),
            cw + FT.px(8), FT.py(16),
            {accent[1]*0.12, accent[2]*0.12, accent[3]*0.12, 0.95})
        self.r:appText(x, y - FT.py(13), FT.FONT.SMALL,
            "No workshop found on this farm  (repairs disabled)",
            RenderText.ALIGN_LEFT, FT.C.WARNING)
        y = y - FT.py(24)
    else
        local ws = workshops[1]
        local wsName = "Workshop"
        if ws.getName then wsName = ws:getName() or wsName
        elseif ws.configFileName then
            -- derive a friendly name from the config path
            wsName = ws.configFileName:match("([^/\\]+)%.xml$") or wsName
        end
        self.r:appRect(x - FT.px(4), y - FT.py(18),
            cw + FT.px(8), FT.py(16),
            {accent[1]*0.10, accent[2]*0.10, accent[3]*0.10, 0.95})
        self.r:appText(x, y - FT.py(13), FT.FONT.SMALL,
            wsName,
            RenderText.ALIGN_LEFT, FT.C.POSITIVE)
        self.r:appText(x + cw, y - FT.py(13), FT.FONT.TINY,
            "REPAIRS AVAILABLE",
            RenderText.ALIGN_RIGHT, FT.C.TEXT_ACCENT)
        y = y - FT.py(24)
    end

    -- ── No vehicles ────────────────────────────────────────
    if #nearby == 0 then
        y = y - FT.py(4)
        self.r:appText(x, y, FT.FONT.BODY,
            "No vehicles within 35 m.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, y - FT.py(18), FT.FONT.SMALL,
            "Walk closer to a vehicle to inspect it.",
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        return
    end

    -- ── Vehicle list ───────────────────────────────────────
    y = self:drawSection(y, "NEARBY  (" .. #nearby .. ")")

    local btnW = FT.px(46)
    local btnH = FT.py(18)

    for i = 1, math.min(6, #nearby) do
        local v = nearby[i]
        if y - btnH < minY then break end

        local isSel     = (v.vehicle == sel)
        local nameColor = isSel and FT.C.TEXT_BRIGHT or FT.C.TEXT_NORMAL

        -- Row highlight when selected
        if isSel then
            self.r:appRect(x - FT.px(4), y - FT.py(4),
                cw + FT.px(8), btnH + FT.py(6),
                {accent[1]*0.12, accent[2]*0.12, accent[3]*0.12, 0.95})
        end

        -- Vehicle name
        local nm = v.name
        if #nm > 22 then nm = nm:sub(1, 20) .. ">" end
        self.r:appText(x, y, FT.FONT.SMALL, nm,
            RenderText.ALIGN_LEFT, nameColor)

        -- Distance + wear hint
        local wearColor = v.wearPct <= 30 and FT.C.POSITIVE
                       or v.wearPct <= 65 and FT.C.WARNING
                       or FT.C.NEGATIVE
        self.r:appText(x + cw - btnW - FT.px(62), y, FT.FONT.TINY,
            v.distance .. "m  " .. v.wearPct .. "%W",
            RenderText.ALIGN_LEFT,
            v.wearPct > 65 and wearColor or FT.C.TEXT_DIM)

        -- Select / Deselect toggle
        local bColor  = isSel and FT.C.BTN_ACTIVE or FT.C.BTN_NEUTRAL
        local bLabel  = isSel and "DESEL" or "SELECT"
        local vehicle = v.vehicle
        local btn = self.r:button(x + cw - btnW, y - FT.py(2), btnW, btnH,
            bLabel, bColor,
            { onClick = function()
                if isSel then
                    self.system.workshopSelectedVehicle = nil
                else
                    self.system.workshopSelectedVehicle = vehicle
                end
                self:switchApp(FT.APP.WORKSHOP)
            end })
        table.insert(self._contentBtns, btn)

        y = y - FT.py(24)
    end

    -- ── Diagnostics panel ──────────────────────────────────
    if not sel then
        y = y - FT.py(4)
        self.r:appText(x, y, FT.FONT.SMALL,
            "Select a vehicle above to inspect.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    local selData = nil
    for _, v in ipairs(nearby) do
        if v.vehicle == sel then selData = v; break end
    end
    if not selData then return end

    y = y - FT.py(4)
    y = self:drawRule(y, 0.4)
    y = self:drawSection(y, "DIAGNOSTICS")

    -- Full name
    local fullName = (sel.getFullName and sel:getFullName()) or selData.name
    if #fullName > 26 then fullName = fullName:sub(1, 24) .. ">" end
    y = self:drawRow(y, "Vehicle", fullName)

    -- Fuel
    local fuelPct   = selData.fuelPct
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

    -- Operating hours
    y = self:drawRow(y - FT.py(4), "Operating Hours",
        selData.opHours .. " h")

    -- ── Repair button (only if workshop present + vehicle is worn) ─────
    if #workshops > 0 and wearPct > 2 then
        y = y - FT.py(8)
        if y < minY then return end

        local _, repairBtn = self:drawButton(y, "REPAIR VEHICLE", FT.C.BTN_PRIMARY, {
            onClick = function()
                local ws      = workshops[1]
                local repaired = false

                -- Strategy 1: spec_wearable direct reset (most reliable in SP)
                if sel.spec_wearable then
                    local ws_spec = sel.spec_wearable
                    -- Full repair amount reset
                    if ws_spec.totalAmount ~= nil then
                        ws_spec.totalAmount = 0
                        repaired = true
                    end
                    -- Reset per-component amounts
                    for _, comp in ipairs(ws_spec.wearableComponents or {}) do
                        comp.amount = 0
                        repaired = true
                    end
                    -- Trigger FS25 damage-state refresh if available
                    if sel.updateWearable then
                        sel:updateWearable(0)
                    end
                end

                -- Strategy 2: workshop placeable repairVehicle method
                if ws.repairVehicle then
                    local ok = pcall(function() ws:repairVehicle(sel) end)
                    if ok then repaired = true end
                end

                -- Strategy 3: VehicleRepairEvent for MP safety
                if not repaired or g_server == nil then
                    if VehicleRepairEvent ~= nil then
                        local ok = pcall(function()
                            local evt = VehicleRepairEvent.new(sel)
                            if g_client then
                                g_client:getServerConnection():sendEvent(evt)
                            end
                        end)
                        if ok then repaired = true end
                    end
                end

                if repaired then
                    self.system.data:invalidate()
                    self:switchApp(FT.APP.WORKSHOP)
                end
            end
        })
    end
end)
