-- =========================================================
-- FS25 Farm Tablet -- Bucket Load Tracker App
-- =========================================================

function FarmTabletUI:loadBucketTrackerApp()
    self.ui.appTexts = {}
    local content = self.ui.appContentArea
    if not content then return end

    local C       = self.UI_CONSTANTS
    local padX    = self:px(15)
    local padY    = self:py(12)
    local sys     = self.tabletSystem
    local tracker = sys.bucketTracker

    local titleY = content.y + content.height - padY - self:titleH()
    self:drawText("Bucket Load Tracker", content.x + padX, titleY, 0.019,
        RenderText.ALIGN_LEFT, C.TITLE_COLOR)
    self:drawDivider(titleY - self:py(4))

    local y = titleY - 0.030

    -- Current vehicle / bucket
    local vehicle = sys:getCurrentBucketVehicle()
    self:drawSectionHeader("CURRENT VEHICLE", y)
    y = y - 0.022

    if vehicle then
        local vname = (vehicle.getFullName and vehicle:getFullName()) or "Unknown"
        if #vname > 24 then vname = vname:sub(1, 21) .. "..." end
        self:drawRow("Vehicle", vname, y, C.LABEL_COLOR, C.VALUE_COLOR)
        y = y - 0.022

        local fi = sys:getBucketFillInfo(vehicle)
        if fi.totalFillLevel > 0 then
            local pct = fi.fillPercentage
            local pctColor = pct > 80 and C.POSITIVE_COLOR or
                             pct > 40 and C.WARNING_COLOR  or C.NEGATIVE_COLOR
            self:drawRow("Fill Type", fi.fillTypeName, y, C.LABEL_COLOR, C.VALUE_COLOR)
            y = y - 0.022
            self:drawRow("Volume",
                string.format("%d / %d L", math.floor(fi.totalFillLevel), math.floor(fi.totalCapacity)),
                y, C.LABEL_COLOR, C.VALUE_COLOR)
            y = y - 0.022
            self:drawRow("Fill %", string.format("%.0f%%", pct), y, C.LABEL_COLOR, pctColor)
            y = y - 0.022
            y = self:drawProgressBar(pct, 100, y, pctColor)
            local wt = sys:estimateBucketWeight(fi)
            self:drawRow("Est. Weight", string.format("%d kg", wt), y, C.LABEL_COLOR, C.VALUE_COLOR)
            y = y - 0.022
        else
            self:drawText("Bucket empty.", content.x + padX, y, 0.014,
                RenderText.ALIGN_LEFT, C.MUTED_COLOR)
            y = y - 0.022
        end
    else
        self:drawText("No bucket vehicle detected.", content.x + padX, y, 0.014,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        y = y - 0.020
        self:drawText("Drive a loader or excavator.", content.x + padX, y, 0.013,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        y = y - 0.022
    end

    -- Session stats
    y = y - 0.010
    self:drawSectionHeader("SESSION", y)
    y = y - 0.022

    self:drawRow("Total Loads",  tostring(tracker.totalLoads),                     y, C.LABEL_COLOR, C.VALUE_COLOR)
    y = y - 0.022
    self:drawRow("Total Weight", string.format("%d kg", tracker.totalWeight),       y, C.LABEL_COLOR, C.VALUE_COLOR)
    y = y - 0.022

    if tracker.startTime > 0 then
        local elapsed = ((g_currentMission.time or 0) - tracker.startTime) / 1000
        self:drawRow("Duration", self:formatTime(elapsed), y, C.LABEL_COLOR, C.VALUE_COLOR)
        y = y - 0.022
        if tracker.totalLoads > 0 then
            local avg = math.floor(tracker.totalWeight / tracker.totalLoads)
            self:drawRow("Avg Load", string.format("%d kg", avg), y, C.LABEL_COLOR, C.VALUE_COLOR)
            y = y - 0.022
        end
    end

    -- Recent history
    if #tracker.bucketHistory > 0 then
        y = y - 0.010
        self:drawSectionHeader("RECENT LOADS", y)
        y = y - 0.022
        local start = math.max(1, #tracker.bucketHistory - 4)
        for i = #tracker.bucketHistory, start, -1 do
            local load = tracker.bucketHistory[i]
            if load and y > content.y + padY then
                local ft = load.fillTypeName or (load.fillType and tostring(load.fillType)) or "?"
                self:drawRow(
                    string.format("#%d  %s", load.number, ft),
                    string.format("%dL  %dkg", load.volume, load.weight),
                    y, C.LABEL_COLOR, C.MUTED_COLOR
                )
                y = y - 0.020
            end
        end
    end

    -- Reset button — use createAppOverlay so it's cleaned on switch
    local btnW = self:px(140)
    local btnH = self:py(26)
    local btnX = content.x + content.width - padX - btnW
    local btnY = content.y + padY

    self.ui.resetBucketButton = self:drawButton("Reset Session", btnX, btnY, btnW, btnH, C.BTN_RED)
end

function FarmTabletUI:formatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then
        return string.format("%02d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end
