-- =========================================================
-- FarmTablet v2 – AppRegistry
-- Central registry for all installed apps
-- =========================================================
---@class AppRegistry
AppRegistry = {}
local AppRegistry_mt = Class(AppRegistry)

-- App category display groups
AppRegistry.GROUPS = {
    { id = "core",      label = "CORE",     icon = "CORE" },
    { id = "farm",      label = "FARM",     icon = "FARM" },
    { id = "finance",   label = "FINANCE",  icon = "FIN" },
    { id = "mods",      label = "MODS",     icon = "MODS" },
}

-- Built-in app definitions (always present)
AppRegistry.BUILTIN_APPS = {
    {
        id = FT.APP.DASHBOARD,  group = "core",
        name = "ft_ui_app_dashboard",  navLabel = "DASH",
        icon = "dashboard",         order = 1,
        developer = "FarmTablet",   version = "Built-in",
        description = "Farm overview: balance, fields, vehicles, world state",
    },
    {
        id = FT.APP.APP_STORE,  group = "core",
        name = "ft_ui_app_store",      navLabel = "APPS",
        icon = "store",             order = 2,
        developer = "FarmTablet",   version = "Built-in",
        description = "Browse and manage installed apps",
    },
    {
        id = FT.APP.SETTINGS,   group = "core",
        name = "ft_ui_app_settings",   navLabel = "SET",
        icon = "settings",          order = 3,
        developer = "FarmTablet",   version = "Built-in",
        description = "Tablet configuration",
    },
    {
        id = FT.APP.WEATHER,    group = "farm",
        name = "ft_ui_app_weather",    navLabel = "WTH",
        icon = "weather",           order = 10,
        developer = "FarmTablet",   version = "Built-in",
        description = "Current conditions and forecast",
    },
    {
        id = FT.APP.FIELDS,     group = "farm",
        name = "ft_ui_app_field_status", navLabel = "FLD",
        icon = "fields",            order = 11,
        developer = "FarmTablet",   version = "Built-in",
        description = "All owned fields with crop and growth state",
    },
    {
        id = FT.APP.ANIMALS,    group = "farm",
        name = "ft_ui_app_animals",    navLabel = "ANI",
        icon = "animals",           order = 12,
        developer = "FarmTablet",   version = "Built-in",
        description = "Animal pens — food, water, cleanliness",
    },
    {
        id = FT.APP.WORKSHOP,   group = "farm",
        name = "ft_ui_app_workshop",   navLabel = "WRK",
        icon = "workshop",          order = 13,
        developer = "FarmTablet",   version = "Built-in",
        description = "Nearby vehicle diagnostics",
    },
    {
        id = FT.APP.DIGGING,    group = "farm",
        name = "ft_ui_app_digging",    navLabel = "DIG",
        icon = "digging",           order = 14,
        developer = "FarmTablet",   version = "Built-in",
        description = "Excavation tracking and soil scanner",
    },
    {
        id = FT.APP.BUCKET,     group = "farm",
        name = "ft_ui_app_bucket_tracker", navLabel = "BCK",
        icon = "bucket",            order = 15,
        developer = "FarmTablet",   version = "Built-in",
        description = "Bucket/loader load counter",
    },
    {
        id = FT.APP.STORAGE,    group = "farm",
        name = "ft_ui_app_storage",    navLabel = "STR",
        icon = "storage",           order = 16,
        developer = "FarmTablet",   version = "Built-in",
        description = "Silo inventory and current sell prices",
    },
    -- NOTE: Companion-mod apps (Income, Tax, NPC Favor, Crop Stress, Soil Fertilizer)
    -- are NOT pre-registered here. They are added dynamically by autoDetect() once the
    -- mission is loaded and the companion mod's global manager is confirmed present.
    -- This prevents "mod not installed" placeholders from cluttering the sidebar.
    {
        id = FT.APP.UPDATES,    group = "core",
        name = "ft_ui_app_updates",    navLabel = "UPD",
        icon = "updates",           order = 100,
        developer = "FarmTablet",   version = "Built-in",
        description = "Changelog and update history",
    },
}

function AppRegistry.new()
    local self = setmetatable({}, AppRegistry_mt)
    self._apps = {}  -- keyed by id
    self._order = {} -- sorted list of ids

    -- Register built-ins
    for _, def in ipairs(AppRegistry.BUILTIN_APPS) do
        self:register(def)
    end

    return self
end

function AppRegistry:register(def)
    if self._apps[def.id] then return end -- already registered
    def.enabled = (def.enabled ~= false)
    self._apps[def.id] = def

    -- Insert into ordered list
    table.insert(self._order, def.id)
    table.sort(self._order, function(a, b)
        local oa = self._apps[a] and self._apps[a].order or 50
        local ob = self._apps[b] and self._apps[b].order or 50
        return oa < ob
    end)

    FT_EventBus:emit(FT_EventBus.EVENTS.APP_REGISTERED, def.id)
end

function AppRegistry:get(id)
    return self._apps[id]
end

function AppRegistry:getAll()
    local out = {}
    for _, id in ipairs(self._order) do
        local app = self._apps[id]
        if app and app.enabled then
            table.insert(out, app)
        end
    end
    return out
end

function AppRegistry:has(id)
    return self._apps[id] ~= nil
end

function AppRegistry:setEnabled(id, state)
    if self._apps[id] then
        self._apps[id].enabled = state
    end
end

-- Auto-detect companion mods and register their apps.
-- Each check uses the EXACT global name set by that mod's main.lua.
-- NOTE: Cross-mod globals (getfenv(0)["name"]) are per-mod scoped in FS25.
-- Use g_currentMission.xxx properties for reliable cross-mod detection.
function AppRegistry:autoDetect()
    -- Income Mod
    if g_currentMission and g_currentMission.incomeManager then
        if not self:has(FT.APP.INCOME) then
            Logging.info("[FarmTablet] autoDetect: Income Mod detected")
            self:register({
                id = FT.APP.INCOME, group = "mods",
                name = "ft_ui_app_income_mod", navLabel = "INC",
                icon = "income", order = 20,
                developer = "TisonK", version = "Integrated",
                description = "Income Mod controls and statistics",
            })
        end
    end

    -- Tax Mod
    -- Bridge: mission.taxManager set by TaxMod in Mission00.load
    if g_currentMission and g_currentMission.taxManager then
        if not self:has(FT.APP.TAX) then
            Logging.info("[FarmTablet] autoDetect: Tax Mod detected")
            self:register({
                id = FT.APP.TAX, group = "mods",
                name = "ft_ui_app_tax_mod", navLabel = "TAX",
                icon = "tax", order = 21,
                developer = "TisonK", version = "Integrated",
                description = "Tax Mod status and toggle",
            })
        end
    end

    -- NPC Favor
    -- Bridge: mission.npcFavorSystem set by NPCFavor in Mission00.load
    local hasNPC = (g_currentMission and g_currentMission.npcFavorSystem ~= nil)
    if hasNPC and not self:has(FT.APP.NPC_FAVOR) then
        Logging.info("[FarmTablet] autoDetect: NPC Favor detected")
        self:register({
            id = FT.APP.NPC_FAVOR, group = "mods",
            name = "ft_ui_app_npc_favor", navLabel = "NPC",
            icon = "npc", order = 22,
            developer = "TisonK", version = "Integrated",
            description = "NPC favor tracker",
        })
    end

    -- Seasonal Crop Stress
    -- Bridge: mission.cropStressManager set by SeasonalCropStress in Mission00.load
    local hasCropStress = (g_currentMission and g_currentMission.cropStressManager ~= nil)
                       or (getfenv(0)["g_cropStressManager"] ~= nil)
    if hasCropStress and not self:has(FT.APP.CROP_STRESS) then
        Logging.info("[FarmTablet] autoDetect: Crop Stress detected")
        self:register({
            id = FT.APP.CROP_STRESS, group = "mods",
            name = "ft_ui_app_crop_stress", navLabel = "CRPS",
            icon = "crop_stress", order = 23,
            developer = "TisonK", version = "Integrated",
            description = "Seasonal crop stress monitor",
        })
    end

    -- Soil Fertilizer
    -- Bridge: mission.soilFertilityManager set by SoilFertilizer in Mission00.load
    local hasSoil = (g_currentMission and g_currentMission.soilFertilityManager ~= nil)
                 or (getfenv(0)["g_SoilFertilityManager"] ~= nil)
    if hasSoil and not self:has(FT.APP.SOIL_FERT) then
        Logging.info("[FarmTablet] autoDetect: Soil Fertilizer detected")
        self:register({
            id = FT.APP.SOIL_FERT, group = "mods",
            name = "ft_ui_app_soil_fertilizer", navLabel = "SOIL",
            icon = "soil", order = 24,
            developer = "TisonK", version = "Integrated",
            description = "Soil fertilizer status",
        })
    end

    -- Market Dynamics
    -- Bridge: mission.MarketDynamics set by MarketDynamics mod in Mission00.load
    if g_currentMission and g_currentMission.MarketDynamics then
        if not self:has(FT.APP.MARKET_DYNAMICS) then
            Logging.info("[FarmTablet] autoDetect: Market Dynamics detected")
            self:register({
                id = FT.APP.MARKET_DYNAMICS, group = "mods",
                name = "ft_ui_app_market_dynamics", navLabel = "MKT",
                icon = "market", order = 25,
                developer = "TisonK", version = "Integrated",
                description = "Market prices and dynamic events",
            })
        end
    end

    -- Worker Costs
    -- Bridge: mission.workerCostsManager set by WorkerCosts in Mission00.load
    if g_currentMission and g_currentMission.workerCostsManager then
        if not self:has(FT.APP.WORKER_COSTS) then
            Logging.info("[FarmTablet] autoDetect: Worker Costs detected")
            self:register({
                id = FT.APP.WORKER_COSTS, group = "mods",
                name = "ft_ui_app_worker_costs", navLabel = "WRK",
                icon = "worker", order = 26,
                developer = "TisonK", version = "Integrated",
                description = "Worker wages and cost breakdown",
            })
        end
    end

    -- Random World Events
    -- Bridge: mission.randomWorldEvents set by RandomWorldEvents in Mission00.load
    if g_currentMission and g_currentMission.randomWorldEvents then
        if not self:has(FT.APP.RANDOM_EVENTS) then
            Logging.info("[FarmTablet] autoDetect: Random World Events detected")
            self:register({
                id = FT.APP.RANDOM_EVENTS, group = "mods",
                name = "ft_ui_app_random_events", navLabel = "RWE",
                icon = "events", order = 27,
                developer = "TisonK", version = "Integrated",
                description = "Random world events tracker",
            })
        end
    end

    -- UsedPlus
    -- Bridge: g_vehicleSaleManager is set globally by UsedPlus main.lua
    -- Also check g_currentMission.usedPlusAPI (cross-mod bridge, also set by UsedPlus)
    local hasUsedPlus = (getfenv(0)["g_vehicleSaleManager"] ~= nil)
                     or (g_currentMission and g_currentMission.usedPlusAPI ~= nil)
    if hasUsedPlus and not self:has(FT.APP.USED_PLUS) then
        Logging.info("[FarmTablet] autoDetect: UsedPlus detected")
        self:register({
            id = FT.APP.USED_PLUS, group = "mods",
            name = "ft_ui_app_used_plus", navLabel = "USED",
            icon = "used_plus", order = 28,
            developer = "TisonK", version = "Integrated",
            description = "UsedPlus — active sale listings and finance deals",
        })
    end

    -- RoleplayPhone / Built-in Invoices
    -- Always registered — built-in FT_InvoiceManager provides fallback data even
    -- without FS25_RoleplayPhone. If the phone mod is present its API is used instead.
    -- TODO: update detection key once FS25_RoleplayPhone publishes its global name.
    if not self:has(FT.APP.ROLEPLAY_PHONE) then
        Logging.info("[FarmTablet] autoDetect: Registering Invoices app (built-in + RoleplayPhone integration)")
        self:register({
            id = FT.APP.ROLEPLAY_PHONE, group = "mods",
            name = "ft_ui_app_roleplay_phone", navLabel = "INV",
            icon = "invoice", order = 29,
            developer = "TisonK", version = "Integrated",
            description = "Invoice tracker — built-in + RoleplayPhone integration",
        })
    end

    Logging.info("[FarmTablet] autoDetect complete — %d apps registered", #self:getAll())
end
