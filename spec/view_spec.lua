local helpers = require("spec.helpers")
local fixture = require("spec.fixture")

local items, recipes = fixture.items, fixture.recipes
local UNRELATED = 999

describe("tooltip lines", function()
    local game, ns, View

    local function plain(text)
        return text and (text:gsub("|T.-UI%-(%a)%a+Icon.-|t", function(initial)
            return initial:lower()
        end))
    end

    local function texts(lines)
        local out = {}
        for _, line in ipairs(lines) do
            table.insert(out, line.left .. (line.right and (" | " .. plain(line.right)) or ""))
        end
        return out
    end

    before_each(function()
        game = helpers.newGame()
        fixture.populate(game)
        ns = helpers.loadAddon(game, fixture.data())
        View = ns.View
    end)

    it("show the raw price, the transformed value and the two best crafts", function()
        assert.are.same({
            "TSM, raw | 6s",
            "Transformed (Copper Bar) | 8s",
            "WarcraftBets: best crafts | per unit",
            "Copper Chain Belt | +13s",
            "Runed Copper Rod | +10s",
            "+6 more · Shift to see more",
        }, texts(View.TooltipLines(items.ORE, false)))
    end)

    it("show five crafts while Shift is held", function()
        assert.are.same({
            "TSM, raw | 6s",
            "Transformed (Copper Bar) | 8s",
            "WarcraftBets: best crafts | per unit",
            "Copper Chain Belt | +13s",
            "Runed Copper Rod | +10s",
            "Copper Tube | +8s",
            "Rough Copper Bomb | +5s",
            "Runed Copper Bracers | +3s",
            "+3 more · /wsb to see all",
        }, texts(View.TooltipLines(items.ORE, true)))
    end)

    it("follow the configured counts", function()
        ns:Set("tooltipCount", 1)
        ns:Set("tooltipShiftCount", 3)
        assert.are.equal(5, #View.TooltipLines(items.ORE, false))
        assert.are.equal(7, #View.TooltipLines(items.ORE, true))
    end)

    it("show the crafting cost of an item that can be made", function()
        local lines = texts(View.TooltipLines(items.BAR, false))
        assert.are.equal("TSM, raw | 8s", lines[1])
        assert.are.equal("Crafting cost | 6s", lines[2])
    end)

    it("grey out crafts this character has not learned", function()
        game.knownSpells[recipes.ROD], game.ranks[fixture.SMITHING] = true, 100
        game:Fire("PLAYER_LOGIN")
        game:RunTimers()
        local lines = View.TooltipLines(items.ORE, false)
        assert.are.same(View.colors.unlearned, lines[4].leftColor)
        assert.are.same(View.colors.white, lines[5].leftColor)
    end)

    it("colour gains green and losses red", function()
        local lines = View.TooltipLines(items.ORE, true)
        assert.are.same(View.colors.gain, lines[4].rightColor)
        ns:Set("tooltipShiftCount", 8)
        lines = View.TooltipLines(items.ORE, true)
        assert.are.equal("Copper Axe", lines[10].left)
        assert.are.equal("-1s", plain(lines[10].right))
        assert.are.same(View.colors.loss, lines[10].rightColor)
    end)

    it("list a craft without a price last, with a question mark", function()
        ns:Set("tooltipShiftCount", 8)
        local lines = View.TooltipLines(items.ORE, true)
        assert.are.equal("Mystery Box", lines[11].left)
        assert.are.equal("?", lines[11].right)
        assert.are.equal(11, #lines)
    end)

    it("leave out unsellable crafts", function()
        ns:Set("tooltipShiftCount", 50)
        for _, line in ipairs(View.TooltipLines(items.ORE, true)) do
            assert.are_not.equal("Copper Badge", line.left)
            assert.are_not.equal("Enchant Bracer", line.left)
        end
    end)

    it("say nothing for an item with no price, no use and no recipe", function()
        assert.is_nil(View.TooltipLines(UNRELATED, false))
    end)

    it("show only the price of an item nothing uses or makes", function()
        game.prices[UNRELATED] = 50
        assert.are.same({ "TSM, raw | 50c" }, texts(View.TooltipLines(UNRELATED, false)))
    end)

    it("show price and crafting cost of a finished product", function()
        local lines = texts(View.TooltipLines(items.BELT, false))
        assert.are.same({ "TSM, raw | 1g 20s", "Crafting cost | 36s" }, lines)
    end)

    it("do not call a finished product a transformation", function()
        for _, line in ipairs(View.TooltipLines(items.BAR, true)) do
            assert.is_nil(line.left:find("Transformed", 1, true))
        end
    end)

    it("show a placeholder while the client loads a name", function()
        game.itemNames[items.BELT] = nil
        assert.are.equal("Loading...", View.TooltipLines(items.ORE, false)[4].left)
    end)

    it("pick up a changed setting on the next hover", function()
        assert.are.equal("+13s", plain(View.TooltipLines(items.ORE, false)[4].right))
        ns:Set("cut", 15)
        assert.are.equal("+11s", plain(View.TooltipLines(items.ORE, false)[4].right))
    end)

    it("pick up new prices after the engine lifetime", function()
        assert.are.equal("+13s", plain(View.TooltipLines(items.ORE, false)[4].right))
        game.prices[items.BELT] = 24000
        assert.are.equal("+13s", plain(View.TooltipLines(items.ORE, false)[4].right))
        game.time = 61
        assert.are.equal("+32s", plain(View.TooltipLines(items.ORE, false)[4].right))
    end)
end)
