-- =========================================================
-- FarmTablet v2 – FarmTabletSystem
-- Orchestrates state, data and the app registry
-- =========================================================
---@class FarmTabletSystem
FarmTabletSystem = {}
local FarmTabletSystem_mt = Class(FarmTabletSystem)

function FarmTabletSystem.new(settings)
    local self = setmetatable({}, FarmTabletSystem_mt)
    self.settings      = settings
    self.isInitialized = false

    self.registry      = AppRegistry.new()
    self.data          = FT_DataProvider.new()

    -- Startup app (ID string from settings)
    self.currentApp   = self.settings.startupApp or "dashboard"
    self.isTabletOpen = false

    -- Workshop state
    self.workshopSelectedVehicle = nil

    -- Bucket tracker
    self.bucket = {
        isEnabled   = true,
        vehicle     = nil,
        history     = {},   -- last 20 loads
        totalLoads  = 0,
        totalWeight = 0,
        lastFill    = 0,
        lastType    = nil,
        startTime   = 0,
    }

    return self
end

function FarmTabletSystem:initialize()
    if self.isInitialized then return end
    self.isInitialized = true
    self.registry:autoDetect()
    self:log("System initialized. Apps: %d", #self.registry:getAll())
end

function FarmTabletSystem:update(dt)
    if not self.settings.enabled or not self.isInitialized then return end
    if self.currentApp == FT.APP.BUCKET and self.bucket.isEnabled then
        self:_updateBucket()
    end
end

-- ── Bucket Tracker ────────────────────────────────────────

function FarmTabletSystem:_getBucketVehicle()
    if not (g_currentMission and g_currentMission.controlledVehicle) then
        return nil
    end
    local v = g_currentMission.controlledVehicle
    if not v.spec_fillUnit then return nil end

    -- Accept if it's a loader type or has a bucket attachment
    local typeName = (v.typeName or ""):lower()
    local loaderTypes = {"wheelloader","frontloader","loader","excavator",
                         "backhoe","telehandler","skidsteer","materialhandler"}
    for _, t in ipairs(loaderTypes) do
        if typeName:find(t) then return v end
    end
    -- Check attachments
    if v.getAttachedImplements then
        for _, impl in ipairs(v:getAttachedImplements()) do
            local it = ((impl.object or {}).typeName or ""):lower()
            if it:find("bucket") or it:find("loader") or
               it:find("grapple") or it:find("fork") then
                return v
            end
        end
    end
    return nil
end

function FarmTabletSystem:_getBucketFillInfo(v)
    local info = { total=0, cap=0, fillType=nil, name="Empty", pct=0 }
    if not v or not v.spec_fillUnit then return info end
    for _, fu in ipairs(v.spec_fillUnit.fillUnits or {}) do
        info.cap   = info.cap   + (fu.capacity  or 0)
        info.total = info.total + (fu.fillLevel or 0)
        if (fu.fillLevel or 0) > 0 then
            info.fillType = fu.fillType or FillType.UNKNOWN
        end
    end
    if info.cap > 0 then info.pct = info.total / info.cap * 100 end
    if info.fillType and g_fillTypeManager then
        local ft2 = g_fillTypeManager:getFillTypeByIndex(info.fillType)
        if ft2 then info.name = ft2.title or ft2.name or "Unknown" end
    end
    return info
end

local DENSITIES = {
    [FillType and FillType.SAND        or 0] = 1.6,
    [FillType and FillType.GRAVEL      or 0] = 1.7,
    [FillType and FillType.CRUSHEDSTONE or 0]= 1.6,
    [FillType and FillType.DIRT        or 0] = 1.3,
}

function FarmTabletSystem:_estimateWeight(vol, fillType)
    local d = DENSITIES[fillType or 0] or 1.5
    return math.floor(vol * d)
end

function FarmTabletSystem:_updateBucket()
    local v = self:_getBucketVehicle()
    local bt = self.bucket

    if not v then
        bt.vehicle = nil; bt.lastFill = 0; bt.lastType = nil
        return
    end

    if bt.vehicle ~= v then
        bt.vehicle = v; bt.lastFill = 0; bt.lastType = nil
    end

    local fi = self:_getBucketFillInfo(v)
    local old = bt.lastFill
    local new = fi.total
    local threshold = math.max(50, (fi.cap or 0) * 0.10)

    if old >= threshold and new < threshold and old > 0 then
        bt.totalLoads = bt.totalLoads + 1
        if bt.startTime == 0 then
            bt.startTime = g_currentMission.time or 0
        end
        local w = self:_estimateWeight(old, bt.lastType)
        bt.totalWeight = bt.totalWeight + w
        table.insert(bt.history, {
            n=bt.totalLoads, vol=math.floor(old),
            type=bt.lastType, typeName=fi.name, weight=w,
            time=g_currentMission.time or 0
        })
        if #bt.history > 20 then table.remove(bt.history, 1) end
    end

    bt.lastFill = new
    bt.lastType = fi.fillType
end

function FarmTabletSystem:resetBucket()
    self.bucket = {
        isEnabled=true, vehicle=nil, history={},
        totalLoads=0, totalWeight=0, lastFill=0, lastType=nil,
        startTime=g_currentMission and g_currentMission.time or 0,
    }
end

-- ── Misc helpers ──────────────────────────────────────────

function FarmTabletSystem:log(msg, ...)
    if self.settings.debugMode then
        Logging.info("[FarmTablet] " .. string.format(msg, ...))
    end
end
