-- =========================================================
-- FarmTablet v2 – Storage App
-- Silo inventory aggregated across all owned silos,
-- plus the best current sell price per stored crop.
-- =========================================================

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
                  "Prices are per 1,000 litres. Data refreshes every 5 seconds." },
        { title = "WHAT COUNTS AS A SILO?",
          body  = "Any placeable with bulk storage you own:\n" ..
                  "grain silos, bunker silos, silage pits, manure stores,\n" ..
                  "and liquid manure tanks." },
    }) then return end

    local data    = self.system.data
    local farmId  = data:getPlayerFarmId()
    local storage = data:getStorages(farmId)
    local prices  = data:getSellPrices()

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
            y = self:drawRow(y, crop.name, data:formatMoney(pd.bestPrice), nil, FT.C.POSITIVE)
        end
    end

    if not shownAny then
        y = self:drawRow(y, "No sell price data found", "")
    end

    self:drawInfoIcon("_storageHelp", AC)
end)
