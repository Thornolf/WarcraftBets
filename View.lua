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

local function colorize(text, color)
    return ("|cff%02x%02x%02x%s|r"):format(color[1] * 255, color[2] * 255, color[3] * 255, text)
end

-- "buy 24s · craft 18s" for a reagent that can be crafted: the option the
-- current mode uses is white, the other grey, and "craft" is green or red
-- depending on whether one of the player's characters knows the recipe.
local function reagentChoice(reagent, anyRecipe)
    local L, Money = ns.L, ns.Money
    local chosen = reagent.entry
    local buy = math.min(anyRecipe.auction or math.huge, anyRecipe.vendor or math.huge)
    local known = ns.Analysis.KnownByAnyone(anyRecipe.recipe.id)
    local crafted = chosen.source == "craft"
    local parts = {}
    if buy < math.huge then
        local text = L.CHOICE_BUY .. " " .. Money.Format(buy * reagent.count)
        table.insert(parts, colorize(text, crafted and GREY or WHITE))
    end
    local craft = colorize(L.CHOICE_CRAFT, known and STATE_GOOD or STATE_BAD)
    local amount = colorize(Money.Format(anyRecipe.craft * reagent.count), crafted and WHITE or GREY)
    table.insert(parts, craft .. " " .. amount)
    return table.concat(parts, colorize("  ·  ", GREY))
end

local function salesBlock(product)
    local stats = product and ns.Prices.SaleStats(product)
    if not stats then
        return nil
    end
    local L = ns.L
    local perDay = ("%.1f"):format(stats.perDay):gsub("%.", L.DECIMAL_SEPARATOR)
    local percent = math.floor(stats.rate * 100 + 0.5)
    return {
        { label = L.SALES_VOLUME, value = L.SALES_VOLUME_VALUE:format(perDay, percent) },
        { label = L.SALES_AVERAGE, value = costText(stats.average) },
        { label = L.SALES_CHEAPEST, value = costText(stats.cheapest) },
    }
end

--- Everything the detail panel shows for one craft of the studied item:
--- identity, how it sells, the profit in each cost mode side by side, and
--- its reagents with the buy and craft prices.
function View.Detail(use, item)
    local L, Money, Analysis = ns.L, ns.Money, ns.Analysis
    local recipe = use.recipe
    local status = ns.Learned.Status(recipe)
    local profession = ns.Learned.ProfessionName(recipe.skill)
    local detail = {
        name = View.RecipeName(recipe),
        known = status.known,
        sales = salesBlock(use.sellable and recipe.product),
        modes = {},
        activeMode = ns.db.settings.costMode,
        reagents = {},
        economics = {},
    }
    if recipe.learnAt then
        detail.skill = L.DETAIL_SKILL_REQUIRED:format(profession, recipe.learnAt)
    else
        detail.skill = L.DETAIL_SKILL_YELLOW:format(profession, recipe.yellowAt)
    end
    detail.state, detail.stateColor = stateText(status)

    local anyRecipeEngine = Analysis.Engine("all")
    for _, reagent in ipairs(use.reagents) do
        local entry = reagent.entry
        local anyRecipe = anyRecipeEngine:Cost(reagent.item)
        local alternatives = {}
        for _, origin in ipairs({ "auction", "vendor", "craft" }) do
            if anyRecipe[origin] then
                local total = Money.Format(anyRecipe[origin] * reagent.count)
                table.insert(alternatives, line(L["ORIGIN_" .. origin], total, WHITE, WHITE))
            end
        end
        local row = {
            item = reagent.item,
            label = L.REAGENT_COUNT:format(ns.Compat.ItemName(reagent.item) or L.LOADING, reagent.count),
            alternatives = alternatives,
        }
        if anyRecipe.craft then
            row.cost = reagentChoice(reagent, anyRecipe)
        else
            row.cost = costText(entry.cost and entry.cost * reagent.count)
            row.origin = entry.source and L["ORIGIN_" .. entry.source] or nil
        end
        table.insert(detail.reagents, row)
    end

    local byMode = {}
    for position, mode in ipairs(Analysis.MODES) do
        detail.modes[position] = L["MODE_" .. mode]
        byMode[position] = Analysis.Engine(mode):Profit(recipe)
    end
    local function add(label, read, strong)
        local row = { label = label, values = {}, colors = {}, strong = strong }
        for position, economics in ipairs(byMode) do
            row.values[position], row.colors[position] = read(economics)
            row.colors[position] = row.colors[position] or WHITE
        end
        table.insert(detail.economics, row)
    end
    if use.sellable then
        local sale = recipe.yield > 1 and L.SALE_PRICE_YIELD:format(recipe.yield) or L.SALE_PRICE
        add(sale, function(economics)
            return costText(economics.revenue)
        end)
        add(L.AUCTION_FEE:format(ns.db.settings.cut), function(economics)
            return economics.fee and Money.Format(-economics.fee) or L.UNKNOWN_PRICE
        end)
        add(L.REAGENT_COST, function(economics)
            return economics.cost and Money.Format(-economics.cost) or L.UNKNOWN_PRICE
        end)
        add(L.PROFIT_PER_CRAFT, function(economics)
            return View.ProfitText(economics.profit)
        end, true)
        add(L.NET_PER_UNIT:format(ns.Compat.ItemName(item) or L.LOADING), function(economics)
            return View.ProfitText(economics.profit and economics.profit / use.units)
        end)
    else
        add(L.NOT_SELLABLE, function()
            return "", GREY
        end)
        add(L.REAGENT_COST, function(economics)
            return costText(economics.cost)
        end)
    end
    return detail
end

--- Name of the TSM price in use: market value, minimum buyout or a custom formula.
function View.FormulaLabel()
    local preset = ns.Prices.FormulaPreset()
    return preset and ns.L["FORMULA_" .. preset] or ns.L.FORMULA_CUSTOM
end

local function sourceName(source)
    local name = ns.L["SOURCE_" .. source]
    if source == "tsm" then
        return ns.L.SOURCE_TSM_PRICE:format(name, View.FormulaLabel())
    end
    return name
end

--- One sentence on where auction prices come from, for the detail panel.
function View.PriceSourceText()
    local L, Prices = ns.L, ns.Prices
    local setting = ns.db.settings.priceSource
    if setting ~= "auto" then
        if Prices.IsAvailable(setting) then
            return sourceName(setting)
        end
        return L.SOURCE_MISSING:format(L["SOURCE_" .. setting])
    end
    local available = {}
    for _, source in ipairs({ "tsm", "auctionator" }) do
        if Prices.IsAvailable(source) then
            table.insert(available, sourceName(source))
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

--- Rows of the favourites tab for followed items: each with its best
--- sellable craft and that craft's profit per unit of the item.
function View.FavoriteItemRows()
    local L = ns.L
    local rows = {}
    for _, favorite in ipairs(ns.Favorites.Items()) do
        local row = { item = favorite.item, name = ns.Compat.ItemName(favorite.item) or L.LOADING }
        for _, use in ipairs(ns.Analysis.Uses(favorite.item)) do
            if use.sellable then
                row.detail = View.RecipeName(use.recipe)
                row.profit, row.profitColor = View.ProfitText(use.profitPerUnit)
                break
            end
        end
        row.detail = row.detail or L.NO_USES
        table.insert(rows, row)
    end
    return rows
end

--- Rows of the favourites tab for followed crafts, with the profit per craft.
function View.FavoriteCraftRows()
    local rows = {}
    local index = ns.Analysis.Index()
    for _, favorite in ipairs(ns.Favorites.Crafts()) do
        local recipe = index.byId[favorite.recipe]
        -- A recipe can disappear from the data between game patches.
        if recipe then
            local economics = ns.Analysis.Engine():Profit(recipe)
            local row = {
                recipe = favorite.recipe,
                item = favorite.item,
                product = recipe.product,
                name = View.RecipeName(recipe),
                detail = ns.Learned.ProfessionName(recipe.skill),
            }
            if economics.sellable then
                row.profit, row.profitColor = View.ProfitText(economics.profit)
            else
                row.profit, row.profitColor = ns.L.NOT_SELLABLE, GREY
            end
            table.insert(rows, row)
        end
    end
    return rows
end
