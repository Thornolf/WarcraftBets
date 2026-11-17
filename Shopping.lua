local _, ns = ...

local Shopping = {}
ns.Shopping = Shopping

local CALLER_ID = "WarcraftBets"

local function api()
    local v1 = Auctionator and Auctionator.API and Auctionator.API.v1
    return v1 and v1.CreateShoppingList and v1 or nil
end

--- Whether Auctionator is loaded and can take a shopping list.
function Shopping.IsAvailable()
    return api() ~= nil
end

--- Creates an Auctionator shopping list with what one craft needs from the
--- auction house, and says so in chat.
function Shopping.Create(use)
    local L, auctionator = ns.L, api()
    local terms = {}
    for _, purchase in ipairs(ns.Analysis.Engine():Purchases(use.recipe)) do
        local name = ns.Compat.ItemName(purchase.item)
        if name and auctionator.ConvertToSearchString then
            local term = { searchString = name, isExact = true, quantity = purchase.count }
            table.insert(terms, auctionator.ConvertToSearchString(CALLER_ID, term))
        elseif name then
            table.insert(terms, name)
        end
    end
    if #terms == 0 then
        ns:Print(L.SHOP_EMPTY)
        return
    end
    local listName = L.SHOP_LIST_NAME:format(ns.View.RecipeName(use.recipe))
    if pcall(auctionator.CreateShoppingList, CALLER_ID, listName, terms) then
        ns:Print(L.SHOP_CREATED:format(listName))
    else
        ns:Print(L.SHOP_FAILED)
    end
end
