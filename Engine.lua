local _, ns = ...

local Engine = {}
Engine.__index = Engine
ns.Engine = Engine

-- Depth never exceeds 5, so item and remaining depth pack into one number.
local DEPTH_SLOTS = 8

--- Creates an engine over a recipe index. `auction` and `vendor` return the
--- unit price of an item in copper or nil, `cut` is the auction house fee as
--- a fraction, `depth` is how many crafting steps a chain may have.
function Engine.New(options)
    return setmetatable({
        index = options.index,
        auction = options.auction,
        vendor = options.vendor,
        cut = options.cut,
        depth = options.depth,
        auctionMemo = {},
        costMemo = {},
    }, Engine)
end

--- Auction house price of one unit, or nil.
function Engine:Auction(item)
    local memo = self.auctionMemo
    if memo[item] == nil then
        memo[item] = self.auction(item) or false
    end
    return memo[item] or nil
end

-- A result that hit the loop guard depends on the path that led to it, so it
-- is reported as tainted and kept out of the memo.
local function cheapest(self, item, depthLeft, path)
    local key = item * DEPTH_SLOTS + depthLeft
    local known = self.costMemo[key]
    if known then
        return known, false
    end
    local entry = { item = item, auction = self:Auction(item), vendor = self.vendor(item) }
    if entry.auction and (not entry.vendor or entry.auction <= entry.vendor) then
        entry.cost, entry.source = entry.auction, "auction"
    elseif entry.vendor then
        entry.cost, entry.source = entry.vendor, "vendor"
    end
    if path[item] then
        return entry, true
    end
    local tainted = false
    if depthLeft > 0 then
        path[item] = true
        for _, recipe in ipairs(self.index.byProduct[item] or {}) do
            local total = 0
            for _, reagent in ipairs(recipe.reagents) do
                local part, partTainted = cheapest(self, reagent.item, depthLeft - 1, path)
                tainted = tainted or partTainted
                if not part.cost then
                    total = nil
                    break
                end
                total = total + part.cost * reagent.count
            end
            if total and (not entry.craft or total / recipe.yield < entry.craft) then
                entry.craft, entry.recipe = total / recipe.yield, recipe
            end
        end
        path[item] = nil
        if entry.craft and (not entry.cost or entry.craft < entry.cost) then
            entry.cost, entry.source = entry.craft, "craft"
        end
    end
    if not tainted then
        self.costMemo[key] = entry
    end
    return entry, tainted
end

--- Cheapest way to get one unit of an item: `cost` and its `source`
--- ("auction", "vendor" or "craft"), next to each alternative (`auction`,
--- `vendor`, `craft` with its `recipe`). `cost` is nil when nothing is known.
function Engine:Cost(item)
    return (cheapest(self, item, self.depth, {}))
end

--- Economics of one craft: reagent costs, and for a sellable product the
--- revenue, fee and net profit. `cost` or `profit` is nil when a price is missing.
function Engine:Profit(recipe)
    local result = {
        recipe = recipe,
        reagents = {},
        sellable = recipe.product ~= nil and not self.index.unsellable[recipe.product],
    }
    local cost = 0
    for _, reagent in ipairs(recipe.reagents) do
        local entry = self:Cost(reagent.item)
        table.insert(result.reagents, { item = reagent.item, count = reagent.count, entry = entry })
        cost = cost and entry.cost and cost + entry.cost * reagent.count
    end
    result.cost = cost or nil
    local price = result.sellable and self:Auction(recipe.product)
    if price then
        result.revenue = price * recipe.yield
        result.fee = math.floor(result.revenue * self.cut + 0.5)
        if result.cost then
            result.profit = result.revenue - result.fee - result.cost
        end
    end
    return result
end

local function rank(use)
    if not use.sellable then
        return 3
    end
    return use.profit and 1 or 2
end

local function bestFirst(a, b)
    local rankA, rankB = rank(a), rank(b)
    if rankA ~= rankB then
        return rankA < rankB
    end
    if rankA == 1 and a.profitPerUnit ~= b.profitPerUnit then
        return a.profitPerUnit > b.profitPerUnit
    end
    return a.recipe.id < b.recipe.id
end

--- Every craft that consumes an item, directly or through intermediate
--- products, within the depth limit. Each result is a Profit() table plus
--- `step` (1 for a direct use), `via` (the intermediate item the craft takes,
--- nil for a direct use), `units` (how many of the item one craft consumes
--- through the chain) and `profitPerUnit`. Sorted best first: known profits,
--- then unknown ones, then unsellable crafts.
function Engine:Uses(item)
    local uses, seenRecipes, seenItems = {}, {}, { [item] = true }
    local frontier = { { item = item, unitsEach = 1, step = 0 } }
    local head = 1
    while frontier[head] do
        local node = frontier[head]
        head = head + 1
        for _, recipe in ipairs(self.index.byReagent[node.item] or {}) do
            if not seenRecipes[recipe.id] then
                seenRecipes[recipe.id] = true
                local count = 0
                for _, reagent in ipairs(recipe.reagents) do
                    if reagent.item == node.item then
                        count = count + reagent.count
                    end
                end
                local use = self:Profit(recipe)
                use.step = node.step + 1
                use.via = node.step > 0 and node.item or nil
                use.units = count * node.unitsEach
                use.profitPerUnit = use.profit and use.profit / use.units
                table.insert(uses, use)
                local product = recipe.product
                if product and use.step < self.depth and not seenItems[product] then
                    seenItems[product] = true
                    table.insert(frontier, {
                        item = product,
                        unitsEach = use.units / recipe.yield,
                        step = use.step,
                    })
                end
            end
        end
    end
    table.sort(uses, bestFirst)
    return uses
end

--- What to buy at the auction house for one craft, following the cheapest
--- path: crafted reagents are replaced by their own reagents, vendor goods
--- are left out. Returns { item, count } in the order first needed.
function Engine:Purchases(recipe)
    local purchases, byItem = {}, {}
    local function need(item, count, level)
        local entry = self:Cost(item)
        if entry.source == "craft" and level < self.depth then
            local crafts = math.ceil(count / entry.recipe.yield)
            for _, reagent in ipairs(entry.recipe.reagents) do
                need(reagent.item, reagent.count * crafts, level + 1)
            end
        elseif entry.source ~= "vendor" then
            if not byItem[item] then
                byItem[item] = { item = item, count = 0 }
                table.insert(purchases, byItem[item])
            end
            byItem[item].count = byItem[item].count + count
        end
    end
    for _, reagent in ipairs(recipe.reagents) do
        need(reagent.item, reagent.count, 1)
    end
    return purchases
end
