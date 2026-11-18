local helpers = require("spec.helpers")
local fixture = require("spec.fixture")

describe("settings window", function()
    local game, ns

    local function controls()
        return WarcraftBetsSettingsFrame.controls
    end

    local function start(configure)
        game = helpers.newGame()
        fixture.populate(game)
        if configure then
            configure()
        end
        ns = helpers.loadAddon(game, fixture.data())
    end

    before_each(function()
        start()
        SlashCmdList.WARCRAFTBETS("options")
    end)

    it("opens with /wsb options and closes with Escape", function()
        assert.is_true(WarcraftBetsSettingsFrame:IsShown())
        assert.are.same({ "WarcraftBetsSettingsFrame" }, UISpecialFrames)
    end)

    it("shows the current settings", function()
        assert.is_true(controls().tooltip:GetChecked())
        assert.are.equal("Auto", controls().source:GetText())
        assert.are.equal("DBMarket", controls().formula:GetText())
        assert.are.equal("5", controls().steppers.cut.value:GetText())
        assert.are.equal("3", controls().steppers.depth.value:GetText())
        assert.are.equal("2", controls().steppers.tooltipCount.value:GetText())
        assert.are.equal("5", controls().steppers.tooltipShiftCount.value:GetText())
    end)

    it("turns the tooltip off and on", function()
        controls().tooltip:SetChecked(false)
        controls().tooltip:Run("OnClick")
        assert.is_false(ns.db.settings.tooltipEnabled)
        controls().tooltip:SetChecked(true)
        controls().tooltip:Run("OnClick")
        assert.is_true(ns.db.settings.tooltipEnabled)
    end)

    it("cycles the price source", function()
        controls().source:Run("OnClick")
        assert.are.equal("tsm", ns.db.settings.priceSource)
        assert.are.equal("TSM", controls().source:GetText())
        controls().source:Run("OnClick")
        controls().source:Run("OnClick")
        assert.are.equal("auto", ns.db.settings.priceSource)
    end)

    it("switches the TSM price between market value and minimum buyout", function()
        assert.are.equal("Market value", controls().preset:GetText())
        controls().preset:Run("OnClick")
        assert.are.equal("DBMinBuyout", ns.db.settings.tsmFormula)
        assert.are.equal("Min buyout", controls().preset:GetText())
        assert.are.equal("DBMinBuyout", controls().formula:GetText())
        controls().preset:Run("OnClick")
        assert.are.equal("DBMarket", ns.db.settings.tsmFormula)
    end)

    it("shows a typed formula as custom", function()
        controls().formula:SetText("DBRegionMarketAvg")
        controls().formula:Run("OnEnterPressed")
        assert.are.equal("Custom formula", controls().preset:GetText())
    end)

    it("keeps the auction house fee between 5 and 15 percent", function()
        local stepper = controls().steppers.cut
        stepper.less:Run("OnClick")
        assert.are.equal(5, ns.db.settings.cut)
        for _ = 1, 12 do
            stepper.more:Run("OnClick")
        end
        assert.are.equal(15, ns.db.settings.cut)
        assert.are.equal("15", stepper.value:GetText())
    end)

    it("keeps the chain depth between 1 and 5", function()
        local stepper = controls().steppers.depth
        for _ = 1, 6 do
            stepper.more:Run("OnClick")
        end
        assert.are.equal(5, ns.db.settings.depth)
        for _ = 1, 6 do
            stepper.less:Run("OnClick")
        end
        assert.are.equal(1, ns.db.settings.depth)
    end)

    it("changes how many crafts the tooltip lists", function()
        controls().steppers.tooltipCount.more:Run("OnClick")
        controls().steppers.tooltipShiftCount.less:Run("OnClick")
        assert.are.equal(3, ns.db.settings.tooltipCount)
        assert.are.equal(4, ns.db.settings.tooltipShiftCount)
    end)

    it("saves the TSM formula on Enter and trims it", function()
        controls().formula:SetText("  DBMinBuyout ")
        controls().formula:Run("OnEnterPressed")
        assert.are.equal("DBMinBuyout", ns.db.settings.tsmFormula)
    end)

    it("keeps the old formula when the box is emptied or Escape is pressed", function()
        controls().formula:SetText("")
        controls().formula:Run("OnEditFocusLost")
        assert.are.equal("DBMarket", ns.db.settings.tsmFormula)
        controls().formula:SetText("typo")
        controls().formula:Run("OnEscapePressed")
        assert.are.equal("DBMarket", controls().formula:GetText())
        assert.are.equal("DBMarket", ns.db.settings.tsmFormula)
    end)

    it("applies a changed setting to the next tooltip", function()
        for _ = 1, 10 do
            controls().steppers.cut.more:Run("OnClick")
        end
        local line = ns.View.TooltipLines(fixture.items.ORE, false)[4]
        assert.is_truthy(line.right:find("+11", 1, true))
    end)

    it("adds an entry to the game options on a newer client", function()
        local registered
        start(function()
            _G.Settings = {
                RegisterCanvasLayoutCategory = function(panel, name)
                    return { panel = panel, name = name }
                end,
                RegisterAddOnCategory = function(category)
                    registered = category
                end,
            }
        end)
        assert.are.equal("WarcraftBets", registered.name)
    end)

    it("adds an entry to the game options on an older client", function()
        local registered
        start(function()
            _G.InterfaceOptions_AddCategory = function(panel)
                registered = panel
            end
        end)
        assert.are.equal("WarcraftBets", registered.name)
    end)

    it("loads even when the options registration fails", function()
        assert.has_no.errors(function()
            start(function()
                _G.Settings = {
                    RegisterCanvasLayoutCategory = function()
                        error("changed API")
                    end,
                    RegisterAddOnCategory = function() end,
                }
            end)
        end)
    end)
end)
