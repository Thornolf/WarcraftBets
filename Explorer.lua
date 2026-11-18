local _, ns = ...

-- Ranks the crafts of the whole game by profit, keeping only those that
-- really sell. The scan is spread over frames: it prices thousands of
-- recipes, too many for one frame.
local Explorer = {}
ns.Explorer = Explorer

local RECIPES_PER_FRAME = 25

local state
local generation = 0

local function emptyState()
    return {
        results = {},
        done = 0,
        total = 0,
        discarded = { slow = 0, unpriced = 0, loss = 0 },
        running = false,
        stale = true,
    }
end

state = emptyState()

-- Why a recipe is left out ("slow", "unpriced", "loss", or "unsellable"
-- which is not counted), or its ranking entry.
local function evaluate(recipe, engine, settings)
    local product = recipe.product
    if not product or engine.index.unsellable[product] then
        return "unsellable"
    end
    local stats = ns.Prices.SaleStats(product)
    if not stats then
        return "unpriced"
    end
    if stats.perDay < settings.explorerMinPerDay or stats.rate * 100 < settings.explorerMinRate then
        return "slow"
    end
    -- An item is worth what buyers really paid, capped by what it is listed
    -- for now: neither a dream asking price nor a stale average.
    local price = math.min(stats.average or math.huge, engine:Auction(product) or math.huge)
    local cost = engine:Profit(recipe).cost
    if price == math.huge or not cost then
        return "unpriced"
    end
    local revenue = price * recipe.yield
    local profit = revenue - math.floor(revenue * engine.cut + 0.5) - cost
    if profit <= 0 then
        return "loss"
    end
    return nil, {
        recipe = recipe,
        price = price,
        profit = profit,
        perDay = stats.perDay,
        rate = stats.rate,
        profitPerDay = profit * stats.perDay / recipe.yield,
    }
end

local function step(candidates, scan)
    if scan ~= generation then
        return
    end
    local settings = ns.db.settings
    local engine = ns.Analysis.Engine()
    for position = state.done + 1, math.min(state.done + RECIPES_PER_FRAME, state.total) do
        local reason, entry = evaluate(candidates[position], engine, settings)
        if entry then
            table.insert(state.results, entry)
        elseif state.discarded[reason] then
            state.discarded[reason] = state.discarded[reason] + 1
        end
        state.done = position
    end
    if state.done < state.total then
        C_Timer.After(0, function()
            step(candidates, scan)
        end)
    else
        state.running = false
    end
    ns:Fire("EXPLORER_CHANGED")
end

--- Starts a scan with the current settings, dropping any scan in progress.
function Explorer.Scan()
    generation = generation + 1
    state = emptyState()
    state.stale = false
    if not ns.Prices.IsAvailable("tsm") then
        state.unavailable = true
        ns:Fire("EXPLORER_CHANGED")
        return
    end
    local filter = ns.db.settings.explorerFilter
    local candidates = {}
    for _, recipe in pairs(ns.Analysis.Index().byId) do
        if ns.View.PassesFilter(ns.Learned.Status(recipe), filter) then
            table.insert(candidates, recipe)
        end
    end
    table.sort(candidates, function(a, b)
        return a.id < b.id
    end)
    state.total, state.running = #candidates, #candidates > 0
    local scan = generation
    C_Timer.After(0, function()
        step(candidates, scan)
    end)
    ns:Fire("EXPLORER_CHANGED")
end

--- Scans again if prices, settings or learned recipes changed since the last scan.
function Explorer.EnsureFresh()
    if state.stale then
        Explorer.Scan()
    end
end

--- The scan so far: `results`, `done` and `total` recipes, `discarded` counts
--- by reason, `running`, and `unavailable` when TSM is not loaded.
function Explorer.State()
    return state
end

--- Results so far, best first by `key`: "profit" or "profitPerDay".
function Explorer.Sorted(key)
    local sorted = {}
    for position, entry in ipairs(state.results) do
        sorted[position] = entry
    end
    table.sort(sorted, function(a, b)
        if a[key] ~= b[key] then
            return a[key] > b[key]
        end
        return a.recipe.id < b.recipe.id
    end)
    return sorted
end

ns:OnMessage("ANALYSIS_CHANGED", function()
    generation = generation + 1
    state.stale, state.running = true, false
    ns:Fire("EXPLORER_CHANGED")
end)
