local helpers = require("spec.helpers")

describe("money", function()
    local Money

    local function plain(text)
        return (text:gsub("|T.-UI%-(%a)%a+Icon.-|t", function(initial)
            return initial:lower()
        end))
    end

    before_each(function()
        local game = helpers.newGame("frFR")
        Money = game:Load("Locales/enUS.lua", "Locales/frFR.lua", "Core.lua", "Money.lua").Money
    end)

    it("splits copper into gold, silver and copper", function()
        assert.are.equal("1g 20s 5c", plain(Money.Format(12005)))
    end)

    it("leaves out empty denominations", function()
        assert.are.equal("1g", plain(Money.Format(10000)))
        assert.are.equal("78s", plain(Money.Format(7800)))
        assert.are.equal("0c", plain(Money.Format(0)))
    end)

    it("rounds fractions of a copper", function()
        assert.are.equal("1s 34c", plain(Money.Format(133.5)))
    end)

    it("signs profits", function()
        assert.are.equal("+13s", plain(Money.Signed(1300)))
        assert.are.equal("-1s 75c", plain(Money.Signed(-175)))
        assert.are.equal("-1s 75c", plain(Money.Format(-175)))
    end)

    it("writes plain text in the client language for chat", function()
        assert.are.equal("1po 20pa 5pc", Money.Text(12005))
        assert.are.equal("-78pa", Money.Text(-7800))
    end)
end)
