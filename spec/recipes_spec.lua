local helpers = require("spec.helpers")

local COPPER_ORE, COPPER_BAR, BRONZE_BAR, TIN_BAR = 2770, 2840, 2841, 3576
local SMELT_COPPER, SMELT_BRONZE = 2657, 2659
local COARSE_THREAD = 2320

describe("recipe data", function()
    local data, index

    setup(function()
        local ns = helpers.newGame():Load("Data/Recipes.lua", "Recipes.lua")
        data = ns.RecipeData
        index = ns.Recipes.Build(data)
    end)

    it("smelts one copper ore into one copper bar", function()
        local recipe = index.byId[SMELT_COPPER]
        assert.are.equal(COPPER_BAR, recipe.product)
        assert.are.equal(1, recipe.yield)
        assert.are.same({ { item = COPPER_ORE, count = 1 } }, recipe.reagents)
        assert.are.equal("Mining", index.skills[recipe.skill])
    end)

    it("finds the recipes that use copper ore and copper bar", function()
        assert.are.same({ index.byId[SMELT_COPPER] }, index.byReagent[COPPER_ORE])
        local usesBar = {}
        for _, recipe in ipairs(index.byReagent[COPPER_BAR]) do
            usesBar[recipe.id] = true
        end
        assert.is_true(usesBar[SMELT_BRONZE])
        assert.is_true(#index.byReagent[COPPER_BAR] > 20)
    end)

    it("finds how an item is made, with its yield", function()
        local recipe = index.byProduct[BRONZE_BAR][1]
        assert.are.equal(SMELT_BRONZE, recipe.id)
        assert.are.equal(2, recipe.yield)
        assert.are.same({ { item = COPPER_BAR, count = 1 }, { item = TIN_BAR, count = 1 } }, recipe.reagents)
    end)

    it("gives every recipe a profession, reagents and positive amounts", function()
        local count = 0
        for id, recipe in pairs(index.byId) do
            count = count + 1
            assert.is_string(index.skills[recipe.skill], "recipe " .. id .. " has no profession")
            assert.is_true(#recipe.reagents > 0, "recipe " .. id .. " has no reagent")
            assert.is_true(recipe.yield >= 1, "recipe " .. id .. " has no yield")
            for _, reagent in ipairs(recipe.reagents) do
                assert.is_true(reagent.item > 0 and reagent.count > 0, "recipe " .. id)
            end
        end
        assert.is_true(count > 2000)
    end)

    it("keeps recipes without a product, such as enchants", function()
        local found = false
        for _, recipe in pairs(index.byId) do
            if not recipe.product and index.skills[recipe.skill] == "Enchanting" then
                found = true
                break
            end
        end
        assert.is_true(found)
    end)

    it("prices vendor supplies per unit", function()
        assert.are.equal(10, index.vendor[COARSE_THREAD])
        assert.are.equal(4, index.vendor[3371])
    end)

    it("flags soulbound products as unsellable", function()
        assert.is_true(next(index.unsellable) ~= nil)
        assert.is_nil(index.unsellable[COPPER_BAR])
    end)

    it("sorts lookups so rankings do not depend on table order", function()
        local list = index.byReagent[COPPER_BAR]
        for i = 2, #list do
            assert.is_true(list[i - 1].id < list[i].id)
        end
    end)
end)
