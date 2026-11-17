local _, ns = ...

-- Owns the engine the views share, so a hover and the window agree, and
-- rebuilds it when its inputs change.
local Analysis = {}
ns.Analysis = Analysis

-- Price add-ons give no change event; a short lifetime keeps prices fresh.
local ENGINE_LIFETIME_SECONDS = 60

local index, engine, builtAt, usesByItem

--- The recipe index, built on first use.
function Analysis.Index()
    index = index or ns.Recipes.Build(ns.RecipeData)
    return index
end

--- The shared engine, rebuilt after a settings or price change.
function Analysis.Engine()
    local now = GetTime()
    if not engine or now - builtAt > ENGINE_LIFETIME_SECONDS then
        local settings = ns.db.settings
        engine = ns.Engine.New({
            index = Analysis.Index(),
            auction = function(item)
                return (ns.Prices.Auction(item))
            end,
            vendor = ns.Prices.Vendor,
            cut = settings.cut / 100,
            depth = settings.depth,
        })
        builtAt, usesByItem = now, {}
    end
    return engine
end

--- Ranked uses of an item, computed once per engine.
function Analysis.Uses(item)
    local current = Analysis.Engine()
    usesByItem[item] = usesByItem[item] or current:Uses(item)
    return usesByItem[item]
end

local function reset()
    engine = nil
    ns:Fire("ANALYSIS_CHANGED")
end

ns:OnMessage("SETTINGS_CHANGED", reset)
ns:OnMessage("PRICES_CHANGED", reset)
