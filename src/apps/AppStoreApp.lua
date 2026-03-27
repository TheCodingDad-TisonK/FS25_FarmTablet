-- =========================================================
-- FarmTablet v2 – App Store
-- Lists all registered apps with metadata
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.APP_STORE, function(self)
    local AC = FT.appColor(FT.APP.APP_STORE)

    if self:drawHelpPage("_appStoreHelp", FT.APP.APP_STORE, "App Store", AC, {
        { title = "WHAT IS THE APP STORE",
          body  = "Lists every app registered with the Farm Tablet,\n" ..
                  "grouped into Built-in, Farming, Finance, and\n" ..
                  "Mod Integration categories." },
        { title = "OPEN BUTTON",
          body  = "Click OPEN on any app row to switch to it directly.\n" ..
                  "This is a shortcut — you can also click the icon in\n" ..
                  "the left sidebar at any time." },
        { title = "MOD INTEGRATIONS",
          body  = "Companion mod apps appear here automatically\n" ..
                  "when their mod is loaded in your savegame.\n" ..
                  "Supported: Income, Tax, NPC Favor, Crop Stress,\n" ..
                  "Soil Fertilizer, Market Dynamics, Worker Costs,\n" ..
                  "Random World Events. No setup needed." },
        { title = "VERSION / DEVELOPER",
          body  = "Built-in apps show 'Built-in' as their version.\n" ..
                  "Third-party companion apps show their own version\n" ..
                  "number and developer name." },
    }) then return end

    local apps     = self.system.registry:getAll()
    local scrollY  = self:getContentScrollY()
    local afterHdr = self:drawAppHeader("App Store", #apps .. " installed")
    local x, contentY, cw, _ = self:contentInner()
    local y = afterHdr + scrollY

    local groups     = {}
    local groupOrder = {}
    for _, app in ipairs(apps) do
        local g = app.group or "core"
        if not groups[g] then groups[g] = {}; table.insert(groupOrder, g) end
        table.insert(groups[g], app)
    end

    local groupLabels = { core="BUILT-IN", farm="FARMING", finance="FINANCE", mods="MOD INTEGRATIONS" }

    for _, gid in ipairs(groupOrder) do
        local list = groups[gid]
        if #list > 0 then
            y = self:drawSection(y, groupLabels[gid] or gid:upper())
            for _, app in ipairs(list) do
                self.r:appRect(x - FT.px(4), y - FT.py(4), cw + FT.px(8), FT.py(30), FT.C.BG_CARD)
                local dispName = (g_i18n and g_i18n:getText(app.name)) or app.navLabel or app.id
                self.r:appText(x + FT.px(8),  y + FT.py(10), FT.FONT.BODY, dispName,
                    RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)
                local desc = app.description or ""
                if #desc > 44 then desc = desc:sub(1,42) .. ">" end
                self.r:appText(x + FT.px(8),  y - FT.py(4),  FT.FONT.TINY, desc,
                    RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
                self.r:appText(x + cw - FT.px(4), y + FT.py(10), FT.FONT.TINY, app.version or "Built-in",
                    RenderText.ALIGN_RIGHT, FT.C.BRAND)
                self.r:appText(x + cw - FT.px(4), y - FT.py(4),  FT.FONT.TINY, app.developer or "",
                    RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
                local appId = app.id
                local lbtn = self.r:button(x + cw - FT.px(48), y, FT.px(44), FT.py(14),
                    "OPEN", FT.C.BTN_PRIMARY, { onClick = function() self:switchApp(appId) end })
                table.insert(self._contentBtns, lbtn)
                y = y - FT.py(34)
            end
            y = y - FT.py(4)
        end
    end

    self:setContentHeight(afterHdr - y)
    self:drawInfoIcon("_appStoreHelp", AC)

    -- ── Scroll indicator bar ──────────────────────────────
    local cx, cy, cw, ch = self:contentInner()
    local scrollMax = self._contentScrollMax or 0
    if scrollMax > 0 then
        local barX    = cx + cw + FT.px(4)
        local barW    = FT.px(4)
        self.r:appRect(barX, cy, barW, ch, {0.12, 0.14, 0.20, 0.85})
        local thumbH  = math.max(FT.py(14), ch * (ch / (ch + scrollMax)))
        local scrolled = self._contentScrollY or 0
        local thumbY  = cy + ch - thumbH - (ch - thumbH) * (scrolled / scrollMax)
        self.r:appRect(barX, thumbY, barW, thumbH,
            {FT.C.BRAND[1], FT.C.BRAND[2], FT.C.BRAND[3], 0.80})
        self.r:appText(barX + barW + FT.px(4), cy + ch - FT.py(10),
            FT.FONT.TINY, "scroll", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    end
end)
