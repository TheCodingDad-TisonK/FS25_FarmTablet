-- =========================================================
-- FS25 Farm Tablet -- Workshop App
-- =========================================================
-- Detects nearby vehicles, shows diagnostics (fuel, wear,
-- operating hours), lets the player open the in-game workshop.
-- =========================================================

function FarmTabletUI:loadWorkshopApp()
    self.ui.appTexts = {}
    self.ui.workshopVehicleButtons = {}
    self.ui.workshopOpenButton     = nil

    local content = self.ui.appContentArea
    if not content then return end

    local C    = self.UI_CONSTANTS
    local padX = self:px(15)
    local padY = self:py(12)

    local nearby   = self:getWorkshopNearbyVehicles(20)
    local selected = self.tabletSystem.workshopSelectedVehicle

    local titleY = content.y + content.height - padY - self:titleH()
    self:drawText("Workshop", content.x + padX, titleY, 0.019, RenderText.ALIGN_LEFT, C.TITLE_COLOR)
    self:drawText(#nearby .. " nearby", content.x + content.width - padX, titleY,
        0.013, RenderText.ALIGN_RIGHT, C.MUTED_COLOR)
    self:drawDivider(titleY - self:py(4))

    local y = titleY - 0.030

    -- No vehicles nearby
    if #nearby == 0 then
        self:drawText("No vehicles within 20 m.", content.x + padX, y, 0.015,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        y = y - 0.022
        self:drawText("Walk closer to a vehicle.", content.x + padX, y, 0.013,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        self.tabletSystem.workshopSelectedVehicle = nil
        return
    end

    -- Nearby vehicle list
    self:drawSectionHeader("NEARBY  (" .. #nearby .. ")", y)
    y = y - 0.022

    local btnW = self:px(44)
    local btnH = self:py(20)

    for i = 1, math.min(4, #nearby) do
        local v = nearby[i]
        if y <= content.y + padY + self:py(35) then break end

        local isSelected = (v.vehicle == selected)
        local nameColor  = isSelected and C.VALUE_COLOR or C.LABEL_COLOR

        local name = v.name
        if #name > 22 then name = name:sub(1, 19) .. "..." end

        self:drawText(name,
            content.x + padX, y, 0.014, RenderText.ALIGN_LEFT, nameColor)
        self:drawText(string.format("%.0f m", v.distance),
            content.x + content.width - padX - btnW - self:px(8), y,
            0.012, RenderText.ALIGN_RIGHT, C.MUTED_COLOR)

        local btn = self:drawButton("SEL",
            content.x + content.width - padX - btnW, y - self:py(2),
            btnW, btnH,
            isSelected and C.BTN_GREEN or C.BTN_GRAY)
        btn.vehicle = v.vehicle
        table.insert(self.ui.workshopVehicleButtons, btn)

        y = y - 0.024
    end

    -- Validate selected vehicle is still in range
    if selected then
        local stillNear = false
        for _, v in ipairs(nearby) do
            if v.vehicle == selected then stillNear = true; break end
        end
        if not stillNear then
            self.tabletSystem.workshopSelectedVehicle = nil
            selected = nil
        end
    end

    -- Selected vehicle diagnostics
    if selected then
        y = y - 0.008
        self:drawSectionHeader("DIAGNOSTICS", y)
        y = y - 0.022

        local fullName = (selected.getFullName and selected:getFullName()) or "Unknown"
        if #fullName > 26 then fullName = fullName:sub(1, 23) .. "..." end
        self:drawRow("Vehicle", fullName, y, C.LABEL_COLOR, C.VALUE_COLOR)
        y = y - 0.022

        -- Fuel
        local fuel, fuelCap = 0, 1
        local mSpec = selected.spec_motorized
        if mSpec then
            fuel    = mSpec.fuelFillLevel or 0
            fuelCap = math.max(mSpec.fuelCapacity or 1, 1)
        end
        local fuelPct   = math.floor((fuel / fuelCap) * 100)
        local fuelColor = fuelPct > 30 and C.POSITIVE_COLOR
                       or fuelPct > 10 and C.WARNING_COLOR or C.NEGATIVE_COLOR

        self:drawRow("Fuel",
            string.format("%d%%  (%.0f / %.0f L)", fuelPct, fuel, fuelCap),
            y, C.LABEL_COLOR, fuelColor)
        y = y - 0.022
        y = self:drawProgressBar(fuelPct, 100, y, fuelColor)

        -- Wear / condition
        local wear    = 0
        local wSpec   = selected.spec_wearable
        if wSpec then wear = math.floor((wSpec.totalWear or 0) * 100) end
        local wearColor = wear < 30 and C.POSITIVE_COLOR
                       or wear < 70 and C.WARNING_COLOR or C.NEGATIVE_COLOR
        local condition = 100 - wear

        self:drawRow("Condition",
            string.format("%d%%  (wear: %d%%)", condition, wear),
            y, C.LABEL_COLOR, wearColor)
        y = y - 0.022
        y = self:drawProgressBar(condition, 100, y, wearColor)

        -- Operating hours
        local opH = math.floor((selected.operatingTime or 0) / 3600000)
        self:drawRow("Op. Hours", string.format("%d h", opH), y, C.LABEL_COLOR, C.VALUE_COLOR)
        y = y - 0.022

        -- Attached implements
        if selected.getAttachedImplements then
            local implCount = 0
            for _ in ipairs(selected:getAttachedImplements()) do
                implCount = implCount + 1
            end
            if implCount > 0 then
                self:drawRow("Attachments", tostring(implCount), y, C.LABEL_COLOR, C.VALUE_COLOR)
                y = y - 0.022
            end
        end

        -- Open Workshop button (pinned to bottom of content area)
        local owBtnW = self:px(160)
        local owBtnH = self:py(24)
        local owBtnY = content.y + padY + self:py(4)
        self.ui.workshopOpenButton = self:drawButton(
            "Open Workshop",
            content.x + padX, owBtnY,
            owBtnW, owBtnH, C.BTN_BLUE)
    else
        y = y - 0.008
        self:drawText("Select a vehicle above to inspect.",
            content.x + padX, y, 0.013, RenderText.ALIGN_LEFT, C.MUTED_COLOR)
    end
end

-- Returns up to 10 motorized vehicles within `radius` metres, sorted by distance.
function FarmTabletUI:getWorkshopNearbyVehicles(radius)
    local result = {}
    if not (g_currentMission and g_currentMission.vehicles) then return result end

    -- Player position: g_localPlayer is the reliable reference for the local client.
    -- g_currentMission.player can be nil or lack a rootNode when the tablet is open.
    local px, py, pz = 0, 0, 0
    if g_localPlayer then
        if type(g_localPlayer.getIsInVehicle) == "function" and g_localPlayer:getIsInVehicle() then
            local cv = g_localPlayer:getCurrentVehicle()
            if cv and cv.rootNode then
                pcall(function() px, py, pz = getWorldTranslation(cv.rootNode) end)
            end
        end
        if px == 0 and py == 0 and pz == 0 and g_localPlayer.rootNode then
            pcall(function() px, py, pz = getWorldTranslation(g_localPlayer.rootNode) end)
        end
    end
    if px == 0 and py == 0 and pz == 0 then
        local player = g_currentMission and g_currentMission.player
        if player and player.rootNode then
            pcall(function() px, py, pz = getWorldTranslation(player.rootNode) end)
        end
    end

    for _, v in pairs(g_currentMission.vehicles) do
        -- Mirror DiggingApp exactly: direct isa check, no pcall, no spec pre-filter
        if v:isa(Vehicle) and v.rootNode then
            local vx, vy, vz = getWorldTranslation(v.rootNode)
            local dist = MathUtil.vector2Length(vx - px, vz - pz)

            if dist <= radius then
                local name = (v.getFullName and v:getFullName())
                          or v.configFileName or "Vehicle"
                table.insert(result, { vehicle = v, name = name, distance = dist })
            end
        end
    end

    table.sort(result, function(a, b) return a.distance < b.distance end)
    return result
end

-- Closes the tablet, then attempts to open the in-game menu.
function FarmTabletUI:openVehicleWorkshop()
    self:closeTablet()
    pcall(function()
        if g_currentMission and g_currentMission.inGameMenu
                and g_currentMission.inGameMenu.openMenu then
            g_currentMission.inGameMenu:openMenu()
        elseif g_gui and g_gui.showGui then
            g_gui:showGui("InGameMenu")
        end
    end)
end

-- Mouse event handler for the Workshop app.
function FarmTabletUI:handleWorkshopMouseEvent(posX, posY)
    -- Vehicle SELECT buttons
    if self.ui.workshopVehicleButtons then
        for _, btn in ipairs(self.ui.workshopVehicleButtons) do
            if posX >= btn.x and posX <= btn.x + btn.width and
               posY >= btn.y and posY <= btn.y + btn.height then
                self.tabletSystem.workshopSelectedVehicle = btn.vehicle
                self:switchApp("workshop")
                return true
            end
        end
    end
    -- Open Workshop button
    if self.ui.workshopOpenButton then
        local b = self.ui.workshopOpenButton
        if posX >= b.x and posX <= b.x + b.width and
           posY >= b.y and posY <= b.y + b.height then
            self:openVehicleWorkshop()
            return true
        end
    end
    return false
end
