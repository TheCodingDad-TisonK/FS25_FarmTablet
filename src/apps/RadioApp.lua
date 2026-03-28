-- =========================================================
-- FarmTablet v2 – Radio App
-- Controls the game's built-in internet radio player and
-- provides a guide for adding custom stations via the
-- player-profile streamingInternetRadios.xml file.
-- =========================================================

-- ── Drawer ────────────────────────────────────────────────

FarmTabletUI:registerDrawer(FT.APP.RADIO, function(self)
    local AC  = FT.appColor(FT.APP.RADIO)
    local s   = self.settings

    if self:drawHelpPage("_radioHelp", FT.APP.RADIO, "Radio", AC, {
        { title = "GAME RADIO CONTROLS",
          body  = "Toggles the game's built-in internet radio player.\n\n" ..
                  "RADIO ON/OFF — enable or disable the radio globally.\n" ..
                  "VEHICLE ONLY — when on, radio only plays while you\n" ..
                  "are seated inside a vehicle." },
        { title = "ADDING CUSTOM STATIONS",
          body  = "The game reads internet streams from:\n" ..
                  "Documents\\My Games\\FarmingSimulator2025\\\n" ..
                  "streamingInternetRadios.xml\n\n" ..
                  "Add any MP3 stream URL using the format shown\n" ..
                  "in the STATIONS GUIDE section of this app.\n" ..
                  "Restart the game after editing the file." },
    }) then return end

    local startY = self:drawAppHeader("Radio", "Game Radio Controls")
    local x, cy, cw, _ = self:contentInner()
    local y     = startY
    local BTN_H = FT.py(22)
    local GAP   = FT.py(6)

    -- ── Read current game radio state ─────────────────────
    local radioActive  = false
    local radioVehicle = false
    if g_settingsModel and SettingsModel and SettingsModel.SETTING then
        local okA, valA = pcall(function()
            return g_settingsModel:getValue(SettingsModel.SETTING.RADIO_IS_ACTIVE)
        end)
        if okA then radioActive = (valA == true) end
        local okV, valV = pcall(function()
            return g_settingsModel:getValue(SettingsModel.SETTING.RADIO_VEHICLE_ONLY)
        end)
        if okV then radioVehicle = (valV == true) end
    end

    -- ── CONTROLS section ──────────────────────────────────
    y = self:drawSection(y, "CONTROLS")
    y = y - GAP

    y = y - BTN_H
    local btnOn = self.r:button(x, y, cw, BTN_H,
        radioActive and "● RADIO: ON" or "○ RADIO: OFF",
        radioActive and FT.C.BTN_PRIMARY or FT.C.BTN_NEUTRAL, {
        onClick = function()
            if g_settingsModel and SettingsModel and SettingsModel.SETTING then
                pcall(function()
                    g_settingsModel:setValue(SettingsModel.SETTING.RADIO_IS_ACTIVE, not radioActive)
                end)
            end
        end
    })
    table.insert(self._contentBtns, btnOn)
    y = y - GAP

    y = y - BTN_H
    local btnVeh = self.r:button(x, y, cw, BTN_H,
        radioVehicle and "VEHICLE ONLY: YES" or "VEHICLE ONLY: NO",
        radioVehicle and FT.C.BTN_ACTIVE or FT.C.BTN_NEUTRAL, {
        onClick = function()
            if g_settingsModel and SettingsModel and SettingsModel.SETTING then
                pcall(function()
                    g_settingsModel:setValue(SettingsModel.SETTING.RADIO_VEHICLE_ONLY, not radioVehicle)
                end)
            end
        end
    })
    table.insert(self._contentBtns, btnVeh)
    self.r:appText(x + FT.px(2), y - FT.py(3),
        FT.FONT.TINY, "Radio only plays while seated inside a vehicle",
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    y = y - FT.py(14) - GAP

    -- ── STATIONS GUIDE section ────────────────────────────
    y = self:drawRule(y - FT.py(4), 0.3)
    y = y - FT.py(6)
    y = self:drawSection(y, "STATIONS GUIDE")
    y = y - GAP

    local info = {
        "Add streams to:",
        "Documents/My Games/FarmingSimulator2025/",
        "streamingInternetRadios.xml",
        "",
        "Format:",
        '<streamingInternetRadios>',
        '  <streamingInternetRadio',
        '    href="http://stream.url/mp3" />',
        '</streamingInternetRadios>',
        "",
        "Restart the game after editing.",
        "",
        "── Suggested streams ────────────────",
        "Groove Salad (Ambient):",
        "ice.somafm.com/groovesalad-256-mp3",
        "Country Roads:",
        "ice.somafm.com/countryroads-128-mp3",
        "Radio Paradise (Rock/Mix):",
        "stream.radioparadise.com/mp3-128",
        "WBGO Jazz 88.3:",
        "wbgo.streamguys.net/wbgo128",
        "BBC World Service:",
        "stream.live.vc.bbcmedia.co.uk/bbc_world_service",
    }

    for _, line in ipairs(info) do
        if y < cy + FT.py(6) then break end
        local color = FT.C.TEXT_DIM
        if line:sub(1,2) == "──" then
            color = AC
        elseif line:sub(1,1) == "<" or line:sub(1,2) == "  " then
            color = FT.C.TEXT_NORMAL
        elseif line:find("ice%.somafm") or line:find("radioparadise") or
               line:find("wbgo") or line:find("bbcmedia") then
            color = FT.C.MUTED
        end
        self.r:appText(x + FT.px(2), y, FT.FONT.TINY, line,
            RenderText.ALIGN_LEFT, color)
        y = y - FT.py(11)
    end

    self:drawInfoIcon("_radioHelp", AC)
end)
