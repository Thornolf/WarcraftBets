local helpers = require("spec.helpers")
local fixture = require("spec.fixture")

local items = fixture.items

describe("tooltip hook", function()
    local game, ns

    local function hover(tooltip, item)
        tooltip.lines, tooltip.shown = {}, false
        function tooltip:GetItem()
            return game.itemNames[item], "|cffffffff|Hitem:" .. item .. "::::::::60:::::|h[x]|h|r"
        end
        tooltip.hooks.OnTooltipSetItem(tooltip)
    end

    before_each(function()
        game = helpers.newGame()
        fixture.populate(game)
        ns = helpers.loadAddon(game, fixture.data())
    end)

    it("adds the block under an item tooltip", function()
        hover(GameTooltip, items.ORE)
        assert.are.equal(" ", GameTooltip.lines[1].left)
        assert.are.equal("TSM, raw", GameTooltip.lines[2].left)
        assert.are.equal(7, #GameTooltip.lines)
        assert.is_true(GameTooltip.shown)
    end)

    it("works on the chat link tooltip too", function()
        hover(ItemRefTooltip, items.ORE)
        assert.are.equal(7, #ItemRefTooltip.lines)
    end)

    it("lists more crafts while Shift is held", function()
        game.shift = true
        hover(GameTooltip, items.ORE)
        assert.are.equal(10, #GameTooltip.lines)
    end)

    it("stays out of the way in combat", function()
        game.inCombat = true
        hover(GameTooltip, items.ORE)
        assert.are.equal(0, #GameTooltip.lines)
    end)

    it("stays out of the way when disabled", function()
        ns:Set("tooltipEnabled", false)
        hover(GameTooltip, items.ORE)
        assert.are.equal(0, #GameTooltip.lines)
    end)

    it("adds nothing to an item it knows nothing about", function()
        hover(GameTooltip, 999)
        assert.are.equal(0, #GameTooltip.lines)
    end)

    it("remembers the last hovered item for /wsb", function()
        hover(GameTooltip, items.BAR)
        assert.are.equal(items.BAR, ns.lastItem)
    end)

    it("rebuilds the tooltip when Shift changes, without moving the mouse", function()
        local refreshed = 0
        function GameTooltip:RebuildFromTooltipInfo()
            refreshed = refreshed + 1
        end
        game:Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
        assert.are.equal(0, refreshed)
        hover(GameTooltip, items.ORE)
        game:Fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
        assert.are.equal(0, refreshed)
        game:Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
        assert.are.equal(1, refreshed)
        GameTooltip.hooks.OnTooltipCleared(GameTooltip)
        game:Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
        assert.are.equal(1, refreshed)
    end)

    it("uses RefreshData on a client that names the rebuild that way", function()
        local refreshed = 0
        function GameTooltip:RefreshData()
            refreshed = refreshed + 1
        end
        hover(GameTooltip, items.ORE)
        game:Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
        assert.are.equal(1, refreshed)
    end)

    it("re-enters the hovered frame on a client without a rebuild method", function()
        local entered = 0
        local owner = {
            GetScript = function()
                return function()
                    entered = entered + 1
                end
            end,
        }
        function GameTooltip:GetOwner()
            return owner
        end
        hover(GameTooltip, items.ORE)
        game:Fire("MODIFIER_STATE_CHANGED", "RSHIFT", 1)
        assert.are.equal(1, entered)
    end)

    it("uses the tooltip data processor when the client has one", function()
        game = helpers.newGame()
        fixture.populate(game)
        local postCall
        _G.Enum = { TooltipDataType = { Item = 0 } }
        _G.TooltipDataProcessor = {
            AddTooltipPostCall = function(kind, fn)
                assert(kind == 0)
                postCall = fn
            end,
        }
        helpers.loadAddon(game, fixture.data())
        postCall(GameTooltip, { id = items.ORE })
        assert.are.equal(7, #GameTooltip.lines)
        postCall({}, { id = items.ORE })
    end)
end)
