local _, ns = ...

local Prices = {}
ns.Prices = Prices

local CALLER_ID = "WarcraftBets"

local function positive(value)
    if type(value) == "number" and value > 0 then
        return value
    end
end

local readers = {}

-- Other add-ons can throw on items they do not know; a broken price source
-- must read as "no price", never as an error in the tooltip.
function readers.tsm(itemID)
    local api = TSM_API
    if not (api and api.GetCustomPriceValue) then
        return nil
    end
    local ok, value = pcall(api.GetCustomPriceValue, ns.db.settings.tsmFormula, "i:" .. itemID)
    return ok and positive(value) or nil
end

function readers.auctionator(itemID)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not (api and api.GetAuctionPriceByItemID) then
        return nil
    end
    local ok, value = pcall(api.GetAuctionPriceByItemID, CALLER_ID, itemID)
    return ok and positive(value) or nil
end

local AUTO_ORDER = { "tsm", "auctionator" }

--- Auction house price of one item in copper, and the source it came from
--- ("tsm" or "auctionator"). Nil when no allowed source knows the item.
function Prices.Auction(itemID)
    local forced = ns.db.settings.priceSource
    if forced ~= "auto" then
        local value = readers[forced](itemID)
        return value, value and forced or nil
    end
    for _, source in ipairs(AUTO_ORDER) do
        local value = readers[source](itemID)
        if value then
            return value, source
        end
    end
    return nil
end

local TSM_PRESETS = { "DBMarket", "DBMinBuyout" }

--- Which TSM price the formula setting stands for: "DBMarket" (14-day market
--- value), "DBMinBuyout" (cheapest auction of the last scan), or nil for a
--- custom formula. TSM reads formulas without regard to case.
function Prices.FormulaPreset()
    local formula = ns.db.settings.tsmFormula:lower()
    for _, preset in ipairs(TSM_PRESETS) do
        if preset:lower() == formula then
            return preset
        end
    end
    return nil
end

--- Switches between market value and minimum buyout. A custom formula goes
--- back to the market value.
function Prices.ToggleFormulaPreset()
    ns:Set("tsmFormula", Prices.FormulaPreset() == "DBMarket" and "DBMinBuyout" or "DBMarket")
end

local function tsmValue(formula, itemID)
    local api = TSM_API
    if not (api and api.GetCustomPriceValue) then
        return nil
    end
    local ok, value = pcall(api.GetCustomPriceValue, formula, "i:" .. itemID)
    return ok and positive(value) or nil
end

local THOUSAND = 1000

--- How an item really sells in the region, from TSM: `perDay` (units sold a
--- day), `rate` (share of auctions that sell, 0 to 1), `average` (copper paid
--- on average) and `cheapest` (lowest auction of the last scan, may be nil).
--- Nil when TSM has no sale data for the item.
function Prices.SaleStats(itemID)
    -- TSM versions disagree on whether these two sources are already
    -- multiplied by 1000, and some round formula results to whole numbers.
    -- Asking for a thousand times the value survives rounding, and a sale
    -- rate above 1 gives away the versions that had already multiplied.
    local rate = tsmValue("DBRegionSaleRate*1000", itemID)
    local perDay = tsmValue("DBRegionSoldPerDay*1000", itemID)
    if not (rate and perDay) then
        return nil
    end
    local scale = rate > THOUSAND and THOUSAND * THOUSAND or THOUSAND
    return {
        rate = rate / scale,
        perDay = perDay / scale,
        average = tsmValue("DBRegionSaleAvg", itemID),
        cheapest = tsmValue("DBMinBuyout", itemID),
    }
end

--- Whether the add-on behind a price source is loaded.
function Prices.IsAvailable(source)
    if source == "tsm" then
        return TSM_API ~= nil and TSM_API.GetCustomPriceValue ~= nil
    end
    return Auctionator ~= nil and Auctionator.API ~= nil and Auctionator.API.v1 ~= nil
end

--- Vendor price of one unit in copper, from the vendors this account has
--- visited, else from the generated list. Nil when no vendor sells the item.
function Prices.Vendor(itemID)
    return ns.db.vendor[itemID] or ns.RecipeData.vendor[itemID]
end

local function merchantItem(slot)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(slot)
        if info then
            return info.price, info.stackCount, info.numAvailable, info.hasExtendedCost
        end
        return nil
    end
    local _, _, price, stackCount, numAvailable, _, _, extendedCost = GetMerchantItemInfo(slot)
    return price, stackCount, numAvailable, extendedCost
end

local UNLIMITED_STOCK = -1

--- Records the unit price of everything the open vendor sells for gold in
--- unlimited quantity. Limited stock is left out: it cannot feed a craft.
function Prices.ScanMerchant()
    local changed = false
    for slot = 1, GetMerchantNumItems() do
        local itemID = GetMerchantItemID(slot)
        local price, stackCount, numAvailable, extendedCost = merchantItem(slot)
        if itemID and positive(price) and numAvailable == UNLIMITED_STOCK and not extendedCost then
            local unit = math.max(1, math.floor(price / math.max(1, stackCount or 1)))
            if ns.db.vendor[itemID] ~= unit then
                ns.db.vendor[itemID] = unit
                changed = true
            end
        end
    end
    if changed then
        ns:Fire("PRICES_CHANGED")
    end
end

ns:On("MERCHANT_SHOW", Prices.ScanMerchant)
