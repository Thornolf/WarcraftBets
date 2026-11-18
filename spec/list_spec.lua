local helpers = require("spec.helpers")
local fixture = require("spec.fixture")

local items, recipes = fixture.items, fixture.recipes

describe("craft list", function()
    local game, ns, View

    local function plain(text)
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
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
            assert.are.same({ "For me", "Buy all", "Craft all" }, detail.modes)
            assert.are.equal("all", detail.activeMode)
            local rows = {}
            for _, row in ipairs(detail.economics) do
                local values = {}
                for _, value in ipairs(row.values) do
                    table.insert(values, plain(value))
                end
                table.insert(rows, row.label .. " | " .. table.concat(values, " | "))
            end
            assert.are.same({
                "Auction house sale price | 1g 20s | 1g 20s | 1g 20s",
                "Auction house fee (5%) | -6s | -6s | -6s",
                "Reagent cost | -48s | -48s | -36s",
                "Profit per craft | +66s | +66s | +78s",
                "Profit per Copper Ore | +11s | +11s | +13s",
            }, rows)
            assert.is_true(detail.economics[4].strong)
            assert.are.same(View.colors.gain, detail.economics[4].colors[3])
        end)

        it("crafts a reagent for me only when one of my characters knows the recipe", function()
            local function forMe()
                local use = find(View.ListRows(items.ORE, "", "all"), recipes.BELT).use
                return plain(View.Detail(use, items.ORE).economics[4].values[1])
            end
            assert.are.equal("+66s", forMe())
            game.knownSpells[recipes.SMELT], game.ranks[fixture.MINING] = true, 100
            login("Jaina")
            game.knownSpells, game.ranks = {}, {}
            login("Thrall")
            assert.are.equal("+78s", forMe())
        end)

        it("ranks the list with the configured cost mode", function()
            ns:Set("costMode", "buy")
            local belt = find(View.ListRows(items.ORE, "", "all"), recipes.BELT).use
            assert.are.equal(6600, belt.profit)
            ns:Set("costMode", "all")
            belt = find(View.ListRows(items.ORE, "", "all"), recipes.BELT).use
            assert.are.equal(7800, belt.profit)
        end)

        it("shows both prices of a reagent that can be crafted", function()
            local detail = View.Detail(find(View.ListRows(items.ORE, "", "all"), recipes.BELT).use, items.ORE)
            assert.are.equal("buy 48s  ·  craft 36s", plain(detail.reagents[1].cost))
            assert.is_nil(detail.reagents[1].origin)
        end)

        it("highlights the price the cost mode uses and whether the recipe is known", function()
            local white, grey, red, green = "|cffffffff", "|cff9e9e9e", "|cffff4c4c", "|cff1eff00"
            local function cost()
                local use = find(View.ListRows(items.ORE, "", "all"), recipes.BELT).use
                return View.Detail(use, items.ORE).reagents[1].cost
            end
            local crafted = cost()
            assert.is_truthy(crafted:find(grey .. "buy ", 1, true))
            assert.is_truthy(crafted:find(red .. "craft|r " .. white, 1, true))
            ns:Set("costMode", "buy")
            local bought = cost()
            assert.is_truthy(bought:find(white .. "buy ", 1, true))
            assert.is_truthy(bought:find(red .. "craft|r " .. grey, 1, true))
            game.knownSpells[recipes.SMELT], game.ranks[fixture.MINING] = true, 100
            login("Thrall")
            assert.is_truthy(cost():find(green .. "craft|r", 1, true))
        end)

        it("shows the single price and origin of a reagent that cannot be crafted", function()
            local detail = View.Detail(find(View.ListRows(items.ORE, "", "all"), recipes.SMELT).use, items.ORE)
            assert.are.equal("6s", plain(detail.reagents[1].cost))
            assert.are.equal("auction house", detail.reagents[1].origin)
        end)

        describe("sale statistics", function()
            local function detail()
                return View.Detail(find(View.ListRows(items.ORE, "", "all"), recipes.BELT).use, items.ORE)
            end

            local function fakeStats(values)
                _G.TSM_API.GetCustomPriceValue = function(formula, itemString)
                    local item = tonumber(itemString:match("%d+"))
                    if formula == "DBMarket" then
                        return game.prices[item]
                    end
                    return item == items.BELT and values[formula] or nil
                end
            end

            it("are absent when TSM has none", function()
                assert.is_nil(detail().sales)
            end)

            it("show volume, sale rate, average sale and cheapest auction", function()
                fakeStats({
                    ["DBRegionSaleRate*1000"] = 481,
                    ["DBRegionSoldPerDay*1000"] = 4810,
                    DBRegionSaleAvg = 5319,
                    DBMinBuyout = 4400,
                })
                local rows = {}
                for _, row in ipairs(detail().sales) do
                    table.insert(rows, row.label .. " | " .. plain(row.value))
                end
                assert.are.same({
                    "Sold per day, sale rate | 4.8 a day, 48%",
                    "Price really paid (average sale) | 53s 19c",
                    "Cheapest on sale now | 44s",
                }, rows)
            end)

            it("read TSM versions that already multiply these values by a thousand", function()
                fakeStats({ ["DBRegionSaleRate*1000"] = 481000, ["DBRegionSoldPerDay*1000"] = 4810000 })
                assert.are.equal("4.8 a day, 48%", detail().sales[1].value)
            end)

            it("show a question mark when nothing is on sale right now", function()
                fakeStats({ ["DBRegionSaleRate*1000"] = 481, ["DBRegionSoldPerDay*1000"] = 4810 })
                assert.are.equal("?", detail().sales[3].value)
            end)

            it("are absent for a craft that cannot be sold", function()
                fakeStats({ ["DBRegionSaleRate*1000"] = 481, ["DBRegionSoldPerDay*1000"] = 4810 })
                local badge = find(View.ListRows(items.ORE, "", "all"), recipes.BADGE).use
                assert.is_nil(View.Detail(badge, items.ORE).sales)
            end)
        end)

        it("lists reagents with their cheapest source and the alternatives", function()
            local detail = View.Detail(find(View.ListRows(items.ORE, "", "all"), recipes.BELT).use, items.ORE)
            local reagent = detail.reagents[1]
            assert.are.equal(items.BAR, reagent.item)
            assert.are.equal("Copper Bar x6", reagent.label)
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
            assert.are.equal("?", detail.economics[1].values[3])
            assert.are.equal("?", detail.economics[2].values[3])
            assert.are.equal("?", detail.economics[4].values[3])
        end)

        it("shows only the cost of an unsellable craft", function()
            local detail = View.Detail(find(View.ListRows(items.ORE, "", "all"), recipes.BADGE).use, items.ORE)
            assert.are.equal("Cannot be sold", detail.economics[1].label)
            assert.are.equal("Reagent cost", detail.economics[2].label)
            assert.are.equal("12s", plain(detail.economics[2].values[3]))
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
            assert.are.equal("TSM (Market value)", View.PriceSourceText())
            _G.Auctionator = { API = { v1 = {} } }
            assert.are.equal("TSM (Market value), then Auctionator", View.PriceSourceText())
        end)

        it("says when nothing is installed", function()
            _G.TSM_API = nil
            assert.are.equal("No price add-on installed (TSM or Auctionator)", View.PriceSourceText())
        end)

        it("says when the forced source is not installed", function()
            ns:Set("priceSource", "auctionator")
            assert.are.equal("Auctionator (not installed)", View.PriceSourceText())
            ns:Set("priceSource", "tsm")
            assert.are.equal("TSM (Market value)", View.PriceSourceText())
        end)

        it("names the TSM price in use", function()
            ns:Set("tsmFormula", "dbminbuyout")
            assert.are.equal("TSM (Min buyout)", View.PriceSourceText())
            ns:Set("tsmFormula", "min(DBMarket, DBRegionMarketAvg)")
            assert.are.equal("TSM (Custom formula)", View.PriceSourceText())
        end)
    end)
end)
