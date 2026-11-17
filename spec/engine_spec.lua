local helpers = require("spec.helpers")

local MINING, SMITHING, ENCHANTING = 186, 164, 333
local ORE, BAR, BELT, TIN, BRONZE, AXE = 1, 2, 3, 4, 5, 6
local THREAD, TROUSERS, GEM, DUST, BADGE, ARROW = 7, 8, 9, 10, 11, 12
local SMELT, MAKE_BELT, SMELT_BRONZE, MAKE_AXE, SEW, CUT_GEM, GRIND_GEM, ENCHANT, MAKE_BADGE, FLETCH =
    100, 101, 102, 103, 104, 105, 106, 107, 108, 109

describe("engine", function()
    local Recipes, Engine, index, prices

    local function engine(options)
        options = options or {}
        return Engine.New({
            index = index,
            auction = function(item)
                return prices[item]
            end,
            vendor = function(item)
                return index.vendor[item]
            end,
            cut = options.cut or 0.05,
            depth = options.depth or 3,
        })
    end

    local function use(uses, recipe)
        for position, candidate in ipairs(uses) do
            if candidate.recipe.id == recipe then
                return candidate, position
            end
        end
    end

    before_each(function()
        local ns = helpers.newGame():Load("Recipes.lua", "Engine.lua")
        Recipes, Engine = ns.Recipes, ns.Engine
        index = Recipes.Build({
            skills = { [MINING] = "Mining", [SMITHING] = "Blacksmithing", [ENCHANTING] = "Enchanting" },
            recipes = {
                [SMELT] = { MINING, 25, 70, 0, BAR, 1, ORE, 1 },
                [MAKE_BELT] = { SMITHING, 70, 110, 0, BELT, 1, BAR, 6 },
                [SMELT_BRONZE] = { MINING, 65, 115, 0, BRONZE, 2, BAR, 1, TIN, 1 },
                [MAKE_AXE] = { SMITHING, 110, 150, 0, AXE, 1, BRONZE, 4 },
                [SEW] = { SMITHING, 10, 50, 0, TROUSERS, 1, THREAD, 2, BAR, 1 },
                [CUT_GEM] = { MINING, 10, 50, 0, DUST, 1, GEM, 1 },
                [GRIND_GEM] = { MINING, 10, 50, 0, GEM, 1, DUST, 1 },
                [ENCHANT] = { ENCHANTING, 10, 50, 0, 0, 1, DUST, 2 },
                [MAKE_BADGE] = { SMITHING, 10, 50, 0, BADGE, 1, BAR, 2 },
                [FLETCH] = { SMITHING, 10, 50, 0, ARROW, 200, BAR, 1 },
            },
            vendor = { [THREAD] = 10 },
            unsellable = { BADGE },
        })
        prices = { [ORE] = 600, [BAR] = 800, [BELT] = 12000 }
    end)

    describe("cost of an item", function()
        it("is the auction price when nothing is cheaper", function()
            local cost = engine():Cost(ORE)
            assert.are.equal(600, cost.cost)
            assert.are.equal("auction", cost.source)
        end)

        it("is the craft when crafting is cheaper than buying", function()
            local cost = engine():Cost(BAR)
            assert.are.equal(600, cost.cost)
            assert.are.equal("craft", cost.source)
            assert.are.equal(SMELT, cost.recipe.id)
            assert.are.equal(800, cost.auction)
        end)

        it("is the purchase when buying is cheaper than crafting", function()
            prices[BAR] = 500
            local cost = engine():Cost(BAR)
            assert.are.equal(500, cost.cost)
            assert.are.equal("auction", cost.source)
            assert.are.equal(600, cost.craft)
        end)

        it("is the vendor price when the vendor undercuts the auction house", function()
            prices[THREAD] = 50
            local cost = engine():Cost(THREAD)
            assert.are.equal(10, cost.cost)
            assert.are.equal("vendor", cost.source)
            assert.are.equal(50, cost.auction)
        end)

        it("is the auction price when it undercuts the vendor", function()
            prices[THREAD] = 4
            local cost = engine():Cost(THREAD)
            assert.are.equal(4, cost.cost)
            assert.are.equal("auction", cost.source)
            assert.are.equal(10, cost.vendor)
        end)

        it("divides the craft by the recipe yield", function()
            prices[TIN] = 400
            assert.are.equal(500, engine():Cost(BRONZE).cost)
        end)

        it("follows a chain of crafts", function()
            prices[TIN] = 400
            local cost = engine():Cost(AXE)
            assert.are.equal(2000, cost.cost)
            assert.are.equal("craft", cost.source)
        end)

        it("stops crafting at the depth limit", function()
            prices[TIN] = 400
            prices[BAR] = nil
            assert.are.equal(2000, engine({ depth = 3 }):Cost(AXE).cost)
            assert.is_nil(engine({ depth = 2 }):Cost(AXE).cost)
        end)

        it("is unknown when no price and no recipe lead to it", function()
            local cost = engine():Cost(TIN)
            assert.is_nil(cost.cost)
            assert.is_nil(cost.source)
        end)

        it("does not loop on recipes that feed each other", function()
            prices[GEM] = 900
            local cost = engine({ depth = 5 }):Cost(DUST)
            assert.are.equal(900, cost.cost)
            assert.are.equal("craft", cost.source)
        end)

        it("gives the same answer whichever item of a loop is asked first", function()
            prices[GEM], prices[DUST] = 900, 700
            local first = engine({ depth = 5 })
            first:Cost(GEM)
            assert.are.equal(700, first:Cost(DUST).cost)
            assert.are.equal(700, engine({ depth = 5 }):Cost(GEM).cost)
        end)
    end)

    describe("profit of a recipe", function()
        it("matches the belt example of the spec", function()
            local profit = engine():Profit(index.byId[MAKE_BELT])
            assert.are.equal(12000, profit.revenue)
            assert.are.equal(600, profit.fee)
            assert.are.equal(3600, profit.cost)
            assert.are.equal(7800, profit.profit)
            assert.is_true(profit.sellable)
        end)

        it("lists each reagent with its cheapest source", function()
            local profit = engine():Profit(index.byId[MAKE_BELT])
            assert.are.equal(1, #profit.reagents)
            assert.are.equal(BAR, profit.reagents[1].item)
            assert.are.equal(6, profit.reagents[1].count)
            assert.are.equal("craft", profit.reagents[1].entry.source)
        end)

        it("applies the configured fee", function()
            local profit = engine({ cut = 0.15 }):Profit(index.byId[MAKE_BELT])
            assert.are.equal(1800, profit.fee)
            assert.are.equal(6600, profit.profit)
        end)

        it("multiplies the revenue by the yield", function()
            prices[ARROW] = 5
            local profit = engine():Profit(index.byId[FLETCH])
            assert.are.equal(1000, profit.revenue)
            assert.are.equal(350, profit.profit)
        end)

        it("can be negative", function()
            prices[BELT] = 1000
            assert.are.equal(-2650, engine():Profit(index.byId[MAKE_BELT]).profit)
        end)

        it("is unknown when the product has no price", function()
            prices[BELT] = nil
            local profit = engine():Profit(index.byId[MAKE_BELT])
            assert.is_nil(profit.profit)
            assert.is_nil(profit.revenue)
            assert.are.equal(3600, profit.cost)
        end)

        it("is unknown when a reagent has no price", function()
            prices[BRONZE] = 5000
            local profit = engine():Profit(index.byId[SMELT_BRONZE])
            assert.is_nil(profit.cost)
            assert.is_nil(profit.profit)
            assert.are.equal(10000, profit.revenue)
        end)

        it("has a cost but no profit for a soulbound product", function()
            prices[BADGE] = 99999
            local profit = engine():Profit(index.byId[MAKE_BADGE])
            assert.is_false(profit.sellable)
            assert.are.equal(1200, profit.cost)
            assert.is_nil(profit.profit)
        end)

        it("has a cost but no profit for a recipe without a product", function()
            prices[DUST] = 300
            local profit = engine():Profit(index.byId[ENCHANT])
            assert.is_false(profit.sellable)
            assert.are.equal(600, profit.cost)
            assert.is_nil(profit.profit)
        end)
    end)

    describe("purchases for a craft", function()
        local function bought(recipe, options)
            local out = {}
            for _, purchase in ipairs(engine(options):Purchases(index.byId[recipe])) do
                table.insert(out, purchase.item .. "x" .. purchase.count)
            end
            return out
        end

        it("replace a crafted reagent by what it is made of", function()
            assert.are.same({ ORE .. "x6" }, bought(MAKE_BELT))
        end)

        it("buy the reagent itself when buying is cheaper", function()
            prices[BAR] = 500
            assert.are.same({ BAR .. "x6" }, bought(MAKE_BELT))
        end)

        it("leave vendor goods out", function()
            assert.are.same({ ORE .. "x1" }, bought(SEW))
        end)

        it("round crafts up to whole yields and add up shared materials", function()
            prices[TIN] = 400
            assert.are.same({ ORE .. "x2", TIN .. "x2" }, bought(MAKE_AXE))
        end)

        it("include reagents without a price, to look them up", function()
            assert.are.same({ ORE .. "x1", TIN .. "x1" }, bought(SMELT_BRONZE))
        end)

        it("stop descending at the depth limit", function()
            prices[TIN] = 400
            assert.are.same({ BRONZE .. "x4" }, bought(MAKE_AXE, { depth = 1 }))
        end)
    end)

    describe("uses of an item", function()
        it("ranks by profit per unit of the item, not per craft", function()
            prices[TROUSERS] = 3000
            local uses = engine():Uses(BAR)
            local belt, beltPosition = use(uses, MAKE_BELT)
            local trousers, trousersPosition = use(uses, SEW)
            assert.are.equal(7800, belt.profit)
            assert.are.equal(1300, belt.profitPerUnit)
            assert.are.equal(2230, trousers.profit)
            assert.are.equal(2230, trousers.profitPerUnit)
            assert.is_true(trousersPosition < beltPosition)
        end)

        it("follows the item through intermediate products", function()
            local uses = engine():Uses(ORE)
            local smelt = use(uses, SMELT)
            assert.are.equal(1, smelt.step)
            assert.is_nil(smelt.via)
            local belt = use(uses, MAKE_BELT)
            assert.are.equal(2, belt.step)
            assert.are.equal(BAR, belt.via)
            assert.are.equal(6, belt.units)
            assert.are.equal(1300, belt.profitPerUnit)
        end)

        it("counts units through yields", function()
            local axe = use(engine():Uses(ORE), MAKE_AXE)
            assert.are.equal(3, axe.step)
            assert.are.equal(BRONZE, axe.via)
            assert.are.equal(2, axe.units)
        end)

        it("stops at the depth limit", function()
            local uses = engine({ depth = 2 }):Uses(ORE)
            assert.is_truthy(use(uses, MAKE_BELT))
            assert.is_nil(use(uses, MAKE_AXE))
            assert.are.equal(1, #engine({ depth = 1 }):Uses(ORE))
        end)

        it("lists each recipe once, at its shortest path, in a loop", function()
            local uses = engine({ depth = 5 }):Uses(GEM)
            assert.are.equal(3, #uses)
            assert.are.equal(1, use(uses, CUT_GEM).step)
            assert.are.equal(2, use(uses, GRIND_GEM).step)
            assert.are.equal(2, use(uses, ENCHANT).step)
        end)

        it("puts unknown profits after known ones and unsellable crafts last", function()
            prices[TROUSERS], prices[ARROW] = 3000, 5
            local uses = engine():Uses(BAR)
            local ids = {}
            for _, candidate in ipairs(uses) do
                table.insert(ids, candidate.recipe.id)
            end
            assert.are.same({ SEW, MAKE_BELT, FLETCH, SMELT_BRONZE, MAKE_AXE, MAKE_BADGE }, ids)
        end)

        it("is empty for an item nothing uses", function()
            assert.are.same({}, engine():Uses(BELT))
        end)
    end)
end)
