-- =========================================================
-- FS25 Farm Tablet -- Field Manager App
-- =========================================================
-- Shows all owned fields with crop type and growth state
-- at a glance. Color-coded for quick action planning.
-- =========================================================

function FarmTabletUI:loadFieldStatusApp()
    self.ui.appTexts = {}
    local content = self.ui.appContentArea
    if not content then return end

    local C    = self.UI_CONSTANTS
    local padX = self:px(15)
    local padY = self:py(12)

    local farmId = self.tabletSystem:getPlayerFarmId()
    local fields = self:getOwnedFields(farmId)

    local titleY = content.y + content.height - padY - self:titleH()
    self:drawText("Field Manager", content.x + padX, titleY, 0.019,
        RenderText.ALIGN_LEFT, C.TITLE_COLOR)
    self:drawText(tostring(#fields) .. " fields",
        content.x + content.width - padX, titleY, 0.013,
        RenderText.ALIGN_RIGHT, C.MUTED_COLOR)
    self:drawDivider(titleY - self:py(4))

    local y = titleY - 0.028

    if #fields == 0 then
        self:drawText("You don't own any fields.", content.x + padX, y, 0.015,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        y = y - 0.022
        self:drawText("Purchase land to start farming.", content.x + padX, y, 0.013,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        return
    end

    -- Summary counts
    local countReady, countGrowing, countEmpty = 0, 0, 0
    for _, field in ipairs(fields) do
        local _, _, _, phase = self:getFieldCropInfo(field)
        if phase == "ready"        then countReady   = countReady   + 1
        elseif phase == "growing"  then countGrowing = countGrowing + 1
        else                            countEmpty   = countEmpty   + 1
        end
    end

    -- Summary row
    if countReady > 0 then
        self:drawText(countReady .. " ready",
            content.x + padX, y, 0.013, RenderText.ALIGN_LEFT, C.POSITIVE_COLOR)
    end
    if countGrowing > 0 then
        local gx = content.x + padX + self:px(countReady > 0 and 55 or 0)
        self:drawText(countGrowing .. " growing",
            gx, y, 0.013, RenderText.ALIGN_LEFT, C.VALUE_COLOR)
    end
    if countEmpty > 0 then
        self:drawText(countEmpty .. " empty",
            content.x + content.width - padX, y, 0.013,
            RenderText.ALIGN_RIGHT, C.MUTED_COLOR)
    end
    y = y - 0.005
    self:drawDivider(y, 0.20)
    y = y - 0.005

    -- Column headers
    self:drawText("#",     content.x + padX,               y, 0.011, RenderText.ALIGN_LEFT,  C.MUTED_COLOR)
    self:drawText("CROP",  content.x + padX + self:px(30),  y, 0.011, RenderText.ALIGN_LEFT,  C.MUTED_COLOR)
    self:drawText("STATE", content.x + content.width - padX, y, 0.011, RenderText.ALIGN_RIGHT, C.MUTED_COLOR)
    y = y - 0.019

    -- Field rows
    local shown = 0
    for _, field in ipairs(fields) do
        if y <= content.y + padY then break end

        local cropName, stateStr, stateColor = self:getFieldCropInfo(field)
        -- Use farmland.id as display ID (same as CropStress/SoilFertilizer)
        local fid = tostring((field.farmland and field.farmland.id) or field.fieldId or "?")

        self:drawText(fid,
            content.x + padX, y, 0.013, RenderText.ALIGN_LEFT, C.VALUE_COLOR)
        self:drawText(cropName,
            content.x + padX + self:px(30), y, 0.013, RenderText.ALIGN_LEFT, C.LABEL_COLOR)
        self:drawText(stateStr,
            content.x + content.width - padX, y, 0.013, RenderText.ALIGN_RIGHT, stateColor)

        y = y - 0.020
        shown = shown + 1
    end

    if #fields > shown then
        self:drawText("+" .. (#fields - shown) .. " more fields not shown",
            content.x + padX, content.y + padY + self:py(2), 0.011,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
    end
end

-- Returns all fields owned by farmId, sorted by farmland ID.
-- Uses field.farmland.ownerId — confirmed valid in FS25 by CropStress/SoilFertilizer apps.
function FarmTabletUI:getOwnedFields(farmId)
    local fields = {}
    local fieldManager = g_currentMission and g_currentMission.fieldManager
    if not fieldManager then return fields end

    local allFields = fieldManager:getFields()
    if not allFields then return fields end

    for _, field in pairs(allFields) do
        -- field.farmland is the Farmland object (confirmed by SeasonalCropStress + SoilFertilizer)
        -- farmland.ownerId is the owning farm's ID
        if field.farmland and field.farmland.ownerId == farmId then
            table.insert(fields, field)
        end
    end

    table.sort(fields, function(a, b)
        local idA = (a.farmland and a.farmland.id) or a.fieldId or 0
        local idB = (b.farmland and b.farmland.id) or b.fieldId or 0
        return idA < idB
    end)
    return fields
end

-- Returns cropName, stateStr, stateColor, phase ("ready"|"growing"|"empty")
-- for a single field object.
function FarmTabletUI:getFieldCropInfo(field)
    local C          = self.UI_CONSTANTS
    local cropName   = "Empty"
    local stateStr   = "-"
    local stateColor = C.MUTED_COLOR
    local phase      = "empty"

    -- fruitType: 0 or nil means no crop planted
    local fruitType = field.fruitType
    if not fruitType or fruitType == 0 then
        local groundType = field.maxGroundType or 0
        if groundType > 0 then
            stateStr   = "Prepared"
            stateColor = C.WARNING_COLOR
        end
        return cropName, stateStr, stateColor, phase
    end

    -- Resolve crop name from fruitType index
    if g_fruitTypeManager then
        pcall(function()
            local ft = g_fruitTypeManager:getFruitTypeByIndex(fruitType)
            if ft then
                local raw = ft.name or ""
                if raw == "" and ft.fillType and g_fillTypeManager then
                    local fti = g_fillTypeManager:getFillTypeByIndex(ft.fillType)
                    raw = fti and (fti.title or fti.name) or ""
                end
                if raw ~= "" then
                    cropName = raw:sub(1,1):upper() .. raw:sub(2):lower()
                    if #cropName > 10 then cropName = cropName:sub(1, 8) .. ".." end
                else
                    cropName = "Crop"
                end
            end
        end)
    end

    -- Growth state
    -- NOTE: In FS25 field.maxFieldStatus can be a table (per-cell data).
    -- Confirmed from NPC Favor log: "growth=table: 0x..."
    -- We extract a scalar from it, or fall back to maxGrowthState.
    local growth = nil
    pcall(function()
        local raw = field.maxFieldStatus
        if type(raw) == "number" then
            growth = raw
        elseif type(raw) == "table" then
            -- Try common scalar properties first
            if type(raw.value) == "number" then
                growth = raw.value
            elseif type(raw.percentage) == "number" then
                growth = raw.percentage
            else
                -- Compute max from numeric table values
                local maxV = 0
                for _, v in pairs(raw) do
                    if type(v) == "number" and v > maxV then maxV = v end
                end
                if maxV > 0 then growth = maxV end
            end
        end
        -- FS25 alternative property
        if growth == nil and type(field.maxGrowthState) == "number" then
            -- maxGrowthState is typically an integer stage (0-7)
            -- normalise against typical max stage of 7
            growth = field.maxGrowthState / 7.0
        end
    end)

    if growth ~= nil then
        if growth >= 0.95 then
            stateStr   = "Ready!"
            stateColor = C.POSITIVE_COLOR
            phase      = "ready"
        elseif growth >= 0.40 then
            stateStr   = "Growing"
            stateColor = C.VALUE_COLOR
            phase      = "growing"
        else
            stateStr   = "Seeded"
            stateColor = C.WARNING_COLOR
            phase      = "growing"
        end
    else
        stateStr   = "Seeded"
        stateColor = C.WARNING_COLOR
        phase      = "growing"
    end

    return cropName, stateStr, stateColor, phase
end
