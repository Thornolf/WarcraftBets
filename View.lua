local _, ns = ...

-- Turns engine results into the lines the tooltip shows, without touching a frame.
local View = {}
ns.View = View

local WHITE = { 1, 1, 1 }
local GREY = { 0.62, 0.62, 0.62 }
local UNLEARNED = { 0.5, 0.5, 0.5 }
local TITLE = { 1, 0.82, 0 }
local GAIN = { 0.12, 1, 0 }
local LOSS = { 1, 0.3, 0.3 }

View.colors = { white = WHITE, grey = GREY, unlearned = UNLEARNED, title = TITLE, gain = GAIN, loss = LOSS }

--- Name of what a recipe makes: its product, or the spell for an enchant.
function View.RecipeName(recipe)
    local name
    if recipe.product then
        name = ns.Compat.ItemName(recipe.product)
    else
        name = ns.Compat.SpellName(recipe.id)
    end
    return name or ns.L.LOADING
end

--- Text and colour of a profit: signed coins in green or red, "?" when unknown.
function View.ProfitText(profit)
    if not profit then
        return ns.L.UNKNOWN_PRICE, GREY
    end
    return ns.Money.Signed(profit), profit < 0 and LOSS or GAIN
end

-- A transformation turns the item alone into another crafting material
-- (ore into bars, cloth into bolts), as opposed to a finished product.
local function isTransformation(use)
    local recipe = use.recipe
    return use.step == 1
        and #recipe.reagents == 1
        and use.revenue ~= nil
        and ns.Analysis.Index().byReagent[recipe.product] ~= nil
end

--- The WarcraftBets block of an item tooltip, as a list of
--- { left, right, leftColor, rightColor }, or nil when there is nothing to say.
--- `expanded` is true while Shift is held.
function View.TooltipLines(item, expanded)
    local L, Money = ns.L, ns.Money
    local settings = ns.db.settings
    local lines = {}
    local function add(left, right, leftColor, rightColor)
        table.insert(lines, { left = left, right = right, leftColor = leftColor, rightColor = rightColor })
    end

    local price, source = ns.Prices.Auction(item)
    if price then
        add(L.TT_RAW:format(L["SOURCE_" .. source]), Money.Format(price), WHITE, WHITE)
    end

    local uses = ns.Analysis.Uses(item)
    local crafts = {}
    for _, use in ipairs(uses) do
        if isTransformation(use) then
            local label = L.TT_TRANSFORMED:format(View.RecipeName(use.recipe))
            add(label, Money.Format(use.revenue / use.units), WHITE, WHITE)
        end
        if use.sellable then
            table.insert(crafts, use)
        end
    end

    local cost = ns.Analysis.Engine():Cost(item)
    if cost.craft then
        add(L.TT_CRAFT_COST, Money.Format(cost.craft), WHITE, WHITE)
    end

    if #crafts > 0 then
        add(L.TT_HEADER, L.PER_UNIT, TITLE, GREY)
        local shown = math.min(#crafts, expanded and settings.tooltipShiftCount or settings.tooltipCount)
        for position = 1, shown do
            local use = crafts[position]
            local known = ns.Learned.Status(use.recipe).known
            local text, color = View.ProfitText(use.profitPerUnit)
            add(View.RecipeName(use.recipe), text, known and WHITE or UNLEARNED, color)
        end
        if #crafts > shown then
            add((expanded and L.TT_MORE_COMMAND or L.TT_MORE_SHIFT):format(#crafts - shown), nil, GREY)
        end
    end

    return #lines > 0 and lines or nil
end
