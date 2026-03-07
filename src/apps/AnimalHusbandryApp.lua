-- =========================================================
-- FS25 Farm Tablet -- Animal Husbandry App
-- =========================================================
-- Shows all owned animal pens with occupancy, food, water,
-- and cleanliness levels at a glance.
-- =========================================================

function FarmTabletUI:loadAnimalHusbandryApp()
    self.ui.appTexts = {}
    local content = self.ui.appContentArea
    if not content then return end

    local C    = self.UI_CONSTANTS
    local padX = self:px(15)
    local padY = self:py(12)

    local farmId = self.tabletSystem:getPlayerFarmId()
    local pens   = self:getAnimalPens(farmId)

    local titleY = content.y + content.height - padY - self:titleH()
    self:drawText("Animals", content.x + padX, titleY, 0.019,
        RenderText.ALIGN_LEFT, C.TITLE_COLOR)
    self:drawText(tostring(#pens) .. " pens",
        content.x + content.width - padX, titleY, 0.013,
        RenderText.ALIGN_RIGHT, C.MUTED_COLOR)
    self:drawDivider(titleY - self:py(4))

    local y = titleY - 0.028

    if #pens == 0 then
        self:drawText("No animal pens owned.", content.x + padX, y, 0.015,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        y = y - 0.022
        self:drawText("Purchase a pen to start raising animals.",
            content.x + padX, y, 0.013, RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        return
    end

    for _, pen in ipairs(pens) do
        if y <= content.y + padY + self:py(10) then break end

        -- Pen header: type + count
        local header = pen.typeName
        if pen.numAnimals > 0 then
            header = header .. "  (" .. pen.numAnimals .. "/" .. pen.maxAnimals .. ")"
        else
            header = header .. "  (empty)"
        end

        self:drawSectionHeader(header, y)
        y = y - 0.022

        -- Food
        if pen.hasFood then
            local foodColor = pen.foodPct >= 50 and C.POSITIVE_COLOR
                           or pen.foodPct >= 20 and C.WARNING_COLOR or C.NEGATIVE_COLOR
            self:drawRow("Food",
                string.format("%d%%", pen.foodPct),
                y, C.LABEL_COLOR, foodColor)
            y = y - 0.020
            y = self:drawProgressBar(pen.foodPct, 100, y, foodColor)
        end

        -- Water
        if pen.hasWater then
            local wColor = pen.waterPct >= 50 and C.POSITIVE_COLOR
                        or pen.waterPct >= 20 and C.WARNING_COLOR or C.NEGATIVE_COLOR
            self:drawRow("Water",
                string.format("%d%%", pen.waterPct),
                y, C.LABEL_COLOR, wColor)
            y = y - 0.020
            y = self:drawProgressBar(pen.waterPct, 100, y, wColor)
        end

        -- Cleanliness
        if pen.hasCleanliness then
            local cColor = pen.cleanPct >= 60 and C.POSITIVE_COLOR
                        or pen.cleanPct >= 30 and C.WARNING_COLOR or C.NEGATIVE_COLOR
            self:drawRow("Cleanliness",
                string.format("%d%%", pen.cleanPct),
                y, C.LABEL_COLOR, cColor)
            y = y - 0.020
            y = self:drawProgressBar(pen.cleanPct, 100, y, cColor)
        end

        -- Productivity (if available)
        if pen.productivity ~= nil then
            local prdColor = pen.productivity >= 80 and C.POSITIVE_COLOR
                          or pen.productivity >= 40 and C.WARNING_COLOR or C.NEGATIVE_COLOR
            self:drawRow("Productivity",
                string.format("%d%%", math.floor(pen.productivity)),
                y, C.LABEL_COLOR, prdColor)
            y = y - 0.020
        end

        y = y - 0.008 -- gap between pens
    end
end

-- Returns table of pen data for all animal placeables owned by farmId.
function FarmTabletUI:getAnimalPens(farmId)
    local result = {}
    local ps = g_currentMission and g_currentMission.placeableSystem
    if not ps then return result end

    local ok, placeables = pcall(function() return ps:getPlaceables() end)
    if not ok or not placeables then return result end

    for _, placeable in pairs(placeables) do
        -- Ownership check
        local ownerId = nil
        pcall(function()
            if placeable.getOwnerFarmId then
                ownerId = placeable:getOwnerFarmId()
            elseif placeable.ownerFarmId then
                ownerId = placeable.ownerFarmId
            elseif placeable.farmId then
                ownerId = placeable.farmId
            end
        end)

        if ownerId == farmId then
            local aSpec = placeable.spec_husbandryAnimals
            if aSpec then
                local pen = self:extractPenData(placeable, aSpec)
                if pen then
                    table.insert(result, pen)
                end
            end
        end
    end

    table.sort(result, function(a, b) return a.typeName < b.typeName end)
    return result
end

-- Extracts display data from a husbandry placeable.
function FarmTabletUI:extractPenData(placeable, aSpec)
    local pen = {
        typeName     = "Animals",
        numAnimals   = 0,
        maxAnimals   = 0,
        hasFood      = false,
        foodPct      = 0,
        hasWater     = false,
        waterPct     = 0,
        hasCleanliness = false,
        cleanPct     = 0,
        productivity = nil,
    }

    -- Animal type name
    pcall(function()
        local at = aSpec.animalType
        if at then
            local raw = at.title or at.name or ""
            if raw ~= "" then
                pen.typeName = raw:sub(1,1):upper() .. raw:sub(2):lower()
            end
        end
    end)

    -- Animal counts
    pcall(function()
        if aSpec.numAnimals ~= nil then
            pen.numAnimals = aSpec.numAnimals
        elseif aSpec.clusters then
            local n = 0
            for _, c in pairs(aSpec.clusters) do
                n = n + (c.numAnimals or 0)
            end
            pen.numAnimals = n
        end
        pen.maxAnimals = aSpec.maxNumAnimals or aSpec.maxAnimals or 0
    end)

    -- Food level
    local fSpec = placeable.spec_husbandryFood
    if fSpec then
        pen.hasFood = true
        pcall(function()
            local level = fSpec.fillLevel or fSpec.foodFillLevel or 0
            local cap   = fSpec.capacity  or fSpec.foodCapacity  or 1
            -- Some FS25 builds store as percentage 0-1 directly
            if fSpec.foodAmount ~= nil and fSpec.foodCapacity and fSpec.foodCapacity > 0 then
                pen.foodPct = math.floor((fSpec.foodAmount / fSpec.foodCapacity) * 100)
            elseif cap > 0 then
                pen.foodPct = math.floor((level / cap) * 100)
            end
            pen.foodPct = math.max(0, math.min(100, pen.foodPct))
        end)
    end

    -- Water level
    local wSpec = placeable.spec_husbandryWater
    if wSpec then
        pen.hasWater = true
        pcall(function()
            local level = wSpec.fillLevel or wSpec.waterFillLevel or 0
            local cap   = wSpec.capacity  or wSpec.waterCapacity  or 1
            if wSpec.waterAmount ~= nil and wSpec.waterCapacity and wSpec.waterCapacity > 0 then
                pen.waterPct = math.floor((wSpec.waterAmount / wSpec.waterCapacity) * 100)
            elseif cap > 0 then
                pen.waterPct = math.floor((level / cap) * 100)
            end
            pen.waterPct = math.max(0, math.min(100, pen.waterPct))
        end)
    end

    -- Cleanliness
    local cSpec = placeable.spec_husbandryCleanliness
    if cSpec then
        pen.hasCleanliness = true
        pcall(function()
            local raw = cSpec.cleanliness or cSpec.cleanlinessPercentage or 0
            -- May be stored as 0-1 or 0-100
            if raw <= 1.0 then
                pen.cleanPct = math.floor(raw * 100)
            else
                pen.cleanPct = math.floor(raw)
            end
            pen.cleanPct = math.max(0, math.min(100, pen.cleanPct))
        end)
    end

    -- Productivity (optional)
    pcall(function()
        local pSpec = placeable.spec_husbandryMilk or placeable.spec_husbandryEggs
                   or placeable.spec_husbandryWool
        if pSpec and pSpec.productivity ~= nil then
            pen.productivity = pSpec.productivity * 100
        elseif aSpec.productivity ~= nil then
            pen.productivity = aSpec.productivity * 100
        end
    end)

    -- Only include if has at least some data
    if pen.numAnimals == 0 and pen.maxAnimals == 0
       and not pen.hasFood and not pen.hasWater then
        return nil
    end

    return pen
end
