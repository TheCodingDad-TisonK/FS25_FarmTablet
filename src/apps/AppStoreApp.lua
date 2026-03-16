-- =========================================================
-- FarmTablet v2 – App Store
-- Lists all registered apps with metadata
-- =========================================================

FarmTabletUI:registerDrawer(FT.APP.APP_STORE, function(self)
    local apps = self.system.registry:getAll()

    local startY = self:drawAppHeader("App Store",
        #apps .. " installed")

    local x, contentY, cw, _ = self:contentInner()
    local y = startY
    local minY = contentY + FT.py(8)

    -- Group apps by category
    local groups = {}
    local groupOrder = {}
    for _, app in ipairs(apps) do
        local g = app.group or "core"
        if not groups[g] then
            groups[g] = {}
            table.insert(groupOrder, g)
        end
        table.insert(groups[g], app)
    end

    local groupLabels = { core="BUILT-IN", farm="FARMING", finance="FINANCE", mods="MOD INTEGRATIONS" }

    for _, gid in ipairs(groupOrder) do
        local list = groups[gid]
        if #list > 0 and y > minY + FT.py(20) then
            y = self:drawSection(y, groupLabels[gid] or gid:upper())

            for _, app in ipairs(list) do
                if y < minY then break end

                -- App row bg
                self.r:appRect(x - FT.px(4), y - FT.py(4),
                    cw + FT.px(8), FT.py(30), FT.C.BG_CARD)

                -- App name (bold-ish with TITLE_COLOR)
                local dispName = (g_i18n and g_i18n:getText(app.name)) or app.navLabel or app.id
                self.r:appText(x + FT.px(8), y + FT.py(10),
                    FT.FONT.BODY, dispName,
                    RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)

                -- Description
                local desc = app.description or ""
                if #desc > 44 then desc = desc:sub(1,42) .. "…" end
                self.r:appText(x + FT.px(8), y - FT.py(4),
                    FT.FONT.TINY, desc,
                    RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)

                -- Version badge
                local versionText = app.version or "Built-in"
                self.r:appText(x + cw - FT.px(4), y + FT.py(10),
                    FT.FONT.TINY, versionText,
                    RenderText.ALIGN_RIGHT, FT.C.BRAND)

                -- Developer
                self.r:appText(x + cw - FT.px(4), y - FT.py(4),
                    FT.FONT.TINY, app.developer or "",
                    RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)

                -- Launch button
                local appId = app.id
                local lbtn = self.r:button(x + cw - FT.px(48), y,
                    FT.px(44), FT.py(14),
                    "OPEN", FT.C.BTN_PRIMARY,
                    { onClick = function()
                        self:switchApp(appId)
                    end })
                table.insert(self._contentBtns, lbtn)

                y = y - FT.py(34)
            end

            y = y - FT.py(4)
        end
    end
end)
