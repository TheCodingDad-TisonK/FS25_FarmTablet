-- =========================================================
-- FarmTablet v2 – Storage App
-- Silo inventory, best sell prices with historical peak
-- tracking, and full per-station price comparison.
-- =========================================================

-- ── Peak price tracking ────────────────────────────────────

local _peakPrices = {}   -- [fillTypeIndex] = {price=n, day=n}

local function _savePath()
    if g_currentMission and g_currentMission.missionInfo
    and g_currentMission.missionInfo.savegameDirectory then
        return g_currentMission.missionInfo.savegameDirectory
               .. "/farm_tablet_storage.xml"
    end
    return nil
end

local function _savePeaks()
    local path = _savePath()
    if not path then return end
    local xml = XMLFile.create("FTStoragePeaks", path, "farmTabletStorage")
    if not xml then return end
    local i = 0
    for fillTypeIdx, data in pairs(_peakPrices) do
        local key = string.format("farmTabletStorage.peak(%d)", i)
        xml:setInt(key .. "#fillType", fillTypeIdx)
        xml:setInt(key .. "#price",    data.price)
        xml:setInt(key .. "#day",      data.day or 0)
        i = i + 1
    end
    xml:setInt("farmTabletStorage#count", i)
    xml:save()
    xml:delete()
end

local function _loadPeaks()
    local path = _savePath()
    if not path or not fileExists(path) then return end
    local xml = XMLFile.load("FTStoragePeaks", path)
    if not xml then return end
    _peakPrices = {}
    local count = xml:getInt("farmTabletStorage#count", 0)
    for i = 0, count - 1 do
        local key     = string.format("farmTabletStorage.peak(%d)", i)
        local idx     = xml:getInt(key .. "#fillType", 0)
        local price   = xml:getInt(key .. "#price",    0)
        local day     = xml:getInt(key .. "#day",      0)
        if idx > 0 and price > 0 then
            _peakPrices[idx] = {price = price, day = day}
        end
    end
    xml:delete()
end

Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission,
    function() _loadPeaks() end)
FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile,
    function() _savePeaks() end)

-- ── Drawer ─────────────────────────────────────────────────

FarmTabletUI:registerDrawer(FT.APP.STORAGE, function(self)
    local AC = FT.appColor(FT.APP.STORAGE)

    if self:drawHelpPage("_storageHelp", FT.APP.STORAGE, "Storage", AC, {
        { title = "INVENTORY",
          body  = "Lists all crops currently stored across your owned silos.\n" ..
                  "Amounts shown in litres, sorted largest-first.\n" ..
                  "Data refreshes every 3 seconds." },
        { title = "BEST SELL PRICES",
          body  = "Shows the best available sell price per stored crop\n" ..
                  "across all active selling stations on the map.\n" ..
                  "Peak price is tracked and saved per savegame.\n" ..
                  "Orange peak = current price is below the recorded high.\n" ..
                  "Prices are per 1,000 litres. Refreshes every 5 seconds." },
        { title = "PRICE COMPARISON",
          body  = "Lists every selling station and its current price for\n" ..
                  "each crop you have in storage.\n" ..
                  "Stations are sorted best-price first.\n" ..
                  "Only shown when 2+ stations buy that crop." },
        { title = "WHAT COUNTS AS A SILO?",
          body  = "Any placeable with bulk storage you own:\n" ..
                  "grain silos, bunker silos, silage pits, manure stores,\n" ..
                  "and liquid manure tanks." },
    }) then return end

    local data    = self.system.data
    local farmId  = data:getPlayerFarmId()
    local storage = data:getStorages(farmId)
    local prices  = data:getSellPrices()

    -- Update peak prices from current data
    local today = (g_currentMission and g_currentMission.environment
                   and g_currentMission.environment.currentDay) or 0
    for fillTypeIdx, pd in pairs(prices) do
        if pd.bestPrice > 0 then
            if not _peakPrices[fillTypeIdx]
            or pd.bestPrice > _peakPrices[fillTypeIdx].price then
                _peakPrices[fillTypeIdx] = {price = pd.bestPrice, day = today}
            end
        end
    end

    local subtitle = storage.siloCount == 1 and "1 silo" or (storage.siloCount .. " silos")
    local startY = self:drawAppHeader("Storage", subtitle)
    local x, contentY, cw, _ = self:contentInner()
    local y = startY

    if storage.siloCount == 0 then
        self.r:appText(x, y - FT.py(12), FT.FONT.BODY,
            "No silos owned.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, y - FT.py(28), FT.FONT.SMALL,
            "Purchase a silo to track stored crops.", RenderText.ALIGN_LEFT, FT.C.MUTED)
        self:drawInfoIcon("_storageHelp", AC)
        return
    end

    local minY = contentY + FT.py(8)

    -- ── INVENTORY ─────────────────────────────────────────
    y = self:drawSection(y, "INVENTORY")

    if #storage.crops == 0 then
        y = self:drawRow(y, "Silos are empty", "")
    else
        for _, crop in ipairs(storage.crops) do
            if y < minY then break end
            y = self:drawRow(y, crop.name, string.format("%d L", crop.amount))
        end
    end

    if y < minY + FT.py(30) then
        self:drawInfoIcon("_storageHelp", AC)
        return
    end

    y = y - FT.py(6)
    y = self:drawRule(y, 0.3)

    -- ── BEST SELL PRICES ──────────────────────────────────
    y = self:drawSection(y, "BEST SELL PRICES  (per 1,000 L)")

    local shownAny = false
    for _, crop in ipairs(storage.crops) do
        if y < minY then break end
        local pd = prices[crop.fillTypeIndex]
        if pd and pd.bestPrice > 0 then
            shownAny = true
            -- Main price row
            self.r:appText(x + FT.px(14), y, FT.FONT.BODY, crop.name,
                RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
            self.r:appText(x + cw - FT.px(14), y, FT.FONT.BODY,
                data:formatMoney(pd.bestPrice),
                RenderText.ALIGN_RIGHT, FT.C.POSITIVE)
            y = y - FT.py(FT.SP.ROW)

            -- Peak sub-row
            local pk = _peakPrices[crop.fillTypeIndex]
            if pk and pk.price > 0 then
                local isAtPeak = pd.bestPrice >= pk.price
                local pkColor  = isAtPeak and FT.C.POSITIVE or FT.C.WARNING
                local pkText   = string.format("  Peak: %s  (day %d)",
                    data:formatMoney(pk.price), pk.day)
                self.r:appText(x + FT.px(14), y, FT.FONT.TINY, pkText,
                    RenderText.ALIGN_LEFT, pkColor)
                y = y - FT.py(13)
            end
        end
    end

    if not shownAny then
        y = self:drawRow(y, "No sell price data found", "")
    end

    if y < minY + FT.py(30) then
        self:drawInfoIcon("_storageHelp", AC)
        return
    end

    y = y - FT.py(6)
    y = self:drawRule(y, 0.3)

    -- ── PRICE COMPARISON ──────────────────────────────────
    y = self:drawSection(y, "PRICE COMPARISON  (all stations)")

    local compShown = false
    for _, crop in ipairs(storage.crops) do
        if y < minY then break end
        local pd = prices[crop.fillTypeIndex]
        if pd and pd.stations and #pd.stations > 1 then
            compShown = true

            -- Crop sub-header
            self.r:appText(x + FT.px(6), y, FT.FONT.SMALL,
                crop.name .. ":",
                RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            y = y - FT.py(16)

            -- Sort stations by price descending
            local sorted = {}
            for _, s in ipairs(pd.stations) do
                table.insert(sorted, s)
            end
            table.sort(sorted, function(a, b) return a.price > b.price end)

            for _, s in ipairs(sorted) do
                if y < minY then break end
                local vc = (s.price == pd.bestPrice) and FT.C.POSITIVE or FT.C.TEXT_NORMAL
                y = self:drawRow(y, "  " .. s.name,
                    data:formatMoney(s.price), nil, vc)
            end

            y = y - FT.py(4)
        end
    end

    if not compShown then
        y = self:drawRow(y, "Single station — no comparison available", "")
    end

    self:drawInfoIcon("_storageHelp", AC)
end)
