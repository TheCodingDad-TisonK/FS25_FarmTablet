# Architecture Overview

Farm Tablet v2 is a client-side HUD mod built on a clean layered architecture. This document explains how all the pieces fit together.

---

## High-Level Structure

```
main.lua
  └── FarmTabletManager          ← top-level coordinator, owns everything
        ├── Settings              ← user preferences value object
        ├── SettingsManager       ← XML serialisation
        ├── SettingsGUI           ← console commands
        ├── SettingsUI            ← pause-menu injection
        ├── FarmTabletSystem      ← data + state (no rendering)
        │     ├── AppRegistry     ← app catalogue + auto-detection
        │     ├── FT_DataProvider ← cached FS25 game-data queries
        │     └── bucket state    ← bucket tracker live state
        ├── FarmTabletUI          ← all rendering + input
        │     └── FT_Renderer     ← overlay + text drawing API
        └── InputHandler          ← key polling
```

---

## Module Responsibilities

### `main.lua`
The FS25 mod entry point. Hooks into `Mission00.load`, `Mission00.loadMission00Finished`, and `FSBaseMission.delete` using `Utils.prependedFunction` / `Utils.appendedFunction`. Also appends to `FSBaseMission.update` to drive the per-frame update loop.

The `g_dedicatedServer` guard prevents any initialisation on dedicated servers — the mod is client-only.

### `FarmTabletManager`
The root object. Created once per mission load. Owns all subsystems and delegates to them. Exposes the public API used by console commands and the global `g_FarmTablet`.

Key responsibilities:
- Constructs all subsystems in the correct order
- Injects into the pause-menu settings frame
- Dispatches the per-frame `update(dt)` to all subsystems
- Shows the welcome HUD notification

### `FarmTabletSystem`
Pure data/state layer — no rendering. Safe to construct on all network contexts (listen-server, client peer, etc.).

Key responsibilities:
- Holds the `AppRegistry` and `FT_DataProvider`
- Tracks `currentApp`, `isTabletOpen`, `workshopSelectedVehicle`, `soilSelectedField`
- Manages the bucket tracker state and update loop
- Resets stale selections in `onTabletClosed()`

### `FarmTabletUI`
The entire rendering and interaction layer. Only constructed when `mission:getIsClient()` is true.

Key responsibilities:
- Builds the tablet layout from `FT.LAYOUT` constants
- Manages the `FT_Renderer` instance
- Dispatches to app-specific drawer functions from `_appDrawers`
- Handles mouse input and hit-testing
- Implements scroll wheel for sidebar and content
- Implements Edit Mode (drag/resize)
- Manages the `_clockTimer` for topbar refresh

### `FT_Renderer`
All visual output goes through this class. Wraps the FS25 `g_overlayManager` API. Maintains separate layers for chrome (persistent), app content (cleared on switch), and cover strips (drawn on top to clip overflow).

### `FT_DataProvider`
Single access point for all FS25 game data. Uses a simple time-based cache (TTL per key) to avoid polling the game's APIs every frame. Invalidated on tablet close and after any state-changing action (e.g. vehicle repair).

### `AppRegistry`
Maintains the catalogue of all installed apps. Built-in apps are registered at construction time. Companion-mod apps are added dynamically by `autoDetect()` after mission load.

### `Settings` + `SettingsManager`
`Settings` is a plain value object holding all user preferences. `SettingsManager` handles XML serialisation to/from the per-savegame config file.

### `InputHandler`
Polls `Input.isKeyPressed(keyConstant)` each frame and calls `toggleTablet()` on rising edge (key down, not held).

---

## Initialisation Sequence

```
FS25 loads the mod
  → source() calls in main.lua register all classes

Mission00.load fires
  → FarmTabletManager.new() is called
    → Settings loaded from XML
    → FarmTabletSystem constructed
    → FarmTabletUI constructed (client only)
    → InputHandler constructed (client only)
    → SettingsUI injected into pause menu (client + g_gui)
    → SettingsGUI registers console commands (client only)

Mission00.loadMission00Finished fires
  → FarmTabletManager:onMissionLoaded()
    → FarmTabletSystem:initialize()
      → AppRegistry:autoDetect() — companion mods checked here
    → InputHandler:registerKeyBinding()
    → Welcome HUD notification shown

Per-frame FSBaseMission.update fires
  → FarmTabletManager:update(dt)
    → InputHandler:update(dt)    — key polling
    → FarmTabletSystem:update(dt) — bucket tracker
    → FarmTabletUI:update(dt)    — clock refresh, scroll polling, digging auto-refresh

FSBaseMission.delete fires
  → FarmTabletManager:delete()
    → Settings:save()
    → InputHandler:unregisterKeyBinding()
    → FarmTabletUI:delete()      — destroys all overlays
```

---

## The App Drawer Pattern

Apps are not classes — they are **drawer functions** registered on the `FarmTabletUI` class table:

```lua
FarmTabletUI:registerDrawer(FT.APP.WEATHER, function(self)
    -- self is the FarmTabletUI instance
    -- Draw the app content here using self.r:appRect(), self.r:appText(), etc.
end)
```

When the user switches to an app, `FarmTabletUI:_drawContent()` calls the registered function inside a `pcall`. If it errors, `_drawError()` renders the error message instead.

The drawer function receives `self` (the `FarmTabletUI` instance) and should use the layout helper methods:
- `self:contentInner()` — padded content area bounds
- `self:drawAppHeader()` — standard title + divider
- `self:drawRow()`, `self:drawSection()`, `self:drawRule()`, `self:drawBar()` — standard row/section primitives
- `self:drawButton()`, `self:drawButtonPair()` — action buttons that register hit regions
- `self:drawInfoIcon()` / `self:drawHelpPage()` — shared help overlay system

See [writing-an-app.md](writing-an-app.md) for a full walkthrough.

---

## Coordinate System

FS25 uses a **normalised screen space** where:
- `x = 0.0` is the left edge of the screen
- `x = 1.0` is the right edge
- `y = 0.0` is the **bottom** of the screen
- `y = 1.0` is the **top**

All drawing coordinates in `FT_Renderer` and app drawers are in this space.

The `FT.px(v)` and `FT.py(v)` helpers convert reference pixel values (designed at 1080p) to normalised units using the scale factors set by `FarmTabletUI:_build()`. Always use these instead of hardcoding normalised values — they handle scaling transparently.

> **Important:** `FT.px()` and `FT.py()` return `0` until `_build()` runs. Never call them at module-load time (i.e. outside a function body).

---

## Rendering Pipeline Per Frame

Each frame where the tablet is open:

1. `FarmTabletUI:draw()` is called by FS25 (registered as a drawable)
2. It calls `self.r:flush(clipY, clipH)` which renders in this order:
   - Persistent overlays (`_overlays`) — chrome body, background
   - App-layer overlays (`_appLayer`) — current app content, clipped to content bounds
   - Cover overlays (`_coverLayer`) — solid strips that hide overflow at content edges
   - Persistent text (`_texts`) — topbar, sidebar labels
   - App-layer text (from `_buttons` where `_isText == true`) — app content text
3. `_drawEditOverlay()` renders the Edit Mode pulsing border on top of everything (native `renderOverlay` calls, bypasses `FT_Renderer`)

---

## Multiplayer Considerations

- The tablet is **client-only**. `FarmTabletSystem` is safe everywhere but `FarmTabletUI` and `InputHandler` are only created when `mission:getIsClient()`.
- Each player has their own independent tablet instance. There is no synchronisation between players.
- Data comes from `FT_DataProvider` which reads from shared game globals (`g_farmManager`, `g_currentMission`, etc.) — so all players see the same farm data for their own farm.
- The Workshop app's **REPAIR** action sends a `VehicleRepairEvent` network event when the local client is not also the server, ensuring the repair is applied correctly in multiplayer.
- Dedicated servers: the `g_dedicatedServer` guard in `main.lua` skips all initialisation entirely.
