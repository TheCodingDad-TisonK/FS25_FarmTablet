-- =========================================================
-- FS25 Farm Tablet -- Digging / Terrain App
-- =========================================================

function FarmTabletUI:loadDiggingApp()
    self.ui.appTexts = {}
    local content = self.ui.appContentArea
    if not content then return end

    local C    = self.UI_CONSTANTS
    local padX = self:px(15)
    local padY = self:py(12)

    local titleY = content.y + content.height - padY - 0.028
    self:drawText("Digging & Terrain", content.x + padX, titleY, 0.019, RenderText.ALIGN_LEFT, C.TITLE_COLOR)

    local info = self:getDiggingInfo()
    local y = titleY - 0.030

    if not info.hasTerrainSystem then
        self:drawText("Terrain system not available.", content.x + padX, y, 0.015,
            RenderText.ALIGN_LEFT, C.WARNING_COLOR)
        y = y - 0.022
        self:drawText("Ensure you are on a terrain map.", content.x + padX, y, 0.013,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        return
    end

    -- Position & height
    self:drawSectionHeader("TERRAIN", y)
    y = y - 0.022

    if info.currentPosition then
        self:drawRow("Position",
            string.format("X %.1f  Z %.1f", info.currentPosition.x, info.currentPosition.z),
            y, C.LABEL_COLOR, C.VALUE_COLOR)
        y = y - 0.022
        self:drawRow("Height",
            string.format("%.2f m", info.currentTerrainHeight or 0),
            y, C.LABEL_COLOR, C.VALUE_COLOR)
        y = y - 0.022

        if info.groundType then
            local gtColor = info.groundType == "FIELD" and C.POSITIVE_COLOR or
                            info.groundType == "PAVED" and C.MUTED_COLOR   or C.WARNING_COLOR
            self:drawRow("Ground Type", info.groundType, y, C.LABEL_COLOR, gtColor)
            y = y - 0.022
        end
    end

    -- Excavation vehicles
    y = y - 0.010
    self:drawSectionHeader("EXCAVATION VEHICLES", y)
    y = y - 0.022

    self:drawRow("Total",  tostring(info.diggingVehicles), y, C.LABEL_COLOR, C.VALUE_COLOR)
    y = y - 0.022
    self:drawRow("Nearby (100 m)", tostring(info.nearbyVehicles), y, C.LABEL_COLOR, C.VALUE_COLOR)
    y = y - 0.022

    if #info.excavationVehicles > 0 then
        for i = 1, math.min(4, #info.excavationVehicles) do
            local v    = info.excavationVehicles[i]
            local name = v.name or "Unknown"
            if #name > 22 then name = name:sub(1, 19) .. "..." end
            local stateColor = v.isDigging and C.WARNING_COLOR or C.MUTED_COLOR
            self:drawRow("• " .. name, v.isDigging and "DIGGING" or "Idle",
                y, C.VALUE_COLOR, stateColor)
            y = y - 0.020
        end
    else
        self:drawText("No excavation vehicles nearby.", content.x + padX, y, 0.013,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        y = y - 0.020
    end

    -- Detected tools
    if info.detectedTools > 0 then
        y = y - 0.010
        self:drawSectionHeader("DETECTED TOOLS", y)
        y = y - 0.022
        for i = 1, math.min(3, #info.tools) do
            local t = info.tools[i]
            self:drawRow("• " .. (t.type or "?"), t.vehicleName or "", y, C.VALUE_COLOR, C.MUTED_COLOR)
            y = y - 0.020
        end
    end

    self:log("Digging app loaded: %d vehicles", info.diggingVehicles)
end

-- Auto-refresh every 2 s when active
function FarmTabletUI:updateDiggingApp(dt)
    if not self.isTabletOpen or self.tabletSystem.currentApp ~= "digging" then return end
    self.diggingUpdateTime = (self.diggingUpdateTime or 0) + dt
    if self.diggingUpdateTime > 2000 then
        self.diggingUpdateTime = 0
        self.ui.appTexts = {}
        self:loadDiggingApp()
    end
end

function FarmTabletUI:getDiggingInfo()
    local info = {
        hasTerrainSystem  = false,
        currentPosition   = nil,
        currentTerrainHeight = nil,
        groundType        = nil,
        diggingVehicles   = 0,
        nearbyVehicles    = 0,
        detectedTools     = 0,
        excavationVehicles = {},
        tools             = {},
    }

    if not (g_currentMission and g_currentMission.terrainRootNode) then
        return info
    end
    info.hasTerrainSystem = true

    -- Player position
    local player = g_currentMission.player
    local px, py, pz = 0, 0, 0
    if player and player.rootNode then
        px, py, pz = getWorldTranslation(player.rootNode)
        info.currentPosition    = { x = px, z = pz }
        info.currentTerrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, px, 0, pz)
        info.groundType = self:getGroundTypeAtPosition(px, pz)
    end

    -- Vehicles
    if g_currentMission.vehicles then
        for _, v in pairs(g_currentMission.vehicles) do
            if v:isa(Vehicle) then
                local vx, vy, vz = getWorldTranslation(v.rootNode)
                local dist = MathUtil.vector2Length(vx - px, vz - pz)

                if self:isFS25Excavator(v) then
                    info.diggingVehicles = info.diggingVehicles + 1
                    if dist < 100 then
                        info.nearbyVehicles = info.nearbyVehicles + 1
                        table.insert(info.excavationVehicles, {
                            name      = v:getFullName() or "Unknown",
                            isDigging = self:isFS25VehicleDigging(v),
                            distance  = dist,
                        })
                    end
                end

                local vtools = self:getVehicleDiggingTools(v)
                for _, t in ipairs(vtools) do
                    info.detectedTools = info.detectedTools + 1
                    table.insert(info.tools, t)
                end
            end
        end
        table.sort(info.excavationVehicles, function(a, b)
            return (a.distance or 9999) < (b.distance or 9999)
        end)
    end

    return info
end

function FarmTabletUI:isFS25Excavator(vehicle)
    if not vehicle then return false end
    if vehicle.spec_digging or vehicle.spec_groundDeformation then return true end
    local cfg = (vehicle.configFileName or ""):lower()
    local typ = (vehicle.typeName or ""):lower()
    local kw  = {"excavator","backhoe","digger","excavation","shovel","dragline","trencher"}
    for _, k in ipairs(kw) do
        if cfg:find(k) or typ:find(k) then return true end
    end
    return false
end

function FarmTabletUI:isFS25VehicleDigging(vehicle)
    if not vehicle then return false end
    if vehicle.spec_digging then
        local s = vehicle.spec_digging
        if s.isDigging or s.isActive then return true end
    end
    if vehicle.spec_groundDeformation and vehicle.spec_groundDeformation.isActive then
        return true
    end
    if vehicle.getIsWorkAreaActive then return vehicle:getIsWorkAreaActive() end
    return false
end

function FarmTabletUI:getVehicleDiggingTools(vehicle)
    local tools = {}
    if not (vehicle and vehicle.getAttachedImplements) then return tools end
    for _, impl in ipairs(vehicle:getAttachedImplements()) do
        local obj = impl.object
        if obj then
            local tt = self:getToolType(obj)
            if tt ~= "UNKNOWN" then
                table.insert(tools, { type = tt, vehicleName = vehicle:getFullName() or "?" })
            end
        end
    end
    return tools
end

function FarmTabletUI:getToolType(obj)
    if not obj then return "UNKNOWN" end
    local cfg = (obj.configFileName or ""):lower()
    local map = { bucket="Bucket", shovel="Shovel", blade="Blade",
                  ripper="Ripper", auger="Auger", trencher="Trencher" }
    for k, v in pairs(map) do
        if cfg:find(k) then return v end
    end
    return "UNKNOWN"
end

function FarmTabletUI:getGroundTypeAtPosition(x, z)
    if not g_currentMission then return "UNKNOWN" end

    -- Check fields via fieldManager (correct FS25 API)
    local fm = g_currentMission.fieldManager
    if fm then
        for _, field in pairs(fm:getFields()) do
            if field.boundingBox then
                local bb = field.boundingBox
                if x >= bb.minX and x <= bb.maxX and z >= bb.minZ and z <= bb.maxZ then
                    return "FIELD"
                end
            end
        end
    end

    return "GROUND"
end
