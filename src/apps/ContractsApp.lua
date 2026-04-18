-- =========================================================
-- FarmTablet v2 – Contracts App
-- Displays active field missions (contracts) for the player's farm.
-- Uses g_missionManager (the FS25 mission system backs all contracts).
-- =========================================================

-- ── Mission type → friendly name ─────────────────────────
local CONTRACT_TYPE_NAMES = {
    PlowMission        = "Plowing",
    CultivatorMission  = "Cultivating",
    SowMission         = "Sowing",
    FertilizeMission   = "Fertilizing",
    SprayMission       = "Spraying",
    HarvestMission     = "Harvesting",
    MowMission         = "Mowing",
    StonePickMission   = "Stone Picking",
    WeedMission        = "Weeding",
    BinderMission      = "Baling",
    DeadwoodMission    = "Deadwood",
    TreePlantMission   = "Tree Planting",
    TransportMission   = "Transport",
}

local function getTypeName(mission)
    local raw = mission.getMissionTypeName and mission:getMissionTypeName()
    return (raw and CONTRACT_TYPE_NAMES[raw]) or raw or "Contract"
end

-- Formats game-minutes remaining into a short string.
-- Returns nil if mins is nil (no deadline), "EXPIRED" if <= 0.
local function fmtMins(mins)
    if mins == nil then return nil end
    if mins <= 0   then return "EXPIRED" end
    local h = math.floor(mins / 60)
    local m = mins % 60
    if     h == 0 then return m .. "m left"
    elseif m == 0 then return h .. "h left"
    else               return h .. "h " .. m .. "m left"
    end
end

-- Returns three lists: active, expiring (< 2 game-hours left), done
local function getContracts(farmId)
    if not g_missionManager then return {}, {}, {} end
    local all = g_missionManager:getMissionsByFarmId(farmId)
    if not all then return {}, {}, {} end

    local active, expiring, done = {}, {}, {}
    for _, m in ipairs(all) do
        if m:getIsFinished() then
            table.insert(done, m)
        elseif m:getIsInProgress() then
            local mins = m.getMinutesLeft and m:getMinutesLeft()
            if mins and mins < 120 then
                table.insert(expiring, m)
            else
                table.insert(active, m)
            end
        end
    end
    return active, expiring, done
end

-- ── App Drawer ────────────────────────────────────────────

FarmTabletUI:registerDrawer(FT.APP.CONTRACTS, function(self)
    local AC = FT.appColor(FT.APP.CONTRACTS)

    if self:drawHelpPage("_contractsHelp", FT.APP.CONTRACTS, "Contracts", AC, {
        { title = "ACTIVE CONTRACTS",
          body  = "Shows all field contracts your farm has accepted\n" ..
                  "and is currently working on.\n" ..
                  "Completion updates automatically." },
        { title = "TIME REMAINING",
          body  = "Time shown is in-game time, not real-world time.\n" ..
                  "Contracts in amber are expiring soon (< 2 game hours).\n" ..
                  "Tap T to close the tablet and get back to work!" },
        { title = "DONE — COLLECT REWARD",
          body  = "Contracts marked DONE are complete but unpaid.\n" ..
                  "Visit the NPC on the map to dismiss and collect\n" ..
                  "your reward." },
        { title = "NO CONTRACTS SHOWING",
          body  = "Accept contracts from NPCs on the map or via the\n" ..
                  "Contracts board in the pause menu. Only accepted\n" ..
                  "contracts appear here — available ones do not." },
    }) then return end

    local data   = self.system.data
    local farmId = data:getPlayerFarmId()
    local active, expiring, done = getContracts(farmId)
    local totalActive = #active + #expiring

    -- Subtitle
    local subtitle
    if totalActive == 0 and #done == 0 then
        subtitle = "none active"
    else
        local parts = {}
        if totalActive > 0 then parts[#parts+1] = totalActive .. " active"   end
        if #expiring   > 0 then parts[#parts+1] = #expiring  .. " expiring"  end
        if #done       > 0 then parts[#parts+1] = #done      .. " to collect" end
        subtitle = table.concat(parts, " · ")
    end

    local startY = self:drawAppHeader("Contracts", subtitle)
    local x, contentY, cw, _ = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y = startY + scrollY

    -- ── Empty state ───────────────────────────────────────
    if totalActive == 0 and #done == 0 then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "No active contracts.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, y - FT.py(28), FT.FONT.SMALL,
            "Accept contracts from NPCs on the map.",
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        self:drawInfoIcon("_contractsHelp", AC)
        return
    end

    -- ── Summary badges ────────────────────────────────────
    local bx = x
    if totalActive > 0 then
        bx = bx + self.r:badge(bx, y, totalActive .. " ACTIVE",
            FT.C.BTN_PRIMARY) + FT.px(4)
    end
    if #expiring > 0 then
        bx = bx + self.r:badge(bx, y, #expiring .. " EXPIRING",
            {0.70, 0.40, 0.10, 0.90}) + FT.px(4)
    end
    if #done > 0 then
        self.r:badge(bx, y, #done .. " COLLECT",
            {0.16, 0.55, 0.30, 0.90})
    end
    y = y - FT.py(20)
    y = self:drawRule(y, 0.35)

    -- ── Contract card helper ──────────────────────────────
    local cardH  = FT.py(58)
    local padX   = FT.px(10)
    local BADGE_W = FT.px(52)

    local function drawCard(mission, cardAccent, statusLabel, statusColor)
        local typeName   = getTypeName(mission)
        local location   = (mission.getLocation and mission:getLocation()) or "Unknown Field"
        location = location:gsub("^Farmland:%s*", "")
        if #location > 26 then location = location:sub(1, 24) .. ".." end

        local completion = (mission.getCompletion and mission:getCompletion()) or 0
        local pct        = math.floor(completion * 100)
        local reward     = (mission.getReward and mission:getReward()) or 0
        local rewardStr  = data:formatMoney(math.floor(reward))

        local mins      = mission.getMinutesLeft and mission:getMinutesLeft()
        local timeStr   = fmtMins(mins)
        local timeColor
        if     timeStr == "EXPIRED" then timeColor = FT.C.NEGATIVE
        elseif mins and mins < 120  then timeColor = FT.C.WARNING
        else                             timeColor = FT.C.TEXT_DIM
        end

        -- Card background + left accent bar
        self.r:appRect(x - FT.px(4), y - cardH + FT.py(4),
            cw + FT.px(8), cardH,
            {cardAccent[1], cardAccent[2], cardAccent[3], 0.07})
        self.r:appRect(x - FT.px(4), y - cardH + FT.py(4),
            FT.px(3), cardH,
            {cardAccent[1], cardAccent[2], cardAccent[3], 0.80})

        -- Status badge (top-right corner)
        self.r:appRect(x + cw - BADGE_W, y - FT.py(1), BADGE_W, FT.py(12),
            {statusColor[1], statusColor[2], statusColor[3], 0.20})
        self.r:appText(x + cw - BADGE_W / 2, y + FT.py(4),
            FT.FONT.TINY, statusLabel,
            RenderText.ALIGN_CENTER, statusColor)

        -- Row 1: type name
        self.r:appText(x + padX, y - FT.py(3),
            FT.FONT.BODY, typeName,
            RenderText.ALIGN_LEFT, {cardAccent[1], cardAccent[2], cardAccent[3], 1.00})

        -- Row 2: field / location
        self.r:appText(x + padX, y - FT.py(17),
            FT.FONT.SMALL, location,
            RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)

        -- Row 3: progress bar + pct label + reward
        local barY = y - FT.py(34)
        local barW = cw * 0.52
        self.r:progressBar(x + padX, barY, barW, completion, 1.0,
            {cardAccent[1], cardAccent[2], cardAccent[3], 0.85})
        self.r:appText(x + padX + barW + FT.px(6), barY + FT.py(1),
            FT.FONT.SMALL, pct .. "%",
            RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)
        self.r:appText(x + cw, barY + FT.py(1),
            FT.FONT.SMALL, rewardStr,
            RenderText.ALIGN_RIGHT, FT.C.TEXT_ACCENT)

        -- Row 4: time remaining or collect prompt
        if statusLabel == "DONE" then
            self.r:appText(x + padX, y - cardH + FT.py(12),
                FT.FONT.TINY, "Visit NPC on map to collect reward",
                RenderText.ALIGN_LEFT, FT.C.POSITIVE)
        elseif timeStr then
            self.r:appText(x + padX, y - cardH + FT.py(12),
                FT.FONT.TINY, "Game time: " .. timeStr,
                RenderText.ALIGN_LEFT, timeColor)
        end

        y = y - cardH - FT.py(6)
    end

    -- Expiring first (most urgent), then active, then done
    for _, m in ipairs(expiring) do
        drawCard(m, {1.00, 0.62, 0.10, 1.00}, "EXPIRING", FT.C.WARNING)
    end
    for _, m in ipairs(active) do
        drawCard(m, AC, "ACTIVE", FT.C.POSITIVE)
    end
    if #done > 0 then
        y = self:drawRule(y, 0.25)
        self.r:appText(x, y - FT.py(2), FT.FONT.TINY,
            "COMPLETED - COLLECT REWARD FROM NPC",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        y = y - FT.py(14)
        for _, m in ipairs(done) do
            drawCard(m, FT.C.POSITIVE, "DONE", FT.C.POSITIVE)
        end
    end

    self:setContentHeight(startY - y + scrollY)
    self:drawScrollBar()
    self:drawInfoIcon("_contractsHelp", AC)
end)
