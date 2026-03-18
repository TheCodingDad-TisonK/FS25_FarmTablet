# API — FarmTabletUI

**File:** `src/FarmTabletUI.lua`  
**Class:** `FarmTabletUI`  
**Instance:** `self` inside any drawer function; `g_FarmTablet.ui` externally

All rendering, layout, and interaction for the tablet. Only constructed on `getIsClient()` contexts.

---

## Tablet Control

### `FarmTabletUI:openTablet()`
Opens the tablet: sets `isOpen`, registers as an FS25 drawable, enables the mouse cursor, hooks mouse events, emits `TABLET_OPENED`.

### `FarmTabletUI:closeTablet()`
Closes the tablet: releases drawable, restores mouse event, hides cursor, resets system state, emits `TABLET_CLOSED`.

### `FarmTabletUI:toggleTablet()`
Calls `openTablet()` or `closeTablet()` depending on current state.

### `FarmTabletUI:switchApp(appId) → boolean`
Switches to the given app. Resets content scroll, rebuilds chrome + sidebar + content. Plays click sound if enabled.

Returns `false` if `appId` is not registered or not enabled.

---

## App Drawer Registration

### `FarmTabletUI:registerDrawer(appId, fn)`
Registers a drawer function for the given app ID. The function is called with `self` (the FarmTabletUI instance) each time the app is rendered.

```lua
FarmTabletUI:registerDrawer("my_app", function(self)
    -- drawing code here
end)
```

This is a **class-level** registration — `_appDrawers` is a table on the `FarmTabletUI` class, not on an instance.

---

## Layout Helpers

### `FarmTabletUI:content() → x, y, w, h`
Returns the raw content area bounds (no padding).

### `FarmTabletUI:contentInner() → x, y, w, h`
Returns the content area inset by the standard padding (`FT.px(16)`, `FT.py(12)`). Always use this in app drawers.

### `FarmTabletUI:getContentScrollY() → number`
Returns the current scroll offset in normalised units. Add this to your starting Y for scrollable apps.

### `FarmTabletUI:setContentHeight(totalH)`
Tells the scroll system how tall your content is. Call at the end of scrollable drawers.

```lua
local totalH = startY - y
self:setContentHeight(totalH)
```

---

## Drawing Primitives

All return the next Y below the element drawn (for chaining).

### `FarmTabletUI:drawAppHeader(title, subtitle) → number`
Draws the standard two-line title bar with a coloured accent divider. Returns the Y below the divider.

```lua
local y = self:drawAppHeader("My App", "subtitle")
```

### `FarmTabletUI:drawSection(y, label) → number`
Draws a section heading with a green left accent bar.

### `FarmTabletUI:drawRow(y, label, value, labelColor, valueColor) → number`
Draws a label/value row. Pass `nil` for colours to use defaults.

### `FarmTabletUI:drawRule(y, alpha) → number`
Draws a thin horizontal divider. `alpha` defaults to 0.6.

### `FarmTabletUI:drawBar(y, value, maxVal, color) → number`
Draws a full-width progress bar.

### `FarmTabletUI:drawButton(y, label, color, meta) → number, descriptor`
Draws a single button and registers it for click handling.

```lua
local nextY, btn = self:drawButton(y, "CONFIRM", FT.C.BTN_PRIMARY, {
    onClick = function()
        -- action
        self:switchApp(FT.APP.WORKSHOP)  -- refresh
    end
})
```

### `FarmTabletUI:drawButtonPair(y, labelA, colorA, metaA, labelB, colorB, metaB) → number, btnA, btnB`
Draws two side-by-side buttons, each registered for click handling.

---

## Help Page Helpers

### `FarmTabletUI:drawInfoIcon(stateKey, accentColor) → descriptor`
Draws the "i" icon in the bottom-right corner. Clicking it sets `self[stateKey] = true` and re-switches to the current app.

`stateKey` must be a unique string per app, e.g. `"_myAppHelp"`.

### `FarmTabletUI:drawHelpPage(stateKey, appId, headerTitle, accentColor, entries) → boolean`
Renders the full help overlay if `self[stateKey]` is `true`. Returns `true` when drawn — caller must immediately `return`.

```lua
if self:drawHelpPage("_myHelp", FT.APP.MY_APP, "My App", AC, {
    { title = "SECTION", body = "Explanation text.\nWith newlines." },
}) then return end
```

Each entry: `{ title = string, body = string }`. Body supports `\n` for line breaks.

---

## Edit Mode

### `FarmTabletUI:toggleEditMode()`
Enters or exits Edit Mode. Called by the Settings app button and the right-click handler.

### `FarmTabletUI:applyPositionFromSettings()`
Forces a full rebuild using current `settings.tabletPosX/Y/Scale/WidthMult`. Called after position reset.

---

## Sound

### `FarmTabletUI:playUISound(soundType)`
Plays a UI sound if `settings.soundEffects` is true.

`soundType`: `"click"` | `"paging"` | `"back"`

---

## Delete

### `FarmTabletUI:delete()`
Destroys all overlays and exits Edit Mode. Called by `FarmTabletManager:delete()`.

---

## FS25 Drawable Interface

### `FarmTabletUI:draw()`
Called by FS25 each frame when registered as a drawable. Calls `self.r:flush()` then `_drawEditOverlay()`.

### `FarmTabletUI:update(dt)`
Called each frame from `FarmTabletManager:update()`. Drives clock refresh (every 2 s), scroll polling, and the Digging app auto-refresh.

---

## Internal State (reference)

| Field | Description |
|-------|-------------|
| `isOpen` | Whether the tablet is currently visible |
| `_mouseX`, `_mouseY` | Last known cursor position |
| `_closeBtn` | Hit region for the X button |
| `_iconBtns` | Array of sidebar icon hit regions `{appId, x, y, w, h}` |
| `_contentBtns` | Array of content button descriptors (registered by app drawers) |
| `_sidebarScrollOffset` | Current sidebar scroll slot offset |
| `_contentScrollY` | Current content scroll in normalised units |
| `_contentScrollMax` | Maximum scroll extent (set by `setContentHeight`) |
| `_editModeActive` | Whether Edit Mode is active |
