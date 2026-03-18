-- =========================================================
-- FarmTablet v2 – EventBus
-- Lightweight publish/subscribe for mod-wide events.
-- FT_EventBus is a singleton — _listeners is a single shared
-- table. Listeners registered with :on() persist for the
-- lifetime of the game session; call :off() to unsubscribe.
-- =========================================================
FT_EventBus = {}
FT_EventBus._listeners = {}

function FT_EventBus:on(event, fn)
    if not self._listeners[event] then
        self._listeners[event] = {}
    end
    table.insert(self._listeners[event], fn)
end

function FT_EventBus:off(event, fn)
    if not self._listeners[event] then return end
    for i, f in ipairs(self._listeners[event]) do
        if f == fn then
            table.remove(self._listeners[event], i)
            return
        end
    end
end

function FT_EventBus:emit(event, ...)
    if not self._listeners[event] then return end
    for _, fn in ipairs(self._listeners[event]) do
        local ok, err = pcall(fn, ...)
        if not ok then
            Logging.warning("[FarmTablet EventBus] Error in listener for '" .. event .. "': " .. tostring(err))
        end
    end
end

-- Well-known events
FT_EventBus.EVENTS = {
    APP_SWITCHED      = "app_switched",
    TABLET_OPENED     = "tablet_opened",
    TABLET_CLOSED     = "tablet_closed",
    APP_REGISTERED    = "app_registered",
    SETTINGS_CHANGED  = "settings_changed",
    DATA_REFRESHED    = "data_refreshed",
}
