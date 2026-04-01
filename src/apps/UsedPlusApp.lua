-- =========================================================
-- FarmTablet v2 – UsedPlus Integration App
-- Shows active vehicle sale listings and finance deals
-- from FS25_UsedPlus via its cross-mod API.
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.USED_PLUS, function(self)
    local AC = FT.appColor(FT.APP.USED_PLUS)

    -- Help sub-page
    if self:drawHelpPage("_usedPlusHelp", FT.APP.USED_PLUS, "UsedPlus", AC, {
        { title = "ACTIVE SALE LISTINGS",
          body  = "Vehicles you have listed for sale through a UsedPlus\n" ..
                  "agent. Shows vehicle name, asking price range, agent\n" ..
                  "tier, and how far through the listing period you are." },
        { title = "PROGRESS BAR",
          body  = "Filled = time elapsed. An offer can arrive any time\n" ..
                  "between 25% and 75% of the listing window.\n" ..
                  "Orange bar = offer is waiting for your decision." },
        { title = "FINANCE DEALS",
          body  = "Active loans and leases arranged through UsedPlus.\n" ..
                  "Shows item name, monthly payment, and remaining\n" ..
                  "balance. Manage deals in the UsedPlus finance menu." },
        { title = "CREDIT SCORE",
          body  = "Your farm's UsedPlus credit rating.\n" ..
                  "Higher score = better loan terms and lower interest." },
    }) then return end

    -- Resolve globals
    local saleManager = getfenv(0)["g_vehicleSaleManager"]
    local api         = g_currentMission and g_currentMission.usedPlusAPI

    -- Guard: mod not installed
    if not saleManager and not api then
        local startY2 = self:drawAppHeader("UsedPlus", "Integration")
        local x2, _, _, _ = self:contentInner()
        local y2 = startY2
        self.r:appText(x2, y2 - FT.py(12), FT.FONT.BODY,
            "UsedPlus is not installed.", RenderText.ALIGN_LEFT, FT.C.NEGATIVE)
        self.r:appText(x2, y2 - FT.py(30), FT.FONT.SMALL,
            "Install FS25_UsedPlus to use this app.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self:drawInfoIcon("_usedPlusHelp", AC)
        return
    end

    local data   = self.system.data
    local farmId = data:getPlayerFarmId()

    local startY = self:drawAppHeader("UsedPlus", "Marketplace")
    local x, contentY, w, _ = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y = startY + scrollY

    -- ── Credit score (top-right hero) ─────────────────────
    if api and api.getCreditScore then
        local score = api.getCreditScore(farmId) or 0
        local rating = (api.getCreditRating and api.getCreditRating(farmId)) or ""
        local scoreColor = FT.C.POSITIVE
        if score < 500      then scoreColor = FT.C.NEGATIVE
        elseif score < 650  then scoreColor = FT.C.WARNING
        elseif score < 750  then scoreColor = FT.C.TEXT_ACCENT
        end
        self.r:appText(x + w - FT.px(8), y - FT.py(5),
            FT.FONT.TINY, "CREDIT", RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
        self.r:appText(x + w - FT.px(8), y - FT.py(17),
            FT.FONT.BODY, tostring(score) .. (rating ~= "" and ("  " .. rating) or ""),
            RenderText.ALIGN_RIGHT, scoreColor)
        y = y - FT.py(4)
    end

    -- ── Active sale listings ───────────────────────────────
    y = self:drawSection(y, "ACTIVE SALE LISTINGS")

    local listings = saleManager and saleManager:getListingsForFarm(farmId, true) or {}

    if #listings == 0 then
        self.r:appText(x + FT.px(4), y - FT.py(12), FT.FONT.BODY,
            "No active listings.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        y = y - FT.py(18)
    else
        for _, lst in ipairs(listings) do
            -- Name row
            local statusColor = FT.C.TEXT_NORMAL
            local statusLabel = ""
            if lst.status == "offer_pending" then
                statusColor = FT.C.WARNING
                statusLabel = "  OFFER"
            end
            local nameText = (lst.vehicleName or "Unknown")
            self.r:appText(x + FT.px(4), y - FT.py(10),
                FT.FONT.BODY, nameText, RenderText.ALIGN_LEFT, statusColor)
            if statusLabel ~= "" then
                self.r:appText(x + w - FT.px(4), y - FT.py(10),
                    FT.FONT.TINY, statusLabel, RenderText.ALIGN_RIGHT, FT.C.WARNING)
            end
            y = y - FT.py(14)

            -- Price range + agent
            local minP = lst.expectedMinPrice or 0
            local maxP = lst.expectedMaxPrice or 0
            local priceStr = string.format("%s – %s",
                data:formatMoney(minP), data:formatMoney(maxP))
            local agentName = (lst.getAgentTierName and lst:getAgentTierName())
                           or tostring(lst.saleTier or "")
            self.r:appText(x + FT.px(4), y - FT.py(8),
                FT.FONT.SMALL, priceStr, RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            self.r:appText(x + w - FT.px(4), y - FT.py(8),
                FT.FONT.TINY, agentName, RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
            y = y - FT.py(11)

            -- Progress bar (elapsed / total)
            local elapsed = lst.hoursElapsed or 0
            local total   = lst.ttl or 1
            local pct     = math.min(1.0, elapsed / math.max(total, 1))
            local barW    = w - FT.px(8)
            local barH    = FT.py(5)
            -- bg track
            self.r:appRect(x + FT.px(4), y - barH, barW, barH, FT.C.BG_PANEL)
            -- fill
            local fillColor = lst.status == "offer_pending" and FT.C.WARNING or AC
            if pct > 0 then
                self.r:appRect(x + FT.px(4), y - barH,
                    barW * pct, barH, fillColor)
            end
            y = y - FT.py(8)

            -- Time remaining label
            local hoursLeft = math.max(0, total - elapsed)
            local daysLeft  = math.floor(hoursLeft / 24)
            local timeStr
            if daysLeft > 0 then
                timeStr = string.format("%d day%s remaining", daysLeft, daysLeft ~= 1 and "s" or "")
            else
                timeStr = string.format("%d hr%s remaining", hoursLeft, hoursLeft ~= 1 and "s" or "")
            end
            self.r:appText(x + FT.px(4), y - FT.py(7),
                FT.FONT.TINY, timeStr, RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            y = y - FT.py(12)
        end
    end

    -- ── Finance deals ──────────────────────────────────────
    if api and api.getActiveDeals then
        local deals = api.getActiveDeals(farmId) or {}
        if #deals > 0 then
            y = y - FT.py(4)
            y = self:drawRule(y, 0.25)
            y = self:drawSection(y, "FINANCE DEALS")

            local monthly = (api.getMonthlyObligations and api.getMonthlyObligations(farmId)) or {}
            if monthly.grandTotal and monthly.grandTotal > 0 then
                y = self:drawRow(y, "Monthly Total",
                    data:formatMoney(monthly.grandTotal), nil, FT.C.WARNING)
                y = y - FT.py(2)
            end

            for _, deal in ipairs(deals) do
                local itemName  = deal.itemName or "Unknown"
                local balance   = deal.currentBalance or 0
                local monthly2  = deal.monthlyPayment or 0
                local remMonths = deal.remainingMonths or 0

                -- Name
                self.r:appText(x + FT.px(4), y - FT.py(10),
                    FT.FONT.BODY, itemName, RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
                y = y - FT.py(14)

                -- Balance / monthly
                local detailStr = string.format("%s  •  %s/mo  •  %d mo left",
                    data:formatMoney(balance),
                    data:formatMoney(monthly2),
                    remMonths)
                self.r:appText(x + FT.px(4), y - FT.py(8),
                    FT.FONT.TINY, detailStr, RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
                y = y - FT.py(12)
            end
        end
    end

    self:setContentHeight(startY - y + scrollY)
    self:drawScrollBar()
    self:drawInfoIcon("_usedPlusHelp", AC)
end)
