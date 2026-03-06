-- =========================================================
-- FS25 Farm Tablet Mod (version 1.1.0.1)
-- =========================================================
-- Bucket Tracker App - Track loader/excavator bucket loads
-- =========================================================
-- Author: TisonK
-- =========================================================

function FarmTabletUI:loadBucketTrackerApp()
    local content = self.ui.appContentArea
    if not content then
        self:log("No content area in bucket tracker app")
        return
    end

    local padX = self:px(15)
    local padY = self:py(15)
    local titleY = content.y + content.height - padY - 0.03

    -- Title
    table.insert(self.ui.appTexts, {
        text = "Bucket Load Tracker",
        x = content.x + padX,
        y = titleY,
        size = 0.022,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })

    local tracker = self.tabletSystem.bucketTracker
    local vehicle = self.tabletSystem:getCurrentBucketVehicle()
    local yPos = titleY - 0.035
    
    -- Current Vehicle Status
    if vehicle then
        local vehicleName = vehicle.getName and vehicle:getName() or "Unknown"
        table.insert(self.ui.appTexts, {
            text = "Vehicle: " .. vehicleName,
            x = content.x + padX,
            y = yPos,
            size = 0.016,
            align = RenderText.ALIGN_LEFT,
            color = {0.4, 0.8, 0.4, 1}
        })
        
        -- Current load info
        local fillInfo = self.tabletSystem:getBucketFillInfo(vehicle)
        yPos = yPos - 0.024
        
        if fillInfo.totalFillLevel > 0 then
            table.insert(self.ui.appTexts, {
                text = "Current Load:",
                x = content.x + padX,
                y = yPos,
                size = 0.015,
                align = RenderText.ALIGN_LEFT,
                color = self.UI_CONSTANTS.TEXT_COLOR
            })
            
            table.insert(self.ui.appTexts, {
                text = fillInfo.fillTypeName,
                x = content.x + content.width - padX,
                y = yPos,
                size = 0.015,
                align = RenderText.ALIGN_RIGHT,
                color = {0.8, 0.8, 0.8, 1}
            })
            
            yPos = yPos - 0.020
            table.insert(self.ui.appTexts, {
                text = string.format("Volume: %d / %d L", 
                    math.floor(fillInfo.totalFillLevel), 
                    math.floor(fillInfo.totalCapacity)),
                x = content.x + padX,
                y = yPos,
                size = 0.014,
                align = RenderText.ALIGN_LEFT,
                color = self.UI_CONSTANTS.TEXT_COLOR
            })
            
            yPos = yPos - 0.020
            table.insert(self.ui.appTexts, {
                text = string.format("Fill: %.0f%%", fillInfo.fillPercentage),
                x = content.x + padX,
                y = yPos,
                size = 0.014,
                align = RenderText.ALIGN_LEFT,
                color = fillInfo.fillPercentage > 80 and {0, 1, 0, 1} or 
                       fillInfo.fillPercentage > 50 and {1, 1, 0, 1} or {1, 0.5, 0, 1}
            })
            
            yPos = yPos - 0.020
            local weight = self.tabletSystem:estimateBucketWeight(fillInfo)
            table.insert(self.ui.appTexts, {
                text = string.format("Weight: %d kg", weight),
                x = content.x + padX,
                y = yPos,
                size = 0.014,
                align = RenderText.ALIGN_LEFT,
                color = {0.6, 0.8, 1, 1}
            })
            
            yPos = yPos - 0.010
        else
            table.insert(self.ui.appTexts, {
                text = "Bucket: EMPTY",
                x = content.x + padX,
                y = yPos,
                size = 0.015,
                align = RenderText.ALIGN_LEFT,
                color = {1, 0.5, 0, 1}
            })
            yPos = yPos - 0.024
        end
    else
        table.insert(self.ui.appTexts, {
            text = "No bucket vehicle detected",
            x = content.x + padX,
            y = yPos,
            size = 0.016,
            align = RenderText.ALIGN_LEFT,
            color = {1, 0.5, 0, 1}
        })
        table.insert(self.ui.appTexts, {
            text = "Drive a loader or excavator",
            x = content.x + padX,
            y = yPos - 0.024,
            size = 0.014,
            align = RenderText.ALIGN_LEFT,
            color = {0.8, 0.8, 0.8, 1}
        })
        yPos = yPos - 0.048
    end
    
    -- Session Statistics
    yPos = yPos - 0.020
    table.insert(self.ui.appTexts, {
        text = "Session Statistics:",
        x = content.x + padX,
        y = yPos,
        size = 0.016,
        align = RenderText.ALIGN_LEFT,
        color = {0.6, 0.9, 0.6, 1}
    })
    
    yPos = yPos - 0.024
    table.insert(self.ui.appTexts, {
        text = "Total Loads: " .. tracker.totalLoads,
        x = content.x + padX,
        y = yPos,
        size = 0.015,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })
    
    yPos = yPos - 0.020
    table.insert(self.ui.appTexts, {
        text = "Total Weight: " .. string.format("%d kg", tracker.totalWeight),
        x = content.x + padX,
        y = yPos,
        size = 0.015,
        align = RenderText.ALIGN_LEFT,
        color = self.UI_CONSTANTS.TEXT_COLOR
    })
    
    if tracker.startTime > 0 then
        local currentTime = g_currentMission.time or 0
        local duration = currentTime - tracker.startTime
        
        yPos = yPos - 0.020
        table.insert(self.ui.appTexts, {
            text = "Session Time: " .. self:formatTime(duration / 1000),
            x = content.x + padX,
            y = yPos,
            size = 0.015,
            align = RenderText.ALIGN_LEFT,
            color = self.UI_CONSTANTS.TEXT_COLOR
        })
        
        if tracker.totalLoads > 0 then
            local avgWeight = math.floor(tracker.totalWeight / tracker.totalLoads)
            yPos = yPos - 0.020
            table.insert(self.ui.appTexts, {
                text = "Avg. Load: " .. string.format("%d kg", avgWeight),
                x = content.x + padX,
                y = yPos,
                size = 0.015,
                align = RenderText.ALIGN_LEFT,
                color = self.UI_CONSTANTS.TEXT_COLOR
            })
        end
    end
    
    -- Recent Loads History
    if #tracker.bucketHistory > 0 then
        yPos = yPos - 0.030
        table.insert(self.ui.appTexts, {
            text = "Recent Loads:",
            x = content.x + padX,
            y = yPos,
            size = 0.016,
            align = RenderText.ALIGN_LEFT,
            color = {0.3, 0.6, 0.8, 1}
        })
        
        yPos = yPos - 0.022
        local startIdx = math.max(1, #tracker.bucketHistory - 4)
        for i = startIdx, #tracker.bucketHistory do
            local load = tracker.bucketHistory[i]
            if load and yPos > content.y + padY then
                local loadText = string.format("#%d: %dL %s", 
                    load.number, load.volume, load.fillType)
                
                table.insert(self.ui.appTexts, {
                    text = loadText,
                    x = content.x + padX + 0.01,
                    y = yPos,
                    size = 0.013,
                    align = RenderText.ALIGN_LEFT,
                    color = {0.8, 0.8, 0.8, 1}
                })
                
                table.insert(self.ui.appTexts, {
                    text = string.format("%d kg", load.weight),
                    x = content.x + content.width - padX,
                    y = yPos,
                    size = 0.013,
                    align = RenderText.ALIGN_RIGHT,
                    color = {0.6, 0.8, 1, 1}
                })
                
                yPos = yPos - 0.018
            end
        end
    end
    
    -- Reset Button
    local buttonWidth = self:px(180)
    local buttonHeight = self:py(35)
    local buttonX = content.x + content.width - padX - buttonWidth
    local buttonY = content.y + padY + buttonHeight/2
    
    local resetButton = self:createBlankOverlay(
        buttonX,
        buttonY,
        buttonWidth,
        buttonHeight,
        {0.8, 0.3, 0.3, 0.9}
    )
    resetButton:setVisible(true)
    table.insert(self.ui.overlays, resetButton)
    
    self.ui.resetBucketButton = {
        overlay = resetButton,
        x = buttonX,
        y = buttonY,
        width = buttonWidth,
        height = buttonHeight
    }
    
    -- Reset button text
    table.insert(self.ui.appTexts, {
        text = "Reset Session",
        x = buttonX + buttonWidth/2,
        y = buttonY + buttonHeight/2 - 0.004,
        size = 0.012,
        align = RenderText.ALIGN_CENTER,
        color = {1, 1, 1, 1}
    })
    
    self:log("Bucket tracker app loaded")
end

function FarmTabletUI:formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    else
        return string.format("%02d:%02d", minutes, secs)
    end
end