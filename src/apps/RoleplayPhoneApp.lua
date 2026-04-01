-- =========================================================
-- FarmTablet v2 – RoleplayPhone / Invoices App
--
-- PRIMARY MODE: If FS25_RoleplayPhone v0.4.0+ is installed,
--   invoice data is read via its global API functions:
--     RoleplayPhone_checkInstalled()
--     RoleplayPhone_getInvoices(farmId, inboxOnly)
--     RoleplayPhone_sendInvoice(fromFarmId, toFarmId, category, amount, desc)
--     RoleplayPhone_getInvoiceCount(farmId, status)
--     RoleplayPhone_pushNotification(type, message)
--
--   Invoice fields from RoleplayPhone:
--     id, fromFarmId, toFarmId, category, description, notes,
--     amount, status ("PENDING"|"PAID"|"REJECTED"), createdDate, dueDate
--
-- FALLBACK MODE: If the phone mod is not present, the app uses
--   FarmTablet's own FT_InvoiceManager (always available).
-- =========================================================

-- ── Helper: detect RoleplayPhone ──────────────────────────
-- FS25 mod scripts each run in their own Lua environment. Plain globals like
-- `RoleplayPhone_checkInstalled` only resolve within the mod that defined them.
-- To read a global set by *another* mod we must go through getfenv(0), which
-- is the shared engine-level environment visible to all mods.
local function isRoleplayPhoneInstalled()
    local fn = getfenv(0)["RoleplayPhone_checkInstalled"]
    return fn ~= nil and fn()
end

-- Safely call a RoleplayPhone API function by name through the shared env.
local function rpCall(fnName, ...)
    local fn = getfenv(0)[fnName]
    if fn then return fn(...) end
    return nil
end

-- ── Helper: get current farmId ────────────────────────────
local function getMyFarmId()
    if g_currentMission and g_currentMission.player then
        return g_currentMission.player.farmId
    end
    return 1
end

-- ── Form presets (used in fallback / built-in mode) ───────
local PARTY_PRESETS = {
    "Contractor", "Supplier", "Farm Supply", "Grain Elevator",
    "Equipment Dealer", "Municipality", "Bank", "Vet", "Custom",
}

local DESC_PRESETS = {
    "Equipment Rental", "Field Work", "Crop Sale", "Transport",
    "Maintenance", "Consulting", "Service Fee", "Loan Payment",
    "Land Lease", "Animal Care", "Custom",
}

local DUE_OPTIONS = {
    { label = "No due date", days = 0  },
    { label = "7 days",      days = 7  },
    { label = "14 days",     days = 14 },
    { label = "30 days",     days = 30 },
    { label = "60 days",     days = 60 },
    { label = "90 days",     days = 90 },
}

-- ── Party list builder (presets + NPCFavor NPC names) ─────
local function buildPartyList()
    local list = {}
    local npcSystem = g_currentMission and g_currentMission.npcFavorSystem
    if npcSystem and npcSystem.entityManager then
        local ok, npcs = pcall(function()
            return npcSystem.entityManager.getAll and npcSystem.entityManager:getAll() or {}
        end)
        if ok and npcs then
            for _, npc in ipairs(npcs) do
                if npc.name and npc.name ~= "" then
                    table.insert(list, npc.name)
                end
            end
        end
    end
    for _, p in ipairs(PARTY_PRESETS) do
        table.insert(list, p)
    end
    return list
end

-- ── Form initialiser ──────────────────────────────────────
local function initForm(self)
    self._invoiceForm = {
        partyList   = buildPartyList(),
        partyIdx    = 1,
        descIdx     = 1,
        amount      = 0,
        dueIdx      = 1,
    }
end

-- ── Cycler row helper ─────────────────────────────────────
local function drawCycler(self, y, label, value, onChange)
    local x, _, w, _ = self:contentInner()

    self.r:appText(x + FT.px(4), y - FT.py(9),
        FT.FONT.TINY, label, RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - FT.py(13)

    self.r:appRect(x - FT.px(4), y - FT.py(2), w + FT.px(8), FT.py(18), FT.C.BG_CARD)

    local arrowW = FT.px(22)
    local rowH   = FT.py(16)
    local appId  = FT.APP.ROLEPLAY_PHONE

    local btnL = self.r:button(x, y, arrowW, rowH, "◄", FT.C.BTN_NEUTRAL, {
        onClick = function()
            onChange(-1)
            self:switchApp(appId)
        end
    })
    table.insert(self._contentBtns, btnL)

    local valX = x + arrowW + FT.px(6)
    local valW = w - arrowW * 2 - FT.px(12)
    local valStr = tostring(value)
    if #valStr > 26 then valStr = valStr:sub(1, 24) .. "…" end
    self.r:appText(valX + valW * 0.5, y + FT.py(4),
        FT.FONT.BODY, valStr, RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)

    local btnR = self.r:button(x + w - arrowW, y, arrowW, rowH, "►", FT.C.BTN_NEUTRAL, {
        onClick = function()
            onChange(1)
            self:switchApp(appId)
        end
    })
    table.insert(self._contentBtns, btnR)

    return y - FT.py(20)
end

-- ── Amount row ────────────────────────────────────────────
local function drawAmountRow(self, y, amount)
    local x, _, w, _ = self:contentInner()
    local data   = self.system.data
    local appId  = FT.APP.ROLEPLAY_PHONE

    self.r:appText(x + FT.px(4), y - FT.py(9),
        FT.FONT.TINY, "AMOUNT", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - FT.py(13)

    local stepW  = FT.px(30)
    local rowH   = FT.py(16)
    local steps  = { -1000, -100, -10, 10, 100, 1000 }
    local labels = { "-1k", "-100", "-10", "+10", "+100", "+1k" }

    self.r:appRect(x - FT.px(4), y - FT.py(2), w + FT.px(8), FT.py(18), FT.C.BG_CARD)

    local totalStepW = stepW * 3
    local midX = x + totalStepW + FT.px(4)
    local midW = w - totalStepW * 2 - FT.px(8)
    self.r:appText(midX + midW * 0.5, y + FT.py(4),
        FT.FONT.BODY, data:formatMoney(amount),
        RenderText.ALIGN_CENTER,
        amount > 0 and FT.C.TEXT_BRIGHT or FT.C.TEXT_DIM)

    for i, step in ipairs(steps) do
        local bx
        if i <= 3 then
            bx = x + (i - 1) * stepW
        else
            bx = x + w - (7 - i) * stepW
        end
        local stepVal = step
        local btn = self.r:button(bx, y, stepW - FT.px(2), rowH, labels[i], FT.C.BTN_NEUTRAL, {
            onClick = function()
                self._invoiceForm.amount = math.max(0, self._invoiceForm.amount + stepVal)
                self:switchApp(appId)
            end
        })
        table.insert(self._contentBtns, btn)
    end

    return y - FT.py(20)
end

-- ── Invoice creation form (built-in / fallback mode only) ─
local function drawInvoiceForm(self)
    local form  = self._invoiceForm
    local x, _, w, _ = self:contentInner()
    local appId = FT.APP.ROLEPLAY_PHONE

    local y = self:drawAppHeader("New Invoice", "Built-in")
    y = y - FT.py(4)

    local partyList = form.partyList
    local partyVal  = partyList[form.partyIdx] or "—"
    if partyVal == "Custom" then partyVal = "Custom (set via console)" end
    y = drawCycler(self, y, "PARTY", partyVal, function(dir)
        form.partyIdx = ((form.partyIdx - 1 + dir + #partyList) % #partyList) + 1
    end)
    y = y - FT.py(4)

    local descVal = DESC_PRESETS[form.descIdx] or "—"
    if descVal == "Custom" then descVal = "Custom (set via console)" end
    y = drawCycler(self, y, "DESCRIPTION", descVal, function(dir)
        form.descIdx = ((form.descIdx - 1 + dir + #DESC_PRESETS) % #DESC_PRESETS) + 1
    end)
    y = y - FT.py(4)

    y = drawAmountRow(self, y, form.amount)
    y = y - FT.py(4)

    local dueOpt = DUE_OPTIONS[form.dueIdx] or DUE_OPTIONS[1]
    y = drawCycler(self, y, "DUE DATE", dueOpt.label, function(dir)
        form.dueIdx = ((form.dueIdx - 1 + dir + #DUE_OPTIONS) % #DUE_OPTIONS) + 1
    end)

    y = y - FT.py(6)
    y = self:drawRule(y, 0.3)
    y = y - FT.py(4)

    local btnH  = FT.py(20)
    local halfW = (w - FT.px(8)) * 0.5

    local btnCancel = self.r:button(x, y, halfW, btnH, "CANCEL", FT.C.BTN_NEUTRAL, {
        onClick = function()
            self._invoiceFormOpen = false
            self._invoiceForm     = nil
            self:switchApp(appId)
        end
    })
    table.insert(self._contentBtns, btnCancel)

    local canCreate   = form.amount > 0
    local createColor = canCreate and FT.C.BTN_PRIMARY or FT.C.BTN_NEUTRAL
    local btnCreate = self.r:button(x + halfW + FT.px(8), y, halfW, btnH, "CREATE", createColor, {
        onClick = function()
            if not canCreate then return end
            local invoiceMgr = g_currentMission and g_currentMission.ftInvoiceManager
            if invoiceMgr then
                local today  = (g_currentMission and g_currentMission.environment and g_currentMission.environment.currentDay) or 0
                local dueDay = dueOpt.days > 0 and (today + dueOpt.days) or 0
                local party  = partyList[form.partyIdx] or ""
                if party == "Custom (set via console)" then party = "Custom" end
                local desc = DESC_PRESETS[form.descIdx] or ""
                if desc == "Custom (set via console)" then desc = "Custom" end
                invoiceMgr:addInvoice({
                    invoiceType = FT_InvoiceManager.TYPE.OUTGOING,
                    party       = party,
                    description = desc,
                    amount      = form.amount,
                    status      = FT_InvoiceManager.STATUS.PENDING,
                    dueDay      = dueDay,
                })
                invoiceMgr:save()
            end
            self._invoiceFormOpen = false
            self._invoiceForm     = nil
            self:switchApp(appId)
        end
    })
    table.insert(self._contentBtns, btnCreate)

    if not canCreate then
        self.r:appText(x + FT.px(4), y - btnH - FT.py(4),
            FT.FONT.TINY, "Set an amount greater than 0 to create.",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    end
end

-- =========================================================
-- Normalise a RoleplayPhone invoice into the shared shape.
--
-- RP field mapping:
--   inv.fromFarmId / inv.toFarmId  → determines inbox/outbox from our farmId
--   inv.category                   → used as "party" display label
--   inv.description                → description
--   inv.amount                     → amount
--   inv.status                     → "PENDING" | "PAID" | "REJECTED"
--   inv.createdDate                → createdDay (game day integer)
--   inv.dueDate                    → string or empty
-- =========================================================
local function normaliseRPInvoice(inv, myFarmId)
    local isIncoming = (inv.toFarmId == myFarmId)
    local rawStatus  = (inv.status or "PENDING"):upper()

    local ftStatus
    if rawStatus == "PAID"     then ftStatus = FT_InvoiceManager.STATUS.PAID
    elseif rawStatus == "REJECTED" then ftStatus = "rejected"
    else   ftStatus = FT_InvoiceManager.STATUS.PENDING
    end

    return {
        id          = inv.id,
        invoiceType = isIncoming and FT_InvoiceManager.TYPE.INCOMING or FT_InvoiceManager.TYPE.OUTGOING,
        party       = inv.category or "Unknown",
        description = inv.description or "",
        amount      = tonumber(inv.amount) or 0,
        status      = ftStatus,
        rawStatus   = rawStatus,
        createdDay  = tonumber(inv.createdDate) or 0,
        dueDay      = 0,
        dueDateStr  = (inv.dueDate and inv.dueDate ~= "") and inv.dueDate or nil,
        fromFarmId  = inv.fromFarmId,
        toFarmId    = inv.toFarmId,
        isRPInvoice = true,
    }
end

-- =========================================================
-- Main drawer
-- =========================================================
FarmTabletUI:registerDrawer(FT.APP.ROLEPLAY_PHONE, function(self)
    local AC = FT.appColor(FT.APP.ROLEPLAY_PHONE)

    -- ── Sub-view: invoice creation form (built-in only) ──
    if self._invoiceFormOpen then
        drawInvoiceForm(self)
        return
    end

    -- ── Sub-view: help page ───────────────────────────────
    if self:drawHelpPage("_rpPhoneHelp", FT.APP.ROLEPLAY_PHONE, "Invoices", AC, {
        { title = "INVOICE TRACKER",
          body  = "Tracks money you owe others (OUTGOING) and\n" ..
                  "money others owe you (INCOMING).\n" ..
                  "Statuses: PENDING, PAID, OVERDUE / REJECTED." },
        { title = "ROLEPLAY PHONE INTEGRATION",
          body  = "If FS25_RoleplayPhone v0.4.0+ is installed,\n" ..
                  "invoices created on the phone appear here\n" ..
                  "automatically via its public API.\n" ..
                  "Without it, use the built-in invoice system." },
        { title = "SUMMARY BAR",
          body  = "Top of the app shows total receivable (green)\n" ..
                  "and total owed (red) across all pending invoices." },
        { title = "NEW INVOICE",
          body  = "Tap + NEW to open the creation form.\n" ..
                  "Only available in built-in mode.\n" ..
                  "Use the RoleplayPhone app to create invoices\n" ..
                  "when that mod is installed." },
    }) then return end

    -- ── Detect data source ────────────────────────────────
    local usingPhone = isRoleplayPhoneInstalled()
    local invoiceMgr = g_currentMission and g_currentMission.ftInvoiceManager
    local myFarmId   = getMyFarmId()

    -- ── Resolve invoice lists ─────────────────────────────
    local incoming, outgoing = {}, {}
    local totalOwed, totalReceivable = 0, 0

    if usingPhone then
        -- RoleplayPhone_getInvoices(farmId, inboxOnly)
        --   true  → invoices sent TO myFarmId (our inbox)
        --   false → all invoices involving myFarmId
        local allIncoming = rpCall("RoleplayPhone_getInvoices", myFarmId, true) or {}
        for _, inv in ipairs(allIncoming) do
            local norm = normaliseRPInvoice(inv, myFarmId)
            table.insert(incoming, norm)
            if norm.status ~= FT_InvoiceManager.STATUS.PAID and norm.rawStatus ~= "REJECTED" then
                totalReceivable = totalReceivable + norm.amount
            end
        end

        -- Outgoing: all involving us, minus those already in inbox
        local allInvolved = rpCall("RoleplayPhone_getInvoices", myFarmId, false) or {}
        for _, inv in ipairs(allInvolved) do
            if inv.toFarmId ~= myFarmId then
                local norm = normaliseRPInvoice(inv, myFarmId)
                table.insert(outgoing, norm)
                if norm.status ~= FT_InvoiceManager.STATUS.PAID and norm.rawStatus ~= "REJECTED" then
                    totalOwed = totalOwed + norm.amount
                end
            end
        end

    elseif invoiceMgr then
        incoming = invoiceMgr:getByType(FT_InvoiceManager.TYPE.INCOMING)
        outgoing = invoiceMgr:getByType(FT_InvoiceManager.TYPE.OUTGOING)
        totalOwed, totalReceivable = invoiceMgr:getTotals()
    end

    -- ── Header + summary bar ──────────────────────────────
    local data   = self.system.data
    local startY = self:drawAppHeader("Invoices", usingPhone and "RoleplayPhone" or "Built-in")
    local x, contentY, w, _ = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y = startY + scrollY

    self.r:appText(x + FT.px(4), y - FT.py(8),
        FT.FONT.TINY, "RECEIVABLE", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    self.r:appText(x + FT.px(4), y - FT.py(19),
        FT.FONT.BODY, data:formatMoney(totalReceivable),
        RenderText.ALIGN_LEFT, FT.C.POSITIVE)

    self.r:appText(x + w - FT.px(4), y - FT.py(8),
        FT.FONT.TINY, "OWED", RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
    self.r:appText(x + w - FT.px(4), y - FT.py(19),
        FT.FONT.BODY, data:formatMoney(totalOwed),
        RenderText.ALIGN_RIGHT,
        totalOwed > 0 and FT.C.NEGATIVE or FT.C.TEXT_DIM)

    y = y - FT.py(28)
    y = self:drawRule(y, 0.3)

    -- ── Invoice list renderer ─────────────────────────────
    local function drawInvoiceList(title, list)
        if #list == 0 then return end
        y = self:drawSection(y, title)
        local appId = FT.APP.ROLEPLAY_PHONE

        for _, inv in ipairs(list) do
            local status     = inv.status or FT_InvoiceManager.STATUS.PENDING
            local rawStatus  = inv.rawStatus or status:upper()
            local isPaid     = (status == FT_InvoiceManager.STATUS.PAID or rawStatus == "PAID")
            local isRejected = (rawStatus == "REJECTED")
            local isOverdue  = (status == FT_InvoiceManager.STATUS.OVERDUE)
            local isActive   = not isPaid and not isRejected

            -- Due date display
            local hasDue, dueStr, dueColor = false, nil, FT.C.TEXT_DIM
            if inv.dueDateStr then
                hasDue  = true
                dueStr  = "Due: " .. inv.dueDateStr
            elseif (inv.dueDay or 0) > 0 then
                hasDue = true
                local today    = (g_currentMission and g_currentMission.environment
                                  and g_currentMission.environment.currentDay) or 0
                local daysLeft = inv.dueDay - today
                if daysLeft < 0 then
                    dueStr   = string.format("Overdue by %d day%s", -daysLeft, -daysLeft ~= 1 and "s" or "")
                    dueColor = FT.C.NEGATIVE
                elseif daysLeft == 0 then
                    dueStr   = "Due today"
                    dueColor = FT.C.WARNING
                else
                    dueStr   = string.format("Due in %d day%s", daysLeft, daysLeft ~= 1 and "s" or "")
                    dueColor = daysLeft <= 3 and FT.C.WARNING or FT.C.TEXT_DIM
                end
            end

            -- Badge
            local badgeColor, statusLabel
            if isPaid then
                badgeColor, statusLabel = FT.C.POSITIVE, "PAID"
            elseif isRejected then
                badgeColor, statusLabel = FT.C.NEGATIVE, "REJECTED"
            elseif isOverdue then
                badgeColor, statusLabel = FT.C.NEGATIVE, "OVERDUE"
            else
                badgeColor, statusLabel = FT.C.WARNING, "PENDING"
            end

            -- Card geometry
            local cardH, line1Y, line2Y, dueLineY
            if hasDue then
                cardH    = FT.py(56)
                line1Y   = y + FT.py(44)
                line2Y   = y + FT.py(32)
                dueLineY = y + FT.py(20)
            else
                cardH  = FT.py(44)
                line1Y = y + FT.py(34)
                line2Y = y + FT.py(22)
            end

            self.r:appRect(x - FT.px(4), y - FT.py(4), w + FT.px(8), cardH, FT.C.BG_CARD)

            -- Line 1: party + badge
            local party = (inv.party and inv.party ~= "") and inv.party or "Unknown"
            self.r:appText(x + FT.px(4), line1Y,
                FT.FONT.BODY, party, RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)
            self.r:appText(x + w - FT.px(4), line1Y,
                FT.FONT.TINY, statusLabel, RenderText.ALIGN_RIGHT, badgeColor)

            -- Line 2: description + amount
            local desc = inv.description or ""
            if #desc > 38 then desc = desc:sub(1, 36) .. "…" end
            self.r:appText(x + FT.px(4), line2Y,
                FT.FONT.SMALL, desc, RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            self.r:appText(x + w - FT.px(4), line2Y,
                FT.FONT.SMALL, data:formatMoney(inv.amount or 0),
                RenderText.ALIGN_RIGHT, FT.C.TEXT_NORMAL)

            -- Line 3: due date
            if hasDue and dueStr then
                self.r:appText(x + FT.px(4), dueLineY,
                    FT.FONT.TINY, dueStr, RenderText.ALIGN_LEFT, dueColor)
            end

            -- Action buttons
            local btnH = FT.py(14)
            local btnY = y + FT.py(2)
            local invId = inv.id

            if isActive then
                if inv.isRPInvoice then
                    -- Read-only in RP mode; direct player to the phone app
                    self.r:appText(x + FT.px(4), btnY + FT.py(10),
                        FT.FONT.TINY, "Manage via RoleplayPhone app",
                        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
                else
                    local gap  = FT.px(6)
                    local btnW = (w - gap) * 0.5
                    local btnPay = self.r:button(x, btnY, btnW, btnH, "PAY",
                        FT.C.BTN_PRIMARY, {
                            onClick = function()
                                local mgr = g_currentMission and g_currentMission.ftInvoiceManager
                                if mgr then mgr:updateStatus(invId, FT_InvoiceManager.STATUS.PAID); mgr:save() end
                                self:switchApp(appId)
                            end
                        })
                    local btnCancel = self.r:button(x + btnW + gap, btnY, btnW, btnH, "CANCEL",
                        FT.C.BTN_DANGER, {
                            onClick = function()
                                local mgr = g_currentMission and g_currentMission.ftInvoiceManager
                                if mgr then mgr:deleteInvoice(invId); mgr:save() end
                                self:switchApp(appId)
                            end
                        })
                    table.insert(self._contentBtns, btnPay)
                    table.insert(self._contentBtns, btnCancel)
                end
            else
                -- Paid / rejected – DELETE only in built-in mode
                if not inv.isRPInvoice then
                    local delW   = FT.px(60)
                    local btnDel = self.r:button(x + w - delW, btnY, delW, btnH, "DELETE",
                        FT.C.BTN_NEUTRAL, {
                            onClick = function()
                                local mgr = g_currentMission and g_currentMission.ftInvoiceManager
                                if mgr then mgr:deleteInvoice(invId); mgr:save() end
                                self:switchApp(appId)
                            end
                        })
                    table.insert(self._contentBtns, btnDel)
                end
            end

            y = y - cardH - FT.py(6)
        end
    end

    drawInvoiceList("INCOMING  (money owed to you)", incoming)

    if #incoming > 0 and #outgoing > 0 then
        y = y - FT.py(4)
        y = self:drawRule(y, 0.2)
    end

    drawInvoiceList("OUTGOING  (money you owe)", outgoing)

    -- ── Empty state ───────────────────────────────────────
    if #incoming == 0 and #outgoing == 0 then
        self.r:appText(x + FT.px(4), y - FT.py(14),
            FT.FONT.BODY, "No invoices yet.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        if usingPhone then
            self.r:appText(x + FT.px(4), y - FT.py(28),
                FT.FONT.SMALL, "Create invoices via the RoleplayPhone app.",
                RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        else
            self.r:appText(x + FT.px(4), y - FT.py(28),
                FT.FONT.SMALL, "Use + NEW to create your first invoice.",
                RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        end
        y = y - FT.py(36)
    end

    -- ── Bottom chrome: + NEW button (built-in mode only) ──
    if not usingPhone and invoiceMgr then
        local _, cY, _, _ = self:contentInner()
        local iSz  = FT.px(18)
        local gap  = FT.px(4)
        local btnW = FT.px(60)
        local newBtn = self.r:button(
            x + w - iSz - gap - btnW, cY,
            btnW, iSz,
            "+ NEW", FT.C.BTN_PRIMARY,
            { onClick = function()
                initForm(self)
                self._invoiceFormOpen = true
                self:switchApp(FT.APP.ROLEPLAY_PHONE)
            end }
        )
        table.insert(self._contentBtns, newBtn)
    end

    self:setContentHeight(startY - y + scrollY)
    self:drawScrollBar()
    self:drawInfoIcon("_rpPhoneHelp", AC)
end)
