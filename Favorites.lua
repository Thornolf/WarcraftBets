local _, ns = ...

-- Items and crafts the player follows, saved per account in the order they
-- were added.
local Favorites = {}
ns.Favorites = Favorites

local function find(list, key, value)
    for position, entry in ipairs(list) do
        if entry[key] == value then
            return position
        end
    end
end

--- Whether an item is followed.
function Favorites.HasItem(item)
    return find(ns.db.favorites.items, "item", item) ~= nil
end

--- Whether a craft is followed.
function Favorites.HasCraft(recipe)
    return find(ns.db.favorites.crafts, "recipe", recipe) ~= nil
end

local function toggle(list, key, entry)
    local position = find(list, key, entry[key])
    if position then
        table.remove(list, position)
    else
        table.insert(list, entry)
    end
    ns:Fire("FAVORITES_CHANGED")
end

--- Follows an item, or stops following it.
function Favorites.ToggleItem(item)
    toggle(ns.db.favorites.items, "item", { item = item })
end

--- Follows a craft, or stops following it. `item` is the item the craft was
--- being studied from, so the craft can be opened again in the same view.
function Favorites.ToggleCraft(recipe, item)
    toggle(ns.db.favorites.crafts, "recipe", { recipe = recipe, item = item })
end

--- Followed items as { item = id }, oldest first.
function Favorites.Items()
    return ns.db.favorites.items
end

--- Followed crafts as { recipe = spell, item = id }, oldest first.
function Favorites.Crafts()
    return ns.db.favorites.crafts
end
