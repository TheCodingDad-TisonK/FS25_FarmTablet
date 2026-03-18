# Writing a New App

This guide walks through building a complete Farm Tablet app from scratch — registering it, drawing content, adding buttons, and wiring up a help page.

---

## 1. Choose an App ID

App IDs are lowercase strings used everywhere: routing, settings, event bus, etc. Pick something short and descriptive with underscores, no spaces.

```lua
-- Good
"my_custom_app"
"vehicle_tracker"
"fuel_log"

-- Avoid
"MyApp"          -- mixed case can cause issues
"my app"         -- spaces not supported
```

---

## 2. Register the App Constant (optional but recommended)

If you are writing a companion mod that integrates with Farm Tablet, add your app ID to the `FT.APP` table after the mod loads:

```lua
-- In your mod's main.lua, after Farm Tablet has loaded:
if FT and FT.APP then
    FT.APP.MY_APP = "my_custom_app"
end
```

For built-in apps (shipping with the tablet itself), add it to `src/core/Constants.lua`:

```lua
FT.APP = {
    -- ... existing entries ...
    MY_APP = "my_custom_app",
}
```

And add an accent colour in the `FT.APP_COLOR` table:

```lua
FT.APP_COLOR = {
    -- ... existing entries ...
    my_custom_app = {0.30, 0.65, 1.00, 1.00},  -- sky blue
}
```

---

## 3. Register with AppRegistry

**For a built-in app** — add an entry to `AppRegistry.BUILTIN_APPS`:

```lua
{
    id          = FT.APP.MY_APP,
    group       = "farm",           -- "core", "farm", "finance", or "mods"
    name        = "ft_ui_app_my_app",  -- i18n key for the display name
    navLabel    = "MYA",            -- 3-4 char sidebar label
    icon        = "my_app",
    order       = 16,               -- position in sidebar (lower = higher up)
    developer   = "YourName",
    version     = "Built-in",
    description = "Brief description shown in App Store",
},
```

**For a companion mod app** — register it in `AppRegistry:autoDetect()`:

```lua
function AppRegistry:autoDetect()
    -- ... existing checks ...

    -- My Custom Mod
    if g_currentMission and g_currentMission.myModManager then
        if not self:has("my_custom_app") then
            self:register({
                id          = "my_custom_app",
                group       = "mods",
                name        = "ft_ui_app_my_custom",
                navLabel    = "MYA",
                icon        = "my_app",
                order       = 30,
                developer   = "YourName",
                version     = "Integrated",
                description = "My Custom Mod integration",
            })
        end
    end
end
```

---

## 4. Source the App File

Add a `source()` call in `src/main.lua`:

```lua
-- Built-in Apps
source(modDirectory .. "src/apps/MyCustomApp.lua")
```

Order matters only if your app depends on another app's state. In general, place new apps after the existing list.

---

## 5. Write the Drawer Function

Create `src/apps/MyCustomApp.lua`. The entire app is one function registered with `FarmTabletUI:registerDrawer()`:

```lua
-- =========================================================
-- FarmTablet v2 – My Custom App
-- =========================================================

FarmTabletUI:registerDrawer("my_custom_app", function(self)
    local AC = FT.appColor("my_custom_app")   -- accent color for this app

    -- ── Help page (must be first) ──────────────────────
    if self:drawHelpPage("_myAppHelp", "my_custom_app", "My App", AC, {
        { title = "WHAT THIS APP DOES",
          body  = "Explains what your app shows and why it matters." },
        { title = "HOW TO READ IT",
          body  = "Details on what each row/bar/value means." },
    }) then return end  -- <-- always return if help page was drawn

    -- ── Normal page ────────────────────────────────────
    local startY = self:drawAppHeader("My App", "subtitle")
    local x, contentY, cw, _ = self:contentInner()
    local y = startY

    -- Draw a section header
    y = self:drawSection(y, "MY SECTION")

    -- Draw label/value rows
    y = self:drawRow(y, "Some Label", "Some Value")
    y = self:drawRow(y, "Another Row", "42", nil, FT.C.POSITIVE)

    -- Draw a rule
    y = self:drawRule(y, 0.35)

    -- Draw a progress bar
    y = self:drawBar(y, 75, 100, FT.C.BRAND)

    -- Draw a button
    self:drawButton(y, "DO SOMETHING", FT.C.BTN_PRIMARY, {
        onClick = function()
            -- action here
            self:switchApp("my_custom_app")  -- refresh the page
        end
    })

    -- Info icon (always last)
    self:drawInfoIcon("_myAppHelp", AC)
end)
```

---

## 6. The Drawing API

All drawing goes through helpers on `self` (the `FarmTabletUI` instance).

### Layout helpers

```lua
local x, y, w, h = self:contentInner()
-- x, y = bottom-left of padded content area
-- w, h = width and height of padded area
-- y is the BOTTOM edge (FS25 Y increases upward)

local scrollY = self:getContentScrollY()
-- for scrollable apps: add scrollY to your starting y
```

### Standard primitives

```lua
-- App title bar
local startY = self:drawAppHeader("Title", "Optional Subtitle")
-- Returns the Y where content should begin (below the divider)

-- Section header with left accent bar
y = self:drawSection(y, "SECTION LABEL")

-- Label / value row
y = self:drawRow(y, "Label", "Value")
y = self:drawRow(y, "Label", "Value", labelColor, valueColor)
-- labelColor / valueColor are RGBA tables from FT.C, or nil for defaults

-- Horizontal rule
y = self:drawRule(y)
y = self:drawRule(y, 0.4)  -- custom opacity

-- Progress bar (full content width)
y = self:drawBar(y, currentValue, maxValue, color)
-- Returns y below the bar

-- Single button
local nextY, btn = self:drawButton(y, "LABEL", FT.C.BTN_PRIMARY, {
    onClick = function() ... end
})

-- Two buttons side by side
local nextY, btnA, btnB = self:drawButtonPair(y,
    "LEFT",  FT.C.BTN_PRIMARY,  { onClick = function() ... end },
    "RIGHT", FT.C.BTN_NEUTRAL,  { onClick = function() ... end })
```

### Low-level renderer (for custom layout)

```lua
-- Coloured rectangle (app-scoped — cleared on app switch)
self.r:appRect(x, y, w, h, {r, g, b, a})

-- Text (app-scoped)
self.r:appText(x, y, FT.FONT.BODY, "text", RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)

-- Badge/chip
local badgeW = self.r:badge(x, y, "LABEL", FT.C.BTN_PRIMARY)
-- Returns the badge width so you can advance x

-- Section header
self.r:sectionHeader(x, y, contentW, "SECTION")
```

---

## 7. Scrollable Content

For apps that render more content than fits in the content area, call `setContentHeight()` at the end of your drawer:

```lua
-- After all drawing is done:
local totalH = startY - y   -- how tall was everything we drew
self:setContentHeight(totalH)
```

The scroll wheel over the content area will then scroll through it automatically. The system handles the math — your drawer just needs to offset its Y values:

```lua
local scrollY = self:getContentScrollY()
local y = startY + scrollY   -- shift starting position by scroll offset
```

See `SettingsApp.lua` for the full scrollable pattern.

---

## 8. Accessing Game Data

Use `self.system.data` (a `FT_DataProvider` instance) for all game queries:

```lua
local data   = self.system.data
local farmId = data:getPlayerFarmId()

local balance  = data:getBalance(farmId)
local fields   = data:getOwnedFields(farmId)
local vehicles = data:getNearbyVehicles(35)
local weather  = data:getWeather()
local world    = data:getWorldInfo()
```

All methods are cached — calling them multiple times per draw is free.

For raw game data not covered by `DataProvider`, access FS25 globals directly:

```lua
local mission = g_currentMission
local env     = mission and mission.environment
```

---

## 9. Using the EventBus

Listen for events from the EventBus in code outside the drawer (e.g. in a module-level setup block):

```lua
FT_EventBus:on(FT_EventBus.EVENTS.TABLET_OPENED, function()
    -- tablet just opened — do setup
end)

FT_EventBus:on(FT_EventBus.EVENTS.APP_SWITCHED, function(appId)
    if appId == "my_custom_app" then
        -- user switched to my app
    end
end)
```

Available events: `TABLET_OPENED`, `TABLET_CLOSED`, `APP_SWITCHED`, `APP_REGISTERED`, `SETTINGS_CHANGED`, `DATA_REFRESHED`.

---

## 10. Storing App State

Lightweight state (selected items, filter toggles, etc.) can be stored on the `FarmTabletSystem` object:

```lua
-- In your drawer:
if not self.system.myAppSelectedItem then
    self.system.myAppSelectedItem = nil
end
local sel = self.system.myAppSelectedItem
```

For state that should reset when the tablet closes, add a nil assignment in `FarmTabletSystem:onTabletClosed()`.

---

## Full Minimal Example

```lua
-- =========================================================
-- FarmTablet v2 – Hello World App
-- =========================================================

FarmTabletUI:registerDrawer("hello_world", function(self)
    local AC = FT.appColor("hello_world") or FT.C.BRAND

    if self:drawHelpPage("_hwHelp", "hello_world", "Hello World", AC, {
        { title = "ABOUT", body = "This is a demo app." },
    }) then return end

    local startY = self:drawAppHeader("Hello World", "demo")
    local x, contentY, cw, _ = self:contentInner()
    local y = startY

    y = self:drawSection(y, "GREETINGS")
    y = self:drawRow(y, "Message", "Hello, farmer!")
    y = self:drawRow(y, "Farm ID", tostring(self.system.data:getPlayerFarmId()))
    y = self:drawRule(y, 0.3)

    local balance = self.system.data:getBalance(self.system.data:getPlayerFarmId())
    y = self:drawRow(y, "Balance",
        self.system.data:formatMoney(balance),
        nil, balance >= 0 and FT.C.POSITIVE or FT.C.NEGATIVE)

    self:drawInfoIcon("_hwHelp", AC)
end)
```
