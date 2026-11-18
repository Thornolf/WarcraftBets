local helpers = require("spec.helpers")
local fixture = require("spec.fixture")

local items, recipes = fixture.items, fixture.recipes

describe("favourites", function()
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
        return widgets().pages.favorites
    end

    local function rowNamed(name)
        for _, row in ipairs(widgets().rows) do
            if row:IsShown() and row.name:IsShown() and row.name:GetText() == name then
                return row
            end
        end
    end

    local function shown(rows)
        local out = {}
        for _, row in ipairs(rows) do
            if row:IsShown() then
                table.insert(out, row.name:GetText())
            end
        end
        return out
    end

    before_each(function()
        game = helpers.newGame()
        fixture.populate(game)
        ns = helpers.loadAddon(game, fixture.data())
        slash = SlashCmdList.WARCRAFTBETS
        slash("Copper Ore")
    end)

    describe("item star", function()
        it("is unlit for an item that is not followed", function()
            assert.is_false(widgets().itemStar.starred)
            assert.is_true(widgets().itemStar:IsShown())
        end)

        it("follows the item on click and stops on a second click", function()
            widgets().itemStar:Run("OnClick")
            assert.is_true(widgets().itemStar.starred)
            assert.are.same({ { item = items.ORE } }, ns.db.favorites.items)
            widgets().itemStar:Run("OnClick")
            assert.is_false(widgets().itemStar.starred)
            assert.are.same({}, ns.db.favorites.items)
        end)

        it("follows each item separately", function()
            widgets().itemStar:Run("OnClick")
            slash("Copper Bar")
            assert.is_false(widgets().itemStar.starred)
            slash("Copper Ore")
            assert.is_true(widgets().itemStar.starred)
        end)

        it("is hidden while no item is open", function()
            game = helpers.newGame()
            helpers.loadAddon(game, fixture.data())
            SlashCmdList.WARCRAFTBETS("")
            assert.is_false(widgets().itemStar:IsShown())
        end)

        it("says what a click will do", function()
            widgets().itemStar:Run("OnEnter")
            assert.are.equal("Add to favourites", GameTooltip.lines[1].left)
            widgets().itemStar:Run("OnClick")
            widgets().itemStar:Run("OnEnter")
            assert.are.equal("Remove from favourites", GameTooltip.lines[1].left)
        end)
    end)

    describe("craft star", function()
        it("follows the selected craft, remembering the item it was studied from", function()
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
            local star = widgets().detail.star
            assert.is_false(star.starred)
            star:Run("OnClick")
            assert.is_true(star.starred)
            assert.are.same({ { recipe = recipes.BELT, item = items.ORE } }, ns.db.favorites.crafts)
        end)

        it("follows each craft separately", function()
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
            widgets().detail.star:Run("OnClick")
            rowNamed("Copper Tube"):Run("OnClick", "LeftButton")
            assert.is_false(widgets().detail.star.starred)
            widgets().detail.star:Run("OnClick")
            widgets().detail.star:Run("OnClick")
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
            assert.is_true(widgets().detail.star.starred)
            assert.are.equal(1, #ns.db.favorites.crafts)
        end)
    end)

    describe("tab", function()
        it("explains how to follow something while empty", function()
            widgets().tabs.favorites:Run("OnClick")
            assert.is_true(page().empty:IsShown())
            assert.are.same({}, shown(page().items.rows))
            assert.are.same({}, shown(page().crafts.rows))
        end)

        it("lists followed items with their best craft and its profit per unit", function()
            widgets().itemStar:Run("OnClick")
            slash("Copper Bar")
            widgets().itemStar:Run("OnClick")
            widgets().tabs.favorites:Run("OnClick")
            assert.is_false(page().empty:IsShown())
            assert.are.same({ "Copper Ore", "Copper Bar" }, shown(page().items.rows))
            local ore = page().items.rows[1]
            assert.are.equal("Copper Chain Belt", ore.detail:GetText())
            assert.are.equal("+13s", plain(ore.profit:GetText()))
            assert.are.equal("icon-" .. items.ORE, ore.icon.texture)
        end)

        it("says when nothing uses a followed item", function()
            slash("Copper Chain Belt")
            widgets().itemStar:Run("OnClick")
            widgets().tabs.favorites:Run("OnClick")
            assert.are.equal("No recipe uses this item.", page().items.rows[1].detail:GetText())
            assert.are.equal("", page().items.rows[1].profit:GetText())
        end)

        it("lists followed crafts with their profession and profit per craft", function()
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
            widgets().detail.star:Run("OnClick")
            rowNamed("Copper Badge"):Run("OnClick", "LeftButton")
            widgets().detail.star:Run("OnClick")
            widgets().tabs.favorites:Run("OnClick")
            assert.are.same({ "Copper Chain Belt", "Copper Badge" }, shown(page().crafts.rows))
            local belt, badge = page().crafts.rows[1], page().crafts.rows[2]
            assert.are.equal("Blacksmithing", belt.detail:GetText())
            assert.are.equal("+78s", plain(belt.profit:GetText()))
            assert.are.equal("icon-" .. items.BELT, belt.icon.texture)
            assert.are.equal("Cannot be sold", badge.profit:GetText())
        end)

        it("lists recent items, with a lit star on the followed ones", function()
            widgets().itemStar:Run("OnClick")
            slash("Copper Bar")
            widgets().tabs.favorites:Run("OnClick")
            local recents = page().items.recents
            assert.are.same({ "Copper Bar", "Copper Ore" }, shown(recents))
            assert.are.same({ 0.5, 1, 0, 0.5 }, recents[1].star.texCoord)
            assert.are.same({ 0, 0.5, 0, 0.5 }, recents[2].star.texCoord)
        end)

        it("opens a followed item in the item tab", function()
            widgets().itemStar:Run("OnClick")
            slash("Copper Bar")
            widgets().tabs.favorites:Run("OnClick")
            page().items.rows[1]:Run("OnClick", "LeftButton")
            assert.is_true(widgets().pages.item:IsShown())
            assert.are.equal("Copper Ore", widgets().name:GetText())
        end)

        it("opens a followed craft on the item it was studied from, with the craft selected", function()
            rowNamed("Copper Tube"):Run("OnClick", "LeftButton")
            widgets().detail.star:Run("OnClick")
            slash("Copper Chain Belt")
            widgets().tabs.favorites:Run("OnClick")
            page().crafts.rows[1]:Run("OnClick", "LeftButton")
            assert.are.equal("Copper Ore", widgets().name:GetText())
            assert.are.equal("Copper Tube", widgets().detail.name:GetText())
        end)

        it("opens a recent item", function()
            slash("Copper Bar")
            widgets().tabs.favorites:Run("OnClick")
            page().items.recents[2]:Run("OnClick", "LeftButton")
            assert.are.equal("Copper Ore", widgets().name:GetText())
        end)

        it("stops following from the star of a row", function()
            widgets().itemStar:Run("OnClick")
            rowNamed("Copper Tube"):Run("OnClick", "LeftButton")
            widgets().detail.star:Run("OnClick")
            widgets().tabs.favorites:Run("OnClick")
            page().items.rows[1].star:Run("OnClick")
            page().crafts.rows[1].star:Run("OnClick")
            assert.are.same({}, shown(page().items.rows))
            assert.are.same({}, shown(page().crafts.rows))
            assert.is_true(page().empty:IsShown())
        end)

        it("says how many favourites do not fit", function()
            for item = 20, 31 do
                game.itemNames[item] = "Item " .. item
                ns.Favorites.ToggleItem(item)
            end
            widgets().tabs.favorites:Run("OnClick")
            assert.are.equal(9, #shown(page().items.rows))
            assert.is_true(page().items.more:IsShown())
            assert.are.equal("+3 more", page().items.more:GetText())
            assert.is_false(page().crafts.more:IsShown())
        end)

        it("skips a followed craft that no longer exists in the recipe data", function()
            ns.db.favorites.crafts = { { recipe = 99999, item = items.ORE } }
            widgets().tabs.favorites:Run("OnClick")
            assert.are.same({}, shown(page().crafts.rows))
        end)
    end)

    it("marks followed items in the recent list of the item field", function()
        widgets().itemStar:Run("OnClick")
        slash("Copper Bar")
        widgets().itemField:SetFocus()
        local rows = widgets().recents.rows
        assert.are.same({ 0.5, 1, 0, 0.5 }, rows[1].star.texCoord)
        assert.are.same({ 0, 0.5, 0, 0.5 }, rows[2].star.texCoord)
    end)

    it("restores favourites from the saved variables", function()
        game = helpers.newGame()
        fixture.populate(game)
        _G.WarcraftBetsDB = {
            favorites = { items = { { item = items.BAR } }, crafts = { { recipe = recipes.BELT, item = items.BAR } } },
        }
        helpers.loadAddon(game, fixture.data())
        SlashCmdList.WARCRAFTBETS("Copper Bar")
        assert.is_true(widgets().itemStar.starred)
        widgets().tabs.favorites:Run("OnClick")
        assert.are.same({ "Copper Bar" }, shown(page().items.rows))
        assert.are.same({ "Copper Chain Belt" }, shown(page().crafts.rows))
    end)
end)
