local _, ns = ...

-- Owns the engine the views share, so a hover and the window agree, and
-- rebuilds it when its inputs change.
local Analysis = {}
ns.Analysis = Analysis

-- Price add-ons give no change event; a short lifetime keeps prices fresh.
local ENGINE_LIFETIME_SECONDS = 60

--- How reagent costs are worked out: "mine" crafts a reagent only with a
--- recipe one of the player's characters knows, "buy" never crafts, "all"
--- crafts with any recipe.
Analysis.MODES = { "mine", "buy", "all" }

local index, engines, builtAt, usesByMode, knownRecipes

--- The recipe index, built on first use.
function Analysis.Index()
    index = index or ns.Recipes.Build(ns.RecipeData)
    return index
end

local function never()
    return false
end

local function rebuild(now)
    local settings = ns.db.settings
    knownRecipes = {}
    for _, character in pairs(ns.db.chars) do
        for recipe in pairs(character.recipes) do
            knownRecipes[recipe] = true
        end
    end
    -- One memo for the three engines: they ask for the same prices.
    local prices = {}
    local function auction(item)
        if prices[item] == nil then
            prices[item] = ns.Prices.Auction(item) or false
        end
        return prices[item] or nil
    end
    local allowCraft = {
        mine = function(recipe)
            return knownRecipes[recipe.id] == true
        end,
        buy = never,
    }
    engines, usesByMode = {}, {}
    for _, mode in ipairs(Analysis.MODES) do
        engines[mode] = ns.Engine.New({
            index = Analysis.Index(),
            auction = auction,
            vendor = ns.Prices.Vendor,
            cut = settings.cut / 100,
            depth = settings.depth,
            allowCraft = allowCraft[mode],
        })
        usesByMode[mode] = {}
    end
    builtAt = now
end

--- The shared engine for a cost mode (the configured one when nil), rebuilt
--- after a settings, price or learned-recipe change.
function Analysis.Engine(mode)
    local now = GetTime()
    if not engines or now - builtAt > ENGINE_LIFETIME_SECONDS then
        rebuild(now)
    end
    return engines[mode or ns.db.settings.costMode]
end

--- Ranked uses of an item in a cost mode, computed once per engine.
function Analysis.Uses(item, mode)
    mode = mode or ns.db.settings.costMode
    local current = Analysis.Engine(mode)
    local uses = usesByMode[mode]
    uses[item] = uses[item] or current:Uses(item)
    return uses[item]
end

--- Whether one of the player's characters knows a recipe.
function Analysis.KnownByAnyone(recipe)
    Analysis.Engine()
    return knownRecipes[recipe] == true
end

local function reset()
    engines = nil
    ns:Fire("ANALYSIS_CHANGED")
end

ns:OnMessage("SETTINGS_CHANGED", reset)
ns:OnMessage("PRICES_CHANGED", reset)
ns:OnMessage("LEARNED_CHANGED", reset)
