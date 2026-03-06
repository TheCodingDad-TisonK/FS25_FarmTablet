-- =========================================================
-- FS25 Farm Tablet Mod - Digging App (Fixed)
-- =========================================================
-- Shows terrain deformation and digging information
-- =========================================================

function FarmTabletUI:loadDiggingApp()
    local content = self.ui.appContentArea
    if not content then
        self:log("No content area in digging app")
        return
    end

    local padX = self:px(15)
    local padY = self:py(15)
    local titleY = content.y + content.height - padY - 0.03

    -- Title
    table.insert(self.ui.appTexts, {
        text = "Digging Information",
        x = content.x + padX,
        y = titleY,
        size = 0.022,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })

    local diggingInfo = self:getDiggingInfo()
    local yPos = titleY - 0.035

    -- FS25 Terrain System Check
    if not diggingInfo.hasTerrainSystem then
        table.insert(self.ui.appTexts, {
            text = "Terrain system not available",
            x = content.x + padX,
            y = yPos,
            size = 0.016,
            align = RenderText.ALIGN_LEFT,
            color = {1, 0.5, 0, 1}
        })
        yPos = yPos - 0.024
        table.insert(self.ui.appTexts, {
            text = "Ensure you're on terrain",
            x = content.x + padX,
            y = yPos,
            size = 0.014,
            align = RenderText.ALIGN_LEFT,
            color = {0.8, 0.8, 0.8, 1}
        })
        return
    end

    -- System status
    table.insert(self.ui.appTexts, {
        text = "Terrain System: FS25",
        x = content.x + padX,
        y = yPos,
        size = 0.016,
        align = RenderText.ALIGN_LEFT,
        color = {0.4, 0.8, 0.4, 1}
    })
    
    -- Player position and height
    if diggingInfo.currentPosition then
        yPos = yPos - 0.024
        table.insert(self.ui.appTexts, {
            text = string.format("Position: X %.1f  Z %.1f",
                diggingInfo.currentPosition.x,
                diggingInfo.currentPosition.z),
            x = content.x + padX,
            y = yPos,
            size = 0.015,
            align = RenderText.ALIGN_LEFT,
            color = {0.8, 0.8, 0.8, 1}
        })

        yPos = yPos - 0.020
        table.insert(self.ui.appTexts, {
            text = string.format("Height: %.2f m", diggingInfo.currentTerrainHeight),
            x = content.x + padX,
            y = yPos,
            size = 0.015,
            align = RenderText.ALIGN_LEFT,
            color = {0.8, 0.8, 0.8, 1}
        })
        
        -- Ground type info (FS25 has this)
        if diggingInfo.groundType then
            yPos = yPos - 0.020
            table.insert(self.ui.appTexts, {
                text = "Ground: " .. diggingInfo.groundType,
                x = content.x + padX,
                y = yPos,
                size = 0.015,
                align = RenderText.ALIGN_LEFT,
                color = diggingInfo.groundType == "FIELD" and {0.4, 0.9, 0.4, 1} or
                       diggingInfo.groundType == "PAVED" and {0.7, 0.7, 0.7, 1} or
                       {0.9, 0.7, 0.4, 1}
            })
        end
    end

    -- Digging-capable vehicles
    yPos = yPos - 0.030
    table.insert(self.ui.appTexts, {
        text = string.format("Excavation Vehicles: %d", diggingInfo.diggingVehicles),
        x = content.x + padX,
        y = yPos,
        size = 0.016,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })
    
    table.insert(self.ui.appTexts, {
        text = string.format("Nearby: %d", diggingInfo.nearbyVehicles),
        x = content.x + content.width - padX,
        y = yPos,
        size = 0.016,
        align = RenderText.ALIGN_RIGHT,
        color = {0.4, 0.8, 0.4, 1}
    })

    -- List specific excavators (better detection)
    if #diggingInfo.excavationVehicles > 0 then
        yPos = yPos - 0.030
        table.insert(self.ui.appTexts, {
            text = "Active Excavators:",
            x = content.x + padX,
            y = yPos,
            size = 0.016,
            align = RenderText.ALIGN_LEFT,
            color = {0.3, 0.6, 0.8, 1}
        })

        yPos = yPos - 0.022
        for i = 1, math.min(4, #diggingInfo.excavationVehicles) do
            local vehicle = diggingInfo.excavationVehicles[i]
            local displayName = vehicle.name or "Unknown"
            
            -- Shorten long names
            if #displayName > 20 then
                displayName = displayName:sub(1, 17) .. "..."
            end
            
            table.insert(self.ui.appTexts, {
                text = "• " .. displayName,
                x = content.x + padX + 0.01,
                y = yPos,
                size = 0.013,
                align = RenderText.ALIGN_LEFT,
                color = vehicle.isDigging and {0.9, 0.7, 0.4, 1} or {0.8, 0.8, 0.8, 1}
            })

            table.insert(self.ui.appTexts, {
                text = vehicle.isDigging and "DIGGING" or "Idle",
                x = content.x + content.width - padX,
                y = yPos,
                size = 0.013,
                align = RenderText.ALIGN_RIGHT,
                color = vehicle.isDigging and {1, 0.6, 0, 1} or {0.7, 0.7, 0.7, 1}
            })

            yPos = yPos - 0.018
        end
    else
        yPos = yPos - 0.024
        table.insert(self.ui.appTexts, {
            text = "No excavation vehicles found",
            x = content.x + padX,
            y = yPos,
            size = 0.014,
            align = RenderText.ALIGN_LEFT,
            color = {0.7, 0.7, 0.7, 1}
        })
    end

    -- Digging tools information
    if diggingInfo.detectedTools > 0 then
        yPos = yPos - 0.030
        table.insert(self.ui.appTexts, {
            text = "Detected Tools:",
            x = content.x + padX,
            y = yPos,
            size = 0.016,
            align = RenderText.ALIGN_LEFT,
            color = {0.3, 0.6, 0.8, 1}
        })

        yPos = yPos - 0.022
        for i = 1, math.min(3, #diggingInfo.tools) do
            local tool = diggingInfo.tools[i]
            table.insert(self.ui.appTexts, {
                text = "• " .. tool.type,
                x = content.x + padX + 0.01,
                y = yPos,
                size = 0.013,
                align = RenderText.ALIGN_LEFT,
                color = {0.8, 0.8, 0.8, 1}
            })

            table.insert(self.ui.appTexts, {
                text = tool.vehicleName or "",
                x = content.x + content.width - padX,
                y = yPos,
                size = 0.013,
                align = RenderText.ALIGN_RIGHT,
                color = {0.6, 0.8, 1, 1}
            })

            yPos = yPos - 0.018
        end
    end

    self:log("Digging app loaded: %d vehicles found", diggingInfo.diggingVehicles)
end

function FarmTabletUI:getDiggingInfo()
    local info = {
        hasTerrainSystem = false,
        currentPosition = nil,
        currentTerrainHeight = nil,
        groundType = nil,
        
        diggingVehicles = 0,
        nearbyVehicles = 0,
        detectedTools = 0,
        
        excavationVehicles = {},
        tools = {}
    }
    
    -- FS25 Terrain Check
    if g_currentMission and g_currentMission.terrainRootNode then
        info.hasTerrainSystem = true
        
        -- Get player position
        if g_currentMission.player and g_currentMission.player.rootNode then
            local player = g_currentMission.player
            local x, y, z = getWorldTranslation(player.rootNode)
            info.currentPosition = {x = x, z = z}
            
            -- Get terrain height
            info.currentTerrainHeight = getTerrainHeightAtWorldPos(
                g_currentMission.terrainRootNode,
                x, 0, z
            )
            
            -- FS25 ground type detection
            info.groundType = self:getGroundTypeAtPosition(x, z)
        end
    end
    
    -- Vehicle detection for FS25
    if g_currentMission and g_currentMission.vehicles then
        local playerX, playerY, playerZ = 0, 0, 0
        if info.currentPosition then
            playerX, playerZ = info.currentPosition.x, info.currentPosition.z
        end
        
        for _, vehicle in pairs(g_currentMission.vehicles) do
            if vehicle:isa(Vehicle) then
                -- Get vehicle position
                local vX, vY, vZ = getWorldTranslation(vehicle.rootNode)
                local distance = MathUtil.vector2Length(vX - playerX, vZ - playerZ)
                
                -- Check if it's a digging-capable vehicle
                local isExcavator = self:isFS25Excavator(vehicle)
                
                if isExcavator then
                    info.diggingVehicles = info.diggingVehicles + 1
                    
                    if distance < 100 then  -- Within 100m
                        info.nearbyVehicles = info.nearbyVehicles + 1
                        
                        -- Add to excavation vehicles list
                        table.insert(info.excavationVehicles, {
                            name = vehicle:getFullName() or vehicle.configFileName or "Unknown",
                            isDigging = self:isFS25VehicleDigging(vehicle),
                            distance = distance
                        })
                    end
                end
                
                -- Check for digging tools/attachments
                local vehicleTools = self:getVehicleDiggingTools(vehicle)
                if #vehicleTools > 0 then
                    info.detectedTools = info.detectedTools + #vehicleTools
                    for _, tool in ipairs(vehicleTools) do
                        table.insert(info.tools, tool)
                    end
                end
            end
        end
        
        -- Sort excavation vehicles by distance
        table.sort(info.excavationVehicles, function(a, b)
            return (a.distance or 9999) < (b.distance or 9999)
        end)
    end
    
    return info
end

function FarmTabletUI:isFS25Excavator(vehicle)
    if not vehicle then return false end
    
    -- Check config name for excavator types
    local configName = vehicle.configFileName or ""
    configName = configName:lower()
    
    local excavatorKeywords = {
        "excavator",
        "backhoe",
        "digger",
        "excavation",
        "shovel",
        "dragline",
        "trencher"
    }
    
    for _, keyword in ipairs(excavatorKeywords) do
        if configName:find(keyword) then
            return true
        end
    end
    
    -- Check vehicle type
    local typeName = vehicle.typeName or ""
    typeName = typeName:lower()
    
    for _, keyword in ipairs(excavatorKeywords) do
        if typeName:find(keyword) then
            return true
        end
    end
    
    -- Check for digging-specific components
    if vehicle.spec_digging or vehicle.spec_groundDeformation then
        return true
    end
    
    return false
end

function FarmTabletUI:isFS25VehicleDigging(vehicle)
    if not vehicle then return false end
    
    -- Check if vehicle has active digging components
    if vehicle.spec_digging then
        local spec = vehicle.spec_digging
        if spec.isDigging or spec.isActive then
            return true
        end
    end
    
    -- Check ground deformation
    if vehicle.spec_groundDeformation then
        local spec = vehicle.spec_groundDeformation
        if spec.isActive then
            return true
        end
    end
    
    -- Check for animation states that indicate digging
    if vehicle.getIsWorkAreaActive then
        return vehicle:getIsWorkAreaActive()
    end
    
    return false
end

function FarmTabletUI:getVehicleDiggingTools(vehicle)
    local tools = {}
    
    if not vehicle then return tools end
    
    -- Check vehicle attachments
    if vehicle.getAttachedImplements then
        local attached = vehicle:getAttachedImplements()
        for _, impl in ipairs(attached) do
            local object = impl.object
            if object then
                local toolType = self:getToolType(object)
                if toolType ~= "UNKNOWN" then
                    table.insert(tools, {
                        type = toolType,
                        vehicleName = vehicle:getFullName() or "Unknown",
                        isAttached = true
                    })
                end
            end
        end
    end
    
    return tools
end

function FarmTabletUI:getToolType(object)
    if not object then return "UNKNOWN" end
    
    local configName = object.configFileName or ""
    configName = configName:lower()
    
    if configName:find("bucket") then
        return "Bucket"
    elseif configName:find("shovel") then
        return "Shovel"
    elseif configName:find("blade") then
        return "Blade"
    elseif configName:find("ripper") then
        return "Ripper"
    elseif configName:find("auger") then
        return "Auger"
    elseif configName:find("trencher") then
        return "Trencher"
    end
    
    return "UNKNOWN"
end

function FarmTabletUI:getGroundTypeAtPosition(x, z)
    if not g_currentMission or not g_currentMission.terrainDetailHeightId then
        return "UNKNOWN"
    end
    
    -- This is a simplified version - FS25 has proper ground type detection
    -- In reality, you'd use getDensityAtWorldPos or similar FS25 functions
    
    -- Check if it's a field
    if g_fieldManager then
        for _, field in pairs(g_fieldManager.fields) do
            -- Simplified field check
            if field.boundingBox then
                if x >= field.boundingBox.minX and x <= field.boundingBox.maxX and
                   z >= field.boundingBox.minZ and z <= field.boundingBox.maxZ then
                    return "FIELD"
                end
            end
        end
    end
    
    -- Check if on road (simplified)
    if g_currentMission.roadNetwork then
        -- Would need proper road network checks
    end
    
    return "GROUND"
end

function FarmTabletUI:updateDiggingApp(dt)
    if not self.isTabletOpen or self.tabletSystem.currentApp ~= "digging" then
        return
    end
    
    -- Refresh digging info every 2 seconds
    self.diggingUpdateTime = (self.diggingUpdateTime or 0) + dt
    if self.diggingUpdateTime > 2.0 then
        self.diggingUpdateTime = 0
        
        -- Reload app content to update info
        if self.ui.appTexts then
            self.ui.appTexts = {}
            self:loadDiggingApp()
        end
    end
end