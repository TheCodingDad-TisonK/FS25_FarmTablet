-- =========================================================
-- FarmTablet - DairyCore app (Tyson green light 2026-07-25)
-- =========================================================
-- Read-only barn cards from DairyCoreManager:getBarnRows().
-- Shows only fields the live API returns - no invented litres/collection.
-- Handle: g_currentMission.dairyCoreManager or getfenv(0)["g_dairyCoreManager"]
-- DC-27 (BUILD 21:48): HERD NOW / MILK IN TANK sections per card from the server's breed
-- surface (version 1, strict local farm via FT_DataProvider:getPlayerFarmIdStrict).
-- =========================================================

local function _dairyMgr()
    return (g_currentMission and g_currentMission.dairyCoreManager)
        or getfenv(0)["g_dairyCoreManager"]
end

-- Human barn name for the card title. The same ladder as the Esc guest
-- (DairyRfPdaGuest.barnLabel): a real name carried on the row wins, then the
-- placeable's own getName() / nameCustom / nameL10n / store name, and only then
-- the "Barn <id>" fallback. Tablet app only; the Esc guest is untouched.
local function barnLabel(row)
    if row == nil then
        return FT.l10nFormat("ft_dairy_barn_id", "Barn %s", "?")
    end
    local human = row.nameCustom or row.displayName or row.barnName or row.name
    if type(human) == "string" and human ~= "" then
        return human
    end
    local barnId = row.barnId
    local ps = (g_currentMission ~= nil) and g_currentMission.placeableSystem or nil
    if barnId ~= nil and ps ~= nil and type(ps.getPlaceableByUniqueId) == "function" then
        local ok, placeable = pcall(function() return ps:getPlaceableByUniqueId(barnId) end)
        if ok and placeable ~= nil then
            if type(placeable.getName) == "function" then
                local okName, n = pcall(function() return placeable:getName() end)
                if okName and type(n) == "string" and n ~= "" then return n end
            end
            if type(placeable.nameCustom) == "string" and placeable.nameCustom ~= "" then
                return placeable.nameCustom
            end
            if type(placeable.nameL10n) == "string" and placeable.nameL10n ~= "" then
                return placeable.nameL10n
            end
            local si = placeable.storeItem
            if si ~= nil and type(si.name) == "string" and si.name ~= "" then
                return si.name
            end
        end
    end
    local id = tostring(barnId or "?")
    if #id > 24 then
        id = id:sub(1, 22) .. "..."
    end
    return FT.l10nFormat("ft_dairy_barn_id", "Barn %s", id)
end

local function healthColor(pct)
    local p = tonumber(pct) or 0
    if p >= 85 then return FT.C.POSITIVE
    elseif p >= 60 then return FT.C.TEXT_NORMAL
    elseif p >= 35 then return FT.C.WARNING
    else return FT.C.NEGATIVE end
end

local function spoilageColor(status)
    local s = tostring(status or "")
    if s == "Fresh" then return FT.C.POSITIVE
    elseif s == "Ageing" then return FT.C.WARNING
    elseif s == "At Risk" or s == "Condemned" then return FT.C.NEGATIVE
    end
    return FT.C.TEXT_DIM
end

local function tierColor(tier)
    local t = tostring(tier or "")
    if t == "Premium" then return FT.C.POSITIVE
    elseif t == "Standard" then return FT.C.TEXT_NORMAL
    elseif t == "Reduced" then return FT.C.WARNING
    elseif t == "Poor" then return FT.C.NEGATIVE
    end
    return FT.C.TEXT_DIM
end

-- =========================================================
-- DC-27 (BUILD 21:48): breed surfaces, presentation only.
-- =========================================================
-- Two clocks per barn card. HERD NOW is the milking headcount standing in the barn today,
-- by breed. MILK IN TANK is the stored milk by the breeds that produced it, with unknown
-- milk named as unknown. A new herd beside old milk is correct. Both are server records
-- DairyCoreManager already put on the row; nothing here reads local animals or Storage,
-- and no breed is scored, ranked or priced.
local BREED_VERSION = 1
local UNKNOWN_TOKEN = "UNKNOWN"

--- Strict local farm id via the DataProvider getter (positive number or nil, never 1).
local function playerFarmIdStrict()
    if FT_DataProvider ~= nil and type(FT_DataProvider.getPlayerFarmIdStrict) == "function" then
        local ok, id = pcall(function() return FT_DataProvider:getPlayerFarmIdStrict() end)
        if ok and type(id) == "number" and id > 0 then return id end
    end
    return nil
end

--- A record is painted only when the server says it is available. Anything else is a state.
local function breedRecordLive(rec)
    return type(rec) == "table" and rec.available == true and rec.trust == "server"
end

local function breedRecordReason(rec)
    if type(rec) ~= "table" then return "SNAPSHOT_INVALID" end
    if rec.available == false and type(rec.reason) == "string" and rec.reason ~= "" then
        return rec.reason
    end
    return "SNAPSHOT_INVALID"
end

local function breedStateLabel(reason)
    local r = tostring(reason or "")
    if r == "WAITING_FOR_SERVER" then
        return FT.l10n("ft_dairy_breed_waiting_server", "Waiting for server")
    elseif r == "WAITING_FOR_PLAYER_FARM" then
        return FT.l10n("ft_dairy_breed_waiting_farm", "Waiting for player farm")
    elseif r == "UNRESOLVED_FILLTYPE" then
        return FT.l10n("ft_dairy_breed_filltype_unresolved", "Fill type unresolved")
    elseif r == "NO_INTERNAL_STORAGE" then
        return FT.l10n("ft_dairy_breed_storage_missing", "No internal storage")
    elseif r == "NON_SINGLE_STORAGE_ROUTE" then
        return FT.l10n("ft_dairy_breed_route_unavailable", "Tank route unavailable")
    elseif r == "HERD_UNRESOLVED" then
        return FT.l10n("ft_dairy_breed_herd_unresolved", "Herd unreadable")
    end
    return FT.l10n("ft_dairy_breed_snapshot_invalid", "Snapshot invalid")
end

--- Breed label: the subtype's own fill type title (the game's name for the breed), else a
--- fill type by that name, else the raw token. The UNKNOWN token is localized.
local function breedLabel(key)
    local k = tostring(key or "")
    if k == "" or k == UNKNOWN_TOKEN then
        return FT.l10n("ft_dairy_breed_unknown", "unknown")
    end
    local as = g_currentMission ~= nil and g_currentMission.animalSystem or nil
    if as ~= nil and type(as.getSubTypeByName) == "function" and g_fillTypeManager ~= nil
        and type(g_fillTypeManager.getFillTypeTitleByIndex) == "function" then
        local ok, st = pcall(function() return as:getSubTypeByName(k) end)
        if ok and type(st) == "table" and st.fillTypeIndex ~= nil then
            local ok2, title = pcall(function()
                return g_fillTypeManager:getFillTypeTitleByIndex(st.fillTypeIndex)
            end)
            if ok2 and type(title) == "string" and title ~= "" then return title end
        end
    end
    if g_fillTypeManager ~= nil and type(g_fillTypeManager.getFillTypeByName) == "function" then
        local ok, ft = pcall(function() return g_fillTypeManager:getFillTypeByName(k) end)
        if ok and type(ft) == "table" and type(ft.title) == "string" and ft.title ~= "" then
            return ft.title
        end
    end
    return k
end

local function fillTypeLabel(name)
    local n = tostring(name or "")
    if g_fillTypeManager ~= nil and type(g_fillTypeManager.getFillTypeByName) == "function" then
        local ok, ft = pcall(function() return g_fillTypeManager:getFillTypeByName(n) end)
        if ok and type(ft) == "table" and type(ft.title) == "string" and ft.title ~= "" then
            return ft.title
        end
    end
    return n
end

local function pct(f)
    return math.floor((tonumber(f) or 0) * 100 + 0.5)
end

local function litresText(l)
    return FT.l10nFormat("ft_dairy_breed_litres", "%d L", math.floor((tonumber(l) or 0) + 0.5))
end

--- Shares sorted for display: share descending, then name; unknown after an equal share.
local function sortedShares(fractions, unknownShare)
    local list = {}
    if type(fractions) == "table" then
        for k, f in pairs(fractions) do
            local v = tonumber(f) or 0
            if v > 0 then
                local key = tostring(k)
                list[#list + 1] = { key = key, frac = v, unknown = (key == UNKNOWN_TOKEN) }
            end
        end
    end
    local u = tonumber(unknownShare) or 0
    if u > 0 then
        list[#list + 1] = { key = UNKNOWN_TOKEN, frac = u, unknown = true }
    end
    table.sort(list, function(a, b)
        if a.frac ~= b.frac then return a.frac > b.frac end
        if a.unknown ~= b.unknown then return not a.unknown end
        return a.key < b.key
    end)
    return list
end

--- The barn's tracked milk fill types, MILK first, then by name.
local function milkFillTypeNames(prov)
    local names = {}
    if type(prov) == "table" then
        for k, _ in pairs(prov) do names[#names + 1] = tostring(k) end
    end
    table.sort(names, function(a, b)
        if (a == "MILK") ~= (b == "MILK") then return a == "MILK" end
        return a < b
    end)
    return names
end

--- The breed rows for one card as { label, value, color } triples in draw order. Every
--- breed and every tracked fill type is listed; unknown milk is a named row, never a gap.
local function breedCardRows(row)
    local out = {}
    local function add(label, value, color)
        out[#out + 1] = { label, value, color }
    end
    if row.breedSurfaceVersion ~= BREED_VERSION then
        add(FT.l10n("ft_dairy_breed_help_title", "BREED RECORDS"),
            FT.l10n("ft_dairy_breed_update_required", "Update required"), FT.C.WARNING)
        return out
    end

    local herdLabel = FT.l10n("ft_dairy_breed_herd", "HERD NOW")
    local h = row.herdBreedComposition
    if breedRecordLive(h) then
        local total = math.floor((tonumber(h.totalMilkingHeadcount) or 0) + 0.5)
        local src = h.sourceMode == "REALISTIC_LIVESTOCK"
            and FT.l10n("ft_dairy_breed_source_rl", "Realistic Livestock count")
            or FT.l10n("ft_dairy_breed_source_standard", "standard count")
        add(herdLabel, string.format("%s (%s)",
            FT.l10nFormat("ft_dairy_breed_head", "%d head", total), src), FT.C.TEXT_NORMAL)
        for _, e in ipairs(sortedShares(h.fractions, nil)) do
            local n = tonumber(type(h.counts) == "table" and h.counts[e.key]) or 0
            add("  " .. breedLabel(e.key), string.format("%d (%d%%)", math.floor(n + 0.5), pct(e.frac)),
                e.unknown and FT.C.TEXT_DIM or FT.C.TEXT_NORMAL)
        end
    else
        add(herdLabel, breedStateLabel(breedRecordReason(h)), FT.C.INFO)
    end

    local milkLabel = FT.l10n("ft_dairy_breed_milk", "MILK IN TANK")
    local prov = row.milkBreedProvenance
    local names = milkFillTypeNames(prov)
    if #names == 0 then
        add(milkLabel, breedStateLabel("SNAPSHOT_INVALID"), FT.C.INFO)
    end
    for _, n in ipairs(names) do
        local rec = prov[n]
        local label = milkLabel
        if #names > 1 then label = string.format("%s (%s)", milkLabel, fillTypeLabel(n)) end
        if breedRecordLive(rec) then
            local litres = math.floor((tonumber(rec.litres) or 0) + 0.5)
            if litres <= 0 then
                add(label, FT.l10n("ft_dairy_breed_no_milk", "no milk stored"), FT.C.TEXT_DIM)
            else
                add(label, litresText(litres), FT.C.TEXT_NORMAL)
                for _, e in ipairs(sortedShares(rec.fractions, rec.unknownShare)) do
                    local l
                    if e.unknown then
                        l = tonumber(rec.unknownLitres) or 0
                    else
                        l = tonumber(type(rec.knownLitres) == "table" and rec.knownLitres[e.key]) or 0
                    end
                    add("  " .. breedLabel(e.key), string.format("%s (%d%%)", litresText(l), pct(e.frac)),
                        e.unknown and FT.C.TEXT_DIM or FT.C.TEXT_NORMAL)
                end
            end
        else
            add(label, breedStateLabel(breedRecordReason(rec)), FT.C.INFO)
        end
    end
    return out
end

FarmTabletUI:registerDrawer(FT.APP.DAIRY, function(self)
    local AC = FT.appColor(FT.APP.DAIRY)

    if self:drawHelpPage("_dairyHelp", FT.APP.DAIRY, FT.l10n("ft_ui_app_dairy", "Dairy"), AC, {
        { title = FT.l10n("ft_dairy_help_barns_title", "BARN CARDS"),
          body  = FT.l10n("ft_dairy_help_barns_body",
              "Each card is one dairy barn tracked by DairyCore.\n" ..
              "Herd health, milk quality tier, and spoilage come\n" ..
              "straight from DairyCore - FarmTablet does not invent values.") },
        { title = FT.l10n("ft_dairy_help_ritter_title", "RITTER MODE"),
          body  = FT.l10n("ft_dairy_help_ritter_body",
              "When Realistic Livestock is active, barn cards also show\n" ..
              "healthy / sick / pregnant counts and average genetics.\n" ..
              "Individual animals stay in Ritter's own menu.") },
        { title = FT.l10n("ft_dairy_help_feed_title", "FEED WARNINGS"),
          body  = FT.l10n("ft_dairy_help_feed_body",
              "A feed disease flag means elevated risk on a designated\n" ..
              "feed field. The disease name appears only when DairyCore\n" ..
              "has revealed it (scout or Co-Op report). Mycotoxin is a\n" ..
              "read-only herd-health penalty.") },
        { title = FT.l10n("ft_dairy_help_readonly_title", "READ-ONLY"),
          body  = FT.l10n("ft_dairy_help_readonly_body",
              "This tab does not schedule collections, edit contracts,\n" ..
              "or designate feed fields. It surfaces DairyCore's live\n" ..
              "read model only.") },
        { title = FT.l10n("ft_dairy_breed_help_title", "BREED RECORDS"),
          body  = FT.l10n("ft_dairy_breed_help_body",
              "Herd now counts the milking animals in the barn.\n" ..
              "Milk in tank follows the stored milk by the breeds that\n" ..
              "produced it. A new herd beside old milk is normal. Unknown\n" ..
              "milk predates the record or arrived unproven. No breed is\n" ..
              "rated better here.") },
    }) then return end

    local mgr = _dairyMgr()
    local rows = {}
    if mgr ~= nil and type(mgr.getBarnRows) == "function" then
        local ok, result = pcall(function() return mgr:getBarnRows() end)
        if ok and type(result) == "table" then
            rows = result
        end
    end

    -- DC-27: strict farm gate BEFORE the count, the sort and the cards. Rows carry the
    -- server-validated breedSurfaceFarmId (never the legacy row.farmId). A row from a
    -- DairyCore without the breed surface at all (no version) keeps its legacy card and
    -- says so on the card; a nil farm id or a client still waiting for its mirror shows
    -- no cards and names the wait.
    local farmId = playerFarmIdStrict()
    local waitingServer = false
    do
        local kept = {}
        for _, r in ipairs(rows) do
            if r.breedSurfaceVersion == nil then
                kept[#kept + 1] = r
            elseif farmId ~= nil and type(r.breedSurfaceFarmId) == "number"
                and r.breedSurfaceFarmId == farmId then
                kept[#kept + 1] = r
            elseif r.breedSurfaceFarmId == nil then
                local h = r.herdBreedComposition
                if type(h) == "table" and h.available == false and h.reason == "WAITING_FOR_SERVER" then
                    waitingServer = true
                end
            end
        end
        rows = kept
    end

    table.sort(rows, function(a, b)
        return tostring(a.barnId or "") < tostring(b.barnId or "")
    end)

    local startY = self:drawAppHeader(
        FT.l10n("ft_ui_app_dairy", "Dairy"),
        FT.l10nFormat(#rows == 1 and "ft_dairy_count_barn" or "ft_dairy_count_barns",
            "%d barns", #rows))
    local x, _, cw, _ = self:contentInner()

    if mgr == nil then
        self.r:appText(x, startY - FT.py(12), FT.FONT.BODY,
            FT.l10n("ft_dairy_no_manager", "DairyCore not detected."),
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, startY - FT.py(30), FT.FONT.SMALL,
            FT.l10n("ft_dairy_install_hint", "Install FS25_DairyCore. This app stays hidden when absent."),
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        self:drawInfoIcon("_dairyHelp", AC)
        return
    end

    if #rows == 0 then
        local emptyText = FT.l10n("ft_dairy_no_barns", "No dairy barns tracked yet.")
        local emptyHint = FT.l10n("ft_dairy_no_barns_hint", "Own a dairy barn and DairyCore will list it here.")
        if farmId == nil then
            emptyText = breedStateLabel("WAITING_FOR_PLAYER_FARM")
            emptyHint = FT.l10n("ft_dairy_breed_waiting_farm_hint",
                "The tablet cannot prove your farm yet. Barn cards stay hidden until it can.")
        elseif waitingServer then
            emptyText = breedStateLabel("WAITING_FOR_SERVER")
            emptyHint = FT.l10n("ft_dairy_breed_waiting_server_hint",
                "The server has not sent this farm's breed records yet. Barn cards stay hidden until it does.")
        end
        self.r:appText(x, startY - FT.py(12), FT.FONT.BODY, emptyText,
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x, startY - FT.py(30), FT.FONT.SMALL, emptyHint,
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        self:drawInfoIcon("_dairyHelp", AC)
        return
    end

    local scrollY = self:getContentScrollY()
    local y = startY + scrollY
    local pad = FT.px(8)
    local lineH = FT.py(14)

    local function drawKV(rowY, label, value, valueCol)
        self.r:appText(x + pad, rowY, FT.FONT.TINY, label,
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        self.r:appText(x + cw - pad, rowY, FT.FONT.TINY, tostring(value),
            RenderText.ALIGN_RIGHT, valueCol or FT.C.TEXT_NORMAL)
        return rowY - lineH
    end

    for _, row in ipairs(rows) do
        local lines = 3  -- health, tier, spoilage
        if row.ritterMode then
            lines = lines + 1  -- mode
            if type(row.counts) == "table" then
                lines = lines + 2  -- counts + genetics
            end
        else
            lines = lines + 1  -- Standard mode label
        end
        if (tonumber(row.mycotoxin) or 0) > 0 then
            lines = lines + 1
        end
        if row.feedDiseaseFlag then
            lines = lines + 1
        end
        if row.contractId ~= nil then
            lines = lines + 1
        end
        -- DC-27: the breed rows are counted before the card is sized, like every other line.
        local breedRows = breedCardRows(row)
        lines = lines + #breedRows

        local headerH = FT.py(22)
        local cardH = headerH + lines * lineH + FT.py(10)
        local cardBottom = y - cardH

        self.r:appRect(x - FT.px(4), cardBottom, cw + FT.px(8), cardH, FT.C.BG_CARD)

        local header = barnLabel(row)
        self.r:appText(x + pad, y - FT.py(6), FT.FONT.BODY, header,
            RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)

        local rowY = y - headerH
        local modeLabel = row.ritterMode
            and FT.l10n("ft_dairy_mode_ritter", "Ritter")
            or FT.l10n("ft_dairy_mode_standard", "Standard")
        rowY = drawKV(rowY, FT.l10n("ft_dairy_label_mode", "MODE"), modeLabel, AC)

        local health = math.floor(tonumber(row.herdHealth) or 0)
        rowY = drawKV(rowY, FT.l10n("ft_dairy_label_health", "HERD HEALTH"),
            string.format("%d", health), healthColor(health))

        local tier = tostring(row.qualityTier or "-")
        rowY = drawKV(rowY, FT.l10n("ft_dairy_label_tier", "QUALITY TIER"),
            tier, tierColor(tier))

        local spoil = tostring(row.spoilage or "-")
        rowY = drawKV(rowY, FT.l10n("ft_dairy_label_spoilage", "SPOILAGE"),
            spoil, spoilageColor(spoil))

        if row.ritterMode and type(row.counts) == "table" then
            local c = row.counts
            local countStr = string.format("%d / %d / %d",
                tonumber(c.healthy) or 0,
                tonumber(c.sick) or 0,
                tonumber(c.pregnant) or 0)
            rowY = drawKV(rowY, FT.l10n("ft_dairy_label_counts", "HEALTHY / SICK / PREG"),
                countStr, FT.C.TEXT_NORMAL)
            local gene = tonumber(c.avgGenetics)
            if gene ~= nil then
                rowY = drawKV(rowY, FT.l10n("ft_dairy_label_genetics", "AVG GENETICS"),
                    string.format("%.2f", gene), FT.C.TEXT_NORMAL)
            end
        end

        local myc = tonumber(row.mycotoxin) or 0
        if myc > 0 then
            rowY = drawKV(rowY, FT.l10n("ft_dairy_label_mycotoxin", "MYCOTOXIN"),
                string.format("-%d", myc), FT.C.NEGATIVE)
        end

        if row.feedDiseaseFlag then
            local feedVal = FT.l10n("ft_dairy_feed_flag", "Elevated risk")
            if row.feedDiseaseCropName ~= nil and tostring(row.feedDiseaseCropName) ~= "" then
                feedVal = tostring(row.feedDiseaseCropName)
            end
            rowY = drawKV(rowY, FT.l10n("ft_dairy_label_feed", "FEED DISEASE"),
                feedVal, FT.C.NEGATIVE)
        end

        if row.contractId ~= nil then
            rowY = drawKV(rowY, FT.l10n("ft_dairy_label_contract", "CONTRACT"),
                tostring(row.contractId), FT.C.TEXT_NORMAL)
        end

        -- DC-27: the two breed clocks, every breed and fill type listed, unknown named.
        for _, br in ipairs(breedRows) do
            rowY = drawKV(rowY, br[1], br[2], br[3])
        end

        y = cardBottom - FT.py(8)
    end

    self:setContentHeight(startY - y + scrollY)
    self:drawInfoIcon("_dairyHelp", AC)
    self:drawScrollBar()
end)
