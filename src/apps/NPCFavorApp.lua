-- =========================================================
-- FS25 Farm Tablet -- NPC Favor Integration App
-- =========================================================

function FarmTabletUI:loadNPCFavorApp()
    self.ui.appTexts = {}
    local content = self.ui.appContentArea
    if not content then return end

    local C    = self.UI_CONSTANTS
    local padX = self:px(15)
    local padY = self:py(12)

    local titleY = content.y + content.height - padY - 0.028
    self:drawText("NPC Favor", content.x + padX, titleY, 0.019, RenderText.ALIGN_LEFT, C.TITLE_COLOR)

    -- Access via g_currentMission (cross-mod safe)
    local npc = g_currentMission and g_currentMission.npcFavorSystem

    if not npc then
        local y = titleY - 0.040
        self:drawText("NPC Favor mod not detected.", content.x + padX, y, 0.015,
            RenderText.ALIGN_LEFT, C.NEGATIVE_COLOR)
        y = y - 0.024
        self:drawText("Install FS25_NPCFavor to use this app.", content.x + padX, y, 0.013,
            RenderText.ALIGN_LEFT, C.MUTED_COLOR)
        return
    end

    local y = titleY - 0.030
    self:drawSectionHeader("SYSTEM", y)
    y = y - 0.022

    local npcCount    = npc.npcCount or (npc.activeNPCs and #npc.activeNPCs) or 0
    local initialized = npc.isInitialized and "Ready" or "Initializing..."
    self:drawRow("Status",    initialized, y, C.LABEL_COLOR,
        npc.isInitialized and C.POSITIVE_COLOR or C.WARNING_COLOR)
    y = y - 0.022
    self:drawRow("NPC Count", tostring(npcCount), y, C.LABEL_COLOR, C.VALUE_COLOR)
    y = y - 0.022

    -- Show up to 6 NPCs with their relationship level
    if npc.activeNPCs and #npc.activeNPCs > 0 then
        y = y - 0.010
        self:drawSectionHeader("NEIGHBORS", y)
        y = y - 0.022

        local relNames = { "Hostile", "Unfriendly", "Neutral", "Friendly",
                           "Warm", "Close", "Best Friend" }

        for i = 1, math.min(6, #npc.activeNPCs) do
            local n    = npc.activeNPCs[i]
            local name = (n.name or "NPC #" .. i)
            if #name > 18 then name = name:sub(1, 15) .. "..." end

            local rel      = n.relationship or 0
            local relIdx   = math.max(1, math.min(7, math.floor(rel) + 1))
            local relLabel = relNames[relIdx] or "Unknown"

            local relColor = rel >= 4 and C.POSITIVE_COLOR or
                             rel >= 2 and C.VALUE_COLOR    or
                             rel >= 1 and C.LABEL_COLOR    or C.NEGATIVE_COLOR

            self:drawRow(name, relLabel, y, C.VALUE_COLOR, relColor)
            y = y - 0.021

            if y <= content.y + padY then break end
        end
    end
end
