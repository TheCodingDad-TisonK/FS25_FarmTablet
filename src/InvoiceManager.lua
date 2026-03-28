-- =========================================================
-- FarmTablet v2 – InvoiceManager
-- Built-in invoice system. Stores and persists invoices in
--   {savegameDir}/FS25_FarmTablet_Invoices.xml
--
-- Used by RoleplayPhoneApp as a fallback when FS25_RoleplayPhone
-- is not installed. When the phone mod IS present its API takes
-- precedence and this manager is bypassed for reads.
--
-- Invoice model:
--   id          : string  (auto-generated, e.g. "inv_1")
--   invoiceType : string  "incoming" | "outgoing"
--   party       : string  Name of the other party (NPC / company)
--   description : string  Short description of what it's for
--   amount      : number  Absolute value in game currency
--   status      : string  "pending" | "paid" | "overdue"
--   createdDay  : int     g_currentMission.environment.currentDay at creation
--   dueDay      : int     Expected payment day (0 = no due date)
-- =========================================================

---@class FT_InvoiceManager
FT_InvoiceManager = {}
local FT_InvoiceManager_mt = Class(FT_InvoiceManager)

FT_InvoiceManager.XML_TAG      = "FTInvoices"
FT_InvoiceManager.XML_FILENAME = "FS25_FarmTablet_Invoices.xml"
FT_InvoiceManager.MAX_INVOICES = 100

-- Status constants
FT_InvoiceManager.STATUS = {
    PENDING  = "pending",
    PAID     = "paid",
    OVERDUE  = "overdue",
}

-- Type constants
FT_InvoiceManager.TYPE = {
    INCOMING = "incoming",
    OUTGOING = "outgoing",
}

function FT_InvoiceManager.new()
    local self = setmetatable({}, FT_InvoiceManager_mt)
    self._invoices  = {}   -- list, ordered by createdDay desc
    self._nextId    = 1
    return self
end

-- ── Public API ────────────────────────────────────────────

--- Add a new invoice. Returns the new invoice table or nil on failure.
---@param data table  Fields: invoiceType, party, description, amount, status, dueDay
function FT_InvoiceManager:addInvoice(data)
    if #self._invoices >= FT_InvoiceManager.MAX_INVOICES then
        Logging.warning("[FarmTablet/InvoiceManager] Max invoice limit reached (%d)", FT_InvoiceManager.MAX_INVOICES)
        return nil
    end

    local day = (g_currentMission and g_currentMission.environment and g_currentMission.environment.currentDay) or 0
    local invoice = {
        id          = "inv_" .. self._nextId,
        invoiceType = data.invoiceType or FT_InvoiceManager.TYPE.OUTGOING,
        party       = data.party       or "",
        description = data.description or "",
        amount      = math.max(0, tonumber(data.amount) or 0),
        status      = data.status      or FT_InvoiceManager.STATUS.PENDING,
        createdDay  = day,
        dueDay      = tonumber(data.dueDay) or 0,
    }

    self._nextId = self._nextId + 1
    table.insert(self._invoices, 1, invoice)  -- newest first
    return invoice
end

--- Update the status of an invoice by id. Returns true on success.
function FT_InvoiceManager:updateStatus(id, status)
    for _, inv in ipairs(self._invoices) do
        if inv.id == id then
            inv.status = status
            return true
        end
    end
    return false
end

--- Delete an invoice by id. Returns true on success.
function FT_InvoiceManager:deleteInvoice(id)
    for i, inv in ipairs(self._invoices) do
        if inv.id == id then
            table.remove(self._invoices, i)
            return true
        end
    end
    return false
end

--- Returns all invoices (newest first).
function FT_InvoiceManager:getAll()
    return self._invoices
end

--- Returns all invoices of a given type ("incoming" | "outgoing").
function FT_InvoiceManager:getByType(invoiceType)
    local out = {}
    for _, inv in ipairs(self._invoices) do
        if inv.invoiceType == invoiceType then
            table.insert(out, inv)
        end
    end
    return out
end

--- Returns totals: { totalOwed, totalReceivable }
--- totalOwed        = sum of pending/overdue OUTGOING invoices (money we owe others)
--- totalReceivable  = sum of pending/overdue INCOMING invoices (money others owe us)
function FT_InvoiceManager:getTotals()
    local owed, receivable = 0, 0
    for _, inv in ipairs(self._invoices) do
        if inv.status ~= FT_InvoiceManager.STATUS.PAID then
            if inv.invoiceType == FT_InvoiceManager.TYPE.OUTGOING then
                owed = owed + inv.amount
            else
                receivable = receivable + inv.amount
            end
        end
    end
    return owed, receivable
end

-- ── Persistence ───────────────────────────────────────────

function FT_InvoiceManager:_getXmlPath()
    if g_currentMission and g_currentMission.missionInfo and g_currentMission.missionInfo.savegameDirectory then
        return ("%s/%s"):format(g_currentMission.missionInfo.savegameDirectory, FT_InvoiceManager.XML_FILENAME)
    end
    return nil
end

function FT_InvoiceManager:load()
    local xmlPath = self:_getXmlPath()
    if not xmlPath or not fileExists(xmlPath) then return end

    local xml = XMLFile.load("ft_Invoices", xmlPath)
    if not xml then return end

    -- Restore the next-id counter
    self._nextId = xml:getInt(FT_InvoiceManager.XML_TAG .. "#nextId", 1)

    xml:iterate(FT_InvoiceManager.XML_TAG .. ".invoice", function(_, key)
        local inv = {
            id          = xml:getString(key .. "#id",          ""),
            invoiceType = xml:getString(key .. "#type",        FT_InvoiceManager.TYPE.OUTGOING),
            party       = xml:getString(key .. "#party",       ""),
            description = xml:getString(key .. "#description", ""),
            amount      = xml:getFloat(key  .. "#amount",      0),
            status      = xml:getString(key .. "#status",      FT_InvoiceManager.STATUS.PENDING),
            createdDay  = xml:getInt(key    .. "#createdDay",  0),
            dueDay      = xml:getInt(key    .. "#dueDay",      0),
        }
        if inv.id ~= "" then
            table.insert(self._invoices, inv)
        end
    end)

    xml:delete()
    Logging.info("[FarmTablet/InvoiceManager] Loaded %d invoices", #self._invoices)
end

function FT_InvoiceManager:save()
    local xmlPath = self:_getXmlPath()
    if not xmlPath then return end

    local xml = XMLFile.create("ft_Invoices", xmlPath, FT_InvoiceManager.XML_TAG)
    if not xml then return end

    xml:setInt(FT_InvoiceManager.XML_TAG .. "#nextId", self._nextId)

    for i, inv in ipairs(self._invoices) do
        local key = string.format("%s.invoice(%d)", FT_InvoiceManager.XML_TAG, i - 1)
        xml:setString(key .. "#id",          inv.id)
        xml:setString(key .. "#type",        inv.invoiceType)
        xml:setString(key .. "#party",       inv.party)
        xml:setString(key .. "#description", inv.description)
        xml:setFloat(key  .. "#amount",      inv.amount)
        xml:setString(key .. "#status",      inv.status)
        xml:setInt(key    .. "#createdDay",  inv.createdDay)
        xml:setInt(key    .. "#dueDay",      inv.dueDay)
    end

    xml:save()
    xml:delete()
    Logging.info("[FarmTablet/InvoiceManager] Saved %d invoices", #self._invoices)
end
