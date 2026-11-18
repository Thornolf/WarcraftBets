local _, ns = ...

-- The favourites tab: followed items on the left with recent items under
-- them, followed crafts on the right.
local Page = {}

local MARGIN = 14
local HEADER_HEIGHT = 22
local ROW_HEIGHT = 32
local ITEM_ROWS, CRAFT_ROWS = 9, 15
local RECENT_ROWS, RECENT_ROW_HEIGHT = 6, 20

local label, colorTexture = ns.Widgets.Label, ns.Widgets.ColorTexture

local function header(parent, anchor, offset, title, hint)
    local band = colorTexture(parent, "BACKGROUND", 1, 1, 1, 0.06)
    band:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, offset)
    band:SetPoint("RIGHT", anchor, "RIGHT", 0, 0)
    band:SetHeight(HEADER_HEIGHT)
    local text = label(parent, "GameFontNormal")
    text:SetPoint("LEFT", band, "LEFT", 6, 0)
    text:SetText(title)
    if hint then
        local right = label(parent, "GameFontDisableSmall", "RIGHT")
        right:SetPoint("RIGHT", band, "RIGHT", -6, 0)
        right:SetText(hint)
    end
    return band
end

local function favoriteRow(column, position, top, onStar)
    local row = CreateFrame("Button", nil, column)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", column, "TOPLEFT", 0, top - (position - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", column, "RIGHT", 0, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.star = ns.Widgets.StarButton(row, 16)
    row.star:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.star:SetStarred(true)
    row.star:SetScript("OnClick", function()
        onStar(row.data)
    end)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", row.star, "RIGHT", 6, 0)
    row.profit = label(row, "GameFontHighlightSmall", "RIGHT")
    row.profit:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.name = label(row, "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 1)
    row.name:SetPoint("RIGHT", row.profit, "LEFT", -6, 0)
    row.detail = label(row, "GameFontDisableSmall")
    row.detail:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 6, -1)
    row.detail:SetPoint("RIGHT", row.profit, "LEFT", -6, 0)
    row:SetScript("OnClick", function(self)
        ns.Window:Open(self.data.item, self.data.recipe)
    end)
    return row
end

local function column(page, left, right)
    local frame = CreateFrame("Frame", nil, page)
    frame:SetPoint("TOPLEFT", page, left.point, left.x, -4)
    frame:SetPoint("BOTTOMRIGHT", page, right.point, right.x, MARGIN)
    return frame
end

--- Builds the favourites page once, when the window is first opened.
function Page.Build(page)
    local L = ns.L
    local items = column(page, { point = "TOPLEFT", x = MARGIN }, { point = "BOTTOM", x = -8 })
    local crafts = column(page, { point = "TOP", x = 8 }, { point = "BOTTOMRIGHT", x = -MARGIN })
    page.items, page.crafts = items, crafts

    header(items, items, 0, L.FAVORITE_ITEMS, L.FAVORITE_ITEMS_HINT)
    items.rows = {}
    for position = 1, ITEM_ROWS do
        items.rows[position] = favoriteRow(items, position, -HEADER_HEIGHT - 2, function(data)
            ns.Favorites.ToggleItem(data.item)
        end)
    end
    items.more = label(items, "GameFontDisableSmall")
    items.more:SetPoint("TOPLEFT", items, "TOPLEFT", 6, -HEADER_HEIGHT - 4 - ITEM_ROWS * ROW_HEIGHT)

    local recentsTop = -HEADER_HEIGHT - 22 - ITEM_ROWS * ROW_HEIGHT
    header(items, items, recentsTop, L.RECENTS)
    items.recents = {}
    for position = 1, RECENT_ROWS do
        local row = CreateFrame("Button", nil, items)
        row:SetHeight(RECENT_ROW_HEIGHT)
        local top = recentsTop - HEADER_HEIGHT - 2 - (position - 1) * RECENT_ROW_HEIGHT
        row:SetPoint("TOPLEFT", items, "TOPLEFT", 0, top)
        row:SetPoint("RIGHT", items, "RIGHT", 0, 0)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.star = row:CreateTexture(nil, "ARTWORK")
        row.star:SetSize(12, 12)
        row.star:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.name = label(row, "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", row.star, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row:SetScript("OnClick", function(self)
            ns.Window:Open(self.item)
        end)
        items.recents[position] = row
    end

    header(crafts, crafts, 0, L.FAVORITE_CRAFTS, L.FAVORITE_CRAFTS_HINT)
    crafts.rows = {}
    for position = 1, CRAFT_ROWS do
        crafts.rows[position] = favoriteRow(crafts, position, -HEADER_HEIGHT - 2, function(data)
            ns.Favorites.ToggleCraft(data.recipe)
        end)
    end
    crafts.more = label(crafts, "GameFontDisableSmall")
    crafts.more:SetPoint("TOPLEFT", crafts, "TOPLEFT", 6, -HEADER_HEIGHT - 4 - CRAFT_ROWS * ROW_HEIGHT)

    page.empty = label(page, "GameFontDisable", "CENTER")
    page.empty:SetPoint("TOP", crafts, "TOP", 0, -HEADER_HEIGHT - 40)
    page.empty:SetText(L.FAVORITES_EMPTY)
end

local function drawRows(list, data)
    local Compat = ns.Compat
    for position, row in ipairs(list.rows) do
        local entry = data[position]
        row.data = entry
        row:SetShown(entry ~= nil)
        if entry then
            local product = entry.product or (not entry.recipe and entry.item)
            row.icon:SetTexture(product and Compat.ItemIcon(product) or Compat.SpellIcon(entry.recipe))
            row.name:SetText(entry.name)
            row.detail:SetText(entry.detail)
            row.profit:SetText(entry.profit or "")
            row.profit:SetTextColor(unpack(entry.profitColor or ns.View.colors.grey))
        end
    end
    local hidden = #data - #list.rows
    list.more:SetShown(hidden > 0)
    list.more:SetText(ns.L.FAVORITES_MORE:format(hidden))
end

--- Redraws the favourites page from the saved favourites and recent items.
function Page.Draw(page)
    local items, crafts = ns.View.FavoriteItemRows(), ns.View.FavoriteCraftRows()
    drawRows(page.items, items)
    drawRows(page.crafts, crafts)
    page.empty:SetShown(#items == 0 and #crafts == 0)

    local recents = ns.History.List()
    for position, row in ipairs(page.items.recents) do
        local item = recents[position]
        row.item = item
        row:SetShown(item ~= nil)
        if item then
            row.name:SetText(ns.Compat.ItemName(item) or ns.L.LOADING)
            ns.Widgets.SetStar(row.star, ns.Favorites.HasItem(item))
        end
    end
end

ns.Window:RegisterPage("favorites", Page)
