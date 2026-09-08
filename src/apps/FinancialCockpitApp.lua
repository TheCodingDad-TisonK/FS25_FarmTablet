-- =========================================================
-- FarmTablet - Financial Cockpit (FT-6 v1)
-- =========================================================
-- Read-only whole-farm financial page. Health heart (worst-vital-wins),
-- live instruments, monthly history via own StateLedger module, and a
-- projection forecast. Moves no money. Never re-implements owning apps.
--
-- Gate: none. The page always registers because cash / leverage / runway read
-- base-game balance and loan. Time Guard is the month clock that records
-- history; without it the history vitals say so instead of promising samples.
-- Balance/loan: FT_DataProvider. Economic mods: pcall, neutral when absent.
-- =========================================================

FinancialCockpit = FinancialCockpit or {}

local LEDGER_MODULE = "FarmTablet_FinancialCockpit"
local ACCRUAL_ID    = "FarmTablet_FinancialCockpit_monthSample"
local MONTHLY_KEEP  = 36
local REFRESH_MS    = 1000

-- Balance-pass tunable bands (function is fixed; numbers can move later).
local THRESH = {
    cashGreen       = 50000,
    cashAmber       = 0,
    leverageGreen   = 0.25,
    leverageAmber   = 0.50,
    runwayGreen     = 3.0,
    runwayAmber     = 1.0,
    marginGreen     = 0.15,
    marginAmber     = 0.0,
    directionEps    = 1000,
    trajectoryEps   = 1000,
}

local BAND_RANK = { red = 3, amber = 2, green = 1 }

local _view       = "home"   -- home | vital | history | forecast | flows
local _vitalFocus = nil
local _bound      = false
local _cache      = { t = -1e9, snap = nil }

-- Own history (StateLedger-backed when present).
local _hist = {
    monthly = {},  -- array of { year, monthIndex, closingBalance, loan, perSourceFlowTotals }
    yearly  = {},  -- array of { year, yearEndBalance, yearEndLoan, perSourceFlowSums }
}

-- ── Tiny helpers ──────────────────────────────────────────

local function _T(key, fallback)
    return FT.l10n(key, fallback)
end

local function _pcall(fn, ...)
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

local function _money(data, n)
    n = tonumber(n) or 0
    if data and data.formatMoney then return data:formatMoney(n) end
    if g_i18n and g_i18n.formatMoney then return g_i18n:formatMoney(n, 0, true, true) end
    return string.format("$%.0f", n)
end

local function _timeGuard()
    return g_currentMission and g_currentMission.timeGuard or nil
end

local function _stateLedger()
    return g_currentMission and g_currentMission.stateLedger or nil
end

local function _isServer()
    return g_currentMission ~= nil and g_currentMission.getIsServer
        and g_currentMission:getIsServer()
end

-- Best-effort: dedicated peers have no host FarmTablet recorder.
-- Time Guard is the month clock that closes a row. Without it nothing ever
-- records, so say that plainly rather than promising samples that never come.
local function _historyMode()
    if _timeGuard() == nil then return "no_clock" end
    if _isServer() then return "available" end
    local m = g_currentMission
    if m ~= nil and (m.isDedicatedServer == true
        or (m.missionDynamicInfo and m.missionDynamicInfo.isDedicatedServer == true)) then
        return "dedicated"
    end
    return "host_only"
end

local function _nowMs()
    return (g_currentMission and g_currentMission.time) or 0
end

local function _bandColor(band)
    if band == "green" then return FT.C.POSITIVE end
    if band == "amber" then return FT.C.WARNING end
    if band == "red" then return FT.C.NEGATIVE end
    if band == "partial" then return FT.C.TEXT_ACCENT end
    return FT.C.MUTED
end

local function _bandLabel(band)
    if band == "green" then return _T("ft_fc_band_green", "Healthy") end
    if band == "amber" then return _T("ft_fc_band_amber", "Watch") end
    if band == "red" then return _T("ft_fc_band_red", "Critical") end
    if band == "partial" then return _T("ft_fc_band_partial", "Partial / Estimated") end
    return _T("ft_fc_band_neutral", "Neutral")
end

-- ── Flow reads (neutral when absent; never invent) ────────

local function _readIncomeFlow()
    local mgr = g_currentMission and g_currentMission.incomeManager
    if mgr == nil then return nil end
    local settings = mgr.settings
    local amount = nil
    local mode = nil
    local nextInfo = nil
    local seasonMult = nil
    if settings ~= nil then
        if type(settings.getPaymentAmount) == "function" then
            amount = _pcall(function() return settings:getPaymentAmount() end)
        end
        if type(settings.getPayModeName) == "function" then
            mode = _pcall(function() return settings:getPayModeName() end)
        end
    end
    local sys = mgr.system or mgr
    if type(sys.getNextPaymentInfo) == "function" then
        nextInfo = _pcall(function() return sys:getNextPaymentInfo() end)
    elseif type(mgr.getNextPaymentInfo) == "function" then
        nextInfo = _pcall(function() return mgr:getNextPaymentInfo() end)
    end
    if type(sys.getSeasonalMultiplier) == "function" then
        seasonMult = _pcall(function() return sys:getSeasonalMultiplier() end)
    end
    return {
        present = true,
        amount = tonumber(amount),
        mode = mode,
        nextInfo = nextInfo,
        seasonMult = tonumber(seasonMult),
    }
end

local function _readTaxFlow()
    local mgr = g_currentMission and g_currentMission.taxManager
    if mgr == nil then return nil end
    local state = nil
    if type(mgr.serializeState) == "function" then
        state = _pcall(function() return mgr.serializeState() end)
    elseif type(FS25TaxMod) == "table" and type(FS25TaxMod.serializeState) == "function" then
        state = _pcall(function() return FS25TaxMod.serializeState() end)
    end
    local stats = state and state.stats or nil
    -- Consume ONLY live fields (brief). Drop dead totalTaxesReturned / taxesThisMonth / monthsReturned.
    local totalPaid = stats and tonumber(stats.totalTaxesPaid) or nil
    local annualAcc = stats and tonumber(stats.taxesAccumulatedAnnual) or nil
    return {
        present = true,
        totalTaxesPaid = totalPaid,
        taxesAccumulatedAnnual = annualAcc,
        lastTaxYear = stats and tonumber(stats.lastTaxYear) or nil,
    }
end

local function _readWageFlow()
    local mgr = g_currentMission and g_currentMission.workerCostsManager
    if mgr == nil or type(mgr.getRosterSnapshot) ~= "function" then return nil end
    local snap = _pcall(function() return mgr:getRosterSnapshot() end)
    if type(snap) ~= "table" then return nil end
    local fin = snap.finance or {}
    return {
        present = true,
        monthAccrued = tonumber(fin.monthAccrued),
        estIntervalCost = tonumber(fin.estIntervalCost),
    }
end

local function _readCoopSignal()
    local mgr = g_currentMission and g_currentMission.proStaffManager
    if mgr == nil or type(mgr.getLevel) ~= "function" then return nil end
    local farmId = 1
    if g_localPlayer then
        farmId = (g_localPlayer.getFarmId and g_localPlayer:getFarmId()) or g_localPlayer.farmId or 1
    end
    local level = _pcall(function() return mgr:getLevel(farmId) end)
    if level == nil then return nil end
    return { present = true, level = tonumber(level) or 0 }
end

local function _readDairySignal()
    local mgr = g_currentMission and g_currentMission.dairyCoreManager
    if mgr == nil or type(mgr.getBarnRows) ~= "function" then return nil end
    local rows = _pcall(function() return mgr:getBarnRows() end)
    if type(rows) ~= "table" then return nil end
    -- Signal only (health / spoilage / tier). Contract income is a maturity ask.
    local health, spoilage, tier = nil, nil, nil
    for _, row in ipairs(rows) do
        if type(row) == "table" then
            health = health or row.health or row.herdHealth
            spoilage = spoilage or row.spoilage
            tier = tier or row.qualityTier or row.tierName or row.tier
        end
    end
    return { present = true, barnCount = #rows, health = health, spoilage = spoilage, tier = tier }
end

local function _readMarketSignal()
    local mgr = (g_currentMission and g_currentMission.MarketDynamics)
        or getfenv(0)["g_MarketDynamics"]
    if mgr == nil then return nil end
    local events = nil
    if mgr.worldEvents and type(mgr.worldEvents.getActiveEvents) == "function" then
        events = _pcall(function() return mgr.worldEvents:getActiveEvents() end)
    end
    return {
        present = true,
        activeEvents = type(events) == "table" and #events or 0,
    }
end

local function _readRweSignal()
    -- Handle: g_currentMission.randomWorldEvents (see RandomWorldEventsApp).
    local mgr = g_currentMission and g_currentMission.randomWorldEvents
    if mgr == nil then return nil end
    local ev, intensity = nil, nil
    if type(mgr.getActiveEvent) == "function" then
        ev = _pcall(function() return mgr:getActiveEvent() end)
    elseif type(mgr.EVENT_STATE) == "table" then
        ev = mgr.EVENT_STATE.activeEvent
    end
    if type(mgr.getEventIntensity) == "function" then
        intensity = _pcall(function() return mgr:getEventIntensity() end)
    elseif type(mgr.events) == "table" then
        intensity = mgr.events.intensity
    end
    return { present = true, event = ev, intensity = intensity }
end

-- getActiveEvent() hands back a table ({ name, intensity, category, remainingMs }
-- from RandomWorldEvents, or the event definition from its category API), so the
-- signal row reads a display field and never tostring()s the table.
local function _rweEventLabel(ev)
    local raw
    if type(ev) == "table" then
        raw = ev.title or ev.name or ev.displayName or ev.id or ev.eventId
    else
        raw = ev
    end
    if raw == nil or raw == "" then return "?" end
    -- "field_mice_invasion" -> "Field mice invasion" (same rule as the RWE app).
    local label = tostring(raw):gsub("_", " ")
    return label:sub(1, 1):upper() .. label:sub(2)
end

local function _flowGaps(flows)
    -- Dollar-flow gaps that force PARTIAL on derived vitals / forecast.
    local gaps = {}
    if flows.income == nil then gaps[#gaps + 1] = "income" end
    if flows.tax == nil then gaps[#gaps + 1] = "tax" end
    if flows.wages == nil then gaps[#gaps + 1] = "wages" end
    -- Maturity-ask gaps (fuel / dairy contract / RWE money) always open in v1.
    gaps[#gaps + 1] = "fuel"
    gaps[#gaps + 1] = "dairy_income"
    gaps[#gaps + 1] = "rwe_money"
    return gaps
end

-- ── History (upsert + retention) ──────────────────────────

local function _sortMonthly()
    table.sort(_hist.monthly, function(a, b)
        if a.year ~= b.year then return a.year < b.year end
        return a.monthIndex < b.monthIndex
    end)
end

local function _upsertMonth(row)
    if type(row) ~= "table" then return end
    local y = tonumber(row.year)
    local m = tonumber(row.monthIndex)
    if y == nil or m == nil then return end
    row.year = y
    row.monthIndex = m
    row.closingBalance = tonumber(row.closingBalance) or 0
    row.loan = tonumber(row.loan) or 0
    row.perSourceFlowTotals = type(row.perSourceFlowTotals) == "table" and row.perSourceFlowTotals or {}

    local replaced = false
    for i, existing in ipairs(_hist.monthly) do
        if existing.year == y and existing.monthIndex == m then
            _hist.monthly[i] = row
            replaced = true
            break
        end
    end
    if not replaced then
        _hist.monthly[#_hist.monthly + 1] = row
    end
    _sortMonthly()
    FinancialCockpit._rollupIfNeeded()
end

function FinancialCockpit._rollupIfNeeded()
    while #_hist.monthly > MONTHLY_KEEP do
        local oldest = _hist.monthly[1]
        table.remove(_hist.monthly, 1)
        local year = oldest.year
        local yr = nil
        for _, yrow in ipairs(_hist.yearly) do
            if yrow.year == year then yr = yrow; break end
        end
        if yr == nil then
            yr = {
                year = year,
                yearEndBalance = oldest.closingBalance,
                yearEndLoan = oldest.loan,
                perSourceFlowSums = {},
            }
            _hist.yearly[#_hist.yearly + 1] = yr
        end
        yr.yearEndBalance = oldest.closingBalance
        yr.yearEndLoan = oldest.loan
        local sums = yr.perSourceFlowSums
        for k, v in pairs(oldest.perSourceFlowTotals or {}) do
            sums[k] = (tonumber(sums[k]) or 0) + (tonumber(v) or 0)
        end
    end
    table.sort(_hist.yearly, function(a, b) return a.year < b.year end)
end

local function _serializeHistory()
    return {
        version = 1,
        monthly = _hist.monthly,
        yearly = _hist.yearly,
    }
end

local function _deserializeHistory(data)
    _hist.monthly = {}
    _hist.yearly = {}
    if type(data) ~= "table" then return end
    if type(data.monthly) == "table" then
        for _, row in ipairs(data.monthly) do
            if type(row) == "table" then
                _hist.monthly[#_hist.monthly + 1] = {
                    year = tonumber(row.year) or 0,
                    monthIndex = tonumber(row.monthIndex) or 0,
                    closingBalance = tonumber(row.closingBalance) or 0,
                    loan = tonumber(row.loan) or 0,
                    perSourceFlowTotals = type(row.perSourceFlowTotals) == "table" and row.perSourceFlowTotals or {},
                }
            end
        end
    end
    if type(data.yearly) == "table" then
        for _, row in ipairs(data.yearly) do
            if type(row) == "table" then
                _hist.yearly[#_hist.yearly + 1] = {
                    year = tonumber(row.year) or 0,
                    yearEndBalance = tonumber(row.yearEndBalance) or 0,
                    yearEndLoan = tonumber(row.yearEndLoan) or 0,
                    perSourceFlowSums = type(row.perSourceFlowSums) == "table" and row.perSourceFlowSums or {},
                }
            end
        end
    end
    _sortMonthly()
    FinancialCockpit._rollupIfNeeded()
end

local function _sampleClosedMonth(ctx)
    if not _isServer() then return end
    local dataProvider = nil
    local ft = getfenv(0)["g_FarmTablet"]
    if ft and ft.system and ft.system.data then
        dataProvider = ft.system.data
    end
    local farmId = 1
    if dataProvider and dataProvider.getPlayerFarmId then
        farmId = dataProvider:getPlayerFarmId()
    elseif g_localPlayer then
        farmId = (g_localPlayer.getFarmId and g_localPlayer:getFarmId()) or g_localPlayer.farmId or 1
    end

    local balance, loan = 0, 0
    if dataProvider then
        balance = tonumber(dataProvider:getBalance(farmId)) or 0
        loan = tonumber(dataProvider:getLoan(farmId)) or 0
    end

    -- Settle fires on the NEW period; the closed month is the previous one.
    local year = tonumber(ctx and ctx.year) or 0
    local period = tonumber(ctx and ctx.period) or 1
    local closedMonth = period - 1
    local closedYear = year
    if closedMonth < 1 then
        closedMonth = 12
        closedYear = year - 1
    end

    local income = _readIncomeFlow()
    local tax = _readTaxFlow()
    local wages = _readWageFlow()
    local flows = {}
    if wages and wages.monthAccrued ~= nil then flows.wages = wages.monthAccrued end
    if tax and tax.taxesAccumulatedAnnual ~= nil then flows.taxAnnualAnchor = tax.taxesAccumulatedAnnual end
    if income and income.amount ~= nil then flows.incomeRate = income.amount end

    _upsertMonth({
        year = closedYear,
        monthIndex = closedMonth,
        closingBalance = balance,
        loan = loan,
        perSourceFlowTotals = flows,
    })
end

function FinancialCockpit.bind()
    if _bound then return true end
    local tg = _timeGuard()
    if tg == nil then return false end

    local ledger = _stateLedger()
    if ledger ~= nil and type(ledger.registerModule) == "function" then
        pcall(function()
            ledger:registerModule(LEDGER_MODULE, {
                serialize = function()
                    return _serializeHistory()
                end,
                deserialize = function(data)
                    _deserializeHistory(data)
                end,
            })
        end)
    end

    -- Prefer no-money month accrual (server-only, cursor-idempotent).
    if type(tg.registerAccrual) == "function" then
        pcall(function()
            tg:registerAccrual(ACCRUAL_ID, {
                cadence = "month",
                flowClass = "event",
                firstPeriodPolicy = "skip",
                priority = 900,
                onSettle = function(ctx)
                    _sampleClosedMonth(ctx)
                end,
            })
        end)
    elseif type(tg.subscribeTick) == "function" then
        pcall(function()
            tg:subscribeTick("month", ACCRUAL_ID, function(ctx)
                _sampleClosedMonth(ctx)
            end)
        end)
    end

    _bound = true
    return true
end

function FinancialCockpit.getHistory()
    return _hist
end

-- ── Snapshot gather (throttled) ───────────────────────────

local function _netWorth(balance, loan)
    return (tonumber(balance) or 0) - (tonumber(loan) or 0)
end

local function _leverageRatio(balance, loan)
    balance = tonumber(balance) or 0
    loan = tonumber(loan) or 0
    local denom = balance + loan
    if denom <= 0 then
        if loan > 0 then return 1 end
        return 0
    end
    return loan / denom
end

local function _buildVitals(snap)
    local vitals = {}
    local balance = snap.balance
    local loan = snap.loan
    local nw = snap.netWorth
    local histMode = snap.historyMode
    local gaps = snap.flowGaps
    local hasFlowGap = #gaps > 0
    local monthly = _hist.monthly

    -- Cash position (live)
    local cashBand
    if balance >= THRESH.cashGreen then cashBand = "green"
    elseif balance >= THRESH.cashAmber then cashBand = "amber"
    else cashBand = "red" end
    vitals[#vitals + 1] = {
        id = "cash",
        label = _T("ft_fc_vital_cash", "Cash position"),
        band = cashBand,
        valueText = _money(snap.data, balance),
        detail = _T("ft_fc_vital_cash_detail", "Available farm balance."),
    }

    -- Leverage (live; loan confirm noted in brief)
    local lev = _leverageRatio(balance, loan)
    local levBand
    if lev <= THRESH.leverageGreen then levBand = "green"
    elseif lev <= THRESH.leverageAmber then levBand = "amber"
    else levBand = "red" end
    vitals[#vitals + 1] = {
        id = "leverage",
        label = _T("ft_fc_vital_leverage", "Leverage"),
        band = levBand,
        valueText = string.format("%.0f%%", lev * 100),
        detail = string.format("%s %s",
            _T("ft_fc_vital_leverage_detail", "Loan share of balance plus loan."),
            _money(snap.data, loan)),
    }

    -- Runway: PARTIAL while any dollar-flow gap remains (fuel / dairy / RWE maturity asks
    -- keep this honest in v1 even when wages are readable).
    if hasFlowGap then
        vitals[#vitals + 1] = {
            id = "runway",
            label = _T("ft_fc_vital_runway", "Cash runway"),
            band = "partial",
            valueText = _T("ft_fc_partial", "PARTIAL"),
            detail = _T("ft_fc_vital_runway_partial", "Needs a fuller cost picture before runway is confident."),
        }
    else
        local burn = 0
        if snap.wages then
            burn = tonumber(snap.wages.estIntervalCost) or tonumber(snap.wages.monthAccrued) or 0
        end
        local months = (burn > 0) and (balance / burn) or 99
        local runBand
        if months >= THRESH.runwayGreen then runBand = "green"
        elseif months >= THRESH.runwayAmber then runBand = "amber"
        else runBand = "red" end
        vitals[#vitals + 1] = {
            id = "runway",
            label = _T("ft_fc_vital_runway", "Cash runway"),
            band = runBand,
            valueText = string.format("%.1f %s", months, _T("ft_fc_months", "months")),
            detail = _T("ft_fc_vital_runway_detail", "Balance divided by known operating burn."),
        }
    end

    -- History-derived vitals
    if histMode == "no_clock" then
        local noClock = _T("ft_fc_history_no_clock", "Needs Time Guard")
        local noClockDetail = _T("ft_fc_history_no_clock_detail",
            "Install Time Guard to record monthly history. Live vitals still stand.")
        for _, id in ipairs({ "direction", "margin", "trajectory" }) do
            vitals[#vitals + 1] = {
                id = id,
                label = _T("ft_fc_vital_" .. id, id),
                band = "neutral",
                valueText = noClock,
                detail = noClockDetail,
            }
        end
    elseif histMode == "dedicated" then
        local unavailable = _T("ft_fc_history_dedicated", "Unavailable on this server")
        for _, id in ipairs({ "direction", "margin", "trajectory" }) do
            vitals[#vitals + 1] = {
                id = id,
                label = _T("ft_fc_vital_" .. id, id),
                band = "neutral",
                valueText = unavailable,
                detail = unavailable,
            }
        end
    elseif histMode == "host_only" then
        local hostOnly = _T("ft_fc_history_host_only", "Host-only in v1")
        for _, idLabel in ipairs({
            { "direction", _T("ft_fc_vital_direction", "Profit direction") },
            { "margin", _T("ft_fc_vital_margin", "Margin") },
            { "trajectory", _T("ft_fc_vital_trajectory", "Net-worth trajectory") },
        }) do
            vitals[#vitals + 1] = {
                id = idLabel[1],
                label = idLabel[2],
                band = "neutral",
                valueText = hostOnly,
                detail = _T("ft_fc_history_host_only_detail", "Monthly history is recorded on the host. Live cash and leverage still stand."),
            }
        end
    else
        -- Direction from last two net-worth closes
        if #monthly < 2 then
            vitals[#vitals + 1] = {
                id = "direction",
                label = _T("ft_fc_vital_direction", "Profit direction"),
                band = "neutral",
                valueText = _T("ft_fc_no_history_yet", "No history yet"),
                detail = _T("ft_fc_vital_direction_wait", "Needs at least two monthly samples."),
            }
        else
            local a = monthly[#monthly - 1]
            local b = monthly[#monthly]
            local d = _netWorth(b.closingBalance, b.loan) - _netWorth(a.closingBalance, a.loan)
            local dBand
            if d > THRESH.directionEps then dBand = "green"
            elseif d < -THRESH.directionEps then dBand = "red"
            else dBand = "amber" end
            vitals[#vitals + 1] = {
                id = "direction",
                label = _T("ft_fc_vital_direction", "Profit direction"),
                band = dBand,
                valueText = _money(snap.data, d),
                detail = _T("ft_fc_vital_direction_detail", "Change in net worth across the last two closed months."),
            }
        end

        -- Margin
        if #monthly < 1 then
            vitals[#vitals + 1] = {
                id = "margin",
                label = _T("ft_fc_vital_margin", "Margin"),
                band = "neutral",
                valueText = _T("ft_fc_no_history_yet", "No history yet"),
                detail = _T("ft_fc_vital_margin_wait", "Needs a recorded month with flow totals."),
            }
        elseif hasFlowGap then
            vitals[#vitals + 1] = {
                id = "margin",
                label = _T("ft_fc_vital_margin", "Margin"),
                band = "partial",
                valueText = _T("ft_fc_partial", "PARTIAL"),
                detail = _T("ft_fc_vital_margin_partial", "Flow gaps remain; margin is estimated only."),
            }
        else
            vitals[#vitals + 1] = {
                id = "margin",
                label = _T("ft_fc_vital_margin", "Margin"),
                band = "partial",
                valueText = _T("ft_fc_partial", "PARTIAL"),
                detail = _T("ft_fc_vital_margin_partial", "Flow gaps remain; margin is estimated only."),
            }
        end

        -- Trajectory
        if #monthly < 2 then
            vitals[#vitals + 1] = {
                id = "trajectory",
                label = _T("ft_fc_vital_trajectory", "Net-worth trajectory"),
                band = "neutral",
                valueText = _T("ft_fc_no_history_yet", "No history yet"),
                detail = _T("ft_fc_vital_trajectory_wait", "Needs at least two monthly samples."),
            }
        else
            local first = monthly[math.max(1, #monthly - 5)]
            local last = monthly[#monthly]
            local d = _netWorth(last.closingBalance, last.loan) - _netWorth(first.closingBalance, first.loan)
            local tBand
            if d > THRESH.trajectoryEps then tBand = "green"
            elseif d < -THRESH.trajectoryEps then tBand = "red"
            else tBand = "amber" end
            vitals[#vitals + 1] = {
                id = "trajectory",
                label = _T("ft_fc_vital_trajectory", "Net-worth trajectory"),
                band = tBand,
                valueText = _money(snap.data, d),
                detail = _T("ft_fc_vital_trajectory_detail", "Net worth change over the recent recorded window."),
            }
        end
    end

    return vitals
end

local function _worstVital(vitals)
    local worstBand, worstId = nil, nil
    local worstRank = 0
    for _, v in ipairs(vitals) do
        local rank = BAND_RANK[v.band]
        if rank ~= nil and rank > worstRank then
            worstRank = rank
            worstBand = v.band
            worstId = v.id
        end
    end
    return worstBand or "neutral", worstId
end

local function _buildForecast(snap)
    local tg = snap.tgCtx
    local gaps = snap.flowGaps
    local partial = #gaps > 0
    local remaining = nil
    if tg and snap.tgSynced and snap.timeGuard and type(snap.timeGuard.getPeriodRemainingFraction) == "function" then
        remaining = _pcall(function() return snap.timeGuard:getPeriodRemainingFraction("month") end)
    end

    local lines = {}
    lines[#lines + 1] = {
        label = _T("ft_fc_forecast_label", "Projection"),
        value = _T("ft_fc_forecast_month_end", "Month-end outlook"),
        note = partial and _T("ft_fc_partial", "PARTIAL") or _T("ft_fc_forecast_limited", "Limited to readable flows"),
    }

    if remaining ~= nil then
        lines[#lines + 1] = {
            label = _T("ft_fc_forecast_remaining", "Period remaining"),
            value = string.format("%.0f%%", remaining * 100),
        }
    elseif not snap.tgSynced then
        lines[#lines + 1] = {
            label = _T("ft_fc_forecast_remaining", "Period remaining"),
            value = _T("ft_fc_syncing", "Syncing"),
        }
    end

    if snap.income and snap.income.amount ~= nil then
        lines[#lines + 1] = {
            label = _T("ft_fc_forecast_next_pay", "Next income pulse"),
            value = _money(snap.data, snap.income.amount),
            note = snap.income.nextInfo or snap.income.mode,
        }
    else
        lines[#lines + 1] = {
            label = _T("ft_fc_forecast_next_pay", "Next income pulse"),
            value = _T("ft_fc_not_tracked", "Not yet tracked"),
        }
    end

    if snap.tax and snap.tax.taxesAccumulatedAnnual ~= nil then
        lines[#lines + 1] = {
            label = _T("ft_fc_forecast_tax", "Tax accumulated (annual)"),
            value = _money(snap.data, snap.tax.taxesAccumulatedAnnual),
            note = partial and _T("ft_fc_partial", "PARTIAL") or nil,
        }
    else
        lines[#lines + 1] = {
            label = _T("ft_fc_forecast_tax", "Tax accumulated (annual)"),
            value = _T("ft_fc_not_tracked", "Not yet tracked"),
        }
    end

    if snap.wages and (snap.wages.estIntervalCost ~= nil or snap.wages.monthAccrued ~= nil) then
        local w = snap.wages.estIntervalCost or snap.wages.monthAccrued
        lines[#lines + 1] = {
            label = _T("ft_fc_forecast_wages", "Wage burn (known)"),
            value = _money(snap.data, w),
            note = partial and _T("ft_fc_partial", "PARTIAL") or nil,
        }
    else
        lines[#lines + 1] = {
            label = _T("ft_fc_forecast_wages", "Wage burn (known)"),
            value = _T("ft_fc_not_tracked", "Not yet tracked"),
        }
    end

    -- Never project fuel / dairy contract / RWE money until those accumulators exist.
    lines[#lines + 1] = {
        label = _T("ft_fc_forecast_fuel", "Fuel spend"),
        value = _T("ft_fc_not_tracked", "Not yet tracked"),
    }

    local monthEndNote
    if remaining ~= nil and snap.wages and snap.wages.estIntervalCost then
        local burnLeft = (tonumber(snap.wages.estIntervalCost) or 0) * remaining
        local incomePulse = (snap.income and tonumber(snap.income.amount)) or 0
        local projected = snap.balance - burnLeft + incomePulse * remaining
        monthEndNote = _money(snap.data, projected)
        partial = true -- wage+income only
    end

    return {
        partial = partial,
        remaining = remaining,
        lines = lines,
        monthEndProjected = monthEndNote,
    }
end

local function _gather(self)
    local now = _nowMs()
    if _cache.snap ~= nil and (now - _cache.t) < REFRESH_MS then
        return _cache.snap
    end

    FinancialCockpit.bind()

    local data = self.system.data
    local farmId = data:getPlayerFarmId()
    local balance = tonumber(data:getBalance(farmId)) or 0
    local loan = tonumber(data:getLoan(farmId)) or 0
    local tg = _timeGuard()
    local tgCtx = nil
    local tgSynced = false
    if tg ~= nil and type(tg.getContext) == "function" then
        tgCtx = _pcall(function() return tg:getContext() end)
        tgSynced = tgCtx ~= nil and tgCtx.synced == true
    end

    local income = _readIncomeFlow()
    local tax = _readTaxFlow()
    local wages = _readWageFlow()
    local flows = { income = income, tax = tax, wages = wages }
    local gaps = _flowGaps(flows)

    local snap = {
        data = data,
        farmId = farmId,
        farmName = data:getFarmName(farmId) or ("Farm " .. tostring(farmId)),
        balance = balance,
        loan = loan,
        netWorth = _netWorth(balance, loan),
        timeGuard = tg,
        tgCtx = tgCtx,
        tgSynced = tgSynced,
        income = income,
        tax = tax,
        wages = wages,
        coop = _readCoopSignal(),
        dairy = _readDairySignal(),
        market = _readMarketSignal(),
        rwe = _readRweSignal(),
        flowGaps = gaps,
        historyMode = _historyMode(),
        ledgerPresent = _stateLedger() ~= nil,
        monthlyCount = #_hist.monthly,
        yearlyCount = #_hist.yearly,
    }
    snap.vitals = _buildVitals(snap)
    snap.heartBand, snap.heartVitalId = _worstVital(snap.vitals)
    snap.forecast = _buildForecast(snap)

    _cache.t = now
    _cache.snap = snap
    return snap
end

-- ── UI pieces ─────────────────────────────────────────────

local function _pocketBtn(self, x, y, w, h, label, color, onClick)
    local btn = self.r:button(x, y, w, h, label, color, { onClick = onClick })
    table.insert(self._contentBtns, btn)
    return btn
end

local function _drawHeart(self, x, y, w, snap, AC)
    local band = snap.heartBand
    local col = _bandColor(band)
    local h = FT.py(54)
    self.r:appRect(x, y - h, w, h, FT.C.BG_CARD)
    -- Heart color chip
    local chip = FT.px(22)
    self.r:appRect(x + FT.px(10), y - h + FT.py(16), chip, chip, col)
    self.r:appText(x + FT.px(40), y - FT.py(10), FT.FONT.TINY,
        _T("ft_fc_health", "FARM HEALTH"), RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
    self.r:appText(x + FT.px(40), y - FT.py(28), FT.FONT.TITLE,
        _bandLabel(band), RenderText.ALIGN_LEFT, col)

    local worstLabel = ""
    if snap.heartVitalId then
        for _, v in ipairs(snap.vitals) do
            if v.id == snap.heartVitalId then
                worstLabel = v.label
                break
            end
        end
    end
    if worstLabel ~= "" then
        self.r:appText(x + w - FT.px(10), y - FT.py(18), FT.FONT.TINY,
            FT_Renderer.truncate(worstLabel, 18), RenderText.ALIGN_RIGHT, FT.C.TEXT_DIM)
    end

    _pocketBtn(self, x, y - h, w, h, "", {0, 0, 0, 0}, function()
        _vitalFocus = snap.heartVitalId
        _view = "vital"
        self:switchApp(FT.APP.FINANCIAL_COCKPIT)
    end)
    return y - h - FT.py(6)
end

local function _drawHome(self, snap, AC)
    local startY = self:drawAppHeader(_T("ft_ui_app_financial_cockpit", "Financial Cockpit"), snap.farmName)
    local x, contentY, cw, _ = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y = startY + scrollY

    y = _drawHeart(self, x, y, cw, snap, AC)
    y = self:drawRule(y, 0.35)

    -- Live instruments
    y = self:drawSection(y, _T("ft_fc_section_instruments", "INSTRUMENTS"))
    local balC = snap.balance >= 0 and FT.C.POSITIVE or FT.C.NEGATIVE
    y = self:drawRow(y, _T("ft_fc_balance", "Balance"), _money(snap.data, snap.balance), nil, balC)
    if snap.loan > 0 then
        y = self:drawRow(y, _T("ft_fc_loan", "Loan"), _money(snap.data, snap.loan), nil, FT.C.WARNING)
    else
        y = self:drawRow(y, _T("ft_fc_loan", "Loan"), _money(snap.data, 0), nil, FT.C.TEXT_DIM)
    end
    local nwC = snap.netWorth >= 0 and FT.C.POSITIVE or FT.C.NEGATIVE
    y = self:drawRow(y, _T("ft_fc_net_worth", "Net worth"), _money(snap.data, snap.netWorth), nil, nwC)
    y = y - FT.py(4)
    y = self:drawRule(y, 0.25)

    -- Time Guard rhythm
    y = self:drawSection(y, _T("ft_fc_section_rhythm", "RHYTHM"))
    if snap.tgCtx == nil then
        y = self:drawRow(y, _T("ft_fc_clock", "Economic clock"), _T("ft_fc_unavailable", "Unavailable"), nil, FT.C.MUTED)
    elseif not snap.tgSynced then
        y = self:drawRow(y, _T("ft_fc_clock", "Economic clock"), _T("ft_fc_syncing", "Syncing"), nil, FT.C.WARNING)
    else
        y = self:drawRow(y, _T("ft_fc_period", "Period"),
            string.format("%s %d / %s %d",
                _T("ft_fc_month", "Month"), snap.tgCtx.period or 0,
                _T("ft_fc_year", "Year"), snap.tgCtx.year or 0),
            nil, FT.C.TEXT_NORMAL)
        y = self:drawRow(y, _T("ft_fc_days_per_period", "Days / period"),
            tostring(snap.tgCtx.daysPerPeriod or "-"), nil, FT.C.TEXT_DIM)
    end
    y = y - FT.py(4)
    y = self:drawRule(y, 0.25)

    -- Forecast teaser
    y = self:drawSection(y, _T("ft_fc_section_forecast", "FORECAST"))
    local fc = snap.forecast
    local fcNote = fc.partial and _T("ft_fc_partial", "PARTIAL") or _T("ft_fc_forecast_label", "Projection")
    y = self:drawRow(y, _T("ft_fc_forecast_label", "Projection"), fcNote, nil,
        fc.partial and FT.C.WARNING or FT.C.INFO)
    if fc.monthEndProjected then
        y = self:drawRow(y, _T("ft_fc_forecast_month_end", "Month-end outlook"),
            fc.monthEndProjected, nil, FT.C.TEXT_NORMAL)
    end
    -- OPEN on its own row so it cannot cover the forecast values above.
    local fcBtnW = FT.px(72)
    _pocketBtn(self, x + cw - fcBtnW, y - FT.py(2), fcBtnW, FT.py(16),
        _T("ft_fc_open", "OPEN"), FT.C.BTN_NEUTRAL, function()
            _view = "forecast"
            self:switchApp(FT.APP.FINANCIAL_COCKPIT)
        end)
    y = y - FT.py(22)
    y = self:drawRule(y, 0.25)

    -- History teaser
    y = self:drawSection(y, _T("ft_fc_section_history", "HISTORY"))
    if not snap.ledgerPresent and snap.historyMode == "available" then
        y = self:drawRow(y, _T("ft_fc_history", "Monthly record"),
            _T("ft_fc_history_no_ledger", "No StateLedger (live vitals only)"), nil, FT.C.MUTED)
    elseif snap.historyMode == "dedicated" then
        y = self:drawRow(y, _T("ft_fc_history", "Monthly record"),
            _T("ft_fc_history_dedicated", "Unavailable on this server"), nil, FT.C.MUTED)
    elseif snap.historyMode == "host_only" then
        y = self:drawRow(y, _T("ft_fc_history", "Monthly record"),
            _T("ft_fc_history_host_only", "Host-only in v1"), nil, FT.C.MUTED)
    else
        y = self:drawRow(y, _T("ft_fc_history", "Monthly record"),
            string.format("%d %s", snap.monthlyCount, _T("ft_fc_months", "months")),
            nil, FT.C.TEXT_NORMAL)
    end
    local hBtnW = FT.px(72)
    _pocketBtn(self, x + cw - hBtnW, y - FT.py(2), hBtnW, FT.py(16),
        _T("ft_fc_open", "OPEN"), FT.C.BTN_NEUTRAL, function()
            _view = "history"
            self:switchApp(FT.APP.FINANCIAL_COCKPIT)
        end)
    y = y - FT.py(22)
    y = self:drawRule(y, 0.25)

    -- Flow / signal strip
    y = self:drawSection(y, _T("ft_fc_section_flows", "FLOWS AND SIGNALS"))
    local function flowRow(label, present, value, color)
        if not present then
            y = self:drawRow(y, label, _T("ft_fc_not_tracked", "Not yet tracked"), nil, FT.C.MUTED)
        else
            y = self:drawRow(y, label, value, nil, color or FT.C.TEXT_NORMAL)
        end
    end
    flowRow(_T("ft_fc_flow_income", "Income"), snap.income ~= nil,
        snap.income and _money(snap.data, snap.income.amount or 0) or "", FT.C.POSITIVE)
    flowRow(_T("ft_fc_flow_tax", "Tax paid (total)"), snap.tax ~= nil and snap.tax.totalTaxesPaid ~= nil,
        snap.tax and _money(snap.data, snap.tax.totalTaxesPaid) or "", FT.C.WARNING)
    flowRow(_T("ft_fc_flow_wages", "Wages (month)"), snap.wages ~= nil and snap.wages.monthAccrued ~= nil,
        snap.wages and _money(snap.data, snap.wages.monthAccrued) or "", FT.C.WARNING)
    flowRow(_T("ft_fc_flow_fuel", "Fuel spend"), false, "", nil)
    if snap.coop then
        y = self:drawRow(y, _T("ft_fc_signal_coop", "Co-Op level"),
            tostring(snap.coop.level), nil, FT.C.TEXT_ACCENT)
    else
        y = self:drawRow(y, _T("ft_fc_signal_coop", "Co-Op level"),
            _T("ft_fc_not_tracked", "Not yet tracked"), nil, FT.C.MUTED)
    end
    if snap.dairy then
        y = self:drawRow(y, _T("ft_fc_signal_dairy", "Dairy barns"),
            tostring(snap.dairy.barnCount), nil, FT.C.TEXT_NORMAL)
    end

    local fBtnW = FT.px(72)
    _pocketBtn(self, x + cw - fBtnW, y - FT.py(2), fBtnW, FT.py(16),
        _T("ft_fc_open", "OPEN"), FT.C.BTN_NEUTRAL, function()
            _view = "flows"
            self:switchApp(FT.APP.FINANCIAL_COCKPIT)
        end)
    y = y - FT.py(20)

    self:setContentHeight(startY - y + scrollY)
    self:drawScrollBar()
end

local function _drawVitalPocket(self, snap, AC)
    local startY = self:drawAppHeader(_T("ft_fc_pocket_vital", "Health vital"),
        _bandLabel(snap.heartBand))
    local x, _, cw, _ = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y = startY + scrollY

    y = self:drawSection(y, _T("ft_fc_section_vitals", "VITALS"))
    for _, v in ipairs(snap.vitals) do
        local focus = (_vitalFocus ~= nil and v.id == _vitalFocus)
        local label = focus and ("> " .. v.label) or v.label
        y = self:drawRow(y, label, v.valueText, nil, _bandColor(v.band))
        if focus or v.band == snap.heartBand then
            self.r:appText(x + FT.px(8), y + FT.py(2), FT.FONT.TINY,
                v.detail or "", RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            y = y - FT.py(14)
        end
    end
    y = y - FT.py(8)
    self.r:appText(x, y, FT.FONT.TINY,
        _T("ft_fc_worst_rule", "Heart color = worst vital that has data. Neutrals and partials do not count as healthy."),
        RenderText.ALIGN_LEFT, FT.C.MUTED)
    y = y - FT.py(20)

    self:setContentHeight(startY - y + scrollY)
    self:drawScrollBar()
end

local function _drawHistoryPocket(self, snap, AC)
    local startY = self:drawAppHeader(_T("ft_fc_pocket_history", "Financial history"),
        _T("ft_fc_section_history", "HISTORY"))
    local x, _, cw, _ = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y = startY + scrollY

    if snap.historyMode == "no_clock" then
        y = self:drawRow(y, _T("ft_fc_history", "Monthly record"),
            _T("ft_fc_history_no_clock", "Needs Time Guard"), nil, FT.C.MUTED)
        self.r:appText(x, y, FT.FONT.TINY,
            _T("ft_fc_history_no_clock_detail",
                "Install Time Guard to record monthly history. Live vitals still stand."),
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        y = y - FT.py(18)
    elseif snap.historyMode == "dedicated" then
        y = self:drawRow(y, _T("ft_fc_history", "Monthly record"),
            _T("ft_fc_history_dedicated", "Unavailable on this server"), nil, FT.C.MUTED)
    elseif snap.historyMode == "host_only" then
        y = self:drawRow(y, _T("ft_fc_history", "Monthly record"),
            _T("ft_fc_history_host_only", "Host-only in v1"), nil, FT.C.MUTED)
        self.r:appText(x, y, FT.FONT.TINY,
            _T("ft_fc_history_host_only_detail", "Monthly history is recorded on the host. Live cash and leverage still stand."),
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        y = y - FT.py(18)
    elseif not snap.ledgerPresent then
        y = self:drawRow(y, _T("ft_fc_history", "Monthly record"),
            _T("ft_fc_history_no_ledger", "No StateLedger (live vitals only)"), nil, FT.C.MUTED)
    elseif #_hist.monthly == 0 then
        y = self:drawRow(y, _T("ft_fc_history", "Monthly record"),
            _T("ft_fc_no_history_yet", "No history yet"), nil, FT.C.MUTED)
        self.r:appText(x, y, FT.FONT.TINY,
            _T("ft_fc_history_wait_detail", "A compact row is written each closed in-game month."),
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        y = y - FT.py(18)
    else
        y = self:drawSection(y, _T("ft_fc_recent_months", "RECENT MONTHS"))
        local startIdx = math.max(1, #_hist.monthly - 11)
        -- Walk newest to oldest. A missing month between keys is left as a visual
        -- gap (separate rows only; never interpolate a false continuous trend).
        for i = #_hist.monthly, startIdx, -1 do
            local row = _hist.monthly[i]
            local nw = _netWorth(row.closingBalance, row.loan)
            y = self:drawRow(y,
                string.format("%d / %02d", row.year, row.monthIndex),
                _money(snap.data, nw),
                nil, nw >= 0 and FT.C.POSITIVE or FT.C.NEGATIVE)
        end
        if #_hist.yearly > 0 then
            y = y - FT.py(4)
            y = self:drawRule(y, 0.25)
            y = self:drawSection(y, _T("ft_fc_yearly_rollup", "YEARLY ROLLUP"))
            for i = #_hist.yearly, 1, -1 do
                local yr = _hist.yearly[i]
                local nw = _netWorth(yr.yearEndBalance, yr.yearEndLoan)
                y = self:drawRow(y, tostring(yr.year), _money(snap.data, nw), nil, FT.C.TEXT_NORMAL)
            end
        end
    end

    self:setContentHeight(startY - y + scrollY)
    self:drawScrollBar()
end

local function _drawForecastPocket(self, snap, AC)
    local startY = self:drawAppHeader(_T("ft_fc_pocket_forecast", "Forecast"),
        _T("ft_fc_forecast_label", "Projection"))
    local x, _, cw, _ = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y = startY + scrollY

    local fc = snap.forecast
    if fc.partial then
        y = self:drawRow(y, _T("ft_fc_honesty", "Honesty"),
            _T("ft_fc_partial", "PARTIAL"), nil, FT.C.WARNING)
    end
    for _, line in ipairs(fc.lines) do
        y = self:drawRow(y, line.label, line.value, nil, FT.C.TEXT_NORMAL)
        if line.note then
            self.r:appText(x + FT.px(8), y + FT.py(2), FT.FONT.TINY,
                tostring(line.note), RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
            y = y - FT.py(12)
        end
    end
    if fc.monthEndProjected then
        y = y - FT.py(4)
        y = self:drawRule(y, 0.25)
        y = self:drawRow(y, _T("ft_fc_forecast_month_end", "Month-end outlook"),
            fc.monthEndProjected, nil, FT.C.WARNING)
        self.r:appText(x, y, FT.FONT.TINY,
            _T("ft_fc_forecast_disclaimer", "Projection only. Missing flows are not invented."),
            RenderText.ALIGN_LEFT, FT.C.MUTED)
        y = y - FT.py(16)
    end

    self:setContentHeight(startY - y + scrollY)
    self:drawScrollBar()
end

local function _drawFlowsPocket(self, snap, AC)
    local startY = self:drawAppHeader(_T("ft_fc_pocket_flows", "Flows and signals"),
        _T("ft_fc_section_flows", "FLOWS AND SIGNALS"))
    local x, _, cw, _ = self:contentInner()
    local scrollY = self:getContentScrollY()
    local y = startY + scrollY

    y = self:drawSection(y, _T("ft_fc_dollar_flows", "DOLLAR FLOWS"))
    if snap.income then
        y = self:drawRow(y, _T("ft_fc_flow_income", "Income"),
            _money(snap.data, snap.income.amount or 0), nil, FT.C.POSITIVE)
        if snap.income.mode then
            y = self:drawRow(y, _T("ft_fc_flow_income_mode", "Pay mode"),
                tostring(snap.income.mode), nil, FT.C.TEXT_DIM)
        end
    else
        y = self:drawRow(y, _T("ft_fc_flow_income", "Income"),
            _T("ft_fc_not_tracked", "Not yet tracked"), nil, FT.C.MUTED)
    end
    if snap.tax and snap.tax.totalTaxesPaid ~= nil then
        y = self:drawRow(y, _T("ft_fc_flow_tax", "Tax paid (total)"),
            _money(snap.data, snap.tax.totalTaxesPaid), nil, FT.C.WARNING)
    else
        y = self:drawRow(y, _T("ft_fc_flow_tax", "Tax paid (total)"),
            _T("ft_fc_not_tracked", "Not yet tracked"), nil, FT.C.MUTED)
    end
    if snap.wages and snap.wages.monthAccrued ~= nil then
        y = self:drawRow(y, _T("ft_fc_flow_wages", "Wages (month)"),
            _money(snap.data, snap.wages.monthAccrued), nil, FT.C.WARNING)
    else
        y = self:drawRow(y, _T("ft_fc_flow_wages", "Wages (month)"),
            _T("ft_fc_not_tracked", "Not yet tracked"), nil, FT.C.MUTED)
    end
    y = self:drawRow(y, _T("ft_fc_flow_fuel", "Fuel spend"),
        _T("ft_fc_not_tracked", "Not yet tracked"), nil, FT.C.MUTED)
    y = self:drawRow(y, _T("ft_fc_flow_dairy_income", "Dairy contract income"),
        _T("ft_fc_not_tracked", "Not yet tracked"), nil, FT.C.MUTED)
    y = self:drawRow(y, _T("ft_fc_flow_rwe", "World-event money"),
        _T("ft_fc_not_tracked", "Not yet tracked"), nil, FT.C.MUTED)

    y = y - FT.py(4)
    y = self:drawRule(y, 0.25)
    y = self:drawSection(y, _T("ft_fc_signals", "SIGNALS"))
    if snap.coop then
        y = self:drawRow(y, _T("ft_fc_signal_coop", "Co-Op level"),
            tostring(snap.coop.level), nil, FT.C.TEXT_ACCENT)
        self.r:appText(x, y, FT.FONT.TINY,
            _T("ft_fc_signal_coop_note", "Level only. Quantified savings wait on ProStaff benefit getters."),
            RenderText.ALIGN_LEFT, FT.C.TEXT_DIM)
        y = y - FT.py(14)
    else
        y = self:drawRow(y, _T("ft_fc_signal_coop", "Co-Op level"),
            _T("ft_fc_not_tracked", "Not yet tracked"), nil, FT.C.MUTED)
    end
    if snap.dairy then
        y = self:drawRow(y, _T("ft_fc_signal_dairy", "Dairy barns"),
            tostring(snap.dairy.barnCount), nil, FT.C.TEXT_NORMAL)
    end
    if snap.market then
        y = self:drawRow(y, _T("ft_fc_signal_market", "Market events"),
            tostring(snap.market.activeEvents), nil, FT.C.TEXT_NORMAL)
    end
    if snap.rwe and snap.rwe.event then
        y = self:drawRow(y, _T("ft_fc_signal_rwe", "World event"),
            _rweEventLabel(snap.rwe.event), nil, FT.C.TEXT_ACCENT)
    end

    self:setContentHeight(startY - y + scrollY)
    self:drawScrollBar()
end

-- ── Back handler + drawer ─────────────────────────────────

FarmTabletUI:registerBackHandler(FT.APP.FINANCIAL_COCKPIT, function()
    if _view ~= "home" then
        _view = "home"
        _vitalFocus = nil
        return true
    end
    return false
end)

FarmTabletUI:registerDrawer(FT.APP.FINANCIAL_COCKPIT, function(self)
    local AC = FT.appColor(FT.APP.FINANCIAL_COCKPIT)

    if self:drawHelpPage("_fcHelp", FT.APP.FINANCIAL_COCKPIT,
        _T("ft_ui_app_financial_cockpit", "Financial Cockpit"), AC, {
        { title = _T("ft_fc_help_health_title", "FARM HEALTH"),
          body  = _T("ft_fc_help_health_body",
              "One heart color from the worst vital that has data.\n" ..
              "Green / amber / red. Neutrals and partials never count as healthy.\n" ..
              "Tap the heart to open the vital that set the color.") },
        { title = _T("ft_fc_help_history_title", "HISTORY"),
          body  = _T("ft_fc_help_history_body",
              "This page records a compact monthly row itself.\n" ..
              "Needs Time Guard for the month clock. Host / single-player\n" ..
              "only in v1. Gaps stay gaps.") },
        { title = _T("ft_fc_help_forecast_title", "FORECAST"),
          body  = _T("ft_fc_help_forecast_body",
              "Labeled as a projection. PARTIAL when a flow is missing.\n" ..
              "Missing flows show not yet tracked, never a guess.") },
        { title = _T("ft_fc_help_readonly_title", "READ-ONLY"),
          body  = _T("ft_fc_help_readonly_body",
              "The cockpit never moves money and never re-implements\n" ..
              "Income, Tax, Wages, or other owning apps.") },
    }) then return end

    local snap = _gather(self)
    if _view == "vital" then
        _drawVitalPocket(self, snap, AC)
    elseif _view == "history" then
        _drawHistoryPocket(self, snap, AC)
    elseif _view == "forecast" then
        _drawForecastPocket(self, snap, AC)
    elseif _view == "flows" then
        _drawFlowsPocket(self, snap, AC)
    else
        _drawHome(self, snap, AC)
    end
    self:drawInfoIcon("_fcHelp", AC)
end)
