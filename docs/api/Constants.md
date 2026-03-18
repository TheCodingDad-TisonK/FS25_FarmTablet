# API — Constants (`FT`)

**File:** `src/core/Constants.lua`  
**Global:** `FT`

The `FT` table is the single source of truth for all design tokens, layout zones, app IDs, and coordinate helpers.

---

## `FT.VERSION`
```lua
FT.VERSION  -- string, e.g. "2.1.2.1"
```

---

## `FT.REF_W` / `FT.REF_H`
Reference tablet dimensions in pixels at 1080p. Used by `FarmTabletUI:_build()` to compute `scaleX`/`scaleY`.

```lua
FT.REF_W = 900   -- reference width
FT.REF_H = 600   -- reference height
```

---

## `FT.C` — Colour Palette

All colours are `{r, g, b, a}` tables with components in `0.0–1.0`.

### Backgrounds
| Key | Description |
|-----|-------------|
| `BG_DEEP` | Main tablet body (near-black) |
| `BG_PANEL` | Inner panel backgrounds |
| `BG_CARD` | Card and row backgrounds |
| `BG_NAV` | Sidebar background |

### Brand
| Key | Description |
|-----|-------------|
| `BRAND` | Green accent — active highlights, dividers |
| `BRAND_DIM` | Dimmed brand accent |
| `BRAND_GLOW` | Very subtle glow fill |

### Status
| Key | Meaning |
|-----|---------|
| `POSITIVE` | Good / success (green) |
| `NEGATIVE` | Bad / error / overdrawn (red) |
| `WARNING` | Caution (amber) |
| `INFO` | Informational (blue) |
| `MUTED` | Empty / inactive / secondary (grey) |

### Text
| Key | Use |
|-----|-----|
| `TEXT_BRIGHT` | Headings, selected items |
| `TEXT_NORMAL` | Standard body text |
| `TEXT_DIM` | Secondary info, metadata |
| `TEXT_ACCENT` | Value column highlight |

### Borders and Rules
| Key | Use |
|-----|-----|
| `BORDER` | Subtle border |
| `BORDER_BRIGHT` | Visible border |
| `RULE` | Horizontal divider line |

### Buttons
| Key | Use |
|-----|-----|
| `BTN_PRIMARY` | Primary / confirm action (dark green) |
| `BTN_DANGER` | Destructive action (red) |
| `BTN_NEUTRAL` | Secondary / inactive (dark grey) |
| `BTN_ACTIVE` | Active / selected state |
| `BTN_HOVER` | Hover state (slightly lighter green) |

### Decorative
| Key | Use |
|-----|-----|
| `OVERLAY_DARK` | Semi-transparent overlay |
| `SCANLINE` | Subtle scanline effect |

### Weather-specific
| Key | Use |
|-----|-----|
| `WEATHER_RAIN` | Rain condition (blue) |
| `WEATHER_SUN` | Clear/sunny (yellow-gold) |
| `WEATHER_STORM` | Storm (purple) |
| `WEATHER_FOG` | Fog (light grey-blue) |

---

## `FT.FONT` — Typography Scale

Font sizes in normalised screen units. Use these constants instead of hardcoded values.

| Key | Value | Use |
|-----|-------|-----|
| `HUGE` | 0.020 | Hero numbers (balance display) |
| `TITLE` | 0.016 | App title in header |
| `HEADER` | 0.012 | Section headers |
| `BODY` | 0.011 | Standard row label/value text |
| `SMALL` | 0.009 | Button labels, sidebar nav |
| `TINY` | 0.007 | Column headers, metadata |

---

## `FT.SP` — Spacing

Reference pixel values for spacing. Use `FT.py(FT.SP.ROW)` to convert to normalised units.

| Key | Pixels | Use |
|-----|--------|-----|
| `XS` | 4 | Tight / micro spacing |
| `SM` | 8 | Small gap |
| `MD` | 14 | Standard gap |
| `LG` | 20 | Large gap |
| `XL` | 28 | Extra-large gap |
| `ROW` | 22 | Standard row height |
| `SECT` | 30 | Gap after section header |

---

## `FT.LAYOUT` — Runtime Layout Zones

Populated by `FarmTabletUI:_build()` on every tablet open and rebuild. All values are in normalised screen coordinates.

| Field | Description |
|-------|-------------|
| `tabletX`, `tabletY` | Bottom-left corner of the tablet frame |
| `tabletW`, `tabletH` | Total tablet width and height |
| `sidebarX`, `sidebarY` | Bottom-left of the sidebar zone |
| `sidebarW`, `sidebarH` | Sidebar dimensions |
| `contentX`, `contentY` | Bottom-left of the content area |
| `contentW`, `contentH` | Content area dimensions |
| `topbarX`, `topbarY` | Bottom-left of the top status bar |
| `topbarW`, `topbarH` | Topbar dimensions |
| `scaleX`, `scaleY` | Scale factors: `tw / FT.REF_W` and `th / FT.REF_H` |

> **Note:** All zones are 0 before the first `_build()` call.

---

## `FT.APP` — App ID Constants

String constants for all built-in and integration app IDs.

| Constant | Value |
|----------|-------|
| `FT.APP.DASHBOARD` | `"dashboard"` |
| `FT.APP.APP_STORE` | `"app_store"` |
| `FT.APP.SETTINGS` | `"settings"` |
| `FT.APP.UPDATES` | `"updates"` |
| `FT.APP.WORKSHOP` | `"workshop"` |
| `FT.APP.FIELDS` | `"field_status"` |
| `FT.APP.ANIMALS` | `"animals"` |
| `FT.APP.WEATHER` | `"weather"` |
| `FT.APP.DIGGING` | `"digging"` |
| `FT.APP.BUCKET` | `"bucket_tracker"` |
| `FT.APP.INCOME` | `"income_mod"` |
| `FT.APP.TAX` | `"tax_mod"` |
| `FT.APP.NPC_FAVOR` | `"npc_favor"` |
| `FT.APP.CROP_STRESS` | `"crop_stress"` |
| `FT.APP.SOIL_FERT` | `"soil_fertilizer"` |

---

## `FT.APP_COLOR` — Per-App Accent Colours

A table keyed by app ID string, each value an `{r, g, b, a}` colour used for the active sidebar highlight, header divider, and topbar tint.

---

## Helper Functions

### `FT.appColor(appId) → {r,g,b,a}`
Returns the accent colour for the given app ID. Falls back to `FT.C.BRAND` if the ID is unknown.

```lua
local ac = FT.appColor(FT.APP.WEATHER)  -- {0.35, 0.72, 1.00, 1.00}
local ac = FT.appColor("unknown")       -- FT.C.BRAND
```

### `FT.px(v) → number`
Converts a reference pixel value (X axis) to normalised screen units using the current `FT.LAYOUT.scaleX`.

```lua
FT.px(90)  -- width of a standard button
```

> **Warning:** Returns `0` until `FarmTabletUI:_build()` sets `scaleX`. Never call at module-load time.

### `FT.py(v) → number`
Converts a reference pixel value (Y axis) to normalised screen units using `FT.LAYOUT.scaleY`.

```lua
FT.py(22)  -- standard row height
```
