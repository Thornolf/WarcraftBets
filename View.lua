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

local function line(left, right, leftColor, rightColor)
    return { left = left, right = right, leftColor = leftColor, rightColor = rightColor }
end

--- What an item is worth as it is: auction price with its source, value once
--- transformed, and crafting cost. Shared by the tooltip and the window header.
function View.PriceLines(item)
    local L, Money = ns.L, ns.Money
    local lines = {}
    local price, source = ns.Prices.Auction(item)
    if price then
        table.insert(lines, line(L.TT_RAW:format(L["SOURCE_" .. source]), Money.Format(price), WHITE, WHITE))
    end
    for _, use in ipairs(ns.Analysis.Uses(item)) do
        if isTransformation(use) then
            local label = L.TT_TRANSFORMED:format(View.RecipeName(use.recipe))
            table.insert(lines, line(label, Money.Format(use.revenue / use.units), WHITE, WHITE))
        end
    end
    local cost = ns.Analysis.Engine():Cost(item)
    if cost.craft then
        table.insert(lines, line(L.TT_CRAFT_COST, Money.Format(cost.craft), WHITE, WHITE))
    end
    return lines
end

--- The WarcraftBets block of an item tooltip, as a list of
--- { left, right, leftColor, rightColor }, or nil when there is nothing to say.
--- `expanded` is true while Shift is held.
function View.TooltipLines(item, expanded)
    local L = ns.L
    local settings = ns.db.settings
    local lines = View.PriceLines(item)
    local crafts = {}
    for _, use in ipairs(ns.Analysis.Uses(item)) do
        if use.sellable then
            table.insert(crafts, use)
        end
    end
    if #crafts > 0 then
        table.insert(lines, line(L.TT_HEADER, L.PER_UNIT, TITLE, GREY))
        local shown = math.min(#crafts, expanded and settings.tooltipShiftCount or settings.tooltipCount)
        for position = 1, shown do
            local use = crafts[position]
            local known = ns.Learned.Status(use.recipe).known
            local text, color = View.ProfitText(use.profitPerUnit)
            table.insert(lines, line(View.RecipeName(use.recipe), text, known and WHITE or UNLEARNED, color))
        end
        if #crafts > shown then
            local more = (expanded and L.TT_MORE_COMMAND or L.TT_MORE_SHIFT):format(#crafts - shown)
            table.insert(lines, line(more, nil, GREY))
        end
    end
    return #lines > 0 and lines or nil
end

--- Filters of the craft list, in the order the filter button cycles them.
View.FILTERS = { "all", "known", "alt", "unknown", "learnable" }

local function passesFilter(status, filter)
    if filter == "known" then
        return status.known
    elseif filter == "alt" then
        return not status.known and #status.alts > 0
    elseif filter == "unknown" then
        return not status.known and #status.alts == 0
    elseif filter == "learnable" then
        return status.learnable
    end
    return true
end

local DIRECT_GROUP, UNSELLABLE_GROUP = 0, math.huge

--- Rows of the craft list for an item: a header per group, then its crafts
--- best first. Groups are direct uses, one per intermediate item, and
--- unsellable crafts last. `search` matches the craft name, `filter` is one
--- of View.FILTERS.
function View.ListRows(item, search, filter)
    local L = ns.L
    local needle = search and search ~= "" and search:lower() or nil
    local groups, ordered = {}, {}
    for _, use in ipairs(ns.Analysis.Uses(item)) do
        local name = View.RecipeName(use.recipe)
        local status = ns.Learned.Status(use.recipe)
        if passesFilter(status, filter) and (not needle or name:lower():find(needle, 1, true)) then
            local key = not use.sellable and "unsellable" or use.via or "direct"
            local group = groups[key]
            if not group then
                group = { rows = {} }
                if key == "direct" then
                    group.order, group.title = DIRECT_GROUP, L.GROUP_DIRECT
                elseif key == "unsellable" then
                    group.order, group.title = UNSELLABLE_GROUP, L.GROUP_UNSELLABLE
                else
                    -- Uses come best first, so intermediates are ordered by their best craft.
                    group.order = #ordered + 1
                    group.title = L.GROUP_VIA:format(ns.Compat.ItemName(key) or L.LOADING)
                end
                groups[key] = group
                table.insert(ordered, group)
            end
            table.insert(group.rows, { use = use, name = name, status = status })
        end
    end
    table.sort(ordered, function(a, b)
        return a.order < b.order
    end)
    local rows = {}
    for _, group in ipairs(ordered) do
        table.insert(rows, { header = group.title })
        for _, row in ipairs(group.rows) do
            table.insert(rows, row)
        end
    end
    return rows
end

local STATE_GOOD = { 0.12, 1, 0 }
local STATE_BAD = { 1, 0.3, 0.3 }

local function stateText(status)
    local L = ns.L
    if status.known then
        return L.STATE_KNOWN, STATE_GOOD
    end
    local parts = {}
    if #status.alts > 0 then
        table.insert(parts, L.STATE_ALT:format(table.concat(status.alts, ", ")))
    end
    if status.learnable then
        table.insert(parts, L.STATE_LEARNABLE)
    end
    if #parts == 0 then
        return L.STATE_UNKNOWN, STATE_BAD
    end
    return table.concat(parts, " · "), TITLE
end

local function costText(amount)
    return amount and ns.Money.Format(amount) or ns.L.UNKNOWN_PRICE
end

--- Everything the detail panel shows for one craft of the studied item.
function View.Detail(use, item)
    local L, Money = ns.L, ns.Money
    local recipe = use.recipe
    local status = ns.Learned.Status(recipe)
    local profession = ns.Learned.ProfessionName(recipe.skill)
    local detail = {
        name = View.RecipeName(recipe),
        known = status.known,
        reagents = {},
        economics = {},
    }
    if recipe.learnAt then
        detail.skill = L.DETAIL_SKILL_REQUIRED:format(profession, recipe.learnAt)
    else
        detail.skill = L.DETAIL_SKILL_YELLOW:format(profession, recipe.yellowAt)
    end
    detail.state, detail.stateColor = stateText(status)

    for _, reagent in ipairs(use.reagents) do
        local entry = reagent.entry
        local alternatives = {}
        for _, origin in ipairs({ "auction", "vendor", "craft" }) do
            if entry[origin] then
                local total = Money.Format(entry[origin] * reagent.count)
                table.insert(alternatives, line(L["ORIGIN_" .. origin], total, WHITE, WHITE))
            end
        end
        table.insert(detail.reagents, {
            item = reagent.item,
            label = L.REAGENT_COUNT:format(ns.Compat.ItemName(reagent.item) or L.LOADING, reagent.count),
            cost = costText(entry.cost and entry.cost * reagent.count),
            origin = entry.source and L["ORIGIN_" .. entry.source] or nil,
            alternatives = alternatives,
        })
    end

    local function add(label, value, color, strong)
        local row = { label = label, value = value, color = color or WHITE, strong = strong }
        table.insert(detail.economics, row)
    end
    if use.sellable then
        local sale = recipe.yield > 1 and L.SALE_PRICE_YIELD:format(recipe.yield) or L.SALE_PRICE
        add(sale, costText(use.revenue))
        add(L.AUCTION_FEE:format(ns.db.settings.cut), use.fee and Money.Format(-use.fee) or L.UNKNOWN_PRICE)
        add(L.REAGENT_COST, use.cost and Money.Format(-use.cost) or L.UNKNOWN_PRICE)
        local text, color = View.ProfitText(use.profit)
        add(L.NET_PROFIT, text, color, true)
        text, color = View.ProfitText(use.profitPerUnit)
        add(L.NET_PER_UNIT:format(ns.Compat.ItemName(item) or L.LOADING), text, color)
    else
        add(L.NOT_SELLABLE, "", GREY)
        add(L.REAGENT_COST, costText(use.cost))
    end
    return detail
end

--- One sentence on where auction prices come from, for the detail panel.
function View.PriceSourceText()
    local L, Prices = ns.L, ns.Prices
    local setting = ns.db.settings.priceSource
    if setting ~= "auto" then
        local name = L["SOURCE_" .. setting]
        return Prices.IsAvailable(setting) and name or L.SOURCE_MISSING:format(name)
    end
    local available = {}
    for _, source in ipairs({ "tsm", "auctionator" }) do
        if Prices.IsAvailable(source) then
            table.insert(available, L["SOURCE_" .. source])
        end
    end
    if #available == 0 then
        return L.NO_PRICE_SOURCE
    end
    return table.concat(available, L.SOURCE_THEN)
end

--- One chat line for a craft: its link, then cost, sale price and profit in
--- plain text, since chat cannot show coin icons.
function View.ChatText(use)
    local L, Money = ns.L, ns.Money
    local recipe = use.recipe
    local subject = recipe.product and ns.Compat.ItemLink(recipe.product) or View.RecipeName(recipe)
    local function amount(copper)
        return copper and Money.Text(copper) or L.UNKNOWN_PRICE
    end
    if not use.sellable then
        return L.CHAT_COST_ONLY:format(subject, amount(use.cost))
    end
    return L.CHAT_PROFIT:format(subject, amount(use.cost), amount(use.revenue), amount(use.profit))
end
