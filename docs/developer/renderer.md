# Renderer

`FT_Renderer` is the centralised drawing API. All visual output in Farm Tablet goes through it — app drawers never call FS25 rendering functions directly.

**File:** `src/utils/Renderer.lua`  
**Class:** `FT_Renderer`  
**Instance:** `self.r` (accessible from any app drawer via the FarmTabletUI instance)

---

## Layer Model

The renderer manages five internal lists that are rendered in a specific order each frame:

```
Render order (bottom to top):
  1. _overlays    — chrome/persistent rectangles (tablet body, sidebar, topbar)
  2. _appLayer    — current app content (rectangles, clipped to content area)
  3. _coverLayer  — solid strips that hide overflow at content area edges
  4. _texts       — chrome/persistent text (topbar clock, sidebar labels)
  5. _buttons     — app content text + registered button descriptors (clipped)
```

The separation matters because:
- **Chrome** must be drawn under app content
- **Cover strips** must be drawn over app content to clip scroll overflow
- **Text** must be drawn last (FS25 text renders on top of all overlays)

---

## Scoping Rules

| Method prefix | Layer | Cleared when |
|---------------|-------|-------------|
| `rect()`, `text()` | `_overlays` / `_texts` | `destroyAll()` only (tablet close / full rebuild) |
| `appRect()`, `appText()`, `button()` | `_appLayer` / `_buttons` | `clearAppLayer()` on every app switch |
| `coverRect()` | `_coverLayer` | `clearCoverLayer()` on every chrome rebuild |

**Rule for app drawers:** always use `appRect()`, `appText()`, and `button()`. Never call `rect()` or `text()` from a drawer — those persist across app switches and will build up or render stale content.

---

## Coordinate System

All coordinates are in FS25 normalised screen space:
- `x = 0.0` → left edge of screen
- `x = 1.0` → right edge
- `y = 0.0` → **bottom** of screen
- `y = 1.0` → top

Use `FT.px(v)` and `FT.py(v)` to convert reference pixel values (based on 900×600 reference tablet at 1080p) to normalised units.

---

## Rectangle Methods

### `rect(x, y, w, h, color, sliceId) → overlay`
Draws a **persistent** coloured rectangle. Survives app switches. For chrome only.

```lua
-- Used internally by _drawChrome() — not for app drawers
self.r:rect(tx, ty, tw, th, FT.C.BG_DEEP)
```

### `appRect(x, y, w, h, color, sliceId) → overlay`
Draws an **app-scoped** coloured rectangle. Cleared on every app switch.

```lua
-- Background card
self.r:appRect(x, y - FT.py(24), cw, FT.py(24), FT.C.BG_CARD)

-- Tinted highlight (semi-transparent)
self.r:appRect(x, y, w, h, {0.16, 0.76, 0.38, 0.15})
```

`color` is an RGBA table `{r, g, b, a}` where each component is 0.0–1.0. All `FT.C.*` palette values are in this format.

### `coverRect(x, y, w, h, color) → overlay`
Draws a **cover-layer** rectangle rendered on top of the app layer. Used exclusively to clip scrolled content at the content-area boundaries.

---

## Text Methods

### `text(x, y, size, txt, align, color)`
Queues **persistent** text (chrome layer). Not for app drawers.

### `appText(x, y, size, txt, align, color)`
Queues **app-scoped** text. Use this in all app drawers.

```lua
self.r:appText(x, y, FT.FONT.BODY, "Hello, farmer!",
    RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)

self.r:appText(x + w, y, FT.FONT.SMALL, "Right aligned",
    RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
```

**Font size constants:**

| Constant | Value | Use |
|----------|-------|-----|
| `FT.FONT.HUGE` | 0.020 | Hero numbers (balance) |
| `FT.FONT.TITLE` | 0.016 | App title in header |
| `FT.FONT.HEADER` | 0.012 | Section headers |
| `FT.FONT.BODY` | 0.011 | Standard row text |
| `FT.FONT.SMALL` | 0.009 | Labels, buttons, nav |
| `FT.FONT.TINY` | 0.007 | Column headers, metadata |

**Alignment constants:**

| Constant | Meaning |
|----------|---------|
| `RenderText.ALIGN_LEFT` | Anchor at x, text extends right |
| `RenderText.ALIGN_CENTER` | Anchor at x, text centred |
| `RenderText.ALIGN_RIGHT` | Anchor at x, text extends left |

---

## Composite Widgets

These methods combine rectangles and text into ready-made UI components.

### `button(x, y, w, h, label, color, meta) → descriptor`
Draws a button background with centred label. Returns a descriptor table for hit-testing.

```lua
local btn = self.r:button(x, y, FT.px(90), FT.py(22),
    "REPAIR", FT.C.BTN_PRIMARY,
    { onClick = function() ... end })
table.insert(self._contentBtns, btn)
-- Must insert into _contentBtns manually for click handling
```

The returned descriptor: `{ ov, x, y, w, h, meta }`.

### `rule(x, y, w, alpha)`
Draws a thin horizontal divider line. `alpha` defaults to `0.6`.

```lua
self.r:rule(x, y, w, 0.4)
```

### `progressBar(x, y, w, value, maxVal, barColor) → number`
Draws a horizontal progress bar (dark track + coloured fill). Returns the Y coordinate immediately below the bar.

```lua
local newY = self.r:progressBar(x, y, w, 75, 100, FT.C.POSITIVE)
-- newY = y - barHeight - FT.py(2)
```

A subtle glow is added automatically when the fill ratio exceeds 90%.

### `sectionHeader(x, y, contentW, label)`
Draws a section label with a coloured left accent bar (3 px wide, brand green).

```lua
self.r:sectionHeader(x, y, cw, "MY SECTION")
```

### `row(x, y, contentW, label, value, labelColor, valueColor)`
Draws a label/value pair with the label left-aligned and value right-aligned. Both are padded inward by `FT.px(14)`.

```lua
self.r:row(x, y, cw, "Balance", "$1,284,750", FT.C.TEXT_NORMAL, FT.C.POSITIVE)
```

Pass `nil` for `value` to draw the label only (no right-side text).

### `badge(x, y, label, color) → number`
Draws a small filled chip/badge. Returns the badge width for advancing the X cursor.

```lua
local bx = x
bx = bx + self.r:badge(bx, y, "12 READY", FT.C.BTN_PRIMARY) + FT.px(4)
bx = bx + self.r:badge(bx, y, "5 GROW",  FT.C.BTN_NEUTRAL) + FT.px(4)
```

---

## Lifecycle Methods

### `clearAppLayer()`
Destroys all app-layer overlays and clears `_buttons` (text + hit regions). Called automatically on every app switch by `FarmTabletUI:switchApp()`. Also called explicitly in the digging app's lightweight refresh.

### `clearCoverLayer()`
Destroys and clears all cover-layer overlays. Called at the start of `_drawChrome()` before new cover strips are added.

### `destroyAll()`
Full teardown — destroys every overlay, clears all lists. Called on tablet close and before a full layout rebuild (Edit Mode, scale change, etc.).

### `flush(clipY, clipH)`
Renders everything for the current frame. Called once per frame from `FarmTabletUI:draw()`.

`clipY` / `clipH` define the content area for vertical clip culling of app-layer items:
- Items whose `y` range does not intersect `[clipY, clipY+clipH]` are skipped
- Persistent chrome overlays and cover strips are always rendered (not culled)
- Text is culled by the same bounds

---

## Hit Testing

### `hitTest(px, py) → descriptor | nil`
Tests screen position against all registered button descriptors. Returns the first matching button or `nil`. Text entries are excluded.

This is used internally by `FarmTabletUI:_onMouse()` — app drawers do not need to call it directly.

---

## Palette Reference

All colour constants live in `FT.C` (defined in `src/core/Constants.lua`):

**Backgrounds**

| Constant | Use |
|----------|-----|
| `FT.C.BG_DEEP` | Main tablet body |
| `FT.C.BG_PANEL` | Inner panel backgrounds |
| `FT.C.BG_CARD` | Card / row backgrounds |
| `FT.C.BG_NAV` | Sidebar background |

**Status colours**

| Constant | Meaning |
|----------|---------|
| `FT.C.POSITIVE` | Green — good, success |
| `FT.C.NEGATIVE` | Red — bad, error, overdrawn |
| `FT.C.WARNING` | Amber — caution |
| `FT.C.INFO` | Blue — informational |
| `FT.C.MUTED` | Grey — empty, inactive |

**Text colours**

| Constant | Use |
|----------|-----|
| `FT.C.TEXT_BRIGHT` | Headings, selected items |
| `FT.C.TEXT_NORMAL` | Standard row labels |
| `FT.C.TEXT_DIM` | Secondary info, metadata |
| `FT.C.TEXT_ACCENT` | Value column, highlight |

**Button colours**

| Constant | Use |
|----------|-----|
| `FT.C.BTN_PRIMARY` | Primary/confirm action (green) |
| `FT.C.BTN_DANGER` | Destructive action (red) |
| `FT.C.BTN_NEUTRAL` | Secondary/inactive (dark grey) |
| `FT.C.BTN_ACTIVE` | Active/selected state (brand green) |

**Brand**

| Constant | Use |
|----------|-----|
| `FT.C.BRAND` | Green accent — sidebar active, dividers |
| `FT.C.BRAND_DIM` | Dimmed brand accent |
| `FT.C.BRAND_GLOW` | Very subtle background glow |

**Per-app accent colours** — use `FT.appColor(appId)` to get the accent for any app.
