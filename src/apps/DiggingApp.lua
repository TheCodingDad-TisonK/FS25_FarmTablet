-- =========================================================
-- FarmTablet v2 – Digging / Excavation App  (FIXED)
-- Real-time terrain scanner for excavation work
-- =========================================================

local DiggingState = {
    isScanning = false,
    scanData   = nil,
    lastScan   = 0,
}

FarmTabletUI:registerDrawer(FT.APP.DIGGING, function(self)
    local startY = self:drawAppHeader("Digging", "Excavation")

    local x, contentY, cw, _ = self:contentInner()
    local y = startY

    -- ── Player position ────────────────────────────────────
    local px, py, pz = 0, 0, 0
    local hasPlayer   = false
    if g_currentMission and g_currentMission.player and
       g_currentMission.player.rootNode then
        px, py, pz = getWorldTranslation(g_currentMission.player.rootNode)
        hasPlayer  = true
    end

    if not hasPlayer then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Player position unavailable.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        return
    end

    y = self:drawSection(y, "POSITION")
    y = self:drawRow(y, "X", string.format("%.1f", px))
    y = self:drawRow(y, "Y", string.format("%.1f", py))
    y = self:drawRow(y, "Z", string.format("%.1f", pz))

    -- ── Controlled vehicle ─────────────────────────────────
    local vehicle = g_currentMission and g_currentMission.controlledVehicle
    if vehicle then
        y = y - FT.py(4)
        y = self:drawRule(y, 0.25)
        y = self:drawSection(y, "VEHICLE")

        local nm = (vehicle.getFullName and vehicle:getFullName()) or "Unknown"
        if #nm > 20 then nm = nm:sub(1,18) .. ".." end
        y = self:drawRow(y, "Name", nm)

        -- Speed: lastSpeed is in m/ms, convert to km/h
        if vehicle.lastSpeed then
            local speedKmh = math.abs(vehicle.lastSpeed) * 3600
            y = self:drawRow(y, "Speed",
                string.format("%.1f km/h", speedKmh))
        end

        -- Attached implements
        if vehicle.getAttachedImplements then
            local impls = vehicle:getAttachedImplements()
            if impls and #impls > 0 then
                local names = {}
                for _, imp in ipairs(impls) do
                    if imp.object then
                        local iname = (imp.object.getFullName and
                            imp.object:getFullName()) or "Implement"
                        if #iname > 16 then iname = iname:sub(1,14)..".." end
                        table.insert(names, iname)
                        if #names >= 2 then break end
                    end
                end
                if #names > 0 then
                    y = self:drawRow(y, "Attached", table.concat(names, ", "))
                end
            end
        end
    end

    -- ── Terrain at player position ─────────────────────────
    y = y - FT.py(4)
    y = self:drawRule(y, 0.25)
    y = self:drawSection(y, "TERRAIN AT POSITION")

    -- FIX: correct FS25 signature is getTerrainHeightAtWorldPos(terrainId, worldX, worldZ)
    -- g_terrainNode is the global terrain node (not g_currentMission.terrainRootNode)
    local groundY = nil
    if getTerrainHeightAtWorldPos and g_terrainNode then
        local ok, val = pcall(getTerrainHeightAtWorldPos, g_terrainNode, px, pz)
        if ok then groundY = val end
    end

    if groundY then
        local aboveGround = py - groundY
        y = self:drawRow(y, "Ground Level", string.format("%.2f m", groundY))
        y = self:drawRow(y, "Above Ground", string.format("%.2f m", aboveGround),
            nil,
            aboveGround < 0 and FT.C.NEGATIVE or
            aboveGround < 0.5 and FT.C.WARNING or FT.C.TEXT_ACCENT)
    else
        y = self:drawRow(y, "Ground Level", "N/A", nil, FT.C.TEXT_DIM)
    end

    -- Hint
    y = y - FT.py(8)
    self.r:appText(x, y, FT.FONT.TINY,
        "Walk to scan terrain elevation",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
end)

-- Live update throttle for digging app
function FarmTabletUI:updateDiggingApp(dt)
    if self.system.currentApp ~= FT.APP.DIGGING then return end
    DiggingState.lastScan = (DiggingState.lastScan or 0) + dt
    if DiggingState.lastScan >= 500 then
        DiggingState.lastScan = 0
        self:switchApp(FT.APP.DIGGING)
    end
end
