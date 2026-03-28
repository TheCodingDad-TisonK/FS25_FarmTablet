-- =========================================================
-- FarmTablet v2 – Radio App
-- Streams live internet radio using FS25's built-in
-- createStreamedSample / loadStreamedSample engine API.
-- Music persists while the tablet is open or closed;
-- playback stops cleanly when the game session ends.
-- =========================================================

-- ── Station catalogue ─────────────────────────────────────
-- Free, publicly available HTTP MP3 streams.
-- Station URLs are correct at time of writing — check the
-- mod repo for updates if a stream stops connecting.
local STATIONS = {
    { name = "Groove Salad",   genre = "Ambient",      url = "http://ice.somafm.com/groovesalad-256-mp3"              },
    { name = "Lush",           genre = "Chillout",     url = "http://ice.somafm.com/lush-128-mp3"                     },
    { name = "Country Roads",  genre = "Country",      url = "http://ice.somafm.com/countryroads-128-mp3"             },
    { name = "Metal Detector", genre = "Metal",        url = "http://ice.somafm.com/metal-128-mp3"                    },
    { name = "Space Station",  genre = "Space",        url = "http://ice.somafm.com/spacestation-128-mp3"             },
    { name = "DEF CON Radio",  genre = "Electronic",   url = "http://ice.somafm.com/defcon-256-mp3"                   },
    { name = "Radio Paradise", genre = "Rock / Mix",   url = "http://stream.radioparadise.com/mp3-128"                },
    { name = "BBC World Svc",  genre = "News / Talk",  url = "http://stream.live.vc.bbcmedia.co.uk/bbc_world_service" },
    { name = "WBGO Jazz 88.3", genre = "Jazz",         url = "http://wbgo.streamguys.net/wbgo128"                     },
}

-- ── Module-level state ────────────────────────────────────
-- These survive tablet open/close so music keeps playing.
local _sampleId   = nil    -- streamed sample entity ID (nil or 0 = invalid)
local _stationIdx = 1      -- selected station (1-based)
local _volume     = 0.7    -- stream volume  0.0–1.0
local _playing    = false  -- is a stream currently active?

-- ── Streaming helpers ─────────────────────────────────────

local function _ensureSample()
    if _sampleId and _sampleId ~= 0 then return true end
    local ok, id = pcall(createStreamedSample, "FT_Radio", false)
    if ok and id and id ~= 0 then
        _sampleId = id
        return true
    end
    _sampleId = nil
    return false
end

local function _stopStream()
    if _sampleId and _sampleId ~= 0 then
        pcall(stopStreamedSample, _sampleId)
    end
    _playing = false
end

local function _startStream(idx)
    _stationIdx = ((idx - 1) % #STATIONS) + 1
    _stopStream()
    if not _ensureSample() then return end
    local st = STATIONS[_stationIdx]
    pcall(loadStreamedSample,      _sampleId, st.url)
    pcall(setStreamedSampleVolume, _sampleId, _volume)
    pcall(playStreamedSample,      _sampleId, -1)
    _playing = true
end

-- ── Cleanup on game session end ───────────────────────────
FSBaseMission.delete = Utils.prependedFunction(FSBaseMission.delete, function()
    if _sampleId and _sampleId ~= 0 then
        pcall(stopStreamedSample, _sampleId)
        _sampleId = nil
    end
    _playing = false
end)

-- ── Drawer ────────────────────────────────────────────────

FarmTabletUI:registerDrawer(FT.APP.RADIO, function(self)
    local AC = FT.appColor(FT.APP.RADIO)

    if self:drawHelpPage("_radioHelp", FT.APP.RADIO, "Radio", AC, {
        { title = "INTERNET RADIO",
          body  = "Streams live internet radio via FS25's audio engine.\n" ..
                  "Requires an active internet connection.\n" ..
                  "Music keeps playing after you close the tablet." },
        { title = "CONTROLS",
          body  = "◀ PREV / NEXT ▶  — cycle through 9 stations.\n" ..
                  "PLAY starts the selected stream.  STOP ends it.\n" ..
                  "VOL − and VOL + adjust stream volume in 10% steps." },
        { title = "STATIONS",
          body  = "Groove Salad · Lush · Country Roads · Metal\n" ..
                  "Space Station · DEF CON · Radio Paradise\n" ..
                  "BBC World Service · WBGO Jazz 88.3\n\n" ..
                  "Streams courtesy of SomaFM, Radio Paradise, BBC & WBGO." },
    }) then return end

    local startY = self:drawAppHeader("Radio",
        _playing and "● LIVE" or "○ Stopped")
    local x, contentY, cw, _ = self:contentInner()
    local y    = startY
    local minY = contentY + FT.py(8)
    local st   = STATIONS[_stationIdx]

    -- button row measurements (reused throughout)
    local btnH  = FT.py(22)
    local halfW = (cw - FT.px(4)) / 2

    -- ── Station card ──────────────────────────────────────
    y = y - FT.py(6)
    local cardH = FT.py(46)
    self.r:appRect(x - FT.px(4), y - cardH, cw + FT.px(8), cardH, FT.C.BG_CARD)
    self.r:appText(x + FT.px(8), y - FT.py(10),
        FT.FONT.HEADER, st.name, RenderText.ALIGN_LEFT,
        _playing and FT.C.TEXT_BRIGHT or FT.C.TEXT_DIM)
    self.r:appText(x + FT.px(8), y - FT.py(26),
        FT.FONT.SMALL, st.genre .. "  ·  " .. _stationIdx .. " / " .. #STATIONS,
        RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    self.r:appText(x + FT.px(8), y - FT.py(40),
        FT.FONT.TINY, st.url, RenderText.ALIGN_LEFT, FT.C.MUTED)
    y = y - cardH - FT.py(6)

    -- ── Prev / Next ───────────────────────────────────────
    self.r:button(x, y - btnH, halfW, btnH, "◀  PREV", FT.C.BTN_NEUTRAL, {
        onClick = function()
            local prev = ((_stationIdx - 2) % #STATIONS) + 1
            if _playing then _startStream(prev) else _stationIdx = prev end
        end
    })
    self.r:button(x + halfW + FT.px(4), y - btnH, halfW, btnH, "NEXT  ▶", FT.C.BTN_NEUTRAL, {
        onClick = function()
            local nxt = (_stationIdx % #STATIONS) + 1
            if _playing then _startStream(nxt) else _stationIdx = nxt end
        end
    })
    y = y - btnH - FT.py(6)

    -- ── Play / Stop ───────────────────────────────────────
    self.r:button(x, y - btnH, halfW, btnH, "▶  PLAY",
        _playing and FT.C.BTN_NEUTRAL or FT.C.BTN_PRIMARY, {
        onClick = function()
            if not _playing then _startStream(_stationIdx) end
        end
    })
    self.r:button(x + halfW + FT.px(4), y - btnH, halfW, btnH, "■  STOP",
        _playing and FT.C.BTN_DANGER or FT.C.BTN_NEUTRAL, {
        onClick = function()
            _stopStream()
        end
    })
    y = y - btnH - FT.py(6)

    -- ── Volume ────────────────────────────────────────────
    local volBtnW = FT.px(56)
    local barX    = x + volBtnW + FT.px(6)
    local barW    = cw - volBtnW * 2 - FT.px(12)
    local volPct  = math.floor(_volume * 100 + 0.5)

    self.r:button(x, y - btnH, volBtnW, btnH, "VOL −", FT.C.BTN_NEUTRAL, {
        onClick = function()
            _volume = math.max(0.0, _volume - 0.1)
            if _sampleId and _sampleId ~= 0 then
                pcall(setStreamedSampleVolume, _sampleId, _volume)
            end
        end
    })
    self.r:button(x + volBtnW + barW + FT.px(12), y - btnH, volBtnW, btnH, "VOL +", FT.C.BTN_NEUTRAL, {
        onClick = function()
            _volume = math.min(1.0, _volume + 0.1)
            if _sampleId and _sampleId ~= 0 then
                pcall(setStreamedSampleVolume, _sampleId, _volume)
            end
        end
    })
    -- Volume bar + percentage centred between the two buttons
    local barMidY = y - btnH + (btnH * 0.5)
    self.r:progressBar(barX, barMidY, barW, volPct, 100, FT.C.BRAND)
    self.r:appText(barX + barW * 0.5, barMidY + FT.py(9),
        FT.FONT.TINY, volPct .. "%", RenderText.ALIGN_CENTER, FT.C.TEXT_NORMAL)
    y = y - btnH - FT.py(8)

    -- ── Station list ──────────────────────────────────────
    if y > minY + FT.py(14) then
        self.r:appText(x, y, FT.FONT.TINY, "ALL STATIONS",
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        y = y - FT.py(14)
        for i, station in ipairs(STATIONS) do
            if y < minY then break end
            self.r:appText(x + FT.px(4), y, FT.FONT.TINY,
                string.format("%d.  %-16s [%s]", i, station.name, station.genre),
                RenderText.ALIGN_LEFT,
                (i == _stationIdx) and AC or FT.C.TEXT_DIM)
            y = y - FT.py(12)
        end
    end

    self:drawInfoIcon("_radioHelp", AC)
end)
