-- =========================================================
-- FarmTablet v2 – Field Status App
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.FIELDS, function(self)
    local AC = FT.appColor(FT.APP.FIELDS)

    if self:drawHelpPage("_fieldsHelp", FT.APP.FIELDS, "Field Manager", AC, {
        { title = "SUMMARY BADGES",
          body  = "Top of the screen shows totals: READY fields that can\n" ..
                  "be harvested, GROW fields with crops growing, and EMPTY\n" ..
                  "fields with no active crop." },
        { title = "COLUMNS: # / CROP / HA / STATE",
          body  = "# = field ID.  CROP = crop type name.\n" ..
                  "HA = field area in hectares.\n" ..
                  "STATE = current field condition (see dot colours below)." },
        { title = "STATE DOT COLOURS",
          body  = "Green  = Ready to harvest.\n" ..
                  "Blue   = Growing normally.\n" ..
                  "Yellow = Needs attention (fertilise, plough, roll, etc.).\n" ..
                  "Grey   = Fallow / empty field." },
        { title = "SCROLLING",
          body  = "If you own more fields than fit on screen the list\n" ..
                  "scrolls automatically. Use the mouse wheel to scroll." },
    }) then return end

    local data   = self.system.data
    local farmId = data:getPlayerFarmId()
    local fields = data:getOwnedFields(farmId)

    local startY = self:drawAppHeader("Field Manager", #fields .. " fields")
    local x, contentY, cw, contentH = self:contentInner()
    local scrollY = self:getContentScrollY()

    if #fields == 0 then
        self.r:appText(x, startY - FT.py(12), FT.FONT.BODY,
            "You don't own any fields yet.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, startY - FT.py(32), FT.FONT.SMALL,
            "Purchase land to start farming.", RenderText.ALIGN_LEFT, FT.C.MUTED)
        self:drawInfoIcon("_fieldsHelp", AC)
        return
    end

    local countReady, countGrowing, countEmpty = 0, 0, 0
    for _, f in ipairs(fields) do
        if     f.phase == "ready"   then countReady   = countReady   + 1
        elseif f.phase == "growing" then countGrowing = countGrowing + 1
        else                             countEmpty   = countEmpty   + 1
        end
    end

    local y  = startY - FT.py(2) + scrollY
    local bx = x
    if countReady   > 0 then bx = bx + self.r:badge(bx, y, countReady..  " READY", FT.C.BTN_PRIMARY)   + FT.px(4) end
    if countGrowing > 0 then bx = bx + self.r:badge(bx, y, countGrowing.." GROW",  FT.C.BTN_NEUTRAL)   + FT.px(4) end
    if countEmpty   > 0 then         self.r:badge(bx, y, countEmpty..  " EMPTY", {0.18,0.18,0.22,0.9}) end

    y = y - FT.py(20)
    y = self:drawRule(y, 0.4)

    self.r:appText(x,             y, FT.FONT.TINY, "#",     RenderText.ALIGN_LEFT,  FT.C.TEXT_DIM)
    self.r:appText(x + FT.px(28), y, FT.FONT.TINY, "CROP",  RenderText.ALIGN_LEFT,  FT.C.TEXT_DIM)
    self.r:appText(x + cw * 0.6,  y, FT.FONT.TINY, "HA",    RenderText.ALIGN_LEFT,  FT.C.TEXT_DIM)
    self.r:appText(x + cw,        y, FT.FONT.TINY, "STATE", RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
    y = y - FT.py(16)

    local rowH  = FT.py(19)
    local altBg = {0.09, 0.11, 0.16, 0.50}

    for i, field in ipairs(fields) do
        if i % 2 == 0 then
            self.r:appRect(x - FT.px(4), y - FT.py(4), cw + FT.px(8), rowH, altBg)
        end
        self.r:appRect(x + FT.px(2), y + FT.py(4), FT.px(6), FT.py(6), field.stateColor or FT.C.MUTED)
        self.r:appText(x + FT.px(12), y, FT.FONT.SMALL, tostring(field.id), RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        local cropDisp = field.cropName
        if #cropDisp > 12 then cropDisp = cropDisp:sub(1,10) .. ".." end
        self.r:appText(x + FT.px(28), y, FT.FONT.SMALL, cropDisp, RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
        if field.area and field.area > 0 then
            self.r:appText(x + cw * 0.6, y, FT.FONT.SMALL,
                string.format("%.1f", field.area), RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        end
        self.r:appText(x + cw, y, FT.FONT.SMALL, field.stateName, RenderText.ALIGN_RIGHT, field.stateColor or FT.C.MUTED)
        y = y - rowH
    end

    self:setContentHeight(startY - y + scrollY)
    self:drawScrollBar()
    self:drawInfoIcon("_fieldsHelp", AC)
end)
