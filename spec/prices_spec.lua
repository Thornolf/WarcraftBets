local helpers = require("spec.helpers")

local COPPER_ORE, COARSE_THREAD, MOTE = 2770, 2320, 247786

describe("prices", function()
    local game, ns, Prices

    local function fakeTSM(prices)
        _G.TSM_API = {
            GetCustomPriceValue = function(formula, itemString)
                return prices[formula .. " " .. itemString]
            end,
        }
    end

    local function fakeAuctionator(prices)
        _G.Auctionator = {
            API = {
                v1 = {
                    GetAuctionPriceByItemID = function(caller, itemID)
                        assert(caller == "WarcraftBets")
                        return prices[itemID]
                    end,
                },
            },
        }
    end

    before_each(function()
        game = helpers.newGame()
        _G.TSM_API, _G.Auctionator, _G.C_MerchantFrame = nil, nil, nil
        ns = game:Load("Locales/enUS.lua", "Locales/frFR.lua", "Core.lua", "Data/Recipes.lua", "Prices.lua")
        game:Fire("ADDON_LOADED", "WarcraftBets")
        Prices = ns.Prices
    end)

    describe("in auto mode", function()
        it("prefers TSM", function()
            fakeTSM({ ["DBMarket i:2770"] = 600 })
            fakeAuctionator({ [COPPER_ORE] = 550 })
            assert.are.same({ 600, "tsm" }, { Prices.Auction(COPPER_ORE) })
        end)

        it("falls back to Auctionator when TSM has no price for the item", function()
            fakeTSM({})
            fakeAuctionator({ [COPPER_ORE] = 550 })
            assert.are.same({ 550, "auctionator" }, { Prices.Auction(COPPER_ORE) })
        end)

        it("falls back to Auctionator when TSM is not installed", function()
            fakeAuctionator({ [COPPER_ORE] = 550 })
            assert.are.same({ 550, "auctionator" }, { Prices.Auction(COPPER_ORE) })
        end)

        it("returns nothing when no source is installed", function()
            assert.is_nil(Prices.Auction(COPPER_ORE))
        end)

        it("returns nothing for an item no source knows", function()
            fakeTSM({})
            fakeAuctionator({})
            assert.is_nil(Prices.Auction(COPPER_ORE))
        end)
    end)

    describe("with a forced source", function()
        it("ignores the other source", function()
            fakeTSM({ ["DBMarket i:2770"] = 600 })
            fakeAuctionator({ [COPPER_ORE] = 550 })
            ns:Set("priceSource", "auctionator")
            assert.are.same({ 550, "auctionator" }, { Prices.Auction(COPPER_ORE) })
        end)

        it("does not fall back", function()
            fakeTSM({})
            fakeAuctionator({ [COPPER_ORE] = 550 })
            ns:Set("priceSource", "tsm")
            assert.is_nil(Prices.Auction(COPPER_ORE))
        end)
    end)

    it("uses the configured TSM formula", function()
        fakeTSM({ ["DBMinBuyout i:2770"] = 480 })
        ns:Set("tsmFormula", "DBMinBuyout")
        assert.are.equal(480, (Prices.Auction(COPPER_ORE)))
    end)

    it("treats zero and non-numeric prices as unknown", function()
        fakeTSM({ ["DBMarket i:2770"] = 0 })
        fakeAuctionator({ [COPPER_ORE] = "soon" })
        assert.is_nil(Prices.Auction(COPPER_ORE))
    end)

    it("survives a price add-on that throws", function()
        _G.TSM_API = {
            GetCustomPriceValue = function()
                error("invalid item")
            end,
        }
        fakeAuctionator({ [COPPER_ORE] = 550 })
        assert.are.same({ 550, "auctionator" }, { Prices.Auction(COPPER_ORE) })
    end)

    it("reports which sources are installed", function()
        assert.is_false(Prices.IsAvailable("tsm"))
        assert.is_false(Prices.IsAvailable("auctionator"))
        fakeTSM({})
        fakeAuctionator({})
        assert.is_true(Prices.IsAvailable("tsm"))
        assert.is_true(Prices.IsAvailable("auctionator"))
    end)

    describe("vendor prices", function()
        local stock

        before_each(function()
            _G.GetMerchantNumItems = function()
                return #stock
            end
            _G.GetMerchantItemID = function(slot)
                return stock[slot].id
            end
            _G.GetMerchantItemInfo = function(slot)
                local item = stock[slot]
                return "name", "icon", item.price, item.stack, item.available, true, true, item.extendedCost
            end
        end)

        it("come from the generated list", function()
            assert.are.equal(10, Prices.Vendor(COARSE_THREAD))
            assert.is_nil(Prices.Vendor(COPPER_ORE))
        end)

        it("are learned per unit from the vendors visited", function()
            stock = {
                { id = MOTE, price = 50, stack = 5, available = -1 },
                { id = COARSE_THREAD, price = 9, stack = 1, available = -1 },
            }
            local fired = 0
            ns:OnMessage("PRICES_CHANGED", function()
                fired = fired + 1
            end)
            game:Fire("MERCHANT_SHOW")
            assert.are.equal(10, Prices.Vendor(MOTE))
            assert.are.equal(9, Prices.Vendor(COARSE_THREAD))
            game:Fire("MERCHANT_SHOW")
            assert.are.equal(1, fired)
        end)

        it("skip limited stock and items bought with a currency", function()
            stock = {
                { id = MOTE, price = 50, stack = 1, available = 2 },
                { id = COPPER_ORE, price = 50, stack = 1, available = -1, extendedCost = true },
            }
            game:Fire("MERCHANT_SHOW")
            assert.is_nil(Prices.Vendor(MOTE))
            assert.is_nil(Prices.Vendor(COPPER_ORE))
        end)

        it("read the newer merchant API when the client has it", function()
            stock = { {} }
            _G.GetMerchantItemID = function()
                return MOTE
            end
            _G.C_MerchantFrame = {
                GetItemInfo = function()
                    return { price = 30, stackCount = 3, numAvailable = -1, hasExtendedCost = false }
                end,
            }
            game:Fire("MERCHANT_SHOW")
            assert.are.equal(10, Prices.Vendor(MOTE))
        end)
    end)
end)
