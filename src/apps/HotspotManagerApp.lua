-- =========================================================
-- FarmTablet v2 – Hotspot Manager App
-- View and remove map hotspots/pins.
-- =========================================================

-- ── Category labels ───────────────────────────────────────

local function hs_getCategoryLabel(cat)
    if MapHotspot then
        if cat == MapHotspot.CATEGORY_FIELD      then return "Field"      end
        if cat == MapHotspot.CATEGORY_ANIMAL     then return "Animal"     end
        if cat == MapHotspot.CATEGORY_MISSION    then return "Mission"    end
        if cat == MapHotspot.CATEGORY_STEERABLE  then return "Vehicle"    end
        if cat == MapHotspot.CATEGORY_COMBINE    then return "Combine"    end
        if cat == MapHotspot.CATEGORY_TRAILER    then return "Trailer"    end
        if cat == MapHotspot.CATEGORY_TOOL       then return "Tool"       end
        if cat == MapHotspot.CATEGORY_UNLOADING  then return "Unloading"  end
        if cat == MapHotspot.CATEGORY_LOADING    then return "Loading"    end
        if cat == MapHotspot.CATEGORY_PRODUCTION then return "Production" end
        if cat == MapHotspot.CATEGORY_SHOP       then return "Shop"       end
        if cat == MapHotspot.CATEGORY_AI         then return "AI"         end
        if cat == MapHotspot.CATEGORY_PLAYER     then return "Player"     end
        if cat == MapHotspot.CATEGORY_TOUR       then return "Tour"       end
        if cat == MapHotspot.CATEGORY_OTHER      then return "Other"      end
    end
    return "Pin"
end

local function hs_getName(hotspot)
    local ok, name = pcall(function() return hotspot:getName() end)
    if ok and name and name ~= "" then return name end
    if hotspot.name and hotspot.name ~= "" then return hotspot.name end
    return "(unnamed)"
end

local function hs_getIngameMap()
    return g_currentMission
        and g_currentMission.hud
        and g_currentMission.hud.ingameMap
end

local function hs_removeHotspot(hotspot)
    local im = hs_getIngameMap()
    if not im then return end
    pcall(function()
        im:removeMapHotspot(hotspot)
        if hotspot.delete then hotspot:delete() end
    end)
end

-- ── Module state ──────────────────────────────────────────

local _confirmClear = false
local _confirmTimer = 0

-- ── Drawer ────────────────────────────────────────────────

FarmTabletUI:registerDrawer(FT.APP.HOTSPOT_MGR, function(self)
    local AC = FT.appColor(FT.APP.HOTSPOT_MGR)

    if self:drawHelpPage("_hotspotHelp", FT.APP.HOTSPOT_MGR, "Hotspot Manager", AC, {
        { title = "WHAT IS THIS?",
          body  = "Shows all active map hotspots / pins.\n" ..
                  "You can remove individual entries or clear all.\n\n" ..
                  "Categories shown: Field, Shop, Mission, Vehicle,\n" ..
                  "Player, etc. Removing system hotspots (Missions,\n" ..
                  "Shops) may break game features — be careful." },
        { title = "CLEAR ALL",
          body  = "Press CLEAR ALL once — it turns red and asks\n" ..
                  "for confirmation. Press it again within 4 seconds\n" ..
                  "to remove every hotspot from the map." },
    }) then return end

    local im = hs_getIngameMap()
    local hotspots = im and im.hotspots or {}
    local total = #hotspots

    -- Decay confirm timer
    _confirmTimer = math.max(0, _confirmTimer - 1)
    if _confirmTimer == 0 then _confirmClear = false end

    local startY = self:drawAppHeader("Hotspot Manager",
        total > 0 and (total .. " total") or "Empty")
    local x, cy, cw, ch = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y = startY + scrollY
    local BTN_H = FT.py(22)
    local GAP   = FT.py(5)

    -- ── Clear All ─────────────────────────────────────────
    if total > 0 then
        y = y - FT.py(4)
        local clearLabel = _confirmClear
            and string.format("CONFIRM CLEAR ALL (%d)", total)
            or  string.format("CLEAR ALL (%d)", total)
        local clearColor = _confirmClear and FT.C.BTN_DANGER or FT.C.BTN_NEUTRAL
        local btnClear = self.r:button(x, y - BTN_H, cw, BTN_H, clearLabel, clearColor, {
            onClick = function()
                if _confirmClear then
                    local toRemove = {}
                    for _, hs in ipairs(im.hotspots) do table.insert(toRemove, hs) end
                    for _, hs in ipairs(toRemove) do hs_removeHotspot(hs) end
                    _confirmClear = false
                    _confirmTimer = 0
                else
                    _confirmClear = true
                    _confirmTimer = 240  -- ~4 seconds at 60fps
                end
            end
        })
        table.insert(self._contentBtns, btnClear)
        y = y - BTN_H - FT.py(8)
    end

    -- ── Hotspot list ──────────────────────────────────────
    y = self:drawRule(y - FT.py(2), 0.3)
    y = y - FT.py(6)
    y = self:drawSection(y, "HOTSPOTS")
    y = y - GAP

    if total == 0 then
        self.r:appText(x + cw / 2, y - FT.py(12), FT.FONT.SMALL,
            "No hotspots on the map", RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)
        y = y - FT.py(24)
    else
        local removeW = FT.px(28)
        local catW    = FT.px(64)
        local nameW   = cw - catW - removeW - FT.px(6)

        for i, hs in ipairs(hotspots) do
            if y < cy + FT.py(4) then break end

            local catLabel  = hs_getCategoryLabel(hs.category)
            local nameLabel = hs_getName(hs)
            if string.len(nameLabel) > 20 then
                nameLabel = string.sub(nameLabel, 1, 19) .. "…"
            end

            self.r:appText(x, y - FT.py(5), FT.FONT.TINY,
                catLabel, RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            self.r:appText(x + catW, y - FT.py(5), FT.FONT.SMALL,
                nameLabel, RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)

            local capturedHs = hs
            local btnRm = self.r:button(x + catW + nameW + FT.px(6), y - BTN_H, removeW, BTN_H,
                "✕", FT.C.BTN_DANGER, {
                onClick = function() hs_removeHotspot(capturedHs) end
            })
            table.insert(self._contentBtns, btnRm)

            y = y - BTN_H - GAP
        end
    end

    local contentStartY = startY
    self:setContentHeight(contentStartY - y + scrollY)

    self:drawInfoIcon("_hotspotHelp", AC)
end)
