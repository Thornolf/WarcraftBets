local helpers = require("spec.helpers")
local fixture = require("spec.fixture")

local items, recipes = fixture.items, fixture.recipes

describe("craft list", function()
    local game, ns, View

    local function plain(text)
        return (text:gsub("|T.-UI%-(%a)%a+Icon.-|t", function(initial)
            return initial:lower()
        end))
    end

    local function labels(rows)
        local out = {}
        for _, row in ipairs(rows) do
            table.insert(out, row.header and ("# " .. row.header) or row.name)
        end
        return out
    end

    local function login(character)
        game.character = character
        game:Fire("PLAYER_LOGIN")
        game:RunTimers()
    end

    local function find(rows, recipe)
        for _, row in ipairs(rows) do
            if row.use and row.use.recipe.id == recipe then
                return row
            end
        end
    end

    before_each(function()
        game = helpers.newGame()
        fixture.populate(game)
        ns = helpers.loadAddon(game, fixture.data())
        View = ns.View
    end)

    it("groups crafts by step, best first, with unsellable crafts last", function()
        assert.are.same({
            "# Directly",
            "Copper Bar",
            "# With Copper Bar",
            "Copper Chain Belt",
            "Runed Copper Rod",
            "Copper Tube",
            "Rough Copper Bomb",
            "Runed Copper Bracers",
            "Copper Axe",
            "Mystery Box",
            "# Not sellable",
            "Copper Badge",
            "Enchant Bracer",
        }, labels(View.ListRows(items.ORE, "", "all")))
    end)

    it("searches craft names without caring about case", function()
        assert.are.same({
            "# With Copper Bar",
            "Runed Copper Rod",
            "Runed Copper Bracers",
        }, labels(View.ListRows(items.ORE, "RUNED", "all")))
    end)

    it("treats search text literally", function()
        assert.are.same({}, View.ListRows(items.ORE, "c.pper", "all"))
    end)

    it("returns no row when nothing matches", function()
        assert.are.same({}, View.ListRows(items.ORE, "zzz", "all"))
        assert.are.same({}, View.ListRows(items.BELT, "", "all"))
    end)

    describe("filters", function()
        before_each(function()
            game.knownSpells[recipes.ROD], game.ranks[fixture.SMITHING] = true, 100
            login("Jaina")
            game.knownSpells = { [recipes.TUBE] = true }
            game.ranks = { [fixture.SMITHING] = 40 }
            login("Thrall")
        end)

        it("keep the crafts this character knows", function()
            assert.are.same({ "# With Copper Bar", "Copper Tube" }, labels(View.ListRows(items.ORE, "", "known")))
        end)

        it("keep the crafts only an alt knows", function()
            assert.are.same({ "# With Copper Bar", "Runed Copper Rod" }, labels(View.ListRows(items.ORE, "", "alt")))
        end)

        it("keep the crafts nobody knows", function()
            local rows = labels(View.ListRows(items.ORE, "", "unknown"))
            assert.are.equal(11, #rows)
            for _, label in ipairs(rows) do
                assert.are_not.equal("Copper Tube", label)
                assert.are_not.equal("Runed Copper Rod", label)
            end
        end)

        it("keep the crafts this character can learn now", function()
            assert.are.same({
                "# With Copper Bar",
                "Copper Chain Belt",
                "Runed Copper Rod",
                "Rough Copper Bomb",
                "Runed Copper Bracers",
                "Copper Axe",
                "Mystery Box",
                "# Not sellable",
                "Copper Badge",
            }, labels(View.ListRows(items.ORE, "", "learnable")))
        end)

        it("combine with the search", function()
            assert.are.same({}, View.ListRows(items.ORE, "belt", "known"))
        end)
    end)

    describe("detail of a craft", function()
        it("breaks the profit down as in the spec example", function()
            local detail = View.Detail(find(View.ListRows(items.ORE, "", "all"), recipes.BELT).use, items.ORE)
            assert.are.equal("Copper Chain Belt", detail.name)
            assert.are.equal("Blacksmithing · requires skill 35", detail.skill)
            assert.are.equal("Recipe not learned", detail.state)
            local rows = {}
            for _, row in ipairs(detail.economics) do
                table.insert(rows, row.label .. " | " .. plain(row.value))
            end
            assert.are.same({
                "Auction house sale price | 1g 20s",
                "Auction house fee (5%) | -6s",
                "Reagent cost | -36s",
                "Net profit | +78s",
                "Profit per Copper Ore | +13s",
            }, rows)
            assert.is_true(detail.economics[4].strong)
            assert.are.same(View.colors.gain, detail.economics[4].color)
        end)

        it("lists reagents with their cheapest source and the alternatives", function()
            local detail = View.Detail(find(View.ListRows(items.ORE, "", "all"), recipes.BELT).use, items.ORE)
            local reagent = detail.reagents[1]
            assert.are.equal(items.BAR, reagent.item)
            assert.are.equal("Copper Bar x6", reagent.label)
            assert.are.equal("36s", plain(reagent.cost))
            assert.are.equal("crafted", reagent.origin)
            assert.are.equal("auction house", reagent.alternatives[1].left)
            assert.are.equal("48s", plain(reagent.alternatives[1].right))
            assert.are.equal("crafted", reagent.alternatives[2].left)
            assert.are.equal("36s", plain(reagent.alternatives[2].right))
        end)

        it("falls back to the yellow threshold when the requirement is unknown", function()
            local detail = View.Detail(find(View.ListRows(items.ORE, "", "all"), recipes.ROD).use, items.ORE)
            assert.are.equal("Blacksmithing · yellow at 30", detail.skill)
        end)

        it("shows question marks when a price is missing", function()
            local detail = View.Detail(find(View.ListRows(items.ORE, "", "all"), recipes.MYSTERY).use, items.ORE)
            assert.are.equal("?", detail.economics[1].value)
            assert.are.equal("?", detail.economics[2].value)
            assert.are.equal("?", detail.economics[4].value)
        end)

        it("shows only the cost of an unsellable craft", function()
            local detail = View.Detail(find(View.ListRows(items.ORE, "", "all"), recipes.BADGE).use, items.ORE)
            assert.are.equal("Cannot be sold", detail.economics[1].label)
            assert.are.equal("Reagent cost", detail.economics[2].label)
            assert.are.equal("12s", plain(detail.economics[2].value))
            assert.are.equal(2, #detail.economics)
        end)

        it("names the alts that know the recipe and says when it is learnable", function()
            game.knownSpells[recipes.ROD], game.ranks[fixture.SMITHING] = true, 100
            login("Jaina")
            game.knownSpells = {}
            login("Thrall")
            local rows = View.ListRows(items.ORE, "", "all")
            assert.are.equal("Known by: Jaina · learnable now", View.Detail(find(rows, recipes.ROD).use, items.ORE).state)
            assert.are.equal("learnable now", View.Detail(find(rows, recipes.BELT).use, items.ORE).state)
            game.knownSpells[recipes.BELT] = true
            login("Thrall")
            assert.are.equal("Recipe learned", View.Detail(find(rows, recipes.BELT).use, items.ORE).state)
        end)
    end)

    describe("price source", function()
        it("names the sources auto mode will try", function()
            assert.are.equal("TSM", View.PriceSourceText())
            _G.Auctionator = { API = { v1 = {} } }
            assert.are.equal("TSM, then Auctionator", View.PriceSourceText())
        end)

        it("says when nothing is installed", function()
            _G.TSM_API = nil
            assert.are.equal("No price add-on installed (TSM or Auctionator)", View.PriceSourceText())
        end)

        it("says when the forced source is not installed", function()
            ns:Set("priceSource", "auctionator")
            assert.are.equal("Auctionator (not installed)", View.PriceSourceText())
            ns:Set("priceSource", "tsm")
            assert.are.equal("TSM", View.PriceSourceText())
        end)
    end)
end)
