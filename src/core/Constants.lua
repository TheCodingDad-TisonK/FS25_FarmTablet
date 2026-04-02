-- =========================================================
-- FarmTablet v2 – Constants
-- Single source of truth for the entire design system
-- =========================================================
FT = FT or {}

FT.VERSION = "2.1.8.0"

-- ── Design Tokens ─────────────────────────────────────────
-- Reference dimensions (at 1080p; scaled at runtime)
FT.REF_W = 900   -- tablet width  in ref pixels
FT.REF_H = 600   -- tablet height in ref pixels

-- Color Palette  (R, G, B, A)
FT.C = {
    -- Backgrounds
    BG_DEEP      = {0.04, 0.05, 0.07, 0.97},   -- main tablet body
    BG_PANEL     = {0.07, 0.09, 0.12, 0.96},   -- inner panels
    BG_CARD      = {0.09, 0.11, 0.15, 0.94},   -- card/row bg
    BG_NAV       = {0.05, 0.06, 0.09, 0.98},   -- sidebar bg

    -- Brand / Accent
    BRAND        = {0.16, 0.76, 0.38, 1.00},   -- green accent
    BRAND_DIM    = {0.10, 0.44, 0.22, 0.85},   -- dimmed
    BRAND_GLOW   = {0.16, 0.76, 0.38, 0.18},   -- subtle bg glow

    -- Status
    POSITIVE     = {0.22, 0.88, 0.46, 1.00},
    NEGATIVE     = {0.95, 0.28, 0.28, 1.00},
    WARNING      = {1.00, 0.72, 0.10, 1.00},
    INFO         = {0.30, 0.65, 1.00, 1.00},
    MUTED        = {0.42, 0.44, 0.50, 1.00},

    -- Text
    TEXT_BRIGHT  = {0.96, 0.97, 0.98, 1.00},
    TEXT_NORMAL  = {0.78, 0.80, 0.84, 1.00},
    TEXT_DIM     = {0.50, 0.52, 0.58, 1.00},
    TEXT_ACCENT  = {0.30, 0.90, 0.50, 1.00},

    -- Borders / Rules
    BORDER       = {0.16, 0.76, 0.38, 0.22},
    BORDER_BRIGHT= {0.16, 0.76, 0.38, 0.55},
    RULE         = {0.20, 0.22, 0.28, 0.80},

    -- Buttons
    BTN_PRIMARY  = {0.12, 0.58, 0.28, 0.95},
    BTN_DANGER   = {0.70, 0.18, 0.18, 0.95},
    BTN_NEUTRAL  = {0.18, 0.20, 0.26, 0.95},
    BTN_ACTIVE   = {0.16, 0.76, 0.38, 0.95},
    BTN_HOVER    = {0.15, 0.65, 0.34, 0.95},

    -- Overlay / decorative
    OVERLAY_DARK = {0.00, 0.00, 0.00, 0.60},
    SCANLINE     = {0.00, 0.00, 0.00, 0.04},

    -- App-specific
    WEATHER_RAIN = {0.30, 0.58, 1.00, 1.00},
    WEATHER_SUN  = {1.00, 0.82, 0.20, 1.00},
    WEATHER_STORM= {0.70, 0.44, 1.00, 1.00},
    WEATHER_FOG  = {0.72, 0.74, 0.80, 1.00},
}

-- ── Background Color Palette ───────────────────────────────
-- Index stored in settings.tabletBgColorIndex (1-based).
-- Used by SettingsApp color picker and applied in FarmTabletUI.
FT.BG_PALETTE = {
    { label = "Deep Space",      color = {0.04, 0.05, 0.07, 0.97} },  -- default
    { label = "Ocean Blue",      color = {0.03, 0.07, 0.18, 0.97} },
    { label = "Forest Green",    color = {0.03, 0.10, 0.05, 0.97} },
    { label = "Midnight Purple", color = {0.08, 0.04, 0.14, 0.97} },
    { label = "Warm Dark",       color = {0.12, 0.07, 0.04, 0.97} },
    { label = "Slate Grey",      color = {0.08, 0.09, 0.12, 0.97} },
}

-- ── Typography Scale ──────────────────────────────────────
FT.FONT = {
    TITLE    = 0.016,   -- app title
    HEADER   = 0.012,   -- section header
    BODY     = 0.011,   -- standard body text
    SMALL    = 0.009,   -- caption / label
    TINY     = 0.007,   -- metadata / column headers
    HUGE     = 0.020,   -- hero number (balance etc.)
}

-- ── Spacing ────────────────────────────────────────────────
FT.SP = {
    XS   = 4,    -- tight spacing (ref pixels)
    SM   = 8,
    MD   = 14,
    LG   = 20,
    XL   = 28,
    ROW  = 22,   -- standard row height
    SECT = 30,   -- section gap
}

-- ── Layout Zones (set at runtime by FarmTabletUI) ─────────
FT.LAYOUT = {
    -- These are populated in FarmTabletUI:buildLayout()
    tabletX = 0, tabletY = 0, tabletW = 0, tabletH = 0,
    -- Sidebar (left)
    sidebarX = 0, sidebarY = 0, sidebarW = 0, sidebarH = 0,
    -- Content (right of sidebar)
    contentX = 0, contentY = 0, contentW = 0, contentH = 0,
    -- Topbar
    topbarX = 0, topbarY = 0, topbarW = 0, topbarH = 0,
    -- Scale factors
    scaleX = 1, scaleY = 1,
}

-- ── Per-App Accent Colors ─────────────────────────────────
-- Each app gets a unique accent used for: active sidebar highlight,
-- app header divider, section headers, and topbar tint.
FT.APP_COLOR = {
    -- core
    dashboard    = {0.16, 0.76, 0.38, 1.00},  -- green  (brand default)
    app_store    = {0.30, 0.65, 1.00, 1.00},  -- sky blue
    settings     = {0.60, 0.62, 0.70, 1.00},  -- slate
    updates      = {1.00, 0.72, 0.10, 1.00},  -- amber
    -- farm
    weather      = {0.35, 0.72, 1.00, 1.00},  -- sky
    field_status = {0.45, 0.85, 0.30, 1.00},  -- lime green
    animals      = {1.00, 0.62, 0.22, 1.00},  -- orange
    workshop     = {0.90, 0.38, 0.38, 1.00},  -- red/rust
    digging      = {0.75, 0.55, 0.28, 1.00},  -- earth brown
    bucket_tracker = {0.80, 0.60, 0.25, 1.00},-- sandy
    -- finance / mods
    income_mod   = {0.28, 0.90, 0.55, 1.00},  -- teal-green
    tax_mod      = {1.00, 0.40, 0.40, 1.00},  -- coral-red
    npc_favor    = {0.80, 0.50, 1.00, 1.00},  -- lavender
    crop_stress  = {1.00, 0.80, 0.25, 1.00},  -- gold
    soil_fertilizer = {0.55, 0.80, 0.40, 1.00},-- sage
    market_dynamics  = {0.30, 0.78, 0.95, 1.00},  -- cyan-blue
    worker_costs     = {0.95, 0.58, 0.20, 1.00},  -- amber-orange
    random_world_events = {0.70, 0.35, 0.90, 1.00}, -- purple
    used_plus           = {0.20, 0.78, 0.90, 1.00}, -- cyan
    roleplay_phone      = {0.90, 0.35, 0.85, 1.00}, -- magenta
    storage             = {0.92, 0.78, 0.25, 1.00}, -- wheat gold
    time_controls       = {0.30, 0.78, 1.00, 1.00}, -- sky blue
    hotspot_manager     = {1.00, 0.72, 0.10, 1.00}, -- amber
    notes               = {0.55, 0.90, 0.35, 1.00}, -- lime green
    field_jobs          = {0.30, 0.75, 1.00, 1.00}, -- sky blue
    farm_admin          = {0.95, 0.30, 0.30, 1.00}, -- red
    contracts           = {0.95, 0.72, 0.15, 1.00}, -- amber-gold
}

-- Helper: get the accent color for a given app id
function FT.appColor(appId)
    return FT.APP_COLOR[appId] or FT.C.BRAND
end

-- ── App Icon IDs (for internal routing) ───────────────────
FT.APP = {
    DASHBOARD    = "dashboard",
    APP_STORE    = "app_store",
    SETTINGS     = "settings",
    UPDATES      = "updates",
    WORKSHOP     = "workshop",
    FIELDS       = "field_status",
    ANIMALS      = "animals",
    WEATHER      = "weather",
    DIGGING      = "digging",
    BUCKET       = "bucket_tracker",
    INCOME       = "income_mod",
    TAX          = "tax_mod",
    NPC_FAVOR        = "npc_favor",
    CROP_STRESS      = "crop_stress",
    SOIL_FERT        = "soil_fertilizer",
    MARKET_DYNAMICS  = "market_dynamics",
    WORKER_COSTS     = "worker_costs",
    RANDOM_EVENTS    = "random_world_events",
    USED_PLUS        = "used_plus",
    ROLEPLAY_PHONE   = "roleplay_phone",
    STORAGE          = "storage",
    TIME_CONTROLS    = "time_controls",
    HOTSPOT_MGR      = "hotspot_manager",
    NOTES            = "notes",
    FARM_ADMIN       = "farm_admin",
    FIELD_JOBS       = "field_jobs",
    CONTRACTS        = "contracts",
}

-- Helper: scale a reference pixel value to normalized coords.
-- NOTE: FT.px() / FT.py() return 0 until FarmTabletUI:_build() runs and
-- sets FT.LAYOUT.scaleX / scaleY. Never call them at module-load time.
function FT.px(v) return v * FT.LAYOUT.scaleX end
function FT.py(v) return v * FT.LAYOUT.scaleY end
