# API — Renderer (`FT_Renderer`)

**File:** `src/utils/Renderer.lua`  
**Class:** `FT_Renderer`  
**Instance:** `self.r` from any app drawer

Quick-reference for all public methods. See [developer/renderer.md](../developer/renderer.md) for the layer model, scoping rules, and colour palette.

---

## Constructor

### `FT_Renderer.new() → FT_Renderer`

---

## Rectangle Methods

### `rect(x, y, w, h, color, sliceId) → overlay`
Persistent rectangle (chrome layer). **Do not use in app drawers.**

### `appRect(x, y, w, h, color, sliceId) → overlay`
App-scoped rectangle. Cleared on app switch. Use this in all drawer functions.

```lua
self.r:appRect(x, y - FT.py(24), cw, FT.py(24), FT.C.BG_CARD)
```

### `coverRect(x, y, w, h, color) → overlay`
Cover-layer rectangle. Rendered on top of app content to clip overflow. Used internally by chrome — not for app drawers.

---

## Text Methods

### `text(x, y, size, txt, align, color)`
Persistent text (chrome layer). **Do not use in app drawers.**

### `appText(x, y, size, txt, align, color)`
App-scoped text. Use in all drawer functions.

```lua
self.r:appText(x, y, FT.FONT.BODY, "Label",
    RenderText.ALIGN_LEFT, FT.C.TEXT_NORMAL)
self.r:appText(x + w, y, FT.FONT.BODY, "Value",
    RenderText.ALIGN_RIGHT, FT.C.TEXT_ACCENT)
```

---

## Composite Widgets

### `button(x, y, w, h, label, color, meta) → descriptor`
Background rect + centred label. Returns `{ ov, x, y, w, h, meta }`.

Must be manually inserted into `FarmTabletUI._contentBtns` for click handling:
```lua
local btn = self.r:button(x, y, FT.px(90), FT.py(22), "LABEL", FT.C.BTN_PRIMARY, meta)
table.insert(self._contentBtns, btn)
```

### `rule(x, y, w, alpha)`
Thin horizontal divider. `alpha` defaults to `0.6`.

### `progressBar(x, y, w, value, maxVal, barColor) → number`
Track + fill bar. Returns Y below the bar.

### `sectionHeader(x, y, contentW, label)`
Section label with green left accent bar.

### `row(x, y, contentW, label, value, labelColor, valueColor)`
Label/value pair. Pass `nil` for value to draw label only.

### `badge(x, y, label, color) → number`
Small filled chip. Returns badge width.

---

## Lifecycle

### `clearAppLayer()`
Destroys app-scoped overlays and clears `_buttons`. Called automatically on app switch.

### `clearCoverLayer()`
Destroys cover strips. Called at the start of `_drawChrome()`.

### `destroyAll()`
Full teardown — all layers, all tables. Called on tablet close.

### `flush(clipY, clipH)`
Renders everything for the current frame in layer order. `clipY`/`clipH` define the vertical clip zone for app-layer content.

---

## Hit Testing

### `hitTest(px, py) → descriptor | nil`
Returns first button at screen position, or `nil`. Text entries excluded.
