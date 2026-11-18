local helpers = require("spec.helpers")
local fixture = require("spec.fixture")

local items, recipes = fixture.items, fixture.recipes

describe("explorer", function()
    local game, ns, slash

    local function plain(text)
        return (text:gsub("|T.-UI%-(%a)%a+Icon.-|t", function(initial)
            return initial:lower()
        end))
    end

    local function widgets()
        return WarcraftBetsFrame.widgets
    end

    local function page()
        return widgets().pages.explorer
    end

    local function finishScan()
        for _ = 1, 100 do
            if #game.timers == 0 then
                return
            end
            game:RunTimers()
        end
        error("the scan never finished")
    end

    local function names()
        local out = {}
        for _, row in ipairs(page().rows) do
            if row:IsShown() then
                table.insert(out, row.name:GetText())
            end
        end
        return out
    end

    -- Belt, rod and bar sell well; the tube sells too rarely per listing, the
    -- bomb too few a day, the axe at a loss; bracers and mystery box have no
    -- sale data.
    local function populateSales(target)
        target.sales = {
            [items.BELT] = { rate = 0.48, perDay = 4.8, average = 10000 },
            [items.ROD] = { rate = 0.3, perDay = 2, average = 7000 },
            [items.BAR] = { rate = 0.9, perDay = 300, average = 790 },
            [items.TUBE] = { rate = 0.1, perDay = 5, average = 2947 },
            [items.BOMB] = { rate = 0.5, perDay = 0.5, average = 1158 },
            [items.AXE] = { rate = 0.9, perDay = 30, average = 1579 },
        }
    end

    local function start(settings, configure)
        game = helpers.newGame()
        fixture.populate(game)
        populateSales(game)
        if configure then
            configure()
        end
        local merged = { costMode = "all", explorerFilter = "all" }
        for key, value in pairs(settings or {}) do
            merged[key] = value
        end
        ns = helpers.loadAddon(game, fixture.data(), merged)
        slash = SlashCmdList.WARCRAFTBETS
    end

    before_each(function()
        start()
    end)

    it("opens with /wsb explorer and from its tab", function()
        slash("explorer")
        assert.is_true(WarcraftBetsFrame:IsShown())
        assert.is_true(page():IsShown())
        slash("Copper Ore")
        widgets().tabs.explorer:Run("OnClick")
        assert.is_true(page():IsShown())
    end)

    it("refuses to open in combat", function()
        game.inCombat = true
        slash("explorer")
        assert.is_nil(WarcraftBetsFrame)
    end)

    describe("ranking", function()
        before_each(function()
            slash("explorer")
            finishScan()
        end)

        it("keeps the crafts that sell, best profit per craft first", function()
            assert.are.same({ "Copper Chain Belt", "Runed Copper Rod", "Copper Bar" }, names())
        end)

        it("values a craft at what buyers really paid, capped by the current listing", function()
            local belt, rod = page().rows[1], page().rows[2]
            assert.are.equal("1g", plain(belt.values.price:GetText()))
            assert.are.equal("+59s", plain(belt.values.profit:GetText()))
            assert.are.equal("67s 37c", plain(rod.values.price:GetText()))
            assert.are.equal("+40s", plain(rod.values.profit:GetText()))
        end)

        it("shows how each craft sells and what it earns a day", function()
            local belt = page().rows[1]
            assert.are.equal("4.8", belt.values.perDay:GetText())
            assert.are.equal("48%", belt.values.rate:GetText())
            assert.are.equal("+2g 83s 20c", plain(belt.values.profitPerDay:GetText()))
            assert.are.equal("Blacksmithing", belt.skill:GetText())
            assert.are.equal("icon-" .. items.BELT, belt.icon.texture)
        end)

        it("counts what it left out and why", function()
            assert.are.equal("10 recipes analysed, 3 kept", page().progress:GetText())
            assert.are.equal(
                "Left out: 2 that do not sell enough, 2 without a price, 1 at a loss",
                page().discarded:GetText()
            )
        end)

        it("sorts by profit per day when that header is clicked, and back", function()
            assert.are.equal("Profit per craft v", page().headers.profit.text:GetText())
            page().headers.profitPerDay:Run("OnClick")
            assert.are.same({ "Copper Bar", "Copper Chain Belt", "Runed Copper Rod" }, names())
            assert.are.equal("Profit per day v", page().headers.profitPerDay.text:GetText())
            assert.are.equal("Profit per craft", page().headers.profit.text:GetText())
            assert.are.equal(0, #game.timers)
            page().headers.profit:Run("OnClick")
            assert.are.same({ "Copper Chain Belt", "Runed Copper Rod", "Copper Bar" }, names())
        end)

        it("greys out crafts this character has not learned", function()
            assert.is_true(page().rows[1].icon.desaturated)
            assert.are.same(ns.View.colors.unlearned, page().rows[1].name.textColor)
        end)

        it("opens a craft in the item tab, on its first reagent", function()
            page().rows[1]:Run("OnClick", "LeftButton")
            assert.is_true(widgets().pages.item:IsShown())
            assert.are.equal("Copper Bar", widgets().name:GetText())
            assert.are.equal("Copper Chain Belt", widgets().detail.name:GetText())
        end)

        it("follows a craft from its star", function()
            assert.is_false(page().rows[1].star.starred)
            page().rows[1].star:Run("OnClick")
            assert.are.same({ { recipe = recipes.BELT, item = items.BAR } }, ns.db.favorites.crafts)
        end)

        it("shows the product tooltip with a hint", function()
            page().rows[1]:Run("OnEnter")
            assert.are.equal(items.BELT, GameTooltip.item)
            assert.are.equal("Click: open this craft in the Item tab", GameTooltip.lines[#GameTooltip.lines].left)
        end)
    end)

    describe("filters", function()
        before_each(function()
            slash("explorer")
            finishScan()
        end)

        it("show their current values", function()
            assert.are.equal("All", page().filter:GetText())
            assert.are.equal("Craft all", page().mode:GetText())
            assert.are.equal("1 a day", page().perDay.value:GetText())
            assert.are.equal("20%", page().rate.value:GetText())
        end)

        it("let slower sellers in when the daily threshold is lowered", function()
            page().perDay.less:Run("OnClick")
            finishScan()
            assert.are.equal(0, ns.db.settings.explorerMinPerDay)
            assert.are.same({ "Copper Chain Belt", "Runed Copper Rod", "Rough Copper Bomb", "Copper Bar" }, names())
        end)

        it("drop slow sellers when the daily threshold is raised", function()
            page().perDay.more:Run("OnClick")
            page().perDay.more:Run("OnClick")
            finishScan()
            assert.are.equal(5, ns.db.settings.explorerMinPerDay)
            assert.are.same({ "Copper Bar" }, names())
        end)

        it("stop at the ends of the daily threshold", function()
            for _ = 1, 10 do
                page().perDay.more:Run("OnClick")
            end
            assert.are.equal(50, ns.db.settings.explorerMinPerDay)
            for _ = 1, 10 do
                page().perDay.less:Run("OnClick")
            end
            assert.are.equal(0, ns.db.settings.explorerMinPerDay)
        end)

        it("let rarely sold listings in when the sale rate threshold is lowered", function()
            page().rate.less:Run("OnClick")
            finishScan()
            assert.are.equal(10, ns.db.settings.explorerMinRate)
            assert.are.equal("Copper Tube", names()[3])
        end)

        it("drop them when the sale rate threshold is raised", function()
            page().rate.more:Run("OnClick")
            page().rate.more:Run("OnClick")
            finishScan()
            assert.are.equal(40, ns.db.settings.explorerMinRate)
            assert.are.same({ "Copper Chain Belt", "Copper Bar" }, names())
        end)

        it("follow the cost mode", function()
            page().mode:Run("OnClick", "LeftButton")
            finishScan()
            assert.are.equal("mine", ns.db.settings.costMode)
            assert.are.equal("For me", page().mode:GetText())
            assert.are.equal("+47s", plain(page().rows[1].values.profit:GetText()))
        end)

        it("limit the scan to the chosen recipes", function()
            page().filter:Run("OnClick", "LeftButton")
            finishScan()
            assert.are.equal("known", ns.db.settings.explorerFilter)
            assert.are.same({}, names())
            assert.are.equal("0 recipes analysed, 0 kept", page().progress:GetText())
            assert.are.equal(
                "No craft passes these filters. Lower the thresholds or widen the recipes.",
                page().message:GetText()
            )
        end)
    end)

    it("scans the recipes this character knows by default", function()
        start({ explorerFilter = false }, function() end)
        ns:Set("explorerFilter", "known")
        game.knownSpells[recipes.BELT], game.ranks[fixture.SMITHING] = true, 100
        game:Fire("PLAYER_LOGIN")
        game:RunTimers()
        slash("explorer")
        finishScan()
        assert.are.same({ "Copper Chain Belt" }, names())
        assert.is_false(page().rows[1].icon.desaturated)
    end)

    describe("scan", function()
        local function startWithManyRecipes()
            game = helpers.newGame()
            fixture.populate(game)
            populateSales(game)
            local data = fixture.data()
            for extra = 1, 60 do
                data.recipes[500 + extra] = { fixture.SMITHING, 30, 60, 0, 600 + extra, 1, items.BAR, 1 }
                game.itemNames[600 + extra] = "Trinket " .. extra
                game.prices[600 + extra] = 2000 + extra
                game.sales[600 + extra] = { rate = 0.5, perDay = 3, average = 2000 + extra }
            end
            ns = helpers.loadAddon(game, data, { costMode = "all", explorerFilter = "all" })
            SlashCmdList.WARCRAFTBETS("explorer")
        end

        it("is spread over several frames and reports its progress", function()
            startWithManyRecipes()
            assert.are.equal("0 of 70 recipes analysed, 0 kept", page().progress:GetText())
            game:RunTimers()
            assert.is_truthy(page().progress:GetText():find("^25 of 70 recipes analysed"))
            assert.are.equal(1, #game.timers)
            finishScan()
            assert.are.equal("70 recipes analysed, 63 kept", page().progress:GetText())
        end)

        it("scrolls a long ranking", function()
            startWithManyRecipes()
            finishScan()
            assert.is_true(page().scrollbar:IsShown())
            assert.are.same({ 0, 46 }, { page().scrollbar:GetMinMaxValues() })
            page().list:Run("OnMouseWheel", -1)
            assert.are.equal("Trinket 59", page().rows[1].name:GetText())
            page().scrollbar:SetValue(46)
            assert.are.equal("Copper Bar", page().rows[17].name:GetText())
        end)

        it("starts over when a filter changes mid-scan", function()
            startWithManyRecipes()
            game:RunTimers()
            page().rate.more:Run("OnClick")
            finishScan()
            assert.are.equal("70 recipes analysed, 63 kept", page().progress:GetText())
        end)

        it("does not run while its tab is hidden, and catches up when shown", function()
            slash("Copper Ore")
            ns:Set("cut", 10)
            assert.are.equal(0, #game.timers)
            widgets().tabs.explorer:Run("OnClick")
            finishScan()
            assert.are.equal(3, #names())
        end)

        it("runs again on Refresh", function()
            slash("explorer")
            finishScan()
            game.sales[items.TUBE].rate = 0.9
            page().refresh:Run("OnClick")
            finishScan()
            assert.are.equal(4, #names())
        end)
    end)

    describe("without sale data", function()
        it("says it needs TSM when TSM is not loaded", function()
            start(nil, function() end)
            _G.TSM_API = nil
            slash("explorer")
            assert.is_truthy(page().message:GetText():find("needs TradeSkillMaster", 1, true))
            assert.are.same({}, names())
            assert.are.equal(0, #game.timers)
        end)

        it("says so when TSM has no regional data", function()
            start(nil, function()
                game.sales = {}
            end)
            slash("explorer")
            finishScan()
            assert.is_truthy(page().message:GetText():find("no regional sale data", 1, true))
        end)

        it("hides the message once there are results", function()
            slash("explorer")
            finishScan()
            assert.is_false(page().message:IsShown())
        end)
    end)
end)
