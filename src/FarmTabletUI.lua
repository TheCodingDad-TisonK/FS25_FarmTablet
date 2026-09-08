-- =========================================================
-- FarmTablet v2 – FarmTabletUI  (real-tablet overhaul)
--   • Tablet OS state machine: LOCK → HOME (springboard) → APP
--   • Glossy baked app icons (FT_Icons) on a springboard grid + dock
--   • 3D frame: layered shadow, body gradient, screen gloss, status bar,
--     home indicator, hardware buttons
--   • Tablet behaviour: slide-to-unlock, press-down feedback, launch zoom
--   • All app drawers untouched — they render into FT.LAYOUT.content* which
--     becomes the full screen in APP state.
-- =========================================================
---@class FarmTabletUI
FarmTabletUI = FarmTabletUI or {}
local FarmTabletUI_mt = Class(FarmTabletUI)

-- ── Frame / layout constants (reference px @ FT.REF_W x FT.REF_H) ──
local BEZEL_REF    = 40    -- tablet bezel thickness
local STATUS_H_REF = 28    -- top status bar height
local APPBAR_H_REF = 36    -- in-app top bar height
local DOCK_H_REF   = 78    -- springboard dock height
local HOMEIND_REF  = 10    -- home-indicator strip height

-- ── Dock favourites (always-present built-ins) ───────────
local DOCK_APPS = { "dashboard", "weather", "app_store", "settings" }

local function ftUiText(key, fallback)
    if g_i18n and key and g_i18n:hasText(key) then
        return g_i18n:getText(key)
    end
    return fallback or tostring(key or "")
end
FT_UI_TEXT = FT_UI_TEXT or ftUiText

local function ftUiFormat(key, fallback, ...)
    local text = ftUiText(key, fallback)
    local ok, result = pcall(string.format, text, ...)
    if ok then return result end
    return tostring(text)
end

local function ftClampBattery(v)
    v = tonumber(v) or 100
    if v < 0 then return 0 end
    if v > 100 then return 100 end
    return v
end


-- Axis-aligned hit test for a {x,y,w,h} rect. Defined here (top of file) so it
-- is in scope for every mouse handler below — the provider/battery handlers are
-- declared before the dispatch section and would otherwise see a nil global.
local function hit(b, px, py)
    return b and px >= b.x and px <= b.x + b.w and py >= b.y and py <= b.y + b.h
end

-- BUILD 15:39 (PB-02). A control marked `enabled = false` is drawn dimmed and is
-- inert: it is still hit-tested so the click is swallowed rather than falling
-- through to whatever is behind it, but it fires no action, sound or animation.
-- Declared after `hit` on purpose: an upvalue has to already exist to be closed
-- over, and in Lua 5.1 a forward reference here would silently read a nil global.
local function hitLive(b, px, py)
    return b ~= nil and b.enabled ~= false and hit(b, px, py)
end

local function hitInert(b, px, py)
    return b ~= nil and b.enabled == false and hit(b, px, py)
end

-- ── Nav-glyph helpers (#90) ──────────────────────────────
-- The renderer only draws axis-aligned rects, so the Back arrow and Home
-- house are approximated with a short stack of rects. Sizes are passed in
-- already-normalised (the caller converts via FT.px / FT.py).
--
-- NOTE: coordinates are normalised (0..1), so the stacking dimension uses a
-- fractional half-step overlap (step * 1.5) to avoid hairline gaps — never a
-- literal "+1", which would add a full screen width/height.
local GLYPH_STEPS = 6

-- Left-pointing filled triangle: short tip at (tipX, cy), widening to the
-- right over width w and total height h. Used as the Back arrowhead.
local function drawTriLeft(r, tipX, cy, w, h, color)
    local step = w / GLYPH_STEPS
    for i = 0, GLYPH_STEPS - 1 do
        local colH = h * (i + 1) / GLYPH_STEPS
        r:rect(tipX + i * step, cy - colH / 2, step * 1.5, colH, color)
    end
end

-- Up-pointing filled triangle: full-width base at baseY, narrowing to an apex
-- h above it (screen Y increases upward). Used as the Home roof.
local function drawTriUp(r, cx, baseY, w, h, color)
    local step = h / GLYPH_STEPS
    for i = 0, GLYPH_STEPS - 1 do
        local rowW = w * (1 - i / GLYPH_STEPS)
        r:rect(cx - rowW / 2, baseY + i * step, rowW, step * 1.5, color)
    end
end

-- 4-point star / sparkle (the Favourites glyph): four spikes of length `len`
-- and base half-width `halfW`, all sharing the centre (cx, cy). Each spike is
-- a tapering stack of rects, so the four overlap into a solid star core.
local function drawStar(r, cx, cy, len, halfW, color)
    local s = len / GLYPH_STEPS
    for i = 0, GLYPH_STEPS - 1 do
        local hw = halfW * (1 - i / GLYPH_STEPS)   -- taper toward each apex
        r:rect(cx - hw,         cy + i * s,        hw * 2,   s * 1.5, color)  -- up
        r:rect(cx - hw,         cy - i * s - s,    hw * 2,   s * 1.5, color)  -- down
        r:rect(cx + i * s,      cy - hw,           s * 1.5,  hw * 2,  color)  -- right
        r:rect(cx - i * s - s,  cy - hw,           s * 1.5,  hw * 2,  color)  -- left
    end
end

function FarmTabletUI.new(settings, system, modDirectory)
    local self = setmetatable({}, FarmTabletUI_mt)
    self.settings     = settings
    self.system       = system
    self.modDirectory = modDirectory or ""
    self.r        = FT_Renderer.new()
    self.isOpen   = false

    -- Initialise the baked-icon cache for this mod directory.
    if FT_Icons and FT_Icons.init then FT_Icons.init(self.modDirectory) end

    -- Tablet OS state: "lock" | "home" | "app"
    self.uiState  = "home"
    self._page    = 0       -- current springboard page (0-based)
    self._pageCount = 1

    -- Per-frame hover / press tracking
    self._mouseX  = 0
    self._mouseY  = 0
    self._pressedIcon = nil  -- appId currently pressed (for depress feedback)
    self._pressedRect = nil
    self._pressMoved  = false

    -- Named persistent hitboxes
    self._closeBtn    = nil
    self._powerBtn    = nil
    self._homeBtn     = nil
    self._backBtn     = nil
    self._unlockBtn   = nil
    self._iconBtns    = {}   -- springboard grid {appId,x,y,w,h}
    self._dockBtns    = {}   -- dock {appId,x,y,w,h}
    self._pageDots    = {}   -- {x,y,w,h,page}
    self._contentBtns = {}   -- app-specific, cleared per switch
    self._iconQueue   = {}   -- {appId,x,y,size,mono} rendered in draw()
    self._appCellRects = {}  -- appId -> {x,y,w,h} (for launch/home zoom)

    -- Slide-to-unlock state
    self._unlockTrack = nil  -- {x,y,w,h}
    self._unlockKnobX = nil  -- current knob left-x while dragging
    self._unlockDragging = false

    -- Content area scroll state (per-app, reset on app switch)
    self._contentScrollY      = 0
    self._contentScrollTarget = 0
    self._contentScrollMax    = 0
    self._contentScrollStep   = FT.py and FT.py(46) or 0.036
    self._contentScrollMoving = false

    -- Animation (transient overlay drawn on top of the built screen)
    self._anim    = nil      -- {kind, t, dur, data}
    self._fx      = nil      -- reusable plain-colour overlay for fades/curtains

    -- Battery and mobile-network systems are local tablet flavour only.
    self._battery    = math.max(0, math.min(100, tonumber(settings.tabletBatteryLevel) or 100))
    self._sessionSec = 0
    self._batteryStart = nil
    self._batteryDrainMs = math.max(0, tonumber(settings.tabletBatteryDrainMs) or 0)
    self._lastBatteryRealMs = nil
    self._lastBatterySaveMs = nil
    self._batteryEmpty = false
    self._batteryChargeBtn = nil
    self._batteryCharging = false
    self._batteryChargeTimer = 0
    self._batteryChargeLastMs = nil
    self._batteryChargeStartLevel = nil
    self._batteryChargeNotifyUsable = false
    self._batteryChargeNotifyFull = false
    self._batteryEmptyOpenBlockedLastMs = nil

    -- Physical charging-station support (see setAtCharger).
    self._batteryChargeRateMs = 6000   -- ms per 1%: in-tablet self-charge default (station sets 3000)
    self._atPhysicalCharger   = false  -- true while the local player stands on a charging-station pad
    self._chargeLightState    = false  -- last honest station-light state sent to the placeable

    self._signalBars = 4
    self._signalLabel = "Realistic Farming Mobile"
    self._signalState = "ok"
    self._signalTimer = 0
    self._signalOutageActive = false
    self._signalOutageEndMin = nil
    self._signalNextCheckMin = nil
    self._signalNextCheckStartMin = nil
    self._signalNextCheckDelayMin = nil
    self._signalLastNotify = nil
    self._signalLastState = nil
    self._signalOutageFrequency = "off"
    self._signalOutageDurationHours = 2
    self._signalOfflineDataFrozen = false
    self._signalFrozenStatusTime = nil
    self._signalFrozenWorldInfo = nil
    self._signalProviderSelected = false
    self._signalProvider = nil
    self._signalProviderId = nil
    self._signalProviders = {
        { id = "realistic_farming", name = "Realistic Farming Mobile", bias = 0.85, dailyFee = 5 },
        { id = "landnetz", name = "LandNetz", bias = 0.10, dailyFee = 2 },
        { id = "agraconnect", name = "AgraConnect", bias = 0.35, dailyFee = 4 },
        { id = "rurallink", name = "RuralLink", bias = -0.05, dailyFee = 3 },
    }
    self._providerBtns = {}
    self._providerConfirmBtn = nil
    self._providerPending = nil
    self._providerBillingDays = {}

    -- Tablet display repair system (local flavour, persisted in modSettings).
    -- It never touches gameplay/savegame files; on dedicated servers the UI just
    -- renders the same persisted local status.
    self._tabletRepairActive = false
    self._tabletRepairStartMin = nil
    self._tabletRepairEndMin = nil
    self._tabletRepairInStock = true
    self._tabletRepairNotifiedDone = false
    self._tabletRepairLastDropDay = -1
    self._tabletRepairCloseBtn = nil
    self._tabletRepairOpenedAt = 0
    self._tabletRepairFrequency = "off" -- Aus / Selten / Normal / Häufig; default OFF

    -- Provider selection is persistent and stored in modSettings, not in the savegame.
    -- This keeps the first-run choice across sessions while staying local/dedi-safe.
    self:_loadSignalProviderSelection()

    -- Camera lock while tablet is open (normal mode)
    self._tabletCamRotX = nil
    self._tabletCamRotY = nil
    self._tabletCamRotZ = nil

    -- ── Edit mode (resize/move) — state used by FarmTabletUIEditMode.lua ──
    self._editModeActive  = false
    self._editBgOverlay   = nil
    self._editAnimTimer   = 0
    self._emDragging      = false
    self._emDragOffX      = 0
    self._emDragOffY      = 0
    self._emResizing      = false
    self._emResizeStartX  = 0
    self._emResizeStartY  = 0
    self._emResizeStartS  = 1.0
    self._emHoverCorner   = nil
    self._emEdgeDragging  = nil
    self._emEdgeStartX    = 0
    self._emEdgeStartW    = 1.0
    self._emCamRotX = nil
    self._emCamRotY = nil
    self._emCamRotZ = nil
    self.EM_HANDLE_SIZE  = 0.010
    self.EM_MIN_SCALE    = 0.5
    self.EM_MAX_SCALE    = 2.0
    self.EM_MIN_WIDTH    = 0.5
    self.EM_MAX_WIDTH    = 2.0

    return self
end

-- ─────────────────────────────────────────────────────────
-- OPEN / CLOSE / TOGGLE
-- ─────────────────────────────────────────────────────────


function FarmTabletUI:_persistBattery(force)
    if self.settings == nil then return end
    self.settings.tabletBatteryLevel = math.floor(ftClampBattery(self._battery))
    self.settings.tabletBatteryDrainMs = math.max(0, tonumber(self._batteryDrainMs) or 0)

    -- Akkuwerte werden im Hintergrund gespeichert. Das darf nicht als normale
    -- Settings-Speicherung ins Log gespammt werden. Außerdem schreiben wir nicht
    -- bei jedem Prozent sofort wieder die XML, sondern höchstens selten bzw. beim
    -- Schließen/Laden erzwungen.
    local now = self:_getBatteryRealTimeMs()
    if force == true or self._lastBatterySaveMs == nil or (now - self._lastBatterySaveMs) >= 60000 then
        self._lastBatterySaveMs = now
        if self.settings.save then
            pcall(function() self.settings:save(true) end)
        end
    end
end

function FarmTabletUI:_getBatteryRealTimeMs()
    -- g_time ist echte Engine-Zeit in ms und nicht mit der Ingame-Zeitskalierung
    -- multipliziert. Dadurch kann ein hoher TimeScale den Akku nicht mehr in ein
    -- paar Sekunden leeren. Fallbacks sind nur zur Sicherheit.
    if g_time ~= nil then
        local t = tonumber(g_time)
        if t ~= nil then return t end
    end
    if getTimeSec ~= nil then
        local ok, t = pcall(getTimeSec)
        if ok and tonumber(t) ~= nil then return tonumber(t) * 1000 end
    end
    if os ~= nil and os.clock ~= nil then
        return os.clock() * 1000
    end
    return 0
end

function FarmTabletUI:_getTabletBatteryDrainStepMs()
    if self._tabletRepairActive == true or self.uiState == "repair" or self.uiState == "provider" or self.uiState == "empty" then
        return nil
    end
    local s = self.settings or {}
    local mode = tostring(s.tabletBatteryDrainMode or (s.tabletBatteryDrainEnabled == false and "off" or "standby"))
    if mode == "off" or s.tabletBatteryDrainEnabled == false then return nil end
    if not self.isOpen and mode == "open" then return nil end

    local profile = tostring(s.tabletBatteryDrainProfile or "normal")
    local openMin, standbyMin = 10, 15
    if profile == "low" then
        openMin, standbyMin = 20, 45
    elseif profile == "high" then
        openMin, standbyMin = 5, 10
    elseif profile == "custom" then
        openMin = math.max(5, math.min(60, tonumber(s.tabletBatteryOpenMinutes) or 10))
        standbyMin = math.max(5, math.min(180, tonumber(s.tabletBatteryStandbyMinutes) or 15))
    end
    local minutes = self.isOpen and openMin or standbyMin
    return math.max(60000, minutes * 60000)
end

function FarmTabletUI:_getSafeTimeScale()
    local ts = nil
    if g_currentMission ~= nil then
        if g_currentMission.missionInfo ~= nil then
            ts = tonumber(g_currentMission.missionInfo.timeScale)
        end
        if ts == nil then ts = tonumber(g_currentMission.timeScale) end
    end
    if ts == nil or ts <= 0 then ts = 1 end
    if ts > 360 then ts = 360 end
    return ts
end

function FarmTabletUI:_getSafeDtMs(dt)
    -- Nicht mehr den übergebenen dt für den Akku benutzen. Bei manchen Kombinationen
    -- aus Zeitskalierung/Mod-Hooks kommt dort bereits Ingame-Zeit oder ein großer
    -- Wert an. Das war die Ursache für 10%+ Akkuverlust in wenigen Sekunden.
    local now = self:_getBatteryRealTimeMs()
    if self._lastBatteryRealMs == nil or self._lastBatteryRealMs <= 0 then
        self._lastBatteryRealMs = now
        return 0
    end
    local elapsed = now - self._lastBatteryRealMs
    self._lastBatteryRealMs = now
    if elapsed < 0 then elapsed = 0 end
    -- Lags/Alt-Tab/Schlafen sollen nicht nachträglich den Akku leerziehen.
    if elapsed > 5000 then elapsed = 5000 end
    return elapsed
end


function FarmTabletUI:_getBatteryMinStartLevel()
    local s = self.settings or {}
    return math.max(5, math.min(50, tonumber(s.tabletBatteryMinStartLevel) or 15))
end

function FarmTabletUI:_formatBatteryChargeProgress()
    local pct = math.floor(ftClampBattery(self._battery or 0))
    local filled = math.floor((pct + 5) / 10)
    if filled < 0 then filled = 0 elseif filled > 10 then filled = 10 end
    local bar = string.rep("#", filled) .. string.rep("-", 10 - filled)
    return string.format("%d%% [%s]", pct, bar)
end

--- BUILD 15:39 (PB-12). The one place that answers "what key opens the tablet",
--- read live from the binding rather than from a hardcoded string. Falls back to
--- the shipped default label, which is the same chord modDesc binds.
function FarmTabletUI:_keybindLabel()
    local handler = g_FarmTablet ~= nil and g_FarmTablet.inputHandler or nil
    if handler ~= nil and handler.getKeybindString ~= nil then
        local ok, label = pcall(handler.getKeybindString, handler)
        if ok and type(label) == "string" and label ~= "" then
            return label
        end
    end
    return (InputHandler ~= nil and InputHandler.DEFAULT_KEY_LABEL) or "Right Ctrl + T"
end

function FarmTabletUI:_notifyBattery(titleKey, titleFallback, msgKey, msgFallback, withProgress, ...)
    local title = ftUiText(titleKey or "ft_battery_service_title", titleFallback or "Tablet battery")
    local msg = ftUiText(msgKey or "ft_battery_charging_info", msgFallback or "Tablet is charging.")
    -- Optional format arguments (e.g. the live keybind). string.format is only
    -- reached when the caller passed some, so existing call sites are untouched
    -- and a translation without a placeholder still renders verbatim.
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, msg, ...)
        if ok then msg = formatted end
    end
    if withProgress == true then
        msg = msg .. " " .. self:_formatBatteryChargeProgress()
    end
    self._signalToast = { title = title, msg = msg, time = 5200 }
    local text = title .. ": " .. msg
    if g_currentMission ~= nil and g_currentMission.addIngameNotification ~= nil then
        local typ = (FSBaseMission and (FSBaseMission.INGAME_NOTIFICATION_INFO or FSBaseMission.INGAME_NOTIFICATION_OK or FSBaseMission.INGAME_NOTIFICATION_CRITICAL)) or 1
        pcall(function() g_currentMission:addIngameNotification(typ, text) end)
    elseif g_currentMission ~= nil and g_currentMission.hud ~= nil and g_currentMission.hud.showBlinkingWarning ~= nil then
        pcall(function() g_currentMission.hud:showBlinkingWarning(text, 5000) end)
    elseif g_FarmTablet ~= nil and g_FarmTablet.showNotification ~= nil then
        pcall(function() g_FarmTablet:showNotification(title, msg) end)
    end
end

function FarmTabletUI:_forceCloseForBattery()
    if not self.isOpen then return end
    self.isOpen = false
    if self.system ~= nil then self.system.isTabletOpen = false end
    self._anim = nil
    self:_destroy()
    if self.system ~= nil and self.system.onTabletClosed ~= nil then
        pcall(function() self.system:onTabletClosed() end)
    end
    if g_currentMission ~= nil then
        pcall(function() g_currentMission:removeDrawable(self) end)
        if self._mouseListener ~= nil then
            pcall(function() removeModEventListener(self._mouseListener) end)
            self._mouseListener = nil
        end
    end
    if g_inputBinding ~= nil and g_inputBinding.setShowMouseCursor ~= nil then
        pcall(function() g_inputBinding:setShowMouseCursor(false) end)
    end
    self._tabletCamRotX = nil
    self._tabletCamRotY = nil
    self._tabletCamRotZ = nil
    if FarmTabletFocus then FarmTabletFocus:setFocus(false, nil) end
end

function FarmTabletUI:_updateBatterySystem(dt)
    if self._batteryCharging then return false end
    self._battery = ftClampBattery(self._battery)
    local drainStepMs = self:_getTabletBatteryDrainStepMs()
    if drainStepMs == nil then
        -- Timer zuruecksetzen, damit nach Profilwechsel kein alter Rest sofort 1% frisst.
        self._lastBatteryRealMs = self:_getBatteryRealTimeMs()
        return false
    end

    local old = math.floor(self._battery or 0)

    self._batteryDrainMs = tonumber(self._batteryDrainMs) or 0
    if self._batteryDrainMs < 0 or self._batteryDrainMs > drainStepMs then
        self._batteryDrainMs = self._batteryDrainMs % drainStepMs
    end

    self._batteryDrainMs = self._batteryDrainMs + self:_getSafeDtMs(dt)

    -- Maximal 1 Prozent pro Update-Tick abziehen. Dadurch kann ein kurzer Lag,
    -- Schlafen oder ein großer dt-Wert den Akku nicht schlagartig leeren.
    if self._batteryDrainMs >= drainStepMs and (self._battery or 0) > 0 then
        self._batteryDrainMs = self._batteryDrainMs - drainStepMs
        self._battery = math.max(0, (tonumber(self._battery) or 100) - 1)
    end

    local now = math.floor(self._battery or 0)
    if now ~= old then
        self.settings.tabletBatteryLevel = now
        self.settings.tabletBatteryDrainMs = self._batteryDrainMs
        self:_persistBattery(false)
        if now <= 0 then
            self._batteryEmpty = true
            self:_forceCloseForBattery()
            self:_startBatteryCharge(true)
            self:_notifyBattery("ft_battery_service_title", "Tablet-Akku", "ft_battery_empty_auto_charge", "Tablet-Akku leer. Tablet ist am Ladegerät.", true)
        end
        return true
    end
    return false
end

function FarmTabletUI:_openTabletBody()
    if not self.settings.enabled or self.isOpen then return end
    self._lastBatteryRealMs = nil

    -- Wenn das Display in Reparatur ist, darf das Tablet gar nicht erst öffnen.
    -- T zeigt nur eine Spielmeldung. Sobald die Reparatur fertig ist, kommt eine
    -- Meldung und das Tablet kann wieder normal mit T geöffnet werden.
    self:_updateTabletRepairSystem(0, true)
    if self._tabletRepairActive == true then
        local nowMs = tonumber(g_time) or 0
        if self._tabletRepairOpenBlockedLastMs == nil or (nowMs - self._tabletRepairOpenBlockedLastMs) > 2500 then
            self._tabletRepairOpenBlockedLastMs = nowMs
            self:_notifyTabletRepair(ftUiText("ft_repair_open_blocked_msg", "Tablet in repair. We will notify you when it is delivered again."))
        end
        self.isOpen = false
        if self.system ~= nil then self.system.isTabletOpen = false end
        return
    end

    self._battery = ftClampBattery(self.settings.tabletBatteryLevel or self._battery or 100)
    if (self._battery or 0) <= 0 then
        self:_startBatteryCharge(true)
    end
    if self._batteryCharging == true and (self._battery or 0) < self:_getBatteryMinStartLevel() then
        local nowMs = self:_getBatteryRealTimeMs()
        if self._batteryEmptyOpenBlockedLastMs == nil or (nowMs - self._batteryEmptyOpenBlockedLastMs) > 2500 then
            self._batteryEmptyOpenBlockedLastMs = nowMs
            self:_notifyBattery("ft_battery_service_title", "Tablet-Akku", "ft_battery_charging_locked", "Tablet am Ladegerät. Einschalten ab 15% möglich.", true)
        end
        self.isOpen = false
        if self.system ~= nil then self.system.isTabletOpen = false end
        return
    end
    if self._batteryCharging == true and (self._battery or 0) >= self:_getBatteryMinStartLevel() then
        -- Beim Öffnen wird das Tablet vom Ladegerät genommen. Der aktuelle Akkustand bleibt erhalten.
        self._batteryCharging = false
        self._batteryChargeLastMs = nil
        self._batteryDrainMs = 0
        self:_persistBattery(true)
    end

    self.isOpen = true
    self.system.isTabletOpen = true
    self.system.registry:autoDetect()

    -- Fresh session: first choose a local mobile provider, then continue to lock/home.
    if not self._signalProviderSelected then
        self.uiState = "provider"
        self._providerPending = self._providerPending or ((self._signalProviders and self._signalProviders[1]) or { id = "realistic_farming", name = "Realistic Farming Mobile", bias = 0.35 })
    elseif self.settings.lockScreenEnabled ~= false then
        self.uiState = "lock"
    else
        self.uiState = "home"
    end
    self._page        = 0
    self._homeMode    = "springboard"   -- always start on the full springboard
    self._favEditing  = false
    self._sessionSec  = 0
    if self._tabletRepairTargetMs == nil then self:_resetTabletRepairUseTimer() end
    self._battery = ftClampBattery(self.settings.tabletBatteryLevel or self._battery or 100)
    self._batteryDrainMs = math.max(0, tonumber(self.settings.tabletBatteryDrainMs or self._batteryDrainMs) or 0)
    self._lastBatteryRealMs = nil
    self._batteryStart = self._battery
    self._batteryEmpty = (self._battery or 0) <= 0
    self._batteryCharging = false
    self._batteryChargeTimer = 0
    if self._batteryEmpty and self.uiState ~= "repair" then self.uiState = "empty" end
    self._unlockKnobX = nil
    self._unlockDragging = false
    self._pressedIcon = nil

    -- Reusable plain-colour overlay for fades / curtains.
    if g_overlayManager and g_plainColorSliceId and not self._fx then
        self._fx = g_overlayManager:createOverlay(g_plainColorSliceId, 0, 0, 1, 1)
    end

    self:_build()

    if self.settings.soundOnTabletToggle ~= false then
        self:playUISound("paging")
    end

    if g_currentMission then
        g_currentMission:addDrawable(self)
    end

    if g_inputBinding then
        g_inputBinding:setShowMouseCursor(true)
        self._mouseListener = {_ui = self}
        -- BUILD 06:33 (Vera 8b FAILFIX). This listener ROUTES the mouse to the
        -- tablet's hit tests. It does not, and cannot, consume it: BaseMission
        -- fans mouseEvent out to `g_modEventListeners` and ignores what each
        -- listener returns, and it passes no `eventUsed` argument, so the
        -- previous "swallow the leftovers by returning true" was a door that
        -- never opened - a wallpaper drag still panned the camera behind the
        -- screen. What actually holds the camera is the FT_TABLET_MODAL input
        -- context, claimed at the end of this open so the bound look axes are
        -- already inactive on the first painted frame, with the per-frame
        -- `setRotation` snap in `update()` as the belt. The return value is kept
        -- honest for any listener chain that does read it.
        function self._mouseListener:mouseEvent(posX, posY, isDown, isUp, button)
            local ui = self._ui
            return ui:_onMouse(posX, posY, isDown, isUp, button) == true
        end
        addModEventListener(self._mouseListener)
    end

    if g_cameraManager and getRotation then
        local cam = g_cameraManager:getActiveCamera()
        if cam and cam ~= 0 then
            self._tabletCamRotX, self._tabletCamRotY, self._tabletCamRotZ = getRotation(cam)
        end
    end

    -- "Screen-on" wake animation
    self:_startAnim("wake", 360)

    FT_EventBus:emit(FT_EventBus.EVENTS.TABLET_OPENED)
    -- The tablet opens onto the lock screen, not an app, so no app is focused.
    if FarmTabletFocus then FarmTabletFocus:setFocus(true, nil) end

    -- BUILD 06:33 (Vera 8b FAILFIX). Claim the world HERE, at the end of a fully
    -- successful open and before the first paint. The claim used to be taken
    -- from update() on the frame after `_paintedOnce`, which left a window with
    -- the tablet on screen and the player's bindings still live: `InputAction.MENU`
    -- (-> onInputToggleMenu -> g_gui:changeScreen(nil, InGameMenu)) could open
    -- the pause menu behind the tablet, and the look axes could still be driven.
    -- `setContext(FT_TABLET_MODAL, true, false)` opens a new non-sub context, so
    -- both go inactive the moment it lands.
    --
    -- The old timing existed to stop a half-finished open from muting the world
    -- with nothing drawn over it. That is preserved without the window: this is
    -- the LAST statement of the open body, so the repair and battery gates above
    -- return before it, and `openTablet` pcalls this body and hands everything
    -- back through `_releaseClaims` if anything above throws.
    if FarmTabletModal ~= nil then
        FarmTabletModal.claim(self)
    end
end

--- BUILD 10:50, claim discipline.
---
--- Opening the tablet claims two things that belong to everybody: the mouse
--- cursor, and the MasterHUD fullscreen slot, which the bridge derives from
--- `ui.isOpen` and which HIDES EVERY OTHER HUD while it is set. Both used to be
--- claimed part way through a long open, so a throw anywhere after `isOpen = true`
--- left the player with no tablet AND no other HUD, and no way back except
--- pressing the key again.
---
--- The open body is unchanged. It is simply not allowed to fail halfway and keep
--- the claims: on any error everything it may have taken is handed back.
function FarmTabletUI:_releaseClaims()
    self.isOpen = false
    self._paintedOnce = false
    if self.system ~= nil then
        self.system.isTabletOpen = false
    end

    -- BUILD 15:39 (PB-03). The input context and the vanilla HUD are claimed
    -- together and handed back together. An open that threw must not leave the
    -- world muted with nothing drawn over it.
    if FarmTabletModal ~= nil then
        FarmTabletModal.release(false)
    end

    if g_currentMission ~= nil then
        if FTMasterHUDBridge == nil or not FTMasterHUDBridge.active then
            pcall(function() g_currentMission:removeDrawable(self) end)
        end
        if self._mouseListener ~= nil then
            pcall(function() removeModEventListener(self._mouseListener) end)
            self._mouseListener = nil
        end
    end

    if g_inputBinding ~= nil and g_inputBinding.setShowMouseCursor ~= nil then
        pcall(function() g_inputBinding:setShowMouseCursor(false) end)
    end
end

function FarmTabletUI:openTablet()
    local ok, err = pcall(FarmTabletUI._openTabletBody, self)
    if ok then
        return
    end

    self:_releaseClaims()

    if not FarmTabletUI._loggedOpenFailure then
        FarmTabletUI._loggedOpenFailure = true
        Logging.warning("[FarmTablet v2] tablet did not open, claims released: %s", tostring(err))
    end
end

function FarmTabletUI:closeTablet()
    if not self.isOpen then return end

    self:_maybeTriggerTabletDropOnClose()

    if self.settings.soundOnTabletToggle ~= false then
        self:playUISound("back")
    end

    self.isOpen = false
    self._paintedOnce = false
    self.system.isTabletOpen = false
    self._anim = nil
    self:_destroy()

    -- Give the world back before anything else: input context and vanilla HUD
    -- (PB-03 / PB-10). Harmless when the Escape ladder already released with a
    -- one-frame deferred context revert - that defer is preserved.
    if FarmTabletModal ~= nil then
        FarmTabletModal.release(false)
    end

    if self.system.onTabletClosed then
        self.system:onTabletClosed()
    end

    if g_currentMission then
        g_currentMission:removeDrawable(self)
        if self._mouseListener then
            removeModEventListener(self._mouseListener)
            self._mouseListener = nil
        end
    end
    if g_inputBinding then
        g_inputBinding:setShowMouseCursor(false)
    end

    self._tabletCamRotX = nil
    self._tabletCamRotY = nil
    self._tabletCamRotZ = nil

    self:_persistBattery(true)

    FT_EventBus:emit(FT_EventBus.EVENTS.TABLET_CLOSED)
    if FarmTabletFocus then FarmTabletFocus:setFocus(false, nil) end
end

function FarmTabletUI:toggleTablet()
    -- Wenn das Display in Reparatur ist, darf T den Reparaturbildschirm nicht
    -- sofort wieder schließen. Geschlossen wird dort nur über den sichtbaren
    -- Button, damit Text und Button stabil stehen bleiben.
    if self.isOpen and self.uiState == "repair" then
        return
    end
    if self.isOpen then self:closeTablet() else self:openTablet() end
end

-- ─────────────────────────────────────────────────────────
-- NAVIGATION (state transitions)
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:unlock()
    if (self._battery or 0) <= 0 then
        self._batteryEmpty = true
        self.uiState = "empty"
        self:_rebuildScreen()
        return
    end
    if self.uiState ~= "lock" then return end
    self.uiState = "home"
    self._unlockDragging = false
    self._unlockKnobX = nil
    self:_rebuildScreen()
    self:_startAnim("unlock", 300)
    if self.settings.soundOnTabletToggle ~= false then self:playUISound("paging") end
    -- Unlock lands on the home grid, not an app, so no app is focused.
    if FarmTabletFocus then FarmTabletFocus:setFocus(true, nil) end
end

function FarmTabletUI:lockNow()
    self.uiState = "lock"
    self._unlockKnobX = nil
    self._unlockDragging = false
    self:_rebuildScreen()
    self:_startAnim("lock", 200)
    self:playUISound("back")
end

--- Home: go all the way back to the app grid root. From an app this is the zoom
--- back into the app's own cell. From the grid it is a jump to springboard page
--- one, with no zoom, because there is no icon to fly back to.
function FarmTabletUI:goHome()
    -- BUILD 16:25 (PB-02, 2b): entering the home state drops any live press.
    -- Both branches below land on the grid, so a press captured before the
    -- transition must not survive to be dispatched by the matching mouse-up.
    self._pressedIcon = nil
    self._pressedRect = nil

    if self.uiState == "home" then
        -- BUILD 15:39 (PB-02): Home from the grid means "root of the grid".
        -- Inert at the root itself, so reaching here always changes something.
        self._homeMode   = "springboard"
        self._favEditing = false
        self._page       = 0
        self:_rebuildScreen()
        self:playUISound("back")
        return
    end

    local prev = self.system.currentApp
    self.uiState = "home"
    self:_rebuildScreen()
    local rect = self._appCellRects[prev] or self:_screenCenterSquare()
    self:_startAnim("home", 240, { id = prev, rect = rect })
    self:playUISound("back")
    -- Home shows the app grid, not an app, so no app is focused.
    if FarmTabletFocus then FarmTabletFocus:setFocus(true, nil) end
end

--- App-bar Back: step up one level. If the current app registered a back
--- handler that pops an in-app sub-page (returns true), refresh the content;
--- otherwise we're at the app root, so fall through to the springboard.
function FarmTabletUI:goBack()
    -- BUILD 15:39 (PB-02). On the grid, Back is a real one-level step: the
    -- favourites page pops to the springboard, and page N pops to page N-1.
    -- At the springboard root it is never reached, because it is drawn dimmed
    -- and `_onMouse` refuses to dispatch a disabled control.
    if self.uiState == "home" then
        if self._homeMode == "favorites" then
            self._homeMode   = "springboard"
            self._favEditing = false
            self._page       = 0
            self:_rebuildScreen()
            self:playUISound("back")
        elseif (self._page or 0) > 0 then
            self._page = self._page - 1
            self:_rebuildScreen()
            self:playUISound("back")
        end
        return
    end

    local appId = self.system and self.system.currentApp
    local fn    = appId and self._appBackHandlers and self._appBackHandlers[appId]
    if fn then
        local ok, handled = pcall(fn, self)
        if ok and handled then
            self:playUISound("back")
            self._contentScrollY   = 0
            self._contentScrollMax = 0
            if self.isOpen and self.uiState == "app" then
                self:_drawContent()
                self._contentTimer = 0
            end
            return
        elseif not ok and Logging and Logging.devWarning then
            Logging.devWarning("FarmTablet: back handler error for app '%s': %s",
                tostring(appId), tostring(handled))
        end
    end
    self:goHome()
end

--- Open the favourites page (from the app-bar star). Lands on the springboard
--- in "favourites" mode via the normal home transition.
function FarmTabletUI:openFavorites()
    self._homeMode   = "favorites"
    self._favEditing = false
    self._page       = 0
    self:goHome()
end

--- Springboard star toggle: flip between the full springboard and the
--- favourites page in place (no zoom — we're already on the home screen).
function FarmTabletUI:toggleFavoritesMode()
    self._homeMode   = (self._homeMode == "favorites") and "springboard" or "favorites"
    self._favEditing = false
    self._page       = 0
    self:_rebuildScreen()
    self:playUISound("click")
end

--- Launch an app from the springboard, with a zoom-open animation.
function FarmTabletUI:launchApp(appId, fromRect)
    if (self._battery or 0) <= 0 then
        self._batteryEmpty = true
        self.uiState = "empty"
        self:_rebuildScreen()
        return false
    end
    local ok = self:switchApp(appId)   -- sets state=app + rebuilds + sound
    if ok and self.isOpen then
        self:_startAnim("launch", 280, { id = appId, rect = fromRect or self._appCellRects[appId] or self:_screenCenterSquare() })
    end
    return ok
end

-- ─────────────────────────────────────────────────────────
-- BUILD  (compute layout, then draw current screen)
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_build()
    self:_computeLayout()
    self:_rebuildScreen()
end

function FarmTabletUI:_computeLayout()
    local scaleMultW = (self.settings.tabletScale or 1.0) * (self.settings.tabletWidthMult or 1.0)
    local scaleMultH = self.settings.tabletScale or 1.0
    local tw, th = getNormalizedScreenValues(FT.REF_W * scaleMultW, FT.REF_H * scaleMultH)

    local centreX = self.settings.tabletPosX or 0.5
    local centreY = self.settings.tabletPosY or 0.5
    local tx = centreX - tw/2
    local ty = centreY - th/2
    tx = math.max(0, math.min(1 - tw, tx))
    ty = math.max(0, math.min(1 - th, ty))

    FT.LAYOUT.scaleX = tw / FT.REF_W
    FT.LAYOUT.scaleY = th / FT.REF_H
    -- Font scale tracks the tablet scale so text grows with the tablet, then
    -- applies the player's own content-font multiplier on top.
    FT.LAYOUT.fontScale = (self.settings.tabletScale or 1.0) * (self.settings.contentFontScale or 1.0)
    FT.LAYOUT.tabletX = tx;  FT.LAYOUT.tabletY = ty
    FT.LAYOUT.tabletW = tw;  FT.LAYOUT.tabletH = th

    local bL = FT.px(BEZEL_REF)
    local bR = FT.px(BEZEL_REF)
    local bT = FT.py(BEZEL_REF)
    local bB = FT.py(BEZEL_REF)

    -- Inner screen
    local sx = tx + bL
    local sy = ty + bB
    local sw = tw - bL - bR
    local sh = th - bT - bB
    FT.LAYOUT.screenX = sx;  FT.LAYOUT.screenY = sy
    FT.LAYOUT.screenW = sw;  FT.LAYOUT.screenH = sh

    -- Status bar (top of screen)
    local statusH = FT.py(STATUS_H_REF)
    FT.LAYOUT.statusH = statusH
    FT.LAYOUT.statusY = sy + sh - statusH

    -- Canvas (below status bar) — used by home/lock and as the app region base
    FT.LAYOUT.canvasY = sy
    FT.LAYOUT.canvasH = sh - statusH

    -- Keep legacy sidebar fields defined (edit-mode safety); width 0 now.
    FT.LAYOUT.sidebarX = sx; FT.LAYOUT.sidebarY = sy
    FT.LAYOUT.sidebarW = 0;  FT.LAYOUT.sidebarH = sh

    -- Default content zone (overridden per state in _drawAppView)
    FT.LAYOUT.contentX = sx;  FT.LAYOUT.contentY = sy
    FT.LAYOUT.contentW = sw;  FT.LAYOUT.contentH = sh - statusH
    FT.LAYOUT.topbarX = sx; FT.LAYOUT.topbarY = FT.LAYOUT.statusY
    FT.LAYOUT.topbarW = sw; FT.LAYOUT.topbarH = statusH
end

function FarmTabletUI:_rebuildScreen()
    self.r:destroyAll()
    self._iconBtns    = {}
    self._dockBtns    = {}
    self._pageDots    = {}
    self._contentBtns = {}
    self._iconQueue   = {}
    self._appCellRects = {}
    self._closeBtn = nil
    self._homeBtn  = nil
    self._backBtn  = nil
    self._starBtn  = nil
    self._homeStarBtn = nil
    self._favEditBtn  = nil
    self._unlockBtn = nil
    self._powerBtn  = nil
    self._batteryChargeBtn = nil
    self._providerBtns = {}
    self._providerConfirmBtn = nil

    self:_drawFrame()

    if self.uiState == "empty" then
        self._useWallpaper = false
        self:_drawBatteryEmpty()
    elseif self.uiState == "repair" then
        self._useWallpaper = false
        self:_drawRepairScreen()
    elseif self.uiState == "provider" then
        self._useWallpaper = true
        self:_drawStatusBar()
        self:_drawProviderSelect()
    elseif self.uiState == "lock" then
        self._useWallpaper = true
        self:_drawStatusBar()
        self:_drawLock()
    elseif self.uiState == "app" then
        self._useWallpaper = false
        self:_drawStatusBar()
        self:_drawAppView()
    else
        self.uiState = "home"
        self._useWallpaper = true
        self:_drawStatusBar()
        self:_drawHome()
    end
end

-- ─────────────────────────────────────────────────────────
-- FRAME  (tablet body, bezel, gloss, hardware)
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_drawFrame()
    local L = FT.LAYOUT
    local r = self.r
    r:clearCoverLayer()

    -- The tablet body — rounded bezel, camera, speaker grille, side buttons and
    -- the drop shadow — is a baked texture (gui/tablet_frame.dds) rendered in
    -- draw(), so the silhouette has real rounded corners. The dark screen
    -- backing is painted in draw() (_drawScreenBacking) UNDER the wallpaper;
    -- here we only add the inner screen border, which sits on top of everything.

    -- Inner screen border (subtle)
    local stroke = FT.px(1)
    local accent = FT.appColor(self.system.currentApp)
    r:rect(L.screenX, L.screenY, L.screenW, stroke, {accent[1],accent[2],accent[3],0.30})
    r:rect(L.screenX, L.screenY + L.screenH - stroke, L.screenW, stroke, {accent[1],accent[2],accent[3],0.30})
    r:rect(L.screenX, L.screenY, stroke, L.screenH, {accent[1],accent[2],accent[3],0.18})
    r:rect(L.screenX + L.screenW - stroke, L.screenY, stroke, L.screenH, {accent[1],accent[2],accent[3],0.18})
end

-- Screen backing fill, drawn immediately in draw() UNDER the wallpaper: the
-- bg-palette colour while in an app, a near-black on the home / lock screens.
-- Kept off the base overlay layer so the rest of the chrome can flush on top
-- of the wallpaper.
function FarmTabletUI:_drawScreenBacking()
    local L = FT.LAYOUT
    if self.uiState == "app" then
        local pal = FT.BG_PALETTE[self.settings.tabletBgColorIndex or 1] or FT.BG_PALETTE[1]
        self:_fxRect(L.screenX, L.screenY, L.screenW, L.screenH, {0, 0, 0, 1})
        self:_fxRect(L.screenX, L.screenY, L.screenW, L.screenH, pal.color)
    else
        self:_fxRect(L.screenX, L.screenY, L.screenW, L.screenH, {0.02, 0.03, 0.04, 1})
    end
end

-- ── Status bar (clock / battery / wifi / power) ───────────

function FarmTabletUI:_drawStatusBar()
    local L = FT.LAYOUT
    local r = self.r
    local sx, sw = L.screenX, L.screenW
    local y, h = L.statusY, L.statusH

    -- Translucent bar so wallpaper / content shows behind it
    r:rect(sx, y, sw, h, {0,0,0,0.30})
    r:rect(sx, y, sw, math.max(FT.py(1),0.0007), {1,1,1,0.06})

    -- Right cluster: wifi bars, battery, power/lock glyph
    local pad = FT.px(10)
    local cy  = y + h/2

    -- Power / lock button (far right)
    local pwrW = FT.px(16)
    local pwrX = sx + sw - pad - pwrW
    r:rect(pwrX, cy - FT.py(6), pwrW, FT.py(12), {1,1,1,0.0})  -- (hit padding only)
    -- power glyph: circle outline + top stem (drawn from rects)
    r:rect(pwrX + pwrW/2 - FT.px(1), cy + FT.py(1), FT.px(2), FT.py(5), {0.85,0.9,0.95,0.9})
    r:rect(pwrX + pwrW/2 - FT.px(5), cy - FT.py(5), FT.px(10), FT.px(1.6), {0.85,0.9,0.95,0.55})
    r:rect(pwrX + pwrW/2 - FT.px(5), cy - FT.py(5), FT.px(1.6), FT.py(7), {0.85,0.9,0.95,0.55})
    r:rect(pwrX + pwrW/2 + FT.px(4), cy - FT.py(5), FT.px(1.6), FT.py(7), {0.85,0.9,0.95,0.55})
    r:rect(pwrX + pwrW/2 - FT.px(5), cy + FT.py(2), FT.px(10), FT.px(1.6), {0.85,0.9,0.95,0.55})
    self._powerBtn = { x = pwrX - FT.px(3), y = y, w = pwrW + FT.px(6), h = h }

    -- Battery
    local batW = FT.px(22)
    local batH = FT.py(11)
    local batX = pwrX - FT.px(10) - batW
    local batY = cy - batH/2
    r:rect(batX, batY, batW, batH, {1,1,1,0.16})                 -- shell
    r:rect(batX + batW, cy - FT.py(3), FT.px(2), FT.py(6), {1,1,1,0.5}) -- nub
    local lvl = math.max(0, math.min(1, (self._battery or 80)/100))
    local bc  = (lvl > 0.4) and {0.35,0.85,0.45,0.95}
              or (lvl > 0.15) and {1.0,0.72,0.1,0.95}
              or {0.95,0.3,0.3,0.95}
    if self._batteryCharging then
        bc = {0.30, 0.80, 1.00, 0.98}   -- charging: cyan overrides the level colour
    end
    r:rect(batX + FT.px(1.5), batY + FT.py(1.5), (batW - FT.px(3)) * lvl, batH - FT.py(3), bc)
    if self._batteryCharging then
        -- charging bolt: a bright centred tick over the cell
        r:rect(batX + batW*0.5 - FT.px(1), batY + FT.py(1), FT.px(2), batH - FT.py(2), {1,1,1,0.95})
    end

    -- Local mobile signal bars (0-4). Keep enough room for battery percent text.
    local wfX = batX - FT.px(52)
    local bars = math.max(0, math.min(4, tonumber(self._signalBars) or 4))
    for i = 0, 3 do
        local bh2 = FT.py(4 + i*3.0)
        local active = (i + 1) <= bars
        local col = active and {0.72,1.00,0.72,0.95} or {1,1,1,0.20}
        r:rect(wfX + i*FT.px(4.6), cy - FT.py(5), FT.px(2.8), bh2, col)
    end
    if bars == 0 then
        r:rect(wfX - FT.px(1), cy + FT.py(4), FT.px(21), FT.py(1.8), {0.95,0.30,0.30,0.95})
    end

    -- Remember the level the icon was drawn at, so the 1s tick only forces a
    -- rebuild when the battery actually changes (icon fill/colour is chrome).
    self._batteryDrawn = math.floor(self._battery or 80)

    self:_statusBarText()
end

-- Status-bar text only (re-added on the 1s clock refresh without a full rebuild).
function FarmTabletUI:_statusBarText()
    local L = FT.LAYOUT
    local r = self.r
    local sx, sw = L.screenX, L.screenW
    local cy = L.statusY + L.statusH/2 - FT.py(4)
    local data = self.system.data

    -- Left: clock
    -- Bei Netzausfall wird NUR die Tablet-Anzeige eingefroren. Die echte
    -- Ingame-Zeit laeuft weiter, aber die Tablet-Uhr zeigt den Zeitpunkt,
    -- an dem die Verbindung abgerissen ist.
    local world = nil
    if self._signalOutageActive == true and self._signalFrozenWorldInfo ~= nil then
        world = self._signalFrozenWorldInfo
    else
        world = data and data:getWorldInfo()
    end
    local timeStr = world and string.format("%02d:%02d", (tonumber(world.hour) or 0) % 24, tonumber(world.minute) or 0) or "--:--"
    if self._signalOutageActive == true and self._signalFrozenStatusTime ~= nil then
        timeStr = self._signalFrozenStatusTime
    end
    r:text(sx + FT.px(12), cy, FT.FONT.SMALL, timeStr, RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)

    -- Centre: farm name (+ day/season)
    local farmId = data and data:getPlayerFarmId()
    local farmName = (data and data:getFarmName(farmId)) or "My Farm"
    r:text(sx + sw/2, cy, FT.FONT.SMALL, farmName, RenderText.ALIGN_CENTER, FT.C.TEXT_NORMAL)

    local bars = math.max(0, math.min(4, tonumber(self._signalBars) or 4))
    local net = "4G"
    local col = FT.C.TEXT_DIM
    if self._signalOutageActive then
        net = ftUiText("ft_network_outage_short", "Outage")
        col = {1.0,0.45,0.35,1}
    elseif bars <= 0 then
        net = ftUiText("ft_network_no_signal_short", "No signal")
        col = {1.0,0.45,0.35,1}
    elseif bars == 1 then
        net = ftUiText("ft_network_weak_short", "Weak")
        col = {1.0,0.80,0.25,1}
    elseif bars == 2 then
        net = "3G"
        col = {0.85,0.95,1.0,1}
    end
    local provider = tostring(self._signalProvider or ftUiText("ft_network_default_provider", "Network"))
    -- Statusbar has very little room. Show a clean, readable short provider.
    if string.find(string.lower(provider), "realistic", 1, true) ~= nil then
        provider = "Realistic"
    elseif string.len(provider) > 9 then
        provider = string.sub(provider, 1, 9) .. "."
    end
    -- Status rechts sauber trennen: Netz links, Akku-Prozent rechts daneben.
    -- Kein Trenner direkt vor der Zahl, damit Signal/Batterie sich nicht ueberlappen.
    r:text(sx + sw - FT.px(150), cy, FT.FONT.TINY,
        provider .. " " .. net, RenderText.ALIGN_RIGHT, col)

    -- Battery %: left of the signal bars, so it can never overlap the signal icon.
    r:text(sx + sw - FT.px(116), cy, FT.FONT.TINY,
        string.format("%d%%", math.floor(ftClampBattery(self._battery or 80))),
        RenderText.ALIGN_RIGHT, FT.C.TEXT_BRIGHT)
end

function FarmTabletUI:_refreshStatusBar()
    if not self.isOpen then return end
    if self.uiState == "empty" then return end
    -- The provider-select screen draws its title / hint / button labels into the
    -- persistent text queue. Wiping _texts here would erase them (they are not
    -- re-added like the status bar / lock clock), so do a full rebuild instead.
    if self.uiState == "provider" then
        self:_rebuildScreen()
        return
    end
    -- Only persistent text lives in _texts (status bar + lock clock); safe to rebuild.
    self.r._texts = {}
    self:_statusBarText()
    if self.uiState == "lock" and self._lockText then self:_lockText() end
end

-- ─────────────────────────────────────────────────────────
-- APP VIEW  (full-screen content + top app bar)
-- ─────────────────────────────────────────────────────────

-- Draw a star (Favourites) button: pill background + 4-point star. When
-- `active` it glows in warm gold (a soft halo + brighter fill); otherwise it
-- is a dim gold star on the standard translucent pill. Shared by the app-bar
-- star and the springboard star toggle. Caller records the hit rect.
function FarmTabletUI:_drawStarGlyph(x, y, w, h, active)
    local r = self.r
    local cx, cy = x + w / 2, y + h / 2
    local len, halfW = FT.py(8), FT.px(2.6)
    if active then
        -- soft glow halo (expanding low-alpha gold rects)
        r:rect(x - FT.px(2), y - FT.py(2), w + FT.px(4), h + FT.py(4), {1.0, 0.82, 0.28, 0.12})
        r:rect(x + FT.px(1), y + FT.py(1), w - FT.px(2), h - FT.py(2), {1.0, 0.82, 0.28, 0.22})
        drawStar(r, cx, cy, len, halfW, {1.0, 0.88, 0.40, 1.0})
    else
        r:rect(x, y, w, h, {1, 1, 1, 0.06})
        drawStar(r, cx, cy, len, halfW, {1.0, 0.82, 0.28, 0.80})
    end
end

-- Just the star shape (no pill/glow), centred in the box. Used as the
-- "this app is a favourite" badge on icons in the favourites edit view.
function FarmTabletUI:_drawStarMark(x, y, w, h, color)
    drawStar(self.r, x + w / 2, y + h / 2, h * 0.45, h * 0.18, color)
end

-- BUILD 15:39 (PB-02). Shared disabled-control vocabulary, locked by DESIGN
-- 15:00 §2: a control that cannot act right now keeps its glyph and its slot and
-- is dimmed to ~45%. It never vanishes and it never reads as lit-but-dead.
FarmTabletUI.DISABLED_ALPHA = 0.45

local function dimmed(color, enabled)
    if enabled then return color end
    return { color[1], color[2], color[3], (color[4] or 1) * FarmTabletUI.DISABLED_ALPHA }
end

--- Which nav steps actually exist from where we are standing.
--- Home = "back to the app grid", Back = "up exactly one level".
--- On the grid itself both are inert, which is the PB-02 root case: the old code
--- had no such state and answered a root Back by collapsing the strip and
--- snapping back, which is a panic on an empty history, not a transition.
function FarmTabletUI:_navState()
    if self.uiState == "app" then
        return true, true
    end
    if self.uiState == "home" then
        local off = (self._homeMode == "favorites") or ((self._page or 0) > 0)
        return off, off
    end
    return false, false
end

--- Draw the Home / Back / Star cluster. Returns the x just past the cluster so
--- the caller can lay out whatever follows it.
--- Buttons are recorded with an `enabled` flag; `_onMouse` skips disabled ones
--- entirely, so a dimmed control has no hit action, no sound and no animation.
function FarmTabletUI:_drawNavCluster(sx, barY, barH, accent, starActive)
    local r = self.r
    local homeOn, backOn = self:_navState()
    -- Home / Back / Star are boxed squares in the springboard tile / title-icon
    -- treatment: charcoal BG_CARD fill with a white hairline. The hit rects on
    -- _homeBtn / _backBtn / _starBtn, the enabled dimming and the _onMouse skip
    -- of disabled controls are unchanged.
    local btnW  = FT.px(24)
    local btnH  = FT.py(24)
    local gap   = FT.px(6)
    local glyph = {0.92, 0.95, 0.99, 0.95}
    local hbY   = barY + (barH - btnH) / 2
    local hairH = math.max(FT.py(1), 0.0009)
    local hairW = math.max(FT.px(1), 0.0006)
    local function navBox(bx, enabled)
        r:rect(bx, hbY, btnW, btnH, dimmed(FT.C.BG_CARD, enabled))
        local line = dimmed({1, 1, 1, 0.22}, enabled)
        r:rect(bx, hbY + btnH - hairH, btnW, hairH, line)   -- top
        r:rect(bx, hbY, btnW, hairH, line)                  -- bottom
        r:rect(bx, hbY, hairW, btnH, line)                  -- left
        r:rect(bx + btnW - hairW, hbY, hairW, btnH, line)   -- right
    end

    -- HOME - a little house
    local hbX = sx + gap
    navBox(hbX, homeOn)
    local cx           = hbX + btnW / 2
    local bodyW, bodyH = FT.px(13), FT.py(7)
    local roofW, roofH = FT.px(18), FT.py(6)
    local houseBottom  = hbY + (btnH - (bodyH + roofH)) / 2
    r:rect(cx - bodyW / 2, houseBottom, bodyW, bodyH, dimmed(glyph, homeOn))                                      -- body
    r:rect(cx - FT.px(2), houseBottom, FT.px(4), FT.py(4.5),
           dimmed({accent[1], accent[2], accent[3], 1}, homeOn))                                                  -- door
    drawTriUp(r, cx, houseBottom + bodyH, roofW, roofH, dimmed(glyph, homeOn))                                    -- roof
    self._homeBtn = { x = hbX, y = barY, w = btnW, h = barH, enabled = homeOn }

    -- BACK - a left-pointing arrow
    local bbX = hbX + btnW + gap
    navBox(bbX, backOn)
    local acy = hbY + btnH / 2
    local headW, headH, shaftH = FT.px(7), FT.py(12), FT.py(3)
    local tipX = bbX + FT.px(5)
    drawTriLeft(r, tipX, acy, headW, headH, dimmed(glyph, backOn))                          -- arrowhead
    r:rect(tipX + headW * 0.5, acy - shaftH / 2, FT.px(10), shaftH, dimmed(glyph, backOn))  -- shaft
    self._backBtn = { x = bbX, y = barY, w = btnW, h = barH, enabled = backOn }

    -- STAR - opens / toggles the favourites page. Always available.
    local sbX = bbX + btnW + gap
    navBox(sbX, true)
    self:_drawStarGlyph(sbX, hbY, btnW, btnH, starActive == true)
    self._starBtn = { x = sbX, y = barY, w = btnW, h = barH, enabled = true }

    return sbX + btnW
end

function FarmTabletUI:_drawAppView()
    local L = FT.LAYOUT
    local r = self.r
    local accent = FT.appColor(self.system.currentApp)

    local appbarH = FT.py(APPBAR_H_REF)
    local barY = L.statusY - appbarH
    local sx, sw = L.screenX, L.screenW

    -- App bar background + accent underline
    r:rect(sx, barY, sw, appbarH, {0,0,0,0.22})
    r:rect(sx, barY, sw, FT.py(1.4), {accent[1],accent[2],accent[3],0.65})

    -- Top-left nav (#90): a little house (Home), a left-arrow (Back) and a
    -- star (Favourites). Home jumps to the springboard; Back steps up one
    -- level (sub-page → app root → springboard); the star opens the
    -- favourites page. Glyphs are built from rects (no triangle primitive).
    local sbW = FT.px(30)
    local sbX = self:_drawNavCluster(sx, barY, appbarH, accent, false) - sbW

    -- App icon (small) + title (centre-left)
    local app = self.system.registry:get(self.system.currentApp)
    local appName = (app and g_i18n and app.name and g_i18n:hasText(app.name) and g_i18n:getText(app.name))
                    or (app and app.navLabel) or "App"
    local titleIconSz = FT.py(20)
    local tiX = sbX + sbW + FT.px(10)
    local tiY = barY + (appbarH - titleIconSz)/2
    table.insert(self._iconQueue, { appId = self.system.currentApp, x = tiX, y = tiY, size = titleIconSz,
                                    mono = (app and app.navLabel) or "?" })
    -- App name as a dim right-aligned breadcrumb (apps draw their own bright header)
    r:text(sx + sw - FT.px(12), barY + appbarH/2 - FT.py(5),
           FT.FONT.SMALL, appName, RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)

    -- Content region = below the app bar, full width.
    L.contentX = sx
    L.contentY = L.canvasY
    L.contentW = sw
    L.contentH = (barY) - L.canvasY

    -- Cover strips clip scrolled content at the content edges.
    local coverColor = {0.02,0.03,0.04,1}
    if self.uiState == "app" then
        local pal = FT.BG_PALETTE[self.settings.tabletBgColorIndex or 1] or FT.BG_PALETTE[1]
        coverColor = pal.color
    end
    local topCoverY = L.contentY + L.contentH
    local topGap    = barY - topCoverY
    if topGap > 0 then r:coverRect(sx, topCoverY, sw, topGap, coverColor) end

    self:_drawContent()
end

function FarmTabletUI:_drawContent()
    if FT and FT.LAYOUT then FT.LAYOUT.bodyClipTop = nil end
    self.r:clearAppLayer()
    self._contentBtns = {}
    local appId = self.system.currentApp
    local fn = self._appDrawers and self._appDrawers[appId]
    if fn then
        local ok, err = pcall(fn, self)
        if not ok then self:_drawError(err) end
    else
        self:_drawWelcome()
    end

end

function FarmTabletUI:_drawOfflineDataBannerAt(x, y, w)
    if not self.r or not FT then return y end

    local h = FT.py(30)
    local iconW = FT.px(26)

    -- Zentrale Offline-Leiste: wird oberhalb des App-Titels gezeichnet und
    -- verschiebt den Titel nach unten. Dadurch gibt es keine Überlappung mehr
    -- mit App-Namen oder ersten Inhaltszeilen. Rein clientseitige Anzeige.
    self.r:appRect(x, y - h, w, h, {0.18, 0.12, 0.02, 0.94})
    self.r:appRect(x, y - FT.py(2), w, FT.py(2), {1.00, 0.72, 0.18, 0.90})
    self.r:appRect(x, y - h, w, FT.py(2), {1.00, 0.72, 0.18, 0.55})
    self.r:appRect(x, y - h, FT.px(4), h, {1.00, 0.72, 0.18, 0.95})

    self.r:appText(x + FT.px(10), y - h/2 + FT.py(1), FT.FONT.TITLE,
        "KEIN NETZ", RenderText.ALIGN_LEFT, {1.00, 0.78, 0.25, 1})

    self.r:appText(x + iconW + FT.px(80), y - h/2 + FT.py(1), FT.FONT.SMALL,
        ftUiFormat("ft_network_data_frozen", "%s - data frozen", ftUiText("ft_network_default_provider", "Realistic Farming Mobile")), RenderText.ALIGN_LEFT, {0.95, 0.95, 0.86, 1})

    return y - h - FT.py(18)
end

function FarmTabletUI:_drawOfflineDataBanner()
    -- Alte Overlay-Funktion bleibt absichtlich leer, damit ältere Aufrufe keinen
    -- Text mehr über App-Titel legen. Die neue Leiste wird in drawAppHeader()
    -- zentral und platzsparend gerendert.
end

-- Register an app drawer function (called by app files)
FarmTabletUI._appDrawers = {}
function FarmTabletUI:registerDrawer(appId, fn)
    FarmTabletUI._appDrawers[appId] = fn
end

-- Register an optional back handler for an app with in-app sub-pages.
-- fn(self) should pop one level and return true if it handled the back,
-- or false/nil when already at the app's root (then Back goes to the
-- springboard). Called by app files that have sub-views.
FarmTabletUI._appBackHandlers = {}
function FarmTabletUI:registerBackHandler(appId, fn)
    FarmTabletUI._appBackHandlers[appId] = fn
end

-- ─────────────────────────────────────────────────────────
-- SWITCH APP  (in-place refresh of the app view; no zoom anim)
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:switchApp(appId)
    if AppRegistry and AppRegistry.resolve then
        appId = AppRegistry.resolve(appId)
    elseif appId == FT.APP.TIME_CONTROLS then
        appId = FT.APP.FARM_ADMIN
    elseif appId == FT.APP.DIGGING or appId == FT.APP.BUCKET then
        appId = FT.APP.EXCAVATOR
    end
    if not self.system.registry:has(appId) then return false end
    local app = self.system.registry:get(appId)
    if not app or not app.enabled then return false end

    local s = self.settings
    if s and s.soundEffects and s.soundOnAppSelect and appId ~= self.system.currentApp then
        self:playUISound("click")
    end

    self.system.currentApp = appId
    self._contentScrollY   = 0
    self._contentScrollMax = 0

    if self.isOpen then
        self.uiState = "app"
        self:_rebuildScreen()
    end

    FT_EventBus:emit(FT_EventBus.EVENTS.APP_SWITCHED, appId)
    if FarmTabletFocus then FarmTabletFocus:setFocus(self.isOpen, appId) end
    return true
end

-- ─────────────────────────────────────────────────────────
-- ANIMATION  (transient overlay drawn on top of the built screen)
-- ─────────────────────────────────────────────────────────

local function easeOutCubic(p) return 1 - (1 - p)^3 end
local function easeInCubic(p)  return p*p*p end

function FarmTabletUI:_startAnim(kind, dur, data)
    self._anim = { kind = kind, t = 0, dur = dur or 250, data = data or {} }
end

-- reusable fade/curtain rect (uses self._fx plain overlay)
function FarmTabletUI:_fxRect(x, y, w, h, col)
    if not self._fx then return end
    self._fx:setPosition(x, y)
    self._fx:setDimension(w, h)
    self._fx:setColor(col[1], col[2], col[3], col[4])
    self._fx:render()
end

function FarmTabletUI:_drawAnim()
    local a = self._anim
    if not a then return end
    local L = FT.LAYOUT
    local p = math.max(0, math.min(1, a.t / a.dur))
    local sx, sy, sw, scH = L.screenX, L.screenY, L.screenW, L.screenH

    if a.kind == "wake" then
        -- screen-on: black veil fades out
        self:_fxRect(sx, sy, sw, scH, {0,0,0, (1 - easeOutCubic(p)) * 0.95})

    elseif a.kind == "unlock" then
        -- lock curtain lifts upward + fades
        local e = easeInCubic(p)
        local off = scH * e
        self:_fxRect(sx, sy + off, sw, scH, {0.02,0.03,0.05, (1 - p) * 0.92})

    elseif a.kind == "lock" then
        self:_fxRect(sx, sy, sw, scH, {0.02,0.03,0.05, (1 - p) * 0.7})

    elseif a.kind == "launch" then
        -- app icon zooms from its grid cell to fill the screen, then dissolves
        local rect = a.data.rect or self:_screenCenterSquare()
        local e = easeOutCubic(p)
        local target = math.min(sw, scH) * 0.92
        local size = rect.w + (target - rect.w) * e
        local cx = (rect.x + rect.w/2) + ((sx + sw/2)  - (rect.x + rect.w/2)) * e
        local cy = (rect.y + rect.h/2) + ((sy + scH/2) - (rect.y + rect.h/2)) * e
        local alpha = 1 - easeInCubic(p)
        self:_fxRect(sx, sy, sw, scH, {1,1,1, (1 - p) * 0.10})
        if FT_Icons then FT_Icons.renderIcon(a.data.id, cx - size/2, cy - size/2, size, 1, alpha) end

    elseif a.kind == "home" then
        -- app icon shrinks from screen back to its grid cell
        local rect = a.data.rect or self:_screenCenterSquare()
        local e = easeOutCubic(p)
        local start = math.min(sw, scH) * 0.92
        local size = start + (rect.w - start) * e
        local cx = (sx + sw/2) + ((rect.x + rect.w/2) - (sx + sw/2)) * e
        local cy = (sy + scH/2) + ((rect.y + rect.h/2) - (sy + scH/2)) * e
        local alpha = (1 - easeInCubic(p)) * 0.9
        if FT_Icons then FT_Icons.renderIcon(a.data.id, cx - size/2, cy - size/2, size, 1, alpha) end
    end
end

-- A centred square fallback used when no source cell rect is known.
function FarmTabletUI:_screenCenterSquare()
    local L = FT.LAYOUT
    local s = math.min(L.screenW, L.screenH) * 0.32
    return { x = L.screenX + L.screenW/2 - s/2, y = L.screenY + L.screenH/2 - s/2, w = s, h = s }
end

-- ─────────────────────────────────────────────────────────
-- ICON RENDER PASS  (textured overlays, drawn above content)
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_drawIconQueue()
    for _, ic in ipairs(self._iconQueue) do
        local scale, alpha = 1.0, 1.0
        if ic.appId == self._pressedIcon then
            scale, alpha = 0.90, 0.85
        end
        local isFallback = true
        if FT_Icons then
            isFallback = FT_Icons.renderIcon(ic.appId, ic.x, ic.y, ic.size, scale, alpha)
        end
        if isFallback and ic.mono then
            local s = ic.size * scale
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextColor(0.97, 0.98, 1.0, alpha)
            renderText(ic.x + ic.size/2, ic.y + ic.size/2 - FT.py(5), s * 0.34, tostring(ic.mono))
            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextColor(1,1,1,1)
        end
    end
end

-- ─────────────────────────────────────────────────────────
-- DRAW / UPDATE (FS25 drawable interface)
-- ─────────────────────────────────────────────────────────

-- ── Home / lock wallpaper (custom image from savegame, or default) ──
function FarmTabletUI:_backgroundDir()
    if g_currentMission and g_currentMission.missionInfo and g_currentMission.missionInfo.savegameDirectory then
        return g_currentMission.missionInfo.savegameDirectory .. "/FTBackground/"
    end
    return nil
end

function FarmTabletUI:_drawWallpaper()
    if not FT_Icons then return end
    local L = FT.LAYOUT
    local bg = self.settings.customBackground
    if bg and bg ~= "" then
        local dir = self:_backgroundDir()
        if dir and FT_Icons.renderAbs(dir .. bg, L.screenX, L.screenY, L.screenW, L.screenH, 1.0) then
            return
        end
    end
    FT_Icons.renderImage("wall", "wallpaper.dds", L.screenX, L.screenY, L.screenW, L.screenH, 1.0)
end

function FarmTabletUI:draw()
    if not self.isOpen then return end
    local L = FT.LAYOUT

    -- 0. Rounded tablet body (baked texture, transparent corners). The body maps
    --    to the tablet rect; the texture margin (mf) carries the drop shadow.
    local mf = 0.055
    local rW = L.tabletW / (1 - 2*mf)
    local rH = L.tabletH / (1 - 2*mf)
    local okFrame = false
    if FT_Icons then
        okFrame = FT_Icons.renderImage("frame", "tablet_frame.dds",
            L.tabletX - mf*rW, L.tabletY - mf*rH, rW, rH, 1.0)
    end
    if not okFrame then
        self:_fxRect(L.tabletX, L.tabletY, L.tabletW, L.tabletH, {0.10, 0.11, 0.13, 1})
    end

    -- 0b. Screen backing — the dark/palette fill that sits UNDER the wallpaper.
    --     Drawn before the wallpaper; all other chrome goes on top of it.
    self:_drawScreenBacking()

    -- 1. Wallpaper (home / lock) — custom image if set, else default
    if self._useWallpaper then
        self:_drawWallpaper()
    end

    -- 2. Screen chrome (status bar signal/battery/power, screen border, dock,
    --    page dots, app bar, nav + star). On the base layer, flushed AFTER the
    --    wallpaper so it is never hidden behind it on the home / lock screens.
    self.r:flushBase()

    -- 3. Screen content (app content, labels, text)
    local clipY, clipH = nil, nil
    if self.uiState == "app" then clipY = L.contentY; clipH = L.contentH end
    self.r:flushContent(clipY, clipH)

    -- 4. App icons
    self:_drawIconQueue()

    -- 4b. Tablet-local network notification
    self:_drawSignalToast()

    -- 5. Transient animation overlay
    self:_drawAnim()

    -- 6. Edit-mode chrome
    self:_drawEditOverlay()

    -- BUILD 15:39 (PB-03). A full frame reached the screen, so the tablet is
    -- genuinely painted and is now allowed to claim input and quieten the HUD.
    -- update() takes the claim; setting the flag here is what makes "open but
    -- nothing painted" incapable of muting the world.
    self._paintedOnce = true
end

-- ─────────────────────────────────────────────────────────
-- BATTERY + LOCAL MOBILE NETWORK SYSTEMS
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_drawProviderSelect()
    local L = FT.LAYOUT
    local r = self.r
    local cx = L.screenX + L.screenW / 2
    local top = L.screenY + L.screenH * 0.78

    r:rect(L.screenX, L.screenY, L.screenW, L.screenH, {0.02,0.03,0.04,0.72})
    r:text(cx, top, FT.FONT.TITLE, ftUiText("ft_network_choose_provider", "Choose Network Provider"), RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
    r:text(cx, top - FT.py(28), FT.FONT.SMALL, ftUiText("ft_network_choose_hint", "Select a provider, then activate it."), RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)

    local bw = FT.px(280)
    local bh = FT.py(44)
    local gap = FT.py(8)
    local startY = top - FT.py(74)
    local providers = self._signalProviders or {}
    if self._providerPending == nil and providers[1] ~= nil then
        self._providerPending = providers[1]
    end

    for i, provider in ipairs(providers) do
        local bx = cx - bw / 2
        local by = startY - (i - 1) * (bh + gap)
        local selected = self._providerPending ~= nil and self._providerPending.id == provider.id
        r:rect(bx - FT.px(2), by - FT.py(2), bw + FT.px(4), bh + FT.py(4), selected and {0.45,1.0,0.45,0.35} or {1,1,1,0.08})
        r:rect(bx, by, bw, bh, selected and {0.10,0.48,0.22,0.94} or {0.08,0.10,0.14,0.94})
        r:text(cx, by + bh/2 + FT.py(5), FT.FONT.BODY, provider.name, RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
        local feeText = ftUiFormat("ft_network_fee_format", "Base fee: %s €/day", tostring(provider.dailyFee or self:_getSignalProviderDailyFee(provider.id)))
        r:text(cx, by + FT.py(8), FT.FONT.TINY, feeText, RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)
        table.insert(self._providerBtns, {x=bx, y=by, w=bw, h=bh, provider=provider})
    end

    local cbw = FT.px(170)
    local cbh = FT.py(34)
    local cbx = cx - cbw / 2
    local cby = L.screenY + L.screenH * 0.18
    r:rect(cbx, cby, cbw, cbh, {0.10,0.55,0.22,0.96})
    r:text(cx, cby + cbh/2 - FT.py(4), FT.FONT.BODY, ftUiText("ft_network_activate", "ACTIVATE"), RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
    self._providerConfirmBtn = {x=cbx, y=cby, w=cbw, h=cbh}
end

function FarmTabletUI:_selectSignalProvider(provider)
    provider = provider or {name="Realistic Farming Mobile", id="default"}
    self._signalProvider = provider.name or "Realistic Farming Mobile"
    self._signalProviderId = provider.id or "default"
    self._signalProviderSelected = true
    self._signalLastNotify = nil
    self:_saveSignalProviderSelection(provider)
    self:_updateSignalSystem(0, true)
    self:_processProviderDailyFee(true)
    self.uiState = (self.settings.lockScreenEnabled ~= false) and "lock" or "home"
    self:_rebuildScreen()
    self:_notifySignal(ftUiText("ft_network_default_provider", "Realistic Farming Mobile"), ftUiFormat("ft_network_provider_active", "Active: %s.", tostring(self._signalProvider)))
    self:playUISound("paging")
end


function FarmTabletUI:_getSignalProviderDailyFee(providerId)
    providerId = tostring(providerId or self._signalProviderId or "realistic_farming")
    for _, provider in ipairs(self._signalProviders or {}) do
        if tostring(provider.id or "") == providerId then
            return tonumber(provider.dailyFee) or 5
        end
    end
    return 250
end

function FarmTabletUI:_getNetworkBillingFarmId()
    if g_localPlayer ~= nil and g_localPlayer.farmId ~= nil then
        return g_localPlayer.farmId
    end
    if g_currentMission ~= nil and g_currentMission.player ~= nil and g_currentMission.player.farmId ~= nil then
        return g_currentMission.player.farmId
    end
    if FarmManager ~= nil and FarmManager.SINGLEPLAYER_FARM_ID ~= nil then
        return FarmManager.SINGLEPLAYER_FARM_ID
    end
    return 1
end

function FarmTabletUI:_getNetworkBillingDay()
    local env = g_currentMission and g_currentMission.environment
    if env ~= nil then
        return tonumber(env.currentDay or env.currentMonotonicDay or env.day or 0) or 0
    end
    return 0
end

function FarmTabletUI:_processProviderDailyFee(force)
    -- Dedi-sicher: Geld wird nur auf Server/Listen-Server verändert.
    -- Reine Clients zeigen nur die UI; ohne Serverrechte wird nichts lokal verändert.
    if self._signalProviderSelected ~= true then return false end
    if g_currentMission == nil or g_currentMission.getIsServer == nil or not g_currentMission:getIsServer() then return false end
    if g_farmManager == nil then return false end

    local farmId = self:_getNetworkBillingFarmId()
    local day = self:_getNetworkBillingDay()
    local key = tostring(farmId)
    self._providerBillingDays = self._providerBillingDays or {}
    if self._providerBillingDays[key] == day and force ~= true then return false end

    local fee = math.max(0, math.floor(tonumber(self:_getSignalProviderDailyFee(self._signalProviderId)) or 0))
    if fee <= 0 then
        self._providerBillingDays[key] = day
        self:_saveSignalProviderSelection({ id = self._signalProviderId or "realistic_farming", name = self._signalProvider or "Realistic Farming Mobile" })
        return false
    end

    local ok = pcall(function()
        local farm = g_farmManager:getFarmById(farmId)
        if farm ~= nil and farm.changeBalance ~= nil then
            farm:changeBalance(-fee, MoneyType.OTHER)
            if g_currentMission.addMoneyChange ~= nil then
                g_currentMission:addMoneyChange(-fee, farmId, MoneyType.OTHER, true)
            end
        end
    end)
    if ok then
        self._providerBillingDays[key] = day
        self:_saveSignalProviderSelection({ id = self._signalProviderId or "realistic_farming", name = self._signalProvider or "Realistic Farming Mobile" })
        self:_notifySignal(ftUiText("ft_network_title", "Network"), ftUiFormat("ft_network_fee_deducted", "Base fee deducted: %d €", fee))
        return true
    end
    return false
end

function FarmTabletUI:_getProviderSettingsPath()
    local base = nil
    if g_modSettingsDirectory ~= nil then
        base = g_modSettingsDirectory
    elseif getUserProfileAppPath ~= nil then
        base = getUserProfileAppPath() .. "modSettings"
    end
    if base == nil or base == "" then return nil end

    local dir = base .. "/FS25_FarmTablet"
    if createFolder ~= nil then
        createFolder(dir)
    end
    return dir .. "/provider.xml"
end


function FarmTabletUI:_normalizeSignalProviderId(providerId, providerName)
    providerId = tostring(providerId or "")
    providerName = tostring(providerName or "")

    -- Migration alter Anbieter aus Test-/Altversionen auf die neue saubere Marke.
    if providerId == "fbm" or providerId == "akita" or providerId == "agrar" or providerId == "hof" or providerId == "" then
        return "realistic_farming"
    end
    if string.find(string.lower(providerName), "fbm", 1, true) ~= nil or string.find(string.lower(providerName), "akita", 1, true) ~= nil then
        return "realistic_farming"
    end

    return providerId
end

function FarmTabletUI:_findSignalProviderById(providerId)
    providerId = tostring(providerId or "")
    for _, provider in ipairs(self._signalProviders or {}) do
        if tostring(provider.id or "") == providerId then
            return provider
        end
    end
    return nil
end

function FarmTabletUI:_normalizeSignalOutageFrequency(freq)
    freq = string.lower(tostring(freq or "off"))
    if freq == "rare" or freq == "selten" then return "rare" end
    if freq == "normal" then return "normal" end
    if freq == "frequent" or freq == "haeufig" or freq == "häufig" then return "frequent" end
    return "off"
end

function FarmTabletUI:_getSignalOutageFrequencyLabel(freq)
    freq = self:_normalizeSignalOutageFrequency(freq or self._signalOutageFrequency)
    if freq == "rare" then return ftUiText("ft_common_rare", "Rare") end
    if freq == "normal" then return ftUiText("ft_common_normal", "Normal") end
    if freq == "frequent" then return ftUiText("ft_common_frequent", "Frequent") end
    return ftUiText("ft_common_off", "Off")
end

function FarmTabletUI:_getSignalOutageConfig()
    local freq = self:_normalizeSignalOutageFrequency(self._signalOutageFrequency)
    -- Zufällige Netzstörungen: Aus = nie. Selten/Normal/Häufig planen
    -- den nächsten Ausfall in einem zufälligen Ingame-Zeitfenster. Dadurch
    -- passiert bei „Häufig“ zuverlässig sichtbar etwas, bleibt aber zeitlich variabel.
    if freq == "rare" then
        return { enabled=true, minMinutes=360, maxMinutes=720 }      -- 6-12 Ingame-Stunden
    elseif freq == "normal" then
        return { enabled=true, minMinutes=120, maxMinutes=240 }      -- 2-4 Ingame-Stunden
    elseif freq == "frequent" then
        return { enabled=true, minMinutes=30, maxMinutes=60 }        -- 0.5-1 Ingame-Stunde
    end
    return { enabled=false, minMinutes=0, maxMinutes=0 }
end

function FarmTabletUI:_minutesSince(startMin, currentMin)
    startMin = tonumber(startMin) or 0
    currentMin = tonumber(currentMin) or 0
    if currentMin < startMin then
        currentMin = currentMin + 1440
    end
    return currentMin - startMin
end

function FarmTabletUI:_scheduleNextSignalOutageCheck(currentMinute, cfg)
    cfg = cfg or self:_getSignalOutageConfig()
    if cfg.enabled ~= true then
        self._signalNextCheckMin = nil
        self._signalNextCheckStartMin = nil
        return
    end

    local minDelay = math.max(1, tonumber(cfg.minMinutes) or 60)
    local maxDelay = math.max(minDelay, tonumber(cfg.maxMinutes) or minDelay)
    local delay = math.random(minDelay, maxDelay)
    currentMinute = tonumber(currentMinute) or self:_getWorldMinuteOfDay()
    self._signalNextCheckStartMin = currentMinute
    self._signalNextCheckMin = (currentMinute + delay) % 1440
    self._signalNextCheckDelayMin = delay
end

function FarmTabletUI:_cycleSignalOutageFrequency()
    local freq = self:_normalizeSignalOutageFrequency(self._signalOutageFrequency)
    if freq == "off" then freq = "rare"
    elseif freq == "rare" then freq = "normal"
    elseif freq == "normal" then freq = "frequent"
    else freq = "off" end
    self._signalOutageFrequency = freq
    self._signalNextCheckMin = nil
    self._signalNextCheckStartMin = nil
    self._signalNextCheckDelayMin = nil
    if freq == "off" then
        self._signalOutageActive = false
        self._signalOutageEndMin = nil
        self._signalFrozenStatusTime = nil
        self._signalFrozenWorldInfo = nil
    end
    self:_saveSignalProviderSelection({ id = self._signalProviderId or "realistic_farming", name = self._signalProvider or "Realistic Farming Mobile" })
    self:_updateSignalSystem(0, true)
    return freq
end

function FarmTabletUI:_cycleSignalOutageDuration()
    local h = tonumber(self._signalOutageDurationHours) or 2
    if h < 2 then h = 2
    elseif h < 3 then h = 3
    elseif h < 4 then h = 4
    else h = 1 end
    self._signalOutageDurationHours = h
    self:_saveSignalProviderSelection({ id = self._signalProviderId or "realistic_farming", name = self._signalProvider or "Realistic Farming Mobile" })
    return h
end

function FarmTabletUI:_loadSignalProviderSelection()
    local path = self:_getProviderSettingsPath()
    if path == nil or not fileExists(path) then return end

    local xml = XMLFile.load("ftProvider", path)
    if xml == nil then return end

    local selected = xml:getBool("provider.selected", false)
    local providerId = xml:getString("provider.id", "")
    local providerName = xml:getString("provider.name", "")
    self._signalOutageFrequency = self:_normalizeSignalOutageFrequency(xml:getString("provider.outageFrequency", "off"))
    self._signalOutageDurationHours = math.max(1, math.min(4, tonumber(xml:getFloat("provider.outageDurationHours", 2)) or 2))
    self._providerBillingDays = {}
    self._tabletRepairActive = xml:getBool("provider.repair.active", false)
    self._tabletRepairStartMin = xml:getInt("provider.repair.startMinute", -1)
    if self._tabletRepairStartMin < 0 then self._tabletRepairStartMin = nil end
    self._tabletRepairEndMin = xml:getInt("provider.repair.endMinute", -1)
    if self._tabletRepairEndMin < 0 then self._tabletRepairEndMin = nil end
    self._tabletRepairInStock = xml:getBool("provider.repair.inStock", true)
    self._tabletRepairNotifiedDone = xml:getBool("provider.repair.notifiedDone", false)
    self._tabletRepairLastDropDay = xml:getInt("provider.repair.lastDropDay", -1)
    self._tabletRepairFrequency = self:_normalizeTabletRepairFrequency(xml:getString("provider.repair.frequency", "off"))

    local billingCount = xml:getInt("provider.billing#count", 0)
    for i = 1, billingCount do
        local key = string.format("provider.billing.farm(%d)", i - 1)
        local fid = tostring(xml:getString(key .. "#id", ""))
        local day = xml:getInt(key .. "#lastDay", -1)
        if fid ~= "" and day >= 0 then
            self._providerBillingDays[fid] = day
        end
    end
    providerId = self:_normalizeSignalProviderId(providerId, providerName)
    xml:delete()

    if selected == true then
        local provider = self:_findSignalProviderById(providerId)
        if provider ~= nil then
            self._signalProviderId = provider.id
            self._signalProvider = provider.name
            self._providerPending = provider
            self._signalProviderSelected = true
        elseif providerName ~= nil and providerName ~= "" then
            self._signalProviderId = providerId ~= "" and providerId or "custom"
            self._signalProvider = providerName
            self._providerPending = { id = self._signalProviderId, name = self._signalProvider }
            self._signalProviderSelected = true
        end
    end
end

function FarmTabletUI:_saveSignalProviderSelection(provider)
    local path = self:_getProviderSettingsPath()
    if path == nil then return end

    local xml = XMLFile.create("ftProvider", path, "provider")
    if xml == nil then return end

    xml:setBool("provider.selected", true)
    xml:setString("provider.id", tostring(provider.id or "default"))
    xml:setString("provider.name", tostring(provider.name or "Realistic Farming Mobile"))
    xml:setString("provider.outageFrequency", self:_normalizeSignalOutageFrequency(self._signalOutageFrequency))
    xml:setFloat("provider.outageDurationHours", tonumber(self._signalOutageDurationHours) or 2)
    xml:setBool("provider.repair.active", self._tabletRepairActive == true)
    xml:setInt("provider.repair.startMinute", tonumber(self._tabletRepairStartMin) or -1)
    xml:setInt("provider.repair.endMinute", tonumber(self._tabletRepairEndMin) or -1)
    xml:setBool("provider.repair.inStock", self._tabletRepairInStock ~= false)
    xml:setBool("provider.repair.notifiedDone", self._tabletRepairNotifiedDone == true)
    xml:setInt("provider.repair.lastDropDay", tonumber(self._tabletRepairLastDropDay) or -1)
    xml:setString("provider.repair.frequency", self:_normalizeTabletRepairFrequency(self._tabletRepairFrequency))

    local billing = self._providerBillingDays or {}
    local idx = 0
    for farmId, lastDay in pairs(billing) do
        local key = string.format("provider.billing.farm(%d)", idx)
        xml:setString(key .. "#id", tostring(farmId))
        xml:setInt(key .. "#lastDay", tonumber(lastDay) or 0)
        idx = idx + 1
    end
    xml:setInt("provider.billing#count", idx)
    xml:save()
    xml:delete()
end

function FarmTabletUI:_onMouseProvider(px, py, isDown, isUp, btn)
    -- Die Auswahl darf beim Klick auf einen Anbieter nicht verschwinden.
    -- Klick 1: Anbieter markieren. Klick 2: AKTIVIEREN bestätigt und öffnet danach das Tablet.
    local left = (btn == 1 or btn == 0 or btn == nil)
    if left and isDown then
        self._providerPressed = nil
        for _, b in ipairs(self._providerBtns or {}) do
            if px >= b.x and px <= b.x + b.w and py >= b.y and py <= b.y + b.h then
                self._providerPressed = b
                return true
            end
        end
        local c = self._providerConfirmBtn
        if c ~= nil and px >= c.x and px <= c.x + c.w and py >= c.y and py <= c.y + c.h then
            self._providerPressed = {confirm=true}
            return true
        end
        return true
    end

    if left and isUp and self._providerPressed ~= nil then
        local b = self._providerPressed
        self._providerPressed = nil
        if b.confirm == true then
            local c = self._providerConfirmBtn
            if c ~= nil and px >= c.x and px <= c.x + c.w and py >= c.y and py <= c.y + c.h then
                self:_selectSignalProvider(self._providerPending or ((self._signalProviders or {})[1]) or {id="realistic_farming", name="Realistic Farming Mobile", bias=0.35})
                return true
            end
        elseif b.provider ~= nil and px >= b.x and px <= b.x + b.w and py >= b.y and py <= b.y + b.h then
            -- Nur markieren. Die Auswahl bleibt sichtbar und wird erst mit AKTIVIEREN bestätigt.
            self._providerPending = b.provider
            self._providerSelectedAt = tonumber(g_time) or 0
            self:playUISound("click")
            return true
        end
    end
    return true
end


-- ─────────────────────────────────────────────────────────
-- TABLET DISPLAY REPAIR SYSTEM  (modSettings only)
-- ─────────────────────────────────────────────────────────
function FarmTabletUI:_getWorldAbsoluteMinute()
    -- Absolute Spielminute: wichtig fuer Reparatur-Timer ueber Mitternacht/naechste Tage.
    -- Nur Anzeige-/Tabletlogik, keine Spielzeit wird veraendert.
    local minute = tonumber(self:_getWorldMinuteOfDay()) or 0
    local day = self:_getWorldDayIndexRaw()
    return (day * 1440) + minute
end

function FarmTabletUI:_getWorldDayIndexRaw()
    local env = g_currentMission and g_currentMission.environment
    if env ~= nil then
        return tonumber(env.currentDay or env.currentMonotonicDay or env.day or 0) or 0
    end
    return 0
end

function FarmTabletUI:_getWorldDayIndex()
    return self:_getWorldDayIndexRaw()
end


function FarmTabletUI:_normalizeTabletRepairFrequency(freq)
    freq = string.lower(tostring(freq or "off"))
    if freq == "rare" or freq == "selten" then return "rare" end
    if freq == "normal" then return "normal" end
    if freq == "frequent" or freq == "haeufig" or freq == "häufig" then return "frequent" end
    return "off"
end

function FarmTabletUI:_getTabletRepairFrequencyLabel(freq)
    freq = self:_normalizeTabletRepairFrequency(freq or self._tabletRepairFrequency)
    if freq == "rare" then return ftUiText("ft_common_rare", "Rare") end
    if freq == "normal" then return ftUiText("ft_common_normal", "Normal") end
    if freq == "frequent" then return ftUiText("ft_common_frequent", "Frequent") end
    return ftUiText("ft_common_off", "Off")
end

function FarmTabletUI:_cycleTabletRepairFrequency()
    local freq = self:_normalizeTabletRepairFrequency(self._tabletRepairFrequency)
    if freq == "off" then freq = "rare"
    elseif freq == "rare" then freq = "normal"
    elseif freq == "normal" then freq = "frequent"
    else freq = "off" end
    self._tabletRepairFrequency = freq
    self:_resetTabletRepairUseTimer()
    self:_saveSignalProviderSelection({ id = self._signalProviderId or "realistic_farming", name = self._signalProvider or "Realistic Farming Mobile" })
    return freq
end

function FarmTabletUI:_getTabletRepairDropChance()
    local freq = self:_normalizeTabletRepairFrequency(self._tabletRepairFrequency)
    if freq == "rare" then return 0.20 end
    if freq == "normal" then return 0.45 end
    -- Haeufig ist zum Testen deutlich spuerbar und am Timer garantiert.
    if freq == "frequent" then return 1.00 end
    return 0
end

function FarmTabletUI:_getTabletRepairUseTargetMs()
    local freq = self:_normalizeTabletRepairFrequency(self._tabletRepairFrequency)
    if freq == "rare" then return math.random(900000, 1800000) end      -- 15-30 min Nutzung
    if freq == "normal" then return math.random(300000, 600000) end     -- 5-10 min Nutzung
    if freq == "frequent" then return math.random(20000, 45000) end     -- Test: 20-45 sec Nutzung
    return nil
end

function FarmTabletUI:_resetTabletRepairUseTimer()
    self._tabletRepairUseMs = 0
    self._tabletRepairTargetMs = self:_getTabletRepairUseTargetMs()
end

function FarmTabletUI:_formatRepairRemaining()
    local now = self:_getWorldAbsoluteMinute()
    local remain = math.max(0, (tonumber(self._tabletRepairEndMin) or now) - now)
    local hours = math.floor(remain / 60)
    local minutes = remain % 60
    if hours >= 24 then
        local days = math.floor(hours / 24)
        local restHours = hours % 24
        return ftUiFormat("ft_repair_remaining_day_format", "%d day %02d:%02d", days, restHours, minutes)
    end
    return string.format("%02d:%02d", hours, minutes)
end

function FarmTabletUI:_notifyTabletRepair(msg)
    msg = tostring(msg or "")
    local title = ftUiText("ft_repair_service_title", "Tablet-Service")
    self._signalToast = { title = title, msg = msg, time = 6200 }

    -- Kurze, gut lesbare Spielmeldung statt langer roter Blinkzeile.
    -- Lange Texte waren im HUD kaum lesbar.
    local text = title .. ": " .. msg
    if g_currentMission ~= nil and g_currentMission.addIngameNotification ~= nil then
        local typ = (FSBaseMission and (FSBaseMission.INGAME_NOTIFICATION_INFO or FSBaseMission.INGAME_NOTIFICATION_OK or FSBaseMission.INGAME_NOTIFICATION_CRITICAL)) or 1
        pcall(function() g_currentMission:addIngameNotification(typ, text) end)
    elseif g_currentMission ~= nil and g_currentMission.hud ~= nil and g_currentMission.hud.showBlinkingWarning ~= nil then
        pcall(function() g_currentMission.hud:showBlinkingWarning(text, 6500) end)
    elseif not self.isOpen and g_FarmTablet ~= nil and g_FarmTablet.showNotification ~= nil then
        pcall(function() g_FarmTablet:showNotification(title, msg) end)
    end
end

function FarmTabletUI:_startTabletDisplayRepair(inStock)
    if self._tabletRepairActive == true then return end
    local now = self:_getWorldAbsoluteMinute()
    local duration = (inStock == false) and 1440 or 60
    self._tabletRepairActive = true
    self._tabletRepairStartMin = now
    self._tabletRepairEndMin = now + duration
    self._tabletRepairInStock = inStock ~= false
    self._tabletRepairNotifiedDone = false
    self._tabletRepairLastDropDay = self:_getWorldDayIndex()
    self:_saveSignalProviderSelection({ id = self._signalProviderId or "realistic_farming", name = self._signalProvider or "Realistic Farming Mobile" })
    self:_resetTabletRepairUseTimer()
    self:_notifyTabletRepair(ftUiText("ft_repair_started_msg", "Display damage from a drop. Tablet is being repaired."))
end

function FarmTabletUI:_canTabletRepairTrigger()
    if self._tabletRepairActive == true or self.uiState == "repair" or self.uiState == "provider" then return false end
    local freq = self:_normalizeTabletRepairFrequency(self._tabletRepairFrequency)
    if freq == "off" then return false end
    local day = self:_getWorldDayIndex()
    if tonumber(self._tabletRepairLastDropDay) == day then return false end
    return true
end

function FarmTabletUI:_triggerTabletDropIfAllowed()
    if not self:_canTabletRepairTrigger() then return false end
    local chance = self:_getTabletRepairDropChance()
    if chance <= 0 then return false end
    if math.random() <= chance then
        local displayInStock = (math.random() < 0.70)
        self:_startTabletDisplayRepair(displayInStock)
        return true
    end
    self:_resetTabletRepairUseTimer()
    return false
end

function FarmTabletUI:_updateTabletRepairUsage(dt)
    -- Separater, robuster Nutzungstimer. Der alte Fehler war, dass _sessionSec
    -- nicht zuverlaessig hochgezaehlt wurde; dadurch konnte "Haeufig" nie
    -- ausloesen. Dieser Timer laeuft nur bei geoeffnetem, nutzbarem Tablet.
    if not self.isOpen or not self:_canTabletRepairTrigger() then return false end
    if self.uiState == "empty" then return false end
    if self._tabletRepairTargetMs == nil then
        self:_resetTabletRepairUseTimer()
    end
    if self._tabletRepairTargetMs == nil then return false end
    self._tabletRepairUseMs = (tonumber(self._tabletRepairUseMs) or 0) + (tonumber(dt) or 0)
    self._sessionSec = (tonumber(self._sessionSec) or 0) + ((tonumber(dt) or 0) / 1000)
    if self._tabletRepairUseMs >= self._tabletRepairTargetMs then
        return self:_triggerTabletDropIfAllowed()
    end
    return false
end

function FarmTabletUI:_maybeTriggerTabletDropOnClose()
    -- Beim Schliessen nur noch als Zusatzchance, falls der Nutzungstimer gerade
    -- die Schwelle erreicht hat. Standard bleibt AUS und max. ein Schaden/Tag.
    if not self:_canTabletRepairTrigger() then return end
    if (tonumber(self._tabletRepairUseMs) or 0) >= (tonumber(self._tabletRepairTargetMs) or math.huge) then
        self:_triggerTabletDropIfAllowed()
    end
end

function FarmTabletUI:_updateTabletRepairSystem(dt, force)
    if self._tabletRepairActive ~= true then return false end
    local now = self:_getWorldAbsoluteMinute()
    local endMin = tonumber(self._tabletRepairEndMin) or now
    if now >= endMin then
        self._tabletRepairActive = false
        self._tabletRepairStartMin = nil
        self._tabletRepairEndMin = nil
        self._tabletRepairNotifiedDone = true
        self:_saveSignalProviderSelection({ id = self._signalProviderId or "realistic_farming", name = self._signalProvider or "Realistic Farming Mobile" })
        self:_notifyTabletRepair(ftUiText("ft_repair_done_msg", "Repair completed. Tablet is ready to use again."))
        self:_resetTabletRepairUseTimer()
        if self.uiState == "repair" then
            self.uiState = (self.settings.lockScreenEnabled ~= false) and "lock" or "home"
        end
        return true
    end
    return false
end

-- TEMPORARY console command helper until the real repair station ships.
-- Instantly finishes an in-progress display repair so the tablet is usable again.
-- Charges the farm a fixed fee (FT.FORCE_REPAIR_FEE), then clears the repair state
-- exactly like a natural completion does (see _updateTabletRepairSystem). Remove
-- this together with the TabletForceRepair console command once the repair
-- station exists.
function FarmTabletUI:forceCompleteRepair()
    if self._tabletRepairActive ~= true then
        return false, "Tablet is not in repair, nothing to force"
    end
    if g_currentMission == nil or g_currentMission.getIsServer == nil then
        return false, "Mission not ready"
    end
    if g_currentMission:getIsServer() then
        -- Server: charge the fee here and complete the repair locally.
        local farmId = self:_getNetworkBillingFarmId()
        local ok = pcall(function()
            local farm = g_farmManager ~= nil and g_farmManager:getFarmById(farmId) or nil
            if farm ~= nil and farm.changeBalance ~= nil then
                farm:changeBalance(-FT.FORCE_REPAIR_FEE, MoneyType.OTHER)
                if g_currentMission.addMoneyChange ~= nil then
                    g_currentMission:addMoneyChange(-FT.FORCE_REPAIR_FEE, farmId, MoneyType.OTHER, true)
                end
            end
        end)
        if not ok then
            return false, "Could not deduct the repair fee"
        end
        self:_completeLocalForceRepair()
        return true, string.format("Forced repair complete. Repair fee charged: %d.", FT.FORCE_REPAIR_FEE)
    end

    -- Client on a dedicated server: the fee can only be charged by the server.
    -- Send the request; the server deducts and the broadcast confirm completes
    -- the local repair (see FarmTabletForceRepairEvent).
    if g_client ~= nil and g_client.getServerConnection ~= nil then
        local conn = g_client:getServerConnection()
        if conn ~= nil and conn.sendEvent ~= nil then
            conn:sendEvent(FarmTabletForceRepairEvent.new(self:_getNetworkBillingFarmId()))
            return true, string.format("Repair requested. Repair fee charged: %d.", FT.FORCE_REPAIR_FEE)
        end
    end
    return false, "No server connection available"
end

-- Local half of a forced repair: clear the broken-display state. Called directly by
-- the server path and by the receiving client when the fee-charge confirm arrives.
-- The fee has already been charged wherever money can move.
function FarmTabletUI:_completeLocalForceRepair()
    if self._tabletRepairActive ~= true then return end
    local fee = FT.FORCE_REPAIR_FEE
    self._tabletRepairActive = false
    self._tabletRepairStartMin = nil
    self._tabletRepairEndMin = nil
    self._tabletRepairNotifiedDone = true
    self:_saveSignalProviderSelection({ id = self._signalProviderId or "realistic_farming", name = self._signalProvider or "Realistic Farming Mobile" })
    self:_resetTabletRepairUseTimer()
    if self.uiState == "repair" then
        self.uiState = (self.settings.lockScreenEnabled ~= false) and "lock" or "home"
    end
    self:_notifyTabletRepair(ftUiFormat("ft_repair_force_done_msg", "Forced repair complete. Repair fee charged: %d.", fee))
end

function FarmTabletUI:_drawRepairScreen()
    local L = FT.LAYOUT
    local r = self.r
    local sx, sy, sw, sh = L.screenX, L.screenY, L.screenW, L.screenH
    local cx = sx + sw / 2
    local top = sy + sh * 0.76

    r:rect(sx, sy, sw, sh, {0.015,0.018,0.022,1})
    r:rect(sx, sy + sh - FT.py(4), sw, FT.py(4), {1.0,0.45,0.22,0.90})

    -- Broken display motif
    local crackX = cx - FT.px(70)
    local crackY = sy + sh * 0.50
    r:rect(crackX, crackY, FT.px(140), FT.py(2.0), {1.0,1.0,1.0,0.18})
    r:rect(cx - FT.px(1), crackY - FT.py(48), FT.px(2), FT.py(96), {1.0,1.0,1.0,0.14})
    r:rect(cx - FT.px(40), crackY - FT.py(30), FT.px(80), FT.py(1.6), {1.0,0.45,0.30,0.34})
    r:rect(cx - FT.px(16), crackY - FT.py(18), FT.px(2), FT.py(36), {1.0,0.45,0.30,0.34})

    r:text(cx, top, FT.FONT.TITLE, ftUiText("ft_repair_title", "DISPLAY DAMAGE"), RenderText.ALIGN_CENTER, {1.0,0.72,0.30,1})
    r:text(cx, top - FT.py(32), FT.FONT.BODY, ftUiText("ft_repair_subtitle", "Display damage from a drop"), RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
    r:text(cx, top - FT.py(58), FT.FONT.SMALL, ftUiText("ft_repair_in_progress", "Tablet in repair"), RenderText.ALIGN_CENTER, FT.C.TEXT_NORMAL)
    r:text(cx, top - FT.py(82), FT.FONT.SMALL, ftUiText("ft_repair_notify_done", "We will notify you when the repair is finished."), RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)

    local stockText = (self._tabletRepairInStock ~= false)
        and ftUiText("ft_repair_stock_available", "Display in stock - duration: approx. 1 in-game hour")
        or ftUiText("ft_repair_stock_ordered", "Display ordered - duration: approx. 1 in-game day")
    r:text(cx, sy + sh * 0.30, FT.FONT.SMALL, stockText, RenderText.ALIGN_CENTER, FT.C.TEXT_NORMAL)
    r:text(cx, sy + sh * 0.24, FT.FONT.BODY, ftUiFormat("ft_repair_remaining", "Remaining: %s", self:_formatRepairRemaining()), RenderText.ALIGN_CENTER, {0.80,0.95,1.0,1})

    local bw, bh = FT.px(150), FT.py(34)
    local bx, by = cx - bw/2, sy + sh * 0.12
    r:rect(bx, by, bw, bh, {0.18,0.20,0.24,0.95})
    r:text(cx, by + bh/2 - FT.py(4), FT.FONT.SMALL, ftUiText("ft_common_close", "CLOSE"), RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
    self._tabletRepairCloseBtn = {x=bx,y=by,w=bw,h=bh}
end

function FarmTabletUI:_onMouseRepair(px, py, isDown, isUp, btn)
    if isDown and btn == 1 and hit(self._tabletRepairCloseBtn, px, py) then
        self:closeTablet()
        return true
    end
    return true
end

-- ─────────────────────────────────────────────────────────
-- BATTERY EMPTY SCREEN  (local only, no savegame / no network)
-- ─────────────────────────────────────────────────────────
function FarmTabletUI:_drawBatteryEmpty()
    local L = FT.LAYOUT
    local r = self.r
    local cx = L.screenX + L.screenW / 2
    local cy = L.screenY + L.screenH * 0.56
    r:rect(L.screenX, L.screenY, L.screenW, L.screenH, {0,0,0,1})

    local batW = FT.px(92)
    local batH = FT.py(38)
    local batX = cx - batW / 2
    local batY = cy - batH / 2
    r:rect(batX, batY, batW, batH, {1,1,1,0.16})
    r:rect(batX + batW, batY + batH*0.32, FT.px(5), batH*0.36, {1,1,1,0.16})
    r:rect(batX + FT.px(3), batY + FT.py(3), math.max(FT.px(2), (batW-FT.px(6))*math.max(0, math.min(1, (self._battery or 0)/100))), batH-FT.py(6), {0.95,0.30,0.30,0.90})

    if self._batteryCharging then
        r:text(cx, cy - FT.py(58), FT.FONT.BODY, ftUiText("ft_battery_charging", "Tablet charging..."), RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
        r:text(cx, cy - FT.py(82), FT.FONT.SMALL, string.format("%d%%", math.floor(self._battery or 0)), RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)
    else
        r:text(cx, cy - FT.py(58), FT.FONT.BODY, ftUiText("ft_battery_empty", "Tablet battery empty"), RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
        r:text(cx, cy - FT.py(82), FT.FONT.SMALL, ftUiText("ft_battery_charge_hint", "Charge briefly to continue."), RenderText.ALIGN_CENTER, FT.C.TEXT_DIM)
        local bw = FT.px(170)
        local bh = FT.py(40)
        local bx = cx - bw / 2
        local by = L.screenY + L.screenH * 0.28
        r:rect(bx, by, bw, bh, {0.10,0.55,0.22,0.95})
        r:text(cx, by + bh/2 - FT.py(4), FT.FONT.BODY, ftUiText("ft_battery_charge", "CHARGE"), RenderText.ALIGN_CENTER, FT.C.TEXT_BRIGHT)
        self._batteryChargeBtn = {x=bx, y=by, w=bw, h=bh}
    end
end

function FarmTabletUI:_startBatteryCharge(silent)
    if self._batteryCharging then return end
    self._batteryCharging = true
    self._batteryChargeTimer = 0
    self._batteryChargeLastMs = self:_getBatteryRealTimeMs()
    self._batteryChargeStartLevel = ftClampBattery(self._battery or 0)
    self._batteryChargeNotifyUsable = false
    self._batteryChargeNotifyFull = false
    self._batteryEmpty = true
    if self.isOpen then
        self.uiState = "empty"
        self:_rebuildScreen()
        self:playUISound("paging")
    elseif silent ~= true then
        self:_notifyBattery("ft_battery_service_title", "Tablet-Akku", "ft_battery_empty_auto_charge", "Tablet-Akku leer. Tablet ist am Ladegerät.", true)
    end
end

function FarmTabletUI:_onMouseBatteryEmpty(px, py, isDown, isUp, btn)
    if isDown and btn == 1 and hit(self._batteryChargeBtn, px, py) then
        self:_startBatteryCharge(false)
        return true
    end
    return true
end

--- Physical charging-station hook. A placeable calls this via
--- g_currentMission.farmTablet:setAtCharger(bool) when the LOCAL on-foot player
--- steps on / off its pad. It tops up from the CURRENT battery level (no dead-
--- battery semantics) and only tops up while the tablet is stowed — per design,
--- an open tablet is "in use" and does not charge. The battery is local flavour,
--- so this is purely client-side; there is no network event.
function FarmTabletUI:setAtCharger(isAtCharger)
    isAtCharger = isAtCharger == true
    if isAtCharger == self._atPhysicalCharger then return end
    self._atPhysicalCharger = isAtCharger

    -- One-time heads-up on pad-enter, but only when it will actually charge (stowed,
    -- not empty-self-charging, below full). If the tablet is open, nothing charges
    -- until it is stowed, so no toast fires.
    if isAtCharger and not self._batteryEmpty and (self._battery or 0) < 100 and not self.isOpen then
        self:_notifyBattery("ft_battery_service_title", "Tablet-Akku", "ft_battery_charging", "Tablet charging ...", true)
    end

    self:_evalPhysicalCharge()
end

--- Start/stop the physical-charger top-up so it runs ONLY while the tablet is stowed
--- (design: no charge while open) and below 100%. Called on pad enter/leave AND every
--- update tick, so opening or closing the tablet flips it live. Also drives the world
--- station light through the bridge, so the light is honest: lit only while genuinely
--- topping up, never merely because the player is standing on the pad.
function FarmTabletUI:_evalPhysicalCharge()
    if self._batteryEmpty then return end   -- the empty-state self-charge owns the state

    -- Effective "at charger": the world trigger flags the pad AND the local player is
    -- genuinely close. The distance gate makes an oversized EV-style trigger (or a
    -- missed leave event) safe - without it the tablet would keep topping up and never
    -- drain while the player is merely somewhere near the station.
    local atCharger = self._atPhysicalCharger == true
    if atCharger and FarmTabletFocus and FarmTabletFocus.getChargerDistance then
        local d = FarmTabletFocus:getChargerDistance()
        if d ~= nil and d > 4.0 then atCharger = false end
    end

    if not atCharger and not self._batteryCharging then
        if self._chargeLightState then
            self._chargeLightState = false
            if FarmTabletFocus and FarmTabletFocus.notifyChargeLight then FarmTabletFocus:notifyChargeLight(false) end
        end
        return
    end

    local shouldCharge = atCharger and (not self.isOpen) and (self._battery or 0) < 100
    if shouldCharge and not self._batteryCharging then
        self._batteryChargeRateMs       = 3000
        self._batteryCharging           = true
        self._batteryChargeTimer        = 0
        self._batteryChargeLastMs       = self:_getBatteryRealTimeMs()
        self._batteryChargeStartLevel   = ftClampBattery(self._battery or 0)
        self._batteryChargeNotifyUsable = true
        self._batteryChargeNotifyFull   = false
    elseif (not shouldCharge) and self._batteryCharging then
        -- Paused (tablet opened), left the pad, or reached 100%: keep the % gained.
        self._batteryCharging     = false
        self._batteryChargeRateMs = 6000
        self:_persistBattery(true)
    end

    local lightOn = (self._batteryCharging == true) and (atCharger == true)
    if lightOn ~= self._chargeLightState then
        self._chargeLightState = lightOn
        if FarmTabletFocus and FarmTabletFocus.notifyChargeLight then
            FarmTabletFocus:notifyChargeLight(lightOn)
        end
    end
end

function FarmTabletUI:_getWorldMinuteOfDay()
    -- WICHTIG: Diese Zeit ist nur fuer interne Timer des Netzsystems.
    -- Sie darf NICHT aus dem DataProvider kommen, weil der Provider bei
    -- Netzausfall absichtlich eingefrorene Tablet-Daten liefert.
    -- Die Stoerungsdauer muss aber mit der echten Spielzeit weiterlaufen.
    if g_currentMission and g_currentMission.environment then
        local env = g_currentMission.environment
        local dayTimeMs = tonumber(env.dayTime) or 0
        local dayMinute = math.floor(dayTimeMs / 60000)
        local currentDay = math.max(0, (tonumber(env.currentDay) or 1) - 1)
        return currentDay * 1440 + dayMinute
    end

    -- Fallback nur fuer sehr fruehe Initialisierung, wenn environment noch nicht da ist.
    local data = self.system and self.system.data
    local world = data and data.getWorldInfo and data:getWorldInfo()
    if world and world.hour ~= nil and world.minute ~= nil then
        local d = math.max(0, (tonumber(world.day) or 1) - 1)
        return d * 1440 + (tonumber(world.hour) or 0) * 60 + (tonumber(world.minute) or 0)
    end
    return 0
end

function FarmTabletUI:_notifySignal(title, msg)
    title = tostring(title or "Realistic Farming Mobile")
    msg = tostring(msg or "")
    local key = title .. msg
    if self._signalLastNotify == key then return end
    self._signalLastNotify = key

    -- Tablet-interne Meldung fuer geoeffnetes Tablet und als Merker fuer das naechste Oeffnen.
    -- Lokal/clientseitig und dedi-sicher: keine Sync-, Savegame- oder Gameplay-Eingriffe.
    self._signalToast = {
        title = title,
        msg = msg,
        time = 4200
    }

    -- Wenn das Tablet weggepackt ist, ist die interne Toast-Meldung nicht sichtbar.
    -- Fuer echte Netzstoerungen nutzen wir daher die vorhandene Blinkanzeige des Spiels.
    -- Bewusst nur bei Ausfall/Behebung, nicht bei jedem schwachen Empfang, damit es nicht nervt.
    if not self.isOpen then
        local lowerMsg = string.lower(msg)
        if string.find(lowerMsg, "netzst", 1, true) ~= nil or string.find(lowerMsg, "wiederhergestellt", 1, true) ~= nil then
            if g_FarmTablet ~= nil and g_FarmTablet.showNotification ~= nil then
                pcall(function()
                    g_FarmTablet:showNotification(ftUiText("ft_network_title", "Network"), tostring(msg))
                end)
            elseif g_currentMission ~= nil and g_currentMission.hud ~= nil and g_currentMission.hud.showBlinkingWarning ~= nil then
                pcall(function()
                    g_currentMission.hud:showBlinkingWarning(ftUiText("ft_network_title", "Network") .. ": " .. tostring(msg), 5000)
                end)
            end
        end
    end
end

function FarmTabletUI:_drawSignalToast()
    local toast = self._signalToast
    if toast == nil or (tonumber(toast.time) or 0) <= 0 then return end
    if self.uiState == "empty" or self.uiState == "provider" then return end

    local L = FT.LAYOUT
    local r = self.r
    local w = FT.px(360)
    local h = FT.py(46)
    local x = L.screenX + L.screenW - w - FT.px(18)
    local y = L.screenY + L.screenH - L.statusH - h - FT.py(10)
    local titleFont = (FT.FONT and (FT.FONT.SMALL or FT.FONT.TINY)) or 0.010
    local msgFont = (FT.FONT and (FT.FONT.TINY or FT.FONT.SMALL)) or 0.0085

    -- Dezente Smartphone-Benachrichtigung oben rechts im Tablet.
    self:_fxRect(x, y, w, h, {0.0,0.0,0.0,0.72})
    self:_fxRect(x, y + h - FT.py(2), w, FT.py(2), {0.35,0.90,0.45,0.92})
    local tTitle = tostring(toast.title or ftUiText("ft_network_default_provider", "Realistic Farming Mobile"))
    local tMsg = tostring(toast.msg or "")
    if string.len(tTitle) > 32 then tTitle = string.sub(tTitle, 1, 31) .. "." end
    if string.len(tMsg) > 58 then tMsg = string.sub(tMsg, 1, 57) .. "." end
    r:text(x + FT.px(13), y + h - FT.py(15), titleFont, tTitle, RenderText.ALIGN_LEFT, {0.70,1.0,0.72,1})
    r:text(x + FT.px(13), y + FT.py(11), msgFont, tMsg, RenderText.ALIGN_LEFT, {0.92,0.95,0.98,1})
end

function FarmTabletUI:_calcLocalSignalBars()
    local x, z = 0, 0
    local player = g_currentMission and g_currentMission.player
    if player and player.rootNode and getWorldTranslation then
        local px, _, pz = getWorldTranslation(player.rootNode)
        x, z = tonumber(px) or 0, tonumber(pz) or 0
    end

    -- Dynamische Signalqualität: deterministisch nach Position und Anbieterprofil.
    -- Es wird nichts gespeichert und nichts synchronisiert; dadurch dedi-/MP-sicher.
    local wave = math.sin(x * 0.0021) + math.cos(z * 0.0017) + math.sin((x + z) * 0.0011)
    local provider = self:_findSignalProviderById(self._signalProviderId or "realistic_farming")
    local bias = tonumber(provider and provider.bias) or 0
    wave = wave + bias

    if wave > 1.15 then return 4 end
    if wave > 0.25 then return 3 end
    if wave > -0.65 then return 2 end
    if wave > -1.35 then return 1 end
    return 0
end

function FarmTabletUI:_updateSignalSystem(dt, force)
    self._signalTimer = (self._signalTimer or 0) + (dt or 0)
    if not force and self._signalTimer < 1000 then return false end
    self._signalTimer = 0

    local oldBars = self._signalBars
    local oldOutage = self._signalOutageActive
    local minute = self:_getWorldMinuteOfDay()

    -- Provider-Störungen sind konfigurierbar und standardmäßig AUS.
    -- Nur UI-Status: keine Savegame-, Sync- oder Gameplay-Eingriffe.
    local outageCfg = self:_getSignalOutageConfig()
    local durationMin = math.max(1, math.min(4, tonumber(self._signalOutageDurationHours) or 2)) * 60
    if self._signalOutageActive then
        local endMin = self._signalOutageEndMin or minute
        -- endMin und minute sind absolute Ingame-Minuten. Die sichtbare Tablet-Uhr
        -- darf eingefroren sein, dieser Timer laeuft trotzdem weiter.
        if minute >= endMin then
            self._signalOutageActive = false
            self._signalOutageEndMin = nil
            self._signalFrozenStatusTime = nil
            self._signalFrozenWorldInfo = nil
            self:_scheduleNextSignalOutageCheck(minute, outageCfg)
            self._signalJustRecovered = true
            self:_notifySignal(tostring(self._signalProvider or ftUiText("ft_network_default_provider", "Realistic Farming Mobile")), ftUiText("ft_network_outage_recovered", "Network outage fixed. Data is updating."))
        end
    elseif outageCfg.enabled then
        if self._signalNextCheckMin == nil or self._signalNextCheckStartMin == nil then
            self:_scheduleNextSignalOutageCheck(minute, outageCfg)
        end

        -- TimeScale kann Minuten überspringen. Deshalb nicht auf exakte Minute prüfen,
        -- sondern auf abgelaufene geplante Ingame-Minuten.
        local elapsed = self:_minutesSince(self._signalNextCheckStartMin or minute, minute)
        local dueAfter = tonumber(self._signalNextCheckDelayMin) or 0
        if elapsed >= dueAfter and dueAfter > 0 then
            self._signalOutageActive = true
            do
                local data = self.system and self.system.data
                local world = data and data.getWorldInfo and data:getWorldInfo() or nil
                if world ~= nil then
                    self._signalFrozenWorldInfo = {day=world.day, season=world.season, hour=world.hour, minute=world.minute}
                    self._signalFrozenStatusTime = string.format("%02d:%02d", (tonumber(world.hour) or 0) % 24, tonumber(world.minute) or 0)
                else
                    self._signalFrozenStatusTime = nil
                    self._signalFrozenWorldInfo = nil
                end
            end
            self._signalOutageEndMin = minute + durationMin
            self._signalNextCheckMin = nil
            self._signalNextCheckStartMin = nil
            self._signalNextCheckDelayMin = nil
            self:_notifySignal(tostring(self._signalProvider or ftUiText("ft_network_default_provider", "Realistic Farming Mobile")), ftUiFormat("ft_network_outage_detected", "Network outage detected. Estimated duration: approx. %d in-game hours.", math.floor(durationMin / 60)))
        end
    else
        self._signalNextCheckMin = nil
        self._signalNextCheckStartMin = nil
        self._signalNextCheckDelayMin = nil
        self._signalOutageActive = false
        self._signalOutageEndMin = nil
        self._signalFrozenStatusTime = nil
        self._signalFrozenWorldInfo = nil
    end

    if self._signalOutageActive then
        self._signalBars = 0
        self._signalLabel = ftUiText("ft_network_outage_label", "Network outage")
        self._signalState = "outage"
    else
        self._signalBars = self:_calcLocalSignalBars()
        if self._signalBars <= 0 then
            self._signalLabel = ftUiText("ft_network_no_signal_label", "No signal")
            self._signalState = "offline"
        elseif self._signalBars == 1 then
            self._signalLabel = ftUiText("ft_network_weak_signal_label", "Weak signal")
            self._signalState = "weak"
        else
            self._signalLabel = tostring(self._signalProvider or "Realistic Farming Mobile")
            self._signalState = "ok"
        end
    end

    -- Sichtbare Rückmeldung bei Zustandswechsel, damit man merkt, dass das System arbeitet.
    local stateKey = tostring(self._signalState) .. ":" .. tostring(self._signalBars)
    if stateKey ~= self._signalLastState then
        self._signalLastState = stateKey
        if self._signalState == "offline" then
            self:_notifySignal(tostring(self._signalProvider or ftUiText("ft_network_default_provider", "Realistic Farming Mobile")), ftUiText("ft_network_no_reception_here", "No reception at this location."))
        elseif self._signalState == "weak" then
            self:_notifySignal(tostring(self._signalProvider or ftUiText("ft_network_default_provider", "Realistic Farming Mobile")), ftUiText("ft_network_weak_reception", "Weak reception."))
        elseif self._signalState == "ok" and (oldBars or 4) <= 1 and self._signalJustRecovered ~= true then
            self:_notifySignal(tostring(self._signalProvider or ftUiText("ft_network_default_provider", "Realistic Farming Mobile")), ftUiText("ft_network_outage_recovered", "Network outage fixed. Data is updating."))
        end
        self._signalJustRecovered = false
    end

    -- Publish read-only state for future apps; no network events and no savegame writes.
    if self.system then
        self.system.signal = self.system.signal or {}
        self.system.signal.bars = self._signalBars
        self.system.signal.state = self._signalState
        self.system.signal.label = self._signalLabel
        self.system.signal.outageActive = self._signalOutageActive == true
        self.system.signal.outageEndMinute = self._signalOutageEndMin
        self.system.signal.offlineDataFrozen = self._signalOutageActive == true
        if self.system.data ~= nil and self.system.data.setNetworkOnline ~= nil then
            self.system.data:setNetworkOnline(self._signalOutageActive ~= true)
        end
    end

    -- Bei Netzrückkehr einmal alles neu zeichnen, damit Apps sofort aktuelle Daten holen.
    if oldOutage == true and self._signalOutageActive ~= true then
        if self.system ~= nil and self.system.data ~= nil and self.system.data.invalidate ~= nil then
            self.system.data:invalidate()
        end
    end

    self:_processProviderDailyFee(false)

    return oldBars ~= self._signalBars or oldOutage ~= self._signalOutageActive
end


function FarmTabletUI:_updateBatteryCharging(dt)
    local nowMs = self:_getBatteryRealTimeMs()
    if self._batteryChargeLastMs == nil then self._batteryChargeLastMs = nowMs end
    local elapsed = nowMs - self._batteryChargeLastMs
    self._batteryChargeLastMs = nowMs
    if elapsed < 0 then elapsed = 0 end
    if elapsed > 5000 then elapsed = 5000 end
    self._batteryChargeTimer = (self._batteryChargeTimer or 0) + elapsed

    -- Ladegerät: 1% alle 6 Sekunden Echtzeit, also ca. 10 Minuten von 0 auf 100.
    local oldPct = math.floor(self._battery or 0)
    local startLevel = tonumber(self._batteryChargeStartLevel) or 0
    local gained = math.floor((self._batteryChargeTimer or 0) / (self._batteryChargeRateMs or 6000))
    self._battery = math.min(100, math.max(oldPct, math.floor(startLevel + gained)))
    local pct = math.floor(self._battery or 0)

    if pct ~= oldPct then
        self.settings.tabletBatteryLevel = pct
        self.settings.tabletBatteryDrainMs = 0
        self:_persistBattery(false)
    end

    if pct >= self:_getBatteryMinStartLevel() and self._batteryChargeNotifyUsable ~= true then
        self._batteryChargeNotifyUsable = true
        self._batteryEmpty = false
        -- BUILD 15:39 (PB-12). The key name is no longer baked into the string:
        -- the l10n value carries a %s and we fill it from the live binding, so
        -- this line stays true if the player rebinds the action.
        self:_notifyBattery("ft_battery_service_title", "Tablet-Akku",
            "ft_battery_charged_usable", "Tablet ausreichend geladen. Mit %s wieder einschalten.",
            true, self:_keybindLabel())
    end

    if pct >= 100 then
        self._batteryCharging = false
        self._batteryEmpty = false
        self._battery = 100
        self._batteryStart = self._battery
        self._sessionSec = 0
        self._batteryDrainMs = 0
        self:_persistBattery(true)
        if self.isOpen then
            self.uiState = (self.settings.lockScreenEnabled ~= false) and "lock" or "home"
            self:_rebuildScreen()
            self:playUISound("paging")
        elseif self._batteryChargeNotifyFull ~= true then
            self._batteryChargeNotifyFull = true
            self:_notifyBattery("ft_battery_service_title", "Tablet-Akku", "ft_battery_charged_full", "Tablet voll geladen.", true)
        end
    elseif self.isOpen and (not self._lastChargeDraw or ((self._batteryChargeTimer or 0) - self._lastChargeDraw) >= 1000) then
        self._lastChargeDraw = self._batteryChargeTimer
        self:_rebuildScreen()
    end
end

function FarmTabletUI:update(dt)
    -- BUILD 15:39 (PB-03 / PB-10). Runs before every early return below so the
    -- claim can never outlive the tablet: this flushes a deferred context revert
    -- and force-releases if `isOpen` went false down any path.
    if FarmTabletModal ~= nil then
        FarmTabletModal.update(self)
        -- BUILD 06:33. Backstop only. The claim is taken in `_openTabletBody`
        -- before the first paint; this re-takes it if that call did not land
        -- (an older save path, or a claim refused while `g_inputBinding` was
        -- still coming up). The `_paintedOnce` condition is gone on purpose: it
        -- was the window in which MENU was still live over a painted tablet.
        if self.isOpen and not FarmTabletModal.isClaimed() then
            FarmTabletModal.claim(self)
        end
    end

    -- Das Empfangssystem muss auch laufen, wenn das Tablet weggepackt ist.
    -- So koennen Netzausfaelle per vorhandener Blinkanzeige gemeldet werden.
    local signalChanged = false
    if self.uiState ~= "provider" then
        signalChanged = self:_updateSignalSystem(dt) == true
    end
    local repairChanged = self:_updateTabletRepairSystem(dt) == true

    if self.isOpen then
        local dropStarted = self:_updateTabletRepairUsage(dt) == true
        if dropStarted then
            -- Displaybruch waehrend der Nutzung: Tablet sofort sperren/schliessen.
            -- Danach kann T nur noch eine Reparaturmeldung anzeigen, bis die
            -- Auslieferung abgeschlossen ist.
            self.uiState = "lock"
            self:closeTablet()
            return
        end
    end

    -- Physical charging-station: (re)evaluate every frame so opening/closing the
    -- tablet pauses/resumes the top-up and keeps the station light honest.
    self:_evalPhysicalCharge()

    if not self.isOpen then
        if self._batteryCharging then
            self:_updateBatteryCharging(dt)
        else
            self:_updateBatterySystem(dt)
        end
        return
    end
    if repairChanged then
        self:_rebuildScreen()
    end

    self:_updateEditMode(dt)

    if not self._editModeActive then
        if g_inputBinding and g_inputBinding.setShowMouseCursor then
            g_inputBinding:setShowMouseCursor(true)
        end
        if self._tabletCamRotX and g_cameraManager and setRotation then
            local cam = g_cameraManager:getActiveCamera()
            if cam and cam ~= 0 then
                setRotation(cam, self._tabletCamRotX, self._tabletCamRotY, self._tabletCamRotZ)
            end
        end
    end

    -- Animation tick (transient; no rebuild needed)
    if self._anim then
        self._anim.t = self._anim.t + dt
        if self._anim.t >= self._anim.dur then self._anim = nil end
    end

    if self._signalToast ~= nil then
        self._signalToast.time = (tonumber(self._signalToast.time) or 0) - (dt or 0)
        if self._signalToast.time <= 0 then self._signalToast = nil end
    end

    -- Empfang nur außerhalb der Anbieter-Auswahl aktualisieren, damit die
    -- Auswahl nicht durch Statusbar-Rebuilds verschwindet oder Klicks verliert.
    if self.uiState ~= "provider" and signalChanged and self.uiState ~= "empty" then
        self:_rebuildScreen()
    end

    if self._batteryCharging then
        -- Empty-state self-charge continues while the tablet is open; a physical
        -- charging-station top-up pauses here (design: no charge while in use) and
        -- resumes from the closed-branch tick once the tablet is stowed again.
        if self._batteryEmpty then
            self:_updateBatteryCharging(dt)
            return
        end
    else
        local batteryChanged = self:_updateBatterySystem(dt)
        if batteryChanged and (self._battery or 0) <= 0 then
            return
        end
    end

    -- Scroll / paging by state
    if self.uiState == "app" then
        self:_pollContentScroll()
        self:_updateContentScrollSmooth(dt)
        if self.system.currentApp == FT.APP.EXCAVATOR and self.updateExcavatorApp then
            self:updateExcavatorApp(dt)
        end
    elseif self.uiState == "home" then
        self:_pollHomePaging()
    end

    -- 1s clock / battery text refresh
    self._clockTimer = (self._clockTimer or 0) + dt
    if self._clockTimer >= 1000 then
        self._clockTimer = 0
        -- Bei KEIN NETZ nicht jede Sekunde neu rendern. Dadurch bleibt die
        -- Tablet-Uhr sichtbar eingefroren, waehrend die echte Spielzeit normal
        -- weiterlaeuft. Wenn der Akku-Iconstand wechselt, darf weiterhin neu
        -- aufgebaut werden, aber mit dem eingefrorenen Tablet-Zeitwert.
        if self.uiState ~= "empty" and math.floor(self._battery or 0) ~= (self._batteryDrawn or -1) then
            self:_rebuildScreen()
        elseif self._signalOutageActive ~= true then
            self:_refreshStatusBar()
        end
    end

    -- Live app content refresh. Bei Netzausfall bleibt der sichtbare Tablet-
    -- Inhalt stehen; Aktualisierung erfolgt erst nach Netzrueckkehr.
    self._contentTimer = (self._contentTimer or 0) + dt
    if self.uiState == "app" and self._contentTimer >= 4000 and not self._editModeActive then
        self._contentTimer = 0
        if self._signalOutageActive == true then
            -- absichtlich nichts neu zeichnen
        else
            self:_drawContent()
        end
    end
end

-- ─────────────────────────────────────────────────────────
-- HOME PAGING SCROLL  (wheel pages the springboard)
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_pollHomePaging()
    if not self.isOpen then return end
    local L = FT.LAYOUT
    local px, py = self._mouseX, self._mouseY
    if not (px >= L.screenX and px <= L.screenX + L.screenW and
            py >= L.canvasY and py <= L.canvasY + L.canvasH) then
        self._hWheelUpWas = false; self._hWheelDownWas = false
        return
    end
    local upNow   = Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP)
    local downNow = Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN)
    local dir = nil
    if upNow   and not self._hWheelUpWas   then dir = -1 end
    if downNow and not self._hWheelDownWas then dir =  1 end
    self._hWheelUpWas   = upNow
    self._hWheelDownWas = downNow
    if dir == nil then return end
    local newPage = math.max(0, math.min((self._pageCount or 1) - 1, (self._page or 0) + dir))
    if newPage ~= self._page then
        self._page = newPage
        self:_rebuildScreen()
        self:playUISound("paging")
    end
end

-- ─────────────────────────────────────────────────────────
-- CONTENT AREA SCROLL  (Settings and other tall apps)
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_redrawScrolledContent()
    if not self.r then return end
    self.r:clearAppLayer()
    self._contentBtns = {}
    self:_drawContent()
end

function FarmTabletUI:_applyContentScroll(dir, fast)
    if (self._contentScrollMax or 0) <= 0 then return false end

    -- Stable wheel scrolling:
    -- The previous eased/animated scroll rebuilt the app layer over several
    -- frames. On larger app lists this felt jerky and sometimes continued
    -- farther than expected. Keep it simple and LS-like: one wheel notch moves
    -- a calm, fixed distance and redraws exactly once.
    local step = self._contentScrollStep or FT.py(46)
    if fast then step = step * 1.25 end

    local maxY = self._contentScrollMax or 0
    local current = self._contentScrollY or 0
    local newY = math.max(0, math.min(current + (dir * step), maxY))
    if math.abs(newY - current) <= 0.0001 then return false end

    self._contentScrollY = newY
    self._contentScrollTarget = newY
    self._contentScrollMoving = false
    self:_redrawScrolledContent()
    return true
end

function FarmTabletUI:_updateContentScrollSmooth(dt)
    -- Intentionally disabled. Direct, single-redraw wheel scrolling is smoother
    -- in this tablet because every redraw rebuilds text/buttons for the current
    -- app. Animating that rebuild over multiple frames caused stutter.
    self._contentScrollMoving = false
end

function FarmTabletUI:_pollContentScroll()
    -- Wheel input is handled by _onMouse only. Polling the wheel here made
    -- some mice/drivers repeat a single wheel notch for several frames, which
    -- felt like the list was running to the bottom by itself.
    return
end

-- ─────────────────────────────────────────────────────────
-- MOUSE INPUT  (dispatch by state)
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_onMouse(px, py, isDown, isUp, btn)
    if not self.isOpen then return false end
    -- While editing (move/resize) the dedicated edit handler owns the mouse.
    if self._editModeActive then return false end
    self._mouseX = px
    self._mouseY = py

    -- Direct mouse-wheel scrolling in apps. Do it here instead of only via polling,
    -- so every wheel notch reacts immediately and the camera never receives it.
    if isDown and (btn == Input.MOUSE_BUTTON_WHEEL_UP or btn == Input.MOUSE_BUTTON_WHEEL_DOWN) then
        if self.uiState == "app" then
            local L = FT.LAYOUT
            if L.contentX and px >= L.contentX and px <= L.contentX + L.contentW and
               py >= L.contentY and py <= L.contentY + L.contentH then
                local dir = (btn == Input.MOUSE_BUTTON_WHEEL_UP) and -1 or 1
                self:_applyContentScroll(dir, false)
                self._cWheelUpWas   = Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP)
                self._cWheelDownWas = Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN)
            end
        end
        return true
    end

    if self.uiState == "empty" then
        return self:_onMouseBatteryEmpty(px, py, isDown, isUp, btn)
    end

    if self.uiState == "repair" then
        return self:_onMouseRepair(px, py, isDown, isUp, btn)
    end

    if self.uiState == "provider" then
        return self:_onMouseProvider(px, py, isDown, isUp, btn)
    end

    -- Lock screen gets its own handler (slide-to-unlock drag)
    if self.uiState == "lock" then
        return self:_onMouseLock(px, py, isDown, isUp, btn)
    end

    -- Power / lock button works in every non-lock state
    if isDown and btn == 1 and hit(self._powerBtn, px, py) then
        self:lockNow()
        return true
    end

    -- ── Springboard icon press / release (tactile launch) ──
    if self.uiState == "home" then
        if isDown and btn == 1 then
            -- BUILD 15:39 (PB-02). The grid carries the same Home/Back cluster
            -- as the app bar. At the grid root both are dimmed and inert; off
            -- root (favourites page, or page 2+) they step exactly one level.
            if hitInert(self._homeBtn, px, py) or hitInert(self._backBtn, px, py) then
                return true
            end
            if hitLive(self._homeBtn, px, py) then self:goHome(); return true end
            if hitLive(self._backBtn, px, py) then self:goBack(); return true end
            -- Star toggle: springboard ↔ favourites page
            if hit(self._homeStarBtn, px, py) then
                self:toggleFavoritesMode(); return true
            end
            -- Favourites EDIT / DONE button
            if hit(self._favEditBtn, px, py) then
                self._favEditing = not self._favEditing
                self:_rebuildScreen(); self:playUISound("click"); return true
            end
            -- Page dots (work in every home mode)
            for _, pd in ipairs(self._pageDots) do
                if hit(pd, px, py) and pd.page ~= self._page then
                    self._page = pd.page
                    self:_rebuildScreen()
                    self:playUISound("paging")
                    return true
                end
            end
            -- Favourites edit mode: tapping an app toggles its favourite state
            if self._homeMode == "favorites" and self._favEditing then
                for _, ib in ipairs(self._iconBtns) do
                    if hit(ib, px, py) then
                        self:toggleFavorite(ib.appId)
                        self:_rebuildScreen(); self:playUISound("click")
                        return true
                    end
                end
                return true   -- swallow misses so nothing launches while editing
            end
            -- Normal: press an icon / dock app to launch
            for _, ib in ipairs(self._iconBtns) do
                if hit(ib, px, py) then
                    self._pressedIcon = ib.appId
                    self._pressedRect = { x = ib.x, y = ib.y, w = ib.w, h = ib.h }
                    self._pressMoved  = false
                    return true
                end
            end
            for _, db in ipairs(self._dockBtns) do
                if hit(db, px, py) then
                    self._pressedIcon = db.appId
                    self._pressedRect = { x = db.x, y = db.y, w = db.w, h = db.h }
                    self._pressMoved  = false
                    return true
                end
            end
        end

        -- moving with a pressed icon: cancel if dragged off it
        if not isDown and not isUp and self._pressedIcon then
            if not hit(self._pressedRect, px, py) then
                self._pressedIcon = nil
                self._pressedRect = nil
            end
            return true
        end

        if isUp and btn == 1 and self._pressedIcon then
            local appId = self._pressedIcon
            local rect  = self._pressedRect
            self._pressedIcon = nil
            self._pressedRect = nil
            if hit(rect, px, py) then
                -- zoom from the precise icon rect when known, else the cell
                self:launchApp(appId, self._appCellRects[appId] or rect)
            end
            return true
        end
        return false
    end

    -- ── App view ──
    if self.uiState == "app" then
        if isDown and btn == 1 then
            -- Inert first: a dimmed Home/Back swallows the click and does
            -- nothing at all (PB-02, no collapse strip, no snap-back).
            if hitInert(self._homeBtn, px, py) or hitInert(self._backBtn, px, py) then
                return true
            end
            if hitLive(self._homeBtn, px, py) then self:goHome(); return true end
            if hitLive(self._backBtn, px, py) then self:goBack(); return true end
            if hitLive(self._starBtn, px, py) then self:openFavorites(); return true end

            for _, cb in ipairs(self._contentBtns) do
                if not cb._isText and hit(cb, px, py) then
                    if cb.meta and cb.meta.onClick then
                        cb.meta.onClick()
                        if self.isOpen and self.uiState == "app" then
                            self:_drawContent()
                            self._contentTimer = 0
                        end
                    end
                    return true
                end
            end
        end
        return false
    end

    return false
end

-- ─────────────────────────────────────────────────────────
-- CONTENT LAYOUT HELPERS  (used by app drawer functions)
-- (Unchanged API — apps depend on these signatures.)
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:getContentScrollY()
    return self._contentScrollY or 0
end

function FarmTabletUI:drawInfoIcon(stateKey, accentColor)
    local x, contentY, w, _ = self:contentInner()
    local ac = accentColor or FT.C.BRAND

    local iSz = FT.px(18)
    local iX  = x + w - iSz
    local iY  = contentY

    self.r:appRect(iX, iY, iSz, iSz, {ac[1], ac[2], ac[3], 0.18})

    local bdr = FT.px(1.2)
    local bc  = {ac[1], ac[2], ac[3], 0.65}
    self.r:appRect(iX,             iY,              iSz, bdr, bc)
    self.r:appRect(iX,             iY + iSz - bdr,  iSz, bdr, bc)
    self.r:appRect(iX,             iY,              bdr, iSz, bc)
    self.r:appRect(iX + iSz - bdr, iY,              bdr, iSz, bc)

    local dotW = FT.px(3)
    local dotH = FT.py(3)
    self.r:appRect(iX + (iSz - dotW) * 0.5, iY + iSz - FT.py(5) - dotH, dotW, dotH, {ac[1], ac[2], ac[3], 1.00})

    local stW = FT.px(2.5)
    local stH = FT.py(5.5)
    self.r:appRect(iX + (iSz - stW) * 0.5, iY + FT.py(3.5), stW, stH, {ac[1], ac[2], ac[3], 1.00})

    local sk    = stateKey
    local appId = self.system.currentApp
    local btn = {
        x = iX, y = iY, w = iSz, h = iSz,
        meta = { onClick = function()
            self[sk] = true
            self:switchApp(appId)
        end }
    }
    table.insert(self._contentBtns, btn)
    return btn
end

function FarmTabletUI:drawHelpPage(stateKey, appId, headerTitle, accentColor, entries)
    if not self[stateKey] then return false end

    local ac     = accentColor or FT.C.BRAND
    local startY = self:drawAppHeader(headerTitle, ftUiText("ft_help_common_title", "Help"))
    local x, contentY, w, _ = self:contentInner()
    local y = startY

    local bw = FT.px(52)
    local bh = FT.py(18)
    local backBtn = self.r:button(
        x + w - bw, startY + FT.py(2), bw, bh, ftUiText("ft_help_back", "< BACK"), FT.C.BTN_NEUTRAL,
        { onClick = function()
            self[stateKey] = false
            self:switchApp(appId)
        end }
    )
    table.insert(self._contentBtns, backBtn)

    y = y - FT.py(10)

    for _, entry in ipairs(entries) do
        if y < contentY + FT.py(12) then break end

        self.r:appRect(x - FT.px(4), y - FT.py(1), w + FT.px(8), FT.py(14), {ac[1], ac[2], ac[3], 0.12})
        self.r:appText(x, y, FT.FONT.SMALL, entry.title, RenderText.ALIGN_LEFT, FT.C.TEXT_ACCENT)
        y = y - FT.py(16)

        for line in ((entry.body or "") .. "\n"):gmatch("([^\n]*)\n") do
            if y < contentY + FT.py(8) then break end
            self.r:appText(x + FT.px(8), y, FT.FONT.TINY, line, RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
            y = y - FT.py(13)
        end
        y = y - FT.py(5)
    end

    return true
end

function FarmTabletUI:setContentHeight(totalH)
    local _, _, _, ch = self:contentInner()
    self._contentScrollMax  = math.max(0, totalH - ch)
    self._contentScrollStep = FT.py(46)
    self._contentScrollY = math.min(self._contentScrollY or 0, self._contentScrollMax)
    self._contentScrollTarget = math.min(self._contentScrollTarget or self._contentScrollY or 0, self._contentScrollMax)
end

function FarmTabletUI:drawScrollBar()
    local scrollMax = self._contentScrollMax or 0
    if scrollMax <= 0 then return end

    local cx, cy, cw, ch = self:contentInner()
    local barX     = cx + cw + FT.px(4)
    local barY     = cy
    local barH     = ch
    local barW     = FT.px(4)

    self.r:appRect(barX, barY, barW, barH, {0.12, 0.14, 0.20, 0.85})

    local total    = ch + scrollMax
    local thumbH   = math.max(FT.py(14), barH * (ch / total))
    local scrolled = self._contentScrollY or 0
    local thumbY   = barY + barH - thumbH - (barH - thumbH) * (scrolled / scrollMax)

    self.r:appRect(barX, thumbY, barW, thumbH, {FT.C.BRAND[1], FT.C.BRAND[2], FT.C.BRAND[3], 0.80})

    self.r:appText(barX + barW + FT.px(4), barY + barH - FT.py(10),
        FT.FONT.TINY, ftUiText("ft_scroll_label", "scroll"), RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
end

function FarmTabletUI:content()
    return FT.LAYOUT.contentX, FT.LAYOUT.contentY, FT.LAYOUT.contentW, FT.LAYOUT.contentH
end

function FarmTabletUI:contentInner()
    local px = FT.px(16)
    local py = FT.py(12)
    return FT.LAYOUT.contentX + px,
           FT.LAYOUT.contentY + py,
           FT.LAYOUT.contentW - px*2,
           FT.LAYOUT.contentH - py*2
end

function FarmTabletUI:drawAppHeader(title, subtitle)
    local x, y, w, h = self:contentInner()
    local topY = y + h - FT.py(2)
    local accent = FT.appColor(self.system.currentApp)

    if self._signalOutageActive == true then
        topY = self:_drawOfflineDataBannerAt(x, topY, w)
    end

    if self.r.appHeaderText then
        self.r:appHeaderText(x, topY, FT.FONT.TITLE, title, RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)
    else
        self.r:appText(x, topY, FT.FONT.TITLE, title, RenderText.ALIGN_LEFT, FT.C.TEXT_BRIGHT)
    end

    if subtitle then
        if self.r.appHeaderText then
            self.r:appHeaderText(x + w, topY, FT.FONT.SMALL, subtitle, RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
        else
            self.r:appText(x + w, topY, FT.FONT.SMALL, subtitle, RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
        end
    end

    local divY = topY - FT.py(18)
    if self.r.appHeaderRect then
        self.r:appHeaderRect(x, divY, w, math.max(FT.py(1.5), 0.001), {accent[1], accent[2], accent[3], 0.80})
        self.r:appHeaderRect(x, divY - FT.py(2), w, FT.py(3), {accent[1], accent[2], accent[3], 0.12})
    else
        self.r:appRect(x, divY, w, math.max(FT.py(1.5), 0.001), {accent[1], accent[2], accent[3], 0.80})
        self.r:appRect(x, divY - FT.py(2), w, FT.py(3), {accent[1], accent[2], accent[3], 0.12})
    end

    FT.LAYOUT.bodyClipTop = divY - FT.py(6)
    return divY - FT.py(12)
end

function FarmTabletUI:drawRow(y, label, value, labelC, valueC)
    local x, _, w, _ = self:contentInner()
    self.r:row(x, y, w, label, value, labelC, valueC)
    return y - FT.py(FT.SP.ROW)
end

function FarmTabletUI:drawSection(y, label)
    local x, _, w, _ = self:contentInner()
    self.r:sectionHeader(x, y, w, label)
    return y - FT.py(18)
end

function FarmTabletUI:drawRule(y, alpha)
    local x, _, w, _ = self:contentInner()
    self.r:rule(x, y, w, alpha)
    return y - FT.py(16)
end

function FarmTabletUI:drawBar(y, value, maxVal, color)
    local x, _, w, _ = self:contentInner()
    return self.r:progressBar(x, y, w, value, maxVal, color)
end

function FarmTabletUI:drawButton(y, label, color, meta)
    local x, _, w, _ = self:contentInner()
    local txt = tostring(label or "")
    -- Lange deutsche Texte dürfen nicht aus dem Button links/rechts herauslaufen.
    -- Deshalb wird der Button je nach Text automatisch breiter, maximal bis zur Inhaltsbreite.
    local bw = math.min(w, math.max(FT.px(150), string.len(txt) * FT.px(4.8)))
    local bh = FT.py(22)
    local btn = self.r:button(x, y, bw, bh, label, color, meta)
    table.insert(self._contentBtns, btn)
    return y - bh - FT.py(4), btn
end

function FarmTabletUI:drawButtonPair(y, labelA, colorA, metaA, labelB, colorB, metaB)
    local x, _, w, _ = self:contentInner()
    local bw = FT.px(100)
    local bh = FT.py(22)
    local gap = FT.px(8)
    local btnA = self.r:button(x,        y, bw, bh, labelA, colorA, metaA)
    local btnB = self.r:button(x+bw+gap, y, bw, bh, labelB, colorB, metaB)
    table.insert(self._contentBtns, btnA)
    table.insert(self._contentBtns, btnB)
    return y - bh - FT.py(4), btnA, btnB
end

-- ─────────────────────────────────────────────────────────
-- DEFAULT SCREENS
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_drawWelcome()
    local startY = self:drawAppHeader("Farm Tablet", "v" .. FT.VERSION)
    local y = startY
    local x, _, w, _ = self:contentInner()

    y = y - FT.py(10)
    self.r:appText(x, y, FT.FONT.BODY, "Welcome! Tap an app to begin.", RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
    y = y - FT.py(22)
    self.r:appText(x, y, FT.FONT.SMALL, "Tap HOME to return to the app grid.", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
end

function FarmTabletUI:_drawError(msg)
    local startY = self:drawAppHeader("App Error", "")
    local x, _, _, _ = self:contentInner()
    self.r:appText(x, startY - FT.py(8), FT.FONT.SMALL, tostring(msg), RenderText.ALIGN_LEFT, FT.C.NEGATIVE)
end

-- ─────────────────────────────────────────────────────────
-- CLEANUP
-- ─────────────────────────────────────────────────────────

function FarmTabletUI:_destroy()
    if self._editModeActive then
        self:_exitEditMode()
    end
    if self._editBgOverlay then
        delete(self._editBgOverlay)
        self._editBgOverlay = nil
    end
    self.r:destroyAll()
    self._iconBtns    = {}
    self._dockBtns    = {}
    self._contentBtns = {}
    self._iconQueue   = {}
    self._closeBtn    = nil
    if self._fx and self._fx.delete then self._fx:delete() end
    self._fx = nil
end

function FarmTabletUI:delete()
    self:_destroy()
    -- Free the baked-icon overlay cache on mod unload.
    if FT_Icons and FT_Icons.deleteAll then FT_Icons.deleteAll() end
end

function FarmTabletUI:log(msg, ...)
    if self.settings.debugMode then
        Logging.info("[FarmTablet UI] " .. string.format(msg, ...))
    end
end

-- ── Sound helpers ─────────────────────────────────────────

function FarmTabletUI:playUISound(soundType)
    local s = self.settings
    if not (s and s.soundEffects) then return end
    pcall(function()
        if not (g_gui and g_gui.guiSoundPlayer) then return end
        if soundType == "click" then
            g_gui.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)
        elseif soundType == "paging" then
            g_gui.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.PAGING)
        elseif soundType == "back" then
            g_gui.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.BACK)
        end
    end)
end
