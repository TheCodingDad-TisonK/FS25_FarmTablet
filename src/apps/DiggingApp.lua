-- =========================================================
-- FarmTablet v2 – Digging / Excavation App
-- Real-time terrain scanner for excavation work
-- =========================================================

local DiggingState = {
    isScanning = false,
    scanData   = nil,
    lastScan   = 0,
}

FarmTabletUI:registerDrawer(FT.APP.DIGGING, function(self)
    local AC = FT.appColor(FT.APP.DIGGING)

    if self:drawHelpPage("_diggingHelp", FT.APP.DIGGING, "Digging", AC, {
        { title = "POSITION",
          body  = "Shows your player's current world coordinates.\n" ..
                  "X = east-west  |  Y = elevation  |  Z = north-south.\n" ..
                  "Values update live as you walk around." },
        { title = "VEHICLE",
          body  = "When you are driving a vehicle its name and current\n" ..
                  "speed (km/h) are shown here.\n" ..
                  "Attached implements are listed below the speed." },
        { title = "TERRAIN AT POSITION",
          body  = "Ground Level: the terrain height in metres at your\n" ..
                  "current X/Z position.\n" ..
                  "Above Ground: how far above (or below) the terrain\n" ..
                  "surface you are standing. Negative values mean you\n" ..
                  "are below the original ground height." },
        { title = "LIVE UPDATES",
          body  = "The digging app refreshes automatically every 500ms\n" ..
                  "while it is open — no need to reopen it.\n" ..
                  "Use it to monitor depth while operating an excavator." },
    }) then return end

    local startY = self:drawAppHeader("Digging", "Excavation")
    local x, contentY, cw, _ = self:contentInner()
    local y = startY

    local px, py, pz = 0, 0, 0
    local hasPlayer = false
    if g_currentMission and g_currentMission.player and g_currentMission.player.rootNode then
        px, py, pz = getWorldTranslation(g_currentMission.player.rootNode)
        hasPlayer = true
    end

    if not hasPlayer then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "Player position unavailable.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self:drawInfoIcon("_diggingHelp", AC)
        return
    end

    y = self:drawSection(y, "POSITION")
    y = self:drawRow(y, "X", string.format("%.1f", px))
    y = self:drawRow(y, "Y", string.format("%.1f", py))
    y = self:drawRow(y, "Z", string.format("%.1f", pz))

    local vehicle = g_currentMission and g_currentMission.controlledVehicle
    if vehicle then
        y = y - FT.py(4)
        y = self:drawRule(y, 0.25)
        y = self:drawSection(y, "VEHICLE")
        local nm = (vehicle.getFullName and vehicle:getFullName()) or "Unknown"
        if #nm > 20 then nm = nm:sub(1,18) .. ".." end
        y = self:drawRow(y, "Name", nm)
        if vehicle.lastSpeed then
            y = self:drawRow(y, "Speed", string.format("%.1f km/h", math.abs(vehicle.lastSpeed) * 3600))
        end
        if vehicle.getAttachedImplements then
            local impls = vehicle:getAttachedImplements()
            if impls and #impls > 0 then
                local names = {}
                for _, imp in ipairs(impls) do
                    if imp.object then
                        local iname = (imp.object.getFullName and imp.object:getFullName()) or "Implement"
                        if #iname > 16 then iname = iname:sub(1,14) .. ".." end
                        table.insert(names, iname)
                        if #names >= 2 then break end
                    end
                end
                if #names > 0 then y = self:drawRow(y, "Attached", table.concat(names, ", ")) end
            end
        end
    end

    y = y - FT.py(4)
    y = self:drawRule(y, 0.25)
    y = self:drawSection(y, "TERRAIN AT POSITION")

    local groundY = nil
    if getTerrainHeightAtWorldPos and g_terrainNode then
        local ok, val = pcall(getTerrainHeightAtWorldPos, g_terrainNode, px, pz)
        if ok then groundY = val end
    end

    if groundY then
        local above = py - groundY
        y = self:drawRow(y, "Ground Level", string.format("%.2f m", groundY))
        y = self:drawRow(y, "Above Ground", string.format("%.2f m", above), nil,
            above < 0 and FT.C.NEGATIVE or above < 0.5 and FT.C.WARNING or FT.C.TEXT_ACCENT)
    else
        y = self:drawRow(y, "Ground Level", "N/A", nil, FT.C.TEXT_DIM)
    end

    y = y - FT.py(8)
    self.r:appText(x, y, FT.FONT.TINY, "Walk to scan terrain elevation",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)

    self:drawInfoIcon("_diggingHelp", AC)
end)

function FarmTabletUI:updateDiggingApp(dt)
    if self.system.currentApp ~= FT.APP.DIGGING then return end
    DiggingState.lastScan = (DiggingState.lastScan or 0) + dt
    if DiggingState.lastScan >= 500 then
        DiggingState.lastScan = 0
        self:switchApp(FT.APP.DIGGING)
    end
end
