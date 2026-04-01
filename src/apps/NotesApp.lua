-- =========================================================
-- FarmTablet v2 – Notes App
-- Checkbox-style todo list saved per savegame.
-- =========================================================

-- ── Module state ──────────────────────────────────────────

local _todos        = {}   -- {text=string, done=bool}
local _templateIdx  = 1

local TEMPLATES = {
    "Harvest crops",
    "Sow seeds",
    "Apply fertilizer",
    "Plow / cultivate",
    "Spray fields",
    "Sell crops",
    "Refuel vehicles",
    "Repair vehicles",
    "Feed animals",
    "Clean animal pens",
    "Mow grass",
    "Bale hay / straw",
    "Collect bales",
    "Check contracts",
    "Visit shop",
    "Collect productions",
    "Buy equipment",
    "Water crops",
    "Check weather",
    "Field maintenance",
}

-- ── Save / Load ───────────────────────────────────────────

local function notes_getSavePath()
    if g_currentMission
    and g_currentMission.missionInfo
    and g_currentMission.missionInfo.savegameDirectory then
        return g_currentMission.missionInfo.savegameDirectory
               .. "/farm_tablet_notes.xml"
    end
    return nil
end

local function notes_save()
    local path = notes_getSavePath()
    if not path then return end
    local xml = XMLFile.create("FTNotes", path, "farmTabletNotes")
    if not xml then return end
    xml:setInt("farmTabletNotes#count", #_todos)
    for i, todo in ipairs(_todos) do
        local key = string.format("farmTabletNotes.item(%d)", i - 1)
        xml:setString(key .. "#text", todo.text or "")
        xml:setBool(key .. "#done",   todo.done or false)
    end
    xml:save()
    xml:delete()
end

local function notes_load()
    local path = notes_getSavePath()
    if not path or not fileExists(path) then return end
    local xml = XMLFile.load("FTNotes", path)
    if not xml then return end
    _todos = {}
    local count = xml:getInt("farmTabletNotes#count", 0)
    for i = 1, count do
        local key  = string.format("farmTabletNotes.item(%d)", i - 1)
        local text = xml:getString(key .. "#text", "")
        local done = xml:getBool(key .. "#done", false)
        if text ~= "" then
            table.insert(_todos, {text = text, done = done})
        end
    end
    xml:delete()
end

-- Hook into game lifecycle
Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission,
    function() notes_load() end)

FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile,
    function() notes_save() end)

-- ── Drawer ────────────────────────────────────────────────

FarmTabletUI:registerDrawer(FT.APP.NOTES, function(self)
    local AC = FT.appColor(FT.APP.NOTES)

    -- Count pending
    local pending = 0
    local done    = 0
    for _, t in ipairs(_todos) do
        if t.done then done = done + 1 else pending = pending + 1 end
    end

    if self:drawHelpPage("_notesHelp", FT.APP.NOTES, "Notes", AC, {
        { title = "TODO LIST",
          body  = "Keep track of farm tasks.\n\n" ..
                  "Use ◀ / ▶ to select a task template,\n" ..
                  "then + ADD to add it to the list.\n" ..
                  "Todos are saved automatically per savegame." },
        { title = "ACTIONS",
          body  = "DONE — mark a task as completed (■)\n" ..
                  "UNDO — mark it pending again (□)\n" ..
                  "✕    — remove the task entirely\n" ..
                  "CLEAR COMPLETED — remove all done tasks at once" },
    }) then return end

    local startY = self:drawAppHeader("Notes",
        pending > 0 and (pending .. " pending") or "All done!")
    local x, cy, cw, _ = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y       = startY + scrollY
    local BTN_H   = FT.py(22)
    local GAP     = FT.py(5)

    -- ── Template picker + Add ─────────────────────────────
    y = self:drawSection(y, "NEW TODO")
    y = y - GAP

    local arrowW    = FT.px(28)
    local labelW    = cw - arrowW * 2 - FT.px(6)
    local template  = TEMPLATES[_templateIdx] or "---"

    -- Prev arrow
    local btnPrev = self.r:button(x, y - BTN_H, arrowW, BTN_H, "◀",
        FT.C.BTN_NEUTRAL, {
        onClick = function()
            _templateIdx = ((_templateIdx - 2) % #TEMPLATES) + 1
        end
    })
    table.insert(self._contentBtns, btnPrev)

    -- Label display
    self.r:appRect(x + arrowW + FT.px(3), y - BTN_H,
        labelW, BTN_H, FT.C.BG_CARD)
    self.r:appText(x + arrowW + FT.px(3) + labelW * 0.5,
        y - BTN_H * 0.5 - FT.py(5),
        FT.FONT.SMALL, template, RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)

    -- Next arrow
    local btnNext = self.r:button(x + arrowW + FT.px(3) + labelW + FT.px(3),
        y - BTN_H, arrowW, BTN_H, "▶", FT.C.BTN_NEUTRAL, {
        onClick = function()
            _templateIdx = (_templateIdx % #TEMPLATES) + 1
        end
    })
    table.insert(self._contentBtns, btnNext)
    y = y - BTN_H - GAP

    -- Add button
    local btnAdd = self.r:button(x, y - BTN_H, cw, BTN_H,
        "+ ADD TODO", FT.C.BTN_PRIMARY, {
        onClick = function()
            table.insert(_todos, {text = TEMPLATES[_templateIdx], done = false})
            notes_save()
        end
    })
    table.insert(self._contentBtns, btnAdd)
    y = y - BTN_H - FT.py(8)

    -- ── Todo list ─────────────────────────────────────────
    y = self:drawRule(y - FT.py(4), 0.3)
    y = y - FT.py(6)
    y = self:drawSection(y,
        string.format("TODO LIST  (%d pending · %d done)", pending, done))
    y = y - GAP

    if #_todos == 0 then
        self.r:appText(x + cw * 0.5, y - FT.py(12), FT.FONT.SMALL,
            "No todos yet — add one above",
            RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)
        y = y - FT.py(24)
    else
        local statusW = FT.px(14)
        local actionW = FT.px(52)
        local removeW = FT.px(28)
        local textW   = cw - statusW - actionW - removeW - FT.px(9)

        for i, todo in ipairs(_todos) do
            if y < cy + FT.py(4) then break end

            -- Status glyph
            self.r:appText(x, y - FT.py(6),
                FT.FONT.SMALL, todo.done and "■" or "□",
                RenderText.ALIGN_LEFT,
                todo.done and FT.C.TEXT_DIM or AC)

            -- Task label
            local label = todo.text or ""
            if string.len(label) > 21 then
                label = string.sub(label, 1, 20) .. "…"
            end
            self.r:appText(x + statusW + FT.px(3), y - FT.py(6),
                FT.FONT.SMALL, label, RenderText.ALIGN_LEFT,
                todo.done and FT.C.TEXT_DIM or FT.C.TEXT_NORMAL)

            -- Done / Undo button
            local capturedIdx = i
            local btnDone = self.r:button(
                x + statusW + FT.px(3) + textW + FT.px(3),
                y - BTN_H, actionW, BTN_H,
                todo.done and "UNDO" or "DONE",
                todo.done and FT.C.BTN_NEUTRAL or FT.C.BTN_PRIMARY, {
                onClick = function()
                    if _todos[capturedIdx] then
                        _todos[capturedIdx].done = not _todos[capturedIdx].done
                        notes_save()
                    end
                end
            })
            table.insert(self._contentBtns, btnDone)

            -- Remove button
            local btnRm = self.r:button(
                x + statusW + FT.px(3) + textW + FT.px(3) + actionW + FT.px(3),
                y - BTN_H, removeW, BTN_H, "✕", FT.C.BTN_DANGER, {
                onClick = function()
                    table.remove(_todos, capturedIdx)
                    notes_save()
                end
            })
            table.insert(self._contentBtns, btnRm)

            y = y - BTN_H - GAP
        end
    end

    -- Clear completed button
    if done > 0 then
        y = y - FT.py(4)
        local btnClearDone = self.r:button(x, y - BTN_H, cw, BTN_H,
            string.format("CLEAR %d COMPLETED", done),
            FT.C.BTN_DANGER, {
            onClick = function()
                local remaining = {}
                for _, t in ipairs(_todos) do
                    if not t.done then table.insert(remaining, t) end
                end
                _todos = remaining
                notes_save()
            end
        })
        table.insert(self._contentBtns, btnClearDone)
        y = y - BTN_H
    end

    self:setContentHeight(startY - y + scrollY)
    self:drawInfoIcon("_notesHelp", AC)
    self:drawScrollBar()
end)
