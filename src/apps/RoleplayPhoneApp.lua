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
--   mod author publishes their API. The adapter block below is
--   written against the anticipated interface. Update the
--   _getPhoneInvoices() function when the real API lands.
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.ROLEPLAY_PHONE, function(self)
    local AC = FT.appColor(FT.APP.ROLEPLAY_PHONE)

    -- Help sub-page
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
          body  = "The NEW button opens the invoice creation dialog.\n" ..
                  "If RoleplayPhone is installed the phone's own\n" ..
                  "creation flow is used instead." },
    }) then return end

    -- ── Detect data source ────────────────────────────────

    -- TODO: replace "roleplayPhoneAPI" with the actual field name set by FS25_RoleplayPhone
    local phoneAPI     = g_currentMission and g_currentMission.roleplayPhoneAPI
    local invoiceMgr   = g_currentMission and g_currentMission.ftInvoiceManager
    local usingPhone   = (phoneAPI ~= nil)

    -- ── Resolve invoice lists ─────────────────────────────

    local incoming, outgoing, totalOwed, totalReceivable

    if usingPhone then
        -- TODO: update these calls once FS25_RoleplayPhone API is published.
        -- Anticipated shape: phoneAPI.getInvoices(type) -> array of invoice tables
        --   invoice: { party, description, amount, status, createdDay, dueDay }
        incoming = (phoneAPI.getInvoices and phoneAPI.getInvoices("incoming")) or {}
        outgoing = (phoneAPI.getInvoices and phoneAPI.getInvoices("outgoing")) or {}
        -- TODO: phone may expose its own totals API
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

    -- ── Layout ────────────────────────────────────────────
    local data = self.system.data
    local startY = self:drawAppHeader("Invoices", usingPhone and "RoleplayPhone" or "Built-in")
    local x, contentY, w, _ = self:contentInner()
    local y = startY

    -- ── Summary bar ───────────────────────────────────────
    -- Left: receivable (green), Right: owed (red)
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

    -- ── New Invoice button (built-in mode only) ───────────
    if not usingPhone and invoiceMgr then
        local btnW = FT.px(80)
        local btn = self.r:button(
            x + w - btnW - FT.px(2), y - FT.py(16),
            btnW, FT.py(14),
            "+ NEW", FT.C.BTN_PRIMARY,
            { onClick = function()
                -- TODO: open InvoiceCreationDialog when it is built.
                -- For now, show a placeholder notification.
                if g_FarmTablet then
                    g_FarmTablet:showNotification("Invoices", "Invoice creation dialog coming soon!")
                end
            end }
        )
        table.insert(self._contentBtns, btn)
        y = y - FT.py(18)
    end

    -- ── Helper: draw a section of invoices ────────────────
    local function drawInvoiceList(title, list)
        if #list == 0 then return end

        y = self:drawSection(y, title)

        for _, inv in ipairs(list) do
            -- Row background
            self.r:appRect(x - FT.px(4), y - FT.py(4), w + FT.px(8), FT.py(34), FT.C.BG_CARD)

            -- Status badge color
            local badgeColor = FT.C.WARNING
            local statusLabel = (inv.status or "pending"):upper()
            if inv.status == FT_InvoiceManager.STATUS.PAID or inv.status == "paid" then
                badgeColor  = FT.C.POSITIVE
            elseif inv.status == FT_InvoiceManager.STATUS.OVERDUE or inv.status == "overdue" then
                badgeColor  = FT.C.NEGATIVE
            end

            -- Party name (top-left)
            local party = inv.party ~= "" and inv.party or "Unknown"
            self.r:appText(x + FT.px(4), y - FT.py(10),
                FT.FONT.BODY, party, RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)

            -- Status badge (top-right)
            self.r:appText(x + w - FT.px(4), y - FT.py(10),
                FT.FONT.TINY, statusLabel, RenderText.ALIGN_RIGHT, badgeColor)

            y = y - FT.py(14)

            -- Description (bottom-left, truncated)
            local desc = inv.description or ""
            if #desc > 38 then desc = desc:sub(1, 36) .. "…" end
            self.r:appText(x + FT.px(4), y - FT.py(8),
                FT.FONT.SMALL, desc, RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)

            -- Amount (bottom-right)
            self.r:appText(x + w - FT.px(4), y - FT.py(8),
                FT.FONT.SMALL, data:formatMoney(inv.amount or 0),
                RenderText.ALIGN_RIGHT, FT.C.TEXT_NORMAL)

            y = y - FT.py(14)

            -- Due date line (if set)
            if (inv.dueDay or 0) > 0 then
                local today = (g_currentMission and g_currentMission.environment and g_currentMission.environment.currentDay) or 0
                local daysLeft = (inv.dueDay or 0) - today
                local dueStr
                if daysLeft < 0 then
                    dueStr = string.format("Overdue by %d day%s", -daysLeft, -daysLeft ~= 1 and "s" or "")
                elseif daysLeft == 0 then
                    dueStr = "Due today"
                else
                    dueStr = string.format("Due in %d day%s", daysLeft, daysLeft ~= 1 and "s" or "")
                end
                local dueColor = daysLeft < 0 and FT.C.NEGATIVE or (daysLeft <= 3 and FT.C.WARNING or FT.C.TEXT_DIM)
                self.r:appText(x + FT.px(4), y - FT.py(7),
                    FT.FONT.TINY, dueStr, RenderText.ALIGN_LEFT, dueColor)
                y = y - FT.py(10)
            end

            y = y - FT.py(4)
        end
    end

    -- ── Incoming invoices ─────────────────────────────────
    drawInvoiceList("INCOMING  (money owed to you)", incoming)

    if #incoming > 0 and #outgoing > 0 then
        y = y - FT.py(4)
        y = self:drawRule(y, 0.2)
    end

    -- ── Outgoing invoices ─────────────────────────────────
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
