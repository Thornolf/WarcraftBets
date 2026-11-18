local _, ns = ...

-- The items last opened in the window, most recent first, saved per account.
local History = {}
ns.History = History

local LIMIT = 10

--- Puts an item at the top of the recent list.
function History.Add(item)
    local recents = ns.db.recents
    for position = #recents, 1, -1 do
        if recents[position] == item then
            table.remove(recents, position)
        end
    end
    table.insert(recents, 1, item)
    while #recents > LIMIT do
        table.remove(recents)
    end
end

--- The recent items, most recent first.
function History.List()
    return ns.db.recents
end
