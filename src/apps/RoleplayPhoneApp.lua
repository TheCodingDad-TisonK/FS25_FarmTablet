-- =========================================================
-- FarmTablet v2 – RoleplayPhone / Invoices App
--
-- PRIMARY MODE: If FS25_RoleplayPhone is installed and exposes
--   g_currentMission.roleplayPhoneAPI, invoice data is read
--   from that API.
--
-- FALLBACK MODE: If the phone mod is not present, the app uses
--   FarmTablet's own FT_InvoiceManager (always available).
--
-- TODO: Verify actual FS25_RoleplayPhone API shape once the
--   mod author publishes their API. Update _resolveInvoices()
--   when the real API lands.
-- =========================================================

-- ── Form presets ──────────────────────────────────────────
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

local AMOUNT_STEPS = { -1000, -100, -10, 10, 100, 1000 }

-- ── Party list builder (presets + NPCFavor NPC names) ─────
local function buildPartyList()
    local list = {}
    -- Inject NPC names from NPCFavor if installed
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
    -- Append generic presets
    for _, p in ipairs(PARTY_PRESETS) do
        table.insert(list, p)
    end
    return list
end

-- ── Form initialiser ──────────────────────────────────────
local function initForm(self)
    self._invoiceForm = {
        invoiceType = FT_InvoiceManager.TYPE.OUTGOING,
        partyList   = buildPartyList(),
        partyIdx    = 1,
        descIdx     = 1,
        amount      = 0,
        dueIdx      = 1,   -- index into DUE_OPTIONS
    }
end

-- ── Cycler row helper ─────────────────────────────────────
-- Draws:  LABEL
--         [◄]  current value  [►]
-- Arrow buttons call onChange(-1) / onChange(+1) then switchApp.
local function drawCycler(self, y, label, value, onChange)
    local x, _, w, _ = self:contentInner()
    local AC = FT.appColor(FT.APP.ROLEPLAY_PHONE)

    -- Label
    self.r:appText(x + FT.px(4), y - FT.py(9),
        FT.FONT.TINY, label, RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - FT.py(13)

    -- Row background
    self.r:appRect(x - FT.px(4), y - FT.py(2), w + FT.px(8), FT.py(18), FT.C.BG_CARD)

    -- Left arrow button
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

    -- Value label (centered between arrows)
    local valX = x + arrowW + FT.px(6)
    local valW = w - arrowW * 2 - FT.px(12)
    local valStr = tostring(value)
    if #valStr > 26 then valStr = valStr:sub(1, 24) .. "…" end
    self.r:appText(valX + valW * 0.5, y + FT.py(4),
        FT.FONT.BODY, valStr, RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)

    -- Right arrow button
    local btnR = self.r:button(x + w - arrowW, y, arrowW, rowH, "►", FT.C.BTN_NEUTRAL, {
        onClick = function()
            onChange(1)
            self:switchApp(appId)
        end
    })
    table.insert(self._contentBtns, btnR)

    return y - FT.py(20)  -- next Y
end

-- ── Type toggle row ───────────────────────────────────────
local function drawTypeToggle(self, y, currentType)
    local x, _, w, _ = self:contentInner()
    local appId = FT.APP.ROLEPLAY_PHONE

    self.r:appText(x + FT.px(4), y - FT.py(9),
        FT.FONT.TINY, "TYPE", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - FT.py(13)

    local halfW = (w - FT.px(4)) * 0.5
    local rowH  = FT.py(16)

    local isIn  = (currentType == FT_InvoiceManager.TYPE.INCOMING)
    local isOut = (currentType == FT_InvoiceManager.TYPE.OUTGOING)

    local inColor  = isIn  and FT.C.BTN_ACTIVE or FT.C.BTN_NEUTRAL
    local outColor = isOut and FT.C.BTN_ACTIVE or FT.C.BTN_NEUTRAL

    local btnIn = self.r:button(x, y, halfW, rowH, "INCOMING", inColor, {
        onClick = function()
            self._invoiceForm.invoiceType = FT_InvoiceManager.TYPE.INCOMING
            self:switchApp(appId)
        end
    })
    local btnOut = self.r:button(x + halfW + FT.px(4), y, halfW, rowH, "OUTGOING", outColor, {
        onClick = function()
            self._invoiceForm.invoiceType = FT_InvoiceManager.TYPE.OUTGOING
            self:switchApp(appId)
        end
    })
    table.insert(self._contentBtns, btnIn)
    table.insert(self._contentBtns, btnOut)

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

    -- Step buttons: 3 negative, amount display, 3 positive
    local stepW = FT.px(30)
    local rowH  = FT.py(16)
    local steps = { -1000, -100, -10, 10, 100, 1000 }
    local labels = { "-1k", "-100", "-10", "+10", "+100", "+1k" }

    -- Background
    self.r:appRect(x - FT.px(4), y - FT.py(2), w + FT.px(8), FT.py(18), FT.C.BG_CARD)

    -- Amount display (center)
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

-- ── Invoice creation form sub-view ───────────────────────
local function drawInvoiceForm(self)
    local AC      = FT.appColor(FT.APP.ROLEPLAY_PHONE)
    local form    = self._invoiceForm
    local x, contentY, w, _ = self:contentInner()
    local appId   = FT.APP.ROLEPLAY_PHONE

    -- Header
    local y = self:drawAppHeader("New Invoice", "Built-in")
    y = y - FT.py(4)

    -- ── Type toggle ───────────────────────────────────────
    y = drawTypeToggle(self, y, form.invoiceType)
    y = y - FT.py(4)

    -- ── Party cycler ──────────────────────────────────────
    local partyList = form.partyList
    local partyVal  = partyList[form.partyIdx] or "—"
    -- annotate "Custom" since text entry isn't available yet
    if partyVal == "Custom" then partyVal = "Custom (set via console)" end
    y = drawCycler(self, y, "PARTY", partyVal, function(dir)
        form.partyIdx = ((form.partyIdx - 1 + dir + #partyList) % #partyList) + 1
    end)
    y = y - FT.py(4)

    -- ── Description cycler ────────────────────────────────
    local descVal = DESC_PRESETS[form.descIdx] or "—"
    if descVal == "Custom" then descVal = "Custom (set via console)" end
    y = drawCycler(self, y, "DESCRIPTION", descVal, function(dir)
        form.descIdx = ((form.descIdx - 1 + dir + #DESC_PRESETS) % #DESC_PRESETS) + 1
    end)
    y = y - FT.py(4)

    -- ── Amount ────────────────────────────────────────────
    y = drawAmountRow(self, y, form.amount)
    y = y - FT.py(4)

    -- ── Due date cycler ───────────────────────────────────
    local dueOpt = DUE_OPTIONS[form.dueIdx] or DUE_OPTIONS[1]
    y = drawCycler(self, y, "DUE DATE", dueOpt.label, function(dir)
        form.dueIdx = ((form.dueIdx - 1 + dir + #DUE_OPTIONS) % #DUE_OPTIONS) + 1
    end)

    y = y - FT.py(6)
    y = self:drawRule(y, 0.3)
    y = y - FT.py(4)

    -- ── CANCEL / CREATE ───────────────────────────────────
    local btnH = FT.py(20)
    local halfW = (w - FT.px(8)) * 0.5

    local btnCancel = self.r:button(x, y, halfW, btnH, "CANCEL", FT.C.BTN_NEUTRAL, {
        onClick = function()
            self._invoiceFormOpen = false
            self._invoiceForm     = nil
            self:switchApp(appId)
        end
    })
    table.insert(self._contentBtns, btnCancel)

    -- Validate: amount must be > 0 to create
    local canCreate = form.amount > 0
    local createColor = canCreate and FT.C.BTN_PRIMARY or FT.C.BTN_NEUTRAL
    local btnCreate = self.r:button(x + halfW + FT.px(8), y, halfW, btnH, "CREATE", createColor, {
        onClick = function()
            if not canCreate then return end
            local invoiceMgr = g_currentMission and g_currentMission.ftInvoiceManager
            if invoiceMgr then
                local today = (g_currentMission and g_currentMission.environment and g_currentMission.environment.currentDay) or 0
                local dueDay = dueOpt.days > 0 and (today + dueOpt.days) or 0
                local party = partyList[form.partyIdx] or ""
                if party == "Custom (set via console)" then party = "Custom" end
                local desc = DESC_PRESETS[form.descIdx] or ""
                if desc == "Custom (set via console)" then desc = "Custom" end
                invoiceMgr:addInvoice({
                    invoiceType = form.invoiceType,
                    party       = party,
                    description = desc,
                    amount      = form.amount,
                    status      = FT_InvoiceManager.STATUS.PENDING,
                    dueDay      = dueDay,
                })
                -- Persist immediately
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
-- Main drawer
-- =========================================================
FarmTabletUI:registerDrawer(FT.APP.ROLEPLAY_PHONE, function(self)
    local AC = FT.appColor(FT.APP.ROLEPLAY_PHONE)

    -- ── Sub-view: invoice creation form ──────────────────
    if self._invoiceFormOpen then
        drawInvoiceForm(self)
        return
    end

    -- ── Sub-view: help page ───────────────────────────────
    if self:drawHelpPage("_rpPhoneHelp", FT.APP.ROLEPLAY_PHONE, "Invoices", AC, {
        { title = "INVOICE TRACKER",
          body  = "Tracks money you owe others (OUTGOING) and\n" ..
                  "money others owe you (INCOMING).\n" ..
                  "Statuses: PENDING, PAID, OVERDUE." },
        { title = "ROLEPLAY PHONE INTEGRATION",
          body  = "If FS25_RoleplayPhone is installed, invoices\n" ..
                  "created on the phone appear here automatically.\n" ..
                  "Without it, use the built-in invoice system." },
        { title = "SUMMARY BAR",
          body  = "Top of the app shows total receivable (green)\n" ..
                  "and total owed (red) across all pending/overdue\n" ..
                  "invoices." },
        { title = "NEW INVOICE",
          body  = "Tap + NEW to open the creation form.\n" ..
                  "Party and description cycle through presets.\n" ..
                  "Amount uses step buttons (+10 / +100 / +1k etc).\n" ..
                  "Custom names can be set after creation." },
    }) then return end

    -- ── Detect data source ────────────────────────────────
    -- TODO: replace "roleplayPhoneAPI" with the actual field name set by FS25_RoleplayPhone
    local phoneAPI   = g_currentMission and g_currentMission.roleplayPhoneAPI
    local invoiceMgr = g_currentMission and g_currentMission.ftInvoiceManager
    local usingPhone = (phoneAPI ~= nil)

    -- ── Resolve invoice lists ─────────────────────────────
    local incoming, outgoing, totalOwed, totalReceivable

    if usingPhone then
        -- TODO: update once FS25_RoleplayPhone API is published.
        incoming = (phoneAPI.getInvoices and phoneAPI.getInvoices("incoming")) or {}
        outgoing = (phoneAPI.getInvoices and phoneAPI.getInvoices("outgoing")) or {}
        totalOwed, totalReceivable = 0, 0
        for _, inv in ipairs(outgoing) do
            if inv.status ~= "paid" then totalOwed = totalOwed + (inv.amount or 0) end
        end
        for _, inv in ipairs(incoming) do
            if inv.status ~= "paid" then totalReceivable = totalReceivable + (inv.amount or 0) end
        end
    elseif invoiceMgr then
        incoming = invoiceMgr:getByType(FT_InvoiceManager.TYPE.INCOMING)
        outgoing = invoiceMgr:getByType(FT_InvoiceManager.TYPE.OUTGOING)
        totalOwed, totalReceivable = invoiceMgr:getTotals()
    else
        incoming, outgoing, totalOwed, totalReceivable = {}, {}, 0, 0
    end

    -- ── Header + summary bar ──────────────────────────────
    local data   = self.system.data
    local startY = self:drawAppHeader("Invoices", usingPhone and "RoleplayPhone" or "Built-in")
    local x, contentY, w, _ = self:contentInner()
    local y = startY

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

    -- ── + NEW button (built-in mode only) ─────────────────
    if not usingPhone and invoiceMgr then
        local btnW = FT.px(80)
        local btn = self.r:button(
            x + w - btnW - FT.px(2), y - FT.py(16),
            btnW, FT.py(14),
            "+ NEW", FT.C.BTN_PRIMARY,
            { onClick = function()
                initForm(self)
                self._invoiceFormOpen = true
                self:switchApp(FT.APP.ROLEPLAY_PHONE)
            end }
        )
        table.insert(self._contentBtns, btn)
        y = y - FT.py(18)
    end

    -- ── Invoice list renderer (shared for both sections) ──
    -- y = bottom anchor of each row (same convention as AppStoreApp).
    -- Card bottom = y - py(4); text lines sit ABOVE y; buttons at y + py(2).
    local function drawInvoiceList(title, list)
        if #list == 0 then return end
        y = self:drawSection(y, title)
        local appId = FT.APP.ROLEPLAY_PHONE
        for _, inv in ipairs(list) do
            local status    = inv.status or FT_InvoiceManager.STATUS.PENDING
            local isPaid    = (status == FT_InvoiceManager.STATUS.PAID    or status == "paid")
            local isOverdue = (status == FT_InvoiceManager.STATUS.OVERDUE or status == "overdue")
            local isActive  = not isPaid
            local hasDue    = (inv.dueDay or 0) > 0

            -- Badge color
            local badgeColor = FT.C.WARNING
            if isPaid        then badgeColor = FT.C.POSITIVE
            elseif isOverdue then badgeColor = FT.C.NEGATIVE end
            local statusLabel = status:upper()

            -- Card height + text-line baselines (all relative to y = bottom anchor)
            -- Active rows  : PAY + CANCEL buttons at y+py(2), height py(14)
            -- Paid rows    : display only, no buttons
            local cardH, line1Y, line2Y, dueY
            if isActive then
                if hasDue then
                    cardH  = FT.py(56)
                    line1Y = y + FT.py(44)
                    line2Y = y + FT.py(32)
                    dueY   = y + FT.py(20)
                else
                    cardH  = FT.py(44)
                    line1Y = y + FT.py(34)
                    line2Y = y + FT.py(22)
                end
            else
                if hasDue then
                    cardH  = FT.py(42)
                    line1Y = y + FT.py(26)
                    line2Y = y + FT.py(14)
                    dueY   = y + FT.py(2)
                else
                    cardH  = FT.py(30)
                    line1Y = y + FT.py(14)
                    line2Y = y + FT.py(2)
                end
            end

            -- Card background
            self.r:appRect(x - FT.px(4), y - FT.py(4), w + FT.px(8), cardH, FT.C.BG_CARD)

            -- Line 1: party name (left) + status badge (right)
            local party = (inv.party and inv.party ~= "") and inv.party or "Unknown"
            self.r:appText(x + FT.px(4), line1Y,
                FT.FONT.BODY, party, RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)
            self.r:appText(x + w - FT.px(4), line1Y,
                FT.FONT.TINY, statusLabel, RenderText.ALIGN_RIGHT, badgeColor)

            -- Line 2: description (left) + amount (right)
            local desc = inv.description or ""
            if #desc > 38 then desc = desc:sub(1, 36) .. "…" end
            self.r:appText(x + FT.px(4), line2Y,
                FT.FONT.SMALL, desc, RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            self.r:appText(x + w - FT.px(4), line2Y,
                FT.FONT.SMALL, data:formatMoney(inv.amount or 0),
                RenderText.ALIGN_RIGHT, FT.C.TEXT_NORMAL)

            -- Line 3: due date (if set)
            if hasDue then
                local today = (g_currentMission and g_currentMission.environment
                               and g_currentMission.environment.currentDay) or 0
                local daysLeft = inv.dueDay - today
                local dueStr
                if daysLeft < 0 then
                    dueStr = string.format("Overdue by %d day%s", -daysLeft, -daysLeft ~= 1 and "s" or "")
                elseif daysLeft == 0 then
                    dueStr = "Due today"
                else
                    dueStr = string.format("Due in %d day%s", daysLeft, daysLeft ~= 1 and "s" or "")
                end
                local dueColor = daysLeft < 0 and FT.C.NEGATIVE
                                 or (daysLeft <= 3 and FT.C.WARNING or FT.C.TEXT_DIM)
                self.r:appText(x + FT.px(4), dueY,
                    FT.FONT.TINY, dueStr, RenderText.ALIGN_LEFT, dueColor)
            end

            -- Action buttons (pending / overdue only)
            if isActive then
                local btnH  = FT.py(14)
                local btnY  = y + FT.py(2)
                local gap   = FT.px(6)
                local btnW  = (w - gap) * 0.5
                local invId = inv.id
                local btnPay = self.r:button(x, btnY, btnW, btnH, "PAY",
                    FT.C.BTN_PRIMARY, {
                        onClick = function()
                            local mgr = g_currentMission and g_currentMission.ftInvoiceManager
                            if mgr then
                                mgr:updateStatus(invId, FT_InvoiceManager.STATUS.PAID)
                                mgr:save()
                            end
                            self:switchApp(appId)
                        end
                    })
                local btnCancel = self.r:button(x + btnW + gap, btnY, btnW, btnH, "CANCEL",
                    FT.C.BTN_DANGER, {
                        onClick = function()
                            local mgr = g_currentMission and g_currentMission.ftInvoiceManager
                            if mgr then
                                mgr:deleteInvoice(invId)
                                mgr:save()
                            end
                            self:switchApp(appId)
                        end
                    })
                table.insert(self._contentBtns, btnPay)
                table.insert(self._contentBtns, btnCancel)
            end

            -- Advance y cursor past this card + gap
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
        if not usingPhone then
            self.r:appText(x + FT.px(4), y - FT.py(28),
                FT.FONT.SMALL, "Use + NEW to create your first invoice.",
                RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        end
        y = y - FT.py(36)
    end

    self:drawInfoIcon("_rpPhoneHelp", AC)
end)
