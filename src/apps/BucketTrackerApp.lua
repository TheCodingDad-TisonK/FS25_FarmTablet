-- =========================================================
-- FarmTablet v2 – Bucket Tracker App
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.BUCKET, function(self)
    local AC = FT.appColor(FT.APP.BUCKET)

    if self:drawHelpPage("_bucketHelp", FT.APP.BUCKET, "Bucket Tracker", AC, {
        { title = "AUTOMATIC DETECTION",
          body  = "The tracker activates automatically when you drive or\n" ..
                  "mount a wheel loader, excavator, or material handler.\n" ..
                  "No setup required — just start working." },
        { title = "SUMMARY CARDS",
          body  = "LOADS = total dump cycles recorded this session.\n" ..
                  "WEIGHT = total material moved in tonnes.\n" ..
                  "ITEMS = number of individual load entries in history." },
        { title = "ACTIVE VEHICLE",
          body  = "Shows the vehicle currently being tracked with its\n" ..
                  "bucket fill level and material type as a bar.\n" ..
                  "Updates live while you work." },
        { title = "LOAD HISTORY",
          body  = "Lists the 8 most recent dump cycles with material\n" ..
                  "name and estimated weight per load.\n" ..
                  "Older entries scroll off the bottom of the list." },
        { title = "RESET BUTTON",
          body  = "Clears all load history and resets the session totals\n" ..
                  "to zero. Use at the start of a new job to track\n" ..
                  "productivity separately." },
    }) then return end

    local bt     = self.system.bucket
    local data   = self.system.data

    local startY = self:drawAppHeader("Bucket Tracker", "")
    local x, contentY, cw, _ = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y = startY + scrollY

    -- Summary cards
    y = y - FT.py(4)
    local cardW = (cw - FT.px(8)) / 3
    local cards = {
        { label="LOADS",  value=tostring(bt.totalLoads) },
        { label="WEIGHT", value=string.format("%.0ft", (bt.totalWeight or 0)/1000) },
        { label="ITEMS",  value=tostring(#bt.history) },
    }
    for i, card in ipairs(cards) do
        local cx = x + (i-1) * (cardW + FT.px(4))
        self.r:appRect(cx, y - FT.py(34), cardW, FT.py(38), FT.C.BG_CARD)
        self.r:appText(cx + cardW/2, y - FT.py(10),  FT.FONT.HUGE, card.value,  RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
        self.r:appText(cx + cardW/2, y - FT.py(28), FT.FONT.TINY,  card.label, RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)
    end
    y = y - FT.py(40)

    -- Active vehicle
    if bt.vehicle then
        local fi = self.system:_getBucketFillInfo(bt.vehicle)
        local nm = (bt.vehicle.getFullName and bt.vehicle:getFullName()) or "Unknown"
        if #nm > 22 then nm = nm:sub(1,20) .. ">" end
        y = self:drawSection(y, "ACTIVE VEHICLE")
        y = self:drawRow(y, "Vehicle", nm)
        y = self:drawRow(y, "Fill",
            string.format("%.0f / %.0f L  (%s)", fi.total, fi.cap, fi.name), nil, FT.C.TEXT_ACCENT)
        y = y + FT.py(FT.SP.ROW) - FT.py(8)
        y = self:drawBar(y, fi.total, fi.cap, FT.C.BRAND)
        y = y - FT.py(4)
    else
        y = self:drawSection(y, "ACTIVE VEHICLE")
        self.r:appText(x, y, FT.FONT.SMALL, "No bucket vehicle detected nearby.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        y = y - FT.py(20)
    end

    -- Load history
    y = self:drawRule(y, 0.35)
    y = self:drawSection(y, "LOAD HISTORY  (" .. #bt.history .. ")")
    local minY = contentY + FT.py(32)

    if #bt.history == 0 then
        self.r:appText(x, y, FT.FONT.SMALL, "No loads recorded yet.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        y = y - FT.py(20)
    else
        self.r:appText(x,             y, FT.FONT.TINY, "#",        RenderText.ALIGN_LEFT,  FT.C.TEXT_DIM)
        self.r:appText(x + FT.px(20), y, FT.FONT.TINY, "MATERIAL", RenderText.ALIGN_LEFT,  FT.C.TEXT_DIM)
        self.r:appText(x + cw,        y, FT.FONT.TINY, "WEIGHT",   RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
        y = y - FT.py(14)
        for i = #bt.history, 1, -1 do
            local load = bt.history[i]
            self.r:appText(x,             y, FT.FONT.TINY,  tostring(load.n),              RenderText.ALIGN_LEFT,  FT.C.TEXT_DIM)
            self.r:appText(x + FT.px(20), y, FT.FONT.SMALL, load.typeName or "Unknown",    RenderText.ALIGN_LEFT,  FT.C.TEXT_NORMAL)
            self.r:appText(x + cw,        y, FT.FONT.SMALL, string.format("%.0f kg", load.weight or 0), RenderText.ALIGN_RIGHT, FT.C.TEXT_ACCENT)
            y = y - FT.py(18)
        end
    end

    if y > minY + FT.py(4) then
        self:drawButton(minY + FT.py(2), "RESET", FT.C.BTN_DANGER,
            { onClick = function()
                self.system:resetBucket()
                self:switchApp(FT.APP.BUCKET)
            end })
    end

    self:setContentHeight(startY - y + scrollY)
    self:drawInfoIcon("_bucketHelp", AC)
    self:drawScrollBar()
end)
