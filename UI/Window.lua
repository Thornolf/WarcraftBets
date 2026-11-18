local _, ns = ...

local Window = {}
ns.Window = Window

local FRAME_NAME = "WarcraftBetsFrame"
local WIDTH, HEIGHT = 880, 600
local MARGIN = 14
-- Tabs sit under the title bar; each tab's page starts below them, and the
-- offsets after it are measured from the top of the page.
local TAB_TOP, PAGE_TOP = 28, 56
local HEADER_TOP, CONTENT_TOP = 4, 52
local LIST_TOP = CONTENT_TOP + 46
local LIST_WIDTH = 330
local TABS = { "item", "explorer", "favorites" }
local RECENT_ROWS = 10
local RECENT_ROW_HEIGHT = 20
local FOCUS_LOST_HIDE_SECONDS = 0.2
local ROW_HEIGHT = 24
local VISIBLE_ROWS = 16
local SCROLLBAR_WIDTH = 14
local WHEEL_ROWS = 3
local MAX_REAGENTS = 8
local REAGENT_HEIGHT = 20
local ECONOMICS_ROWS = 5
local ECONOMICS_HEIGHT = 18
local NAME_REFRESH_SECONDS = 0.3
local GREEN = { 0.12, 1, 0 }

local frame
local state = { tab = "item", search = "", filter = "all", rows = {}, offset = 0 }

local label, colorTexture = ns.Widgets.Label, ns.Widgets.ColorTexture

-- Tab pages kept in their own files: each has Build(page) and Draw(page).
local pageModules = {}

--- Registers the module that builds and draws one tab's page.
function Window:RegisterPage(tab, module)
    pageModules[tab] = module
end

local function starTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine(button.starred and ns.L.STAR_REMOVE or ns.L.STAR_ADD, 1, 1, 1)
    GameTooltip:Show()
end

local function starButton(parent, size, onClick)
    local button = ns.Widgets.StarButton(parent, size)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", starTooltip)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return button
end

local function place(target)
    local saved = ns.db.window
    target:ClearAllPoints()
    if saved then
        target:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
    else
        target:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- Green veil shown while the window is dragged, so it is clear what moves
-- and where it will land.
local function buildDragOverlay(parent)
    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetAllPoints(parent)
    overlay:SetFrameLevel(parent:GetFrameLevel() + 50)
    colorTexture(overlay, "BACKGROUND", GREEN[1], GREEN[2], GREEN[3], 0.12):SetAllPoints(overlay)
    local edges = {
        { "TOPLEFT", "TOPRIGHT", nil, 2 },
        { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
        { "TOPLEFT", "BOTTOMLEFT", 2, nil },
        { "TOPRIGHT", "BOTTOMRIGHT", 2, nil },
    }
    for _, edge in ipairs(edges) do
        local line = colorTexture(overlay, "BORDER", GREEN[1], GREEN[2], GREEN[3], 1)
        line:SetPoint(edge[1], overlay, edge[1], 0, 0)
        line:SetPoint(edge[2], overlay, edge[2], 0, 0)
        if edge[3] then
            line:SetWidth(edge[3])
        else
            line:SetHeight(edge[4])
        end
    end
    local hint = label(overlay, "GameFontHighlightLarge", "CENTER")
    hint:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    hint:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
    hint:SetText(ns.L.DRAG_HINT)
    local plate = colorTexture(overlay, "ARTWORK", 0, 0, 0, 0.85)
    plate:SetPoint("TOPLEFT", hint, "TOPLEFT", -14, 8)
    plate:SetPoint("BOTTOMRIGHT", hint, "BOTTOMRIGHT", 14, -8)
    hint:SetDrawLayer("OVERLAY")
    overlay:Hide()
    return overlay
end

local function makeMovable(target, overlay)
    target:SetMovable(true)
    target:EnableMouse(true)
    target:SetClampedToScreen(true)
    target:RegisterForDrag("LeftButton")
    local function drop(self)
        self:StopMovingOrSizing()
        overlay:Hide()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        ns.db.window = { point = point, relativePoint = relativePoint, x = x, y = y }
    end
    target:SetScript("OnDragStart", function(self)
        self:StartMoving()
        overlay:Show()
    end)
    target:SetScript("OnDragStop", drop)
    target:SetScript("OnHide", function(self)
        -- Escape can close the window in the middle of a drag.
        if overlay:IsShown() then
            drop(self)
        end
        ns.lastItem = state.item or ns.lastItem
    end)
end

local function cycle(list, current, backwards)
    for position, value in ipairs(list) do
        if value == current then
            local nextPosition = position + (backwards and -1 or 1)
            return list[(nextPosition - 1) % #list + 1]
        end
    end
    return list[1]
end

local PRICE_SOURCES = { "auto", "tsm", "auctionator" }

local function buildHeader(parent, widgets)
    local slot = CreateFrame("Button", nil, parent)
    slot:SetSize(40, 40)
    slot:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, -HEADER_TOP)
    colorTexture(slot, "BACKGROUND", 1, 0.82, 0, 0.9):SetAllPoints(slot)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
    slot.icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
    slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local function takeCursorItem()
        local item = ns.Compat.CursorItem()
        if item then
            ClearCursor()
            Window:Open(item)
        end
    end
    slot:SetScript("OnReceiveDrag", takeCursorItem)
    slot:SetScript("OnClick", takeCursorItem)
    slot:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns.L.SLOT_HINT, 1, 1, 1)
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    widgets.slot = slot

    widgets.sourceButton = ns.Compat.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    widgets.sourceButton:SetSize(170, 22)
    widgets.sourceButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -MARGIN, -HEADER_TOP - 8)
    widgets.sourceButton:SetScript("OnClick", function()
        ns:Set("priceSource", cycle(PRICE_SOURCES, ns.db.settings.priceSource))
    end)

    widgets.formulaButton = ns.Compat.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    widgets.formulaButton:SetSize(170, 22)
    widgets.formulaButton:SetPoint("RIGHT", widgets.sourceButton, "LEFT", -6, 0)
    widgets.formulaButton:SetScript("OnClick", function()
        ns.Prices.ToggleFormulaPreset()
    end)

    widgets.itemStar = starButton(parent, 18, function()
        ns.Favorites.ToggleItem(state.item)
    end)
    widgets.itemStar:SetPoint("TOPLEFT", slot, "TOPRIGHT", 8, -2)

    widgets.name = label(parent, "GameFontNormalLarge")
    widgets.name:SetPoint("TOPLEFT", widgets.itemStar, "TOPRIGHT", 4, -1)
    widgets.name:SetPoint("RIGHT", widgets.formulaButton, "LEFT", -10, 0)

    widgets.summary = label(parent, "GameFontHighlightSmall")
    widgets.summary:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 10, 3)
    widgets.summary:SetPoint("RIGHT", widgets.formulaButton, "LEFT", -10, 0)
end

local function buildFilters(parent, widgets)
    local search = ns.Compat.CreateFrame("EditBox", nil, parent, "SearchBoxTemplate", "InputBoxTemplate")
    search:SetSize(140, 20)
    search:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN + 8, -CONTENT_TOP)
    search:SetAutoFocus(false)
    search:SetFontObject("ChatFontNormal")
    search:HookScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text ~= state.search then
            state.search, state.offset = text, 0
            Window:Refresh()
        end
    end)
    search:HookScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    widgets.search = search

    local filter = ns.Compat.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    filter:SetSize(LIST_WIDTH - 140 - 16, 22)
    filter:SetPoint("LEFT", search, "RIGHT", 8, 0)
    filter:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    filter:SetScript("OnClick", function(_, button)
        state.filter = cycle(ns.View.FILTERS, state.filter, button == "RightButton")
        state.offset = 0
        Window:Refresh()
    end)
    widgets.filter = filter

    local craftColumn = label(parent, "GameFontDisableSmall")
    craftColumn:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN + 6, -CONTENT_TOP - 28)
    craftColumn:SetText(ns.L.COLUMN_CRAFT)
    widgets.profitColumn = label(parent, "GameFontDisableSmall", "RIGHT")
    local right = MARGIN + LIST_WIDTH - SCROLLBAR_WIDTH - 8
    widgets.profitColumn:SetPoint("TOPRIGHT", parent, "TOPLEFT", right, -CONTENT_TOP - 28)
end

local function showRowTooltip(row)
    local product = row.data and row.data.use and row.data.use.recipe.product
    if product then
        ns.Compat.ShowItemTooltip(row, product)
    end
end

local function hideTooltip()
    GameTooltip:Hide()
end

local function buildRow(list, position)
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(position - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", list, "RIGHT", -SCROLLBAR_WIDTH - 2, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.selected = colorTexture(row, "BACKGROUND", 1, 0.82, 0, 0.18)
    row.selected:SetAllPoints(row)
    row.headerBand = colorTexture(row, "BACKGROUND", 1, 1, 1, 0.06)
    row.headerBand:SetAllPoints(row)
    row.header = label(row, "GameFontNormal")
    row.header:SetPoint("LEFT", row, "LEFT", 6, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.profit = label(row, "GameFontHighlightSmall", "RIGHT")
    row.profit:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.name = label(row, "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.profit, "LEFT", -6, 0)

    row:SetScript("OnClick", function(self)
        state.selected = self.data.use.recipe.id
        Window:Refresh()
    end)
    row:SetScript("OnEnter", showRowTooltip)
    row:SetScript("OnLeave", hideTooltip)
    return row
end

local function buildList(parent, widgets)
    local list = CreateFrame("Frame", nil, parent)
    list:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, -LIST_TOP)
    list:SetSize(LIST_WIDTH, VISIBLE_ROWS * ROW_HEIGHT)
    widgets.list = list

    widgets.rows = {}
    for position = 1, VISIBLE_ROWS do
        widgets.rows[position] = buildRow(list, position)
    end

    widgets.empty = label(list, "GameFontDisable", "CENTER")
    widgets.empty:SetPoint("TOP", list, "TOP", 0, -40)

    local bar = CreateFrame("Slider", nil, list)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(SCROLLBAR_WIDTH)
    bar:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 0)
    colorTexture(bar, "BACKGROUND", 0, 0, 0, 0.4):SetAllPoints(bar)
    bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetValue(0)
    bar:SetScript("OnValueChanged", function(_, value)
        local offset = math.floor(value + 0.5)
        if offset ~= state.offset then
            state.offset = offset
            Window:Refresh()
        end
    end)
    widgets.scrollbar = bar

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        local _, highest = bar:GetMinMaxValues()
        bar:SetValue(math.max(0, math.min(highest, state.offset - delta * WHEEL_ROWS)))
    end)
end

local function showReagentTooltip(row)
    ns.Compat.ShowItemTooltip(row, row.data.item)
    if #row.data.alternatives > 1 then
        GameTooltip:AddLine(" ")
        for _, alternative in ipairs(row.data.alternatives) do
            GameTooltip:AddDoubleLine(alternative.left, alternative.right, 1, 1, 1, 1, 1, 1)
        end
        GameTooltip:Show()
    end
end

local function buildDetail(parent, widgets)
    local detail = CreateFrame("Frame", nil, parent)
    detail:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN + LIST_WIDTH + 16, -CONTENT_TOP)
    detail:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -MARGIN, MARGIN)
    widgets.detail = detail

    widgets.noSelection = label(parent, "GameFontDisable", "CENTER")
    widgets.noSelection:SetPoint("CENTER", detail, "CENTER", 0, 0)
    widgets.noSelection:SetText(ns.L.SELECT_CRAFT)

    detail.icon = detail:CreateTexture(nil, "ARTWORK")
    detail.icon:SetSize(40, 40)
    detail.icon:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
    detail.star = starButton(detail, 18, function()
        ns.Favorites.ToggleCraft(detail.use.recipe.id, state.item)
    end)
    detail.star:SetPoint("TOPRIGHT", detail, "TOPRIGHT", 0, 0)
    detail.name = label(detail, "GameFontNormalLarge")
    detail.name:SetPoint("TOPLEFT", detail.icon, "TOPRIGHT", 10, 0)
    detail.name:SetPoint("RIGHT", detail.star, "LEFT", -6, 0)
    detail.skill = label(detail, "GameFontHighlightSmall")
    detail.skill:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -3)
    detail.state = label(detail, "GameFontHighlightSmall")
    detail.state:SetPoint("TOPLEFT", detail.skill, "BOTTOMLEFT", 0, -3)
    detail.state:SetPoint("RIGHT", detail, "RIGHT", 0, 0)

    local top = 56
    local reagentsTitle = label(detail, "GameFontNormal")
    reagentsTitle:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -top)
    reagentsTitle:SetText(ns.L.REAGENTS)
    top = top + 20

    detail.reagents = {}
    for position = 1, MAX_REAGENTS do
        local row = CreateFrame("Button", nil, detail)
        row:SetHeight(REAGENT_HEIGHT)
        row:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -top - (position - 1) * REAGENT_HEIGHT)
        row:SetPoint("RIGHT", detail, "RIGHT", 0, 0)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.cost = label(row, "GameFontHighlightSmall", "RIGHT")
        row.cost:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row.label = label(row, "GameFontHighlight")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.label:SetPoint("RIGHT", row.cost, "LEFT", -6, 0)
        row:SetScript("OnClick", function(self)
            Window:Open(self.data.item)
        end)
        row:SetScript("OnEnter", showReagentTooltip)
        row:SetScript("OnLeave", hideTooltip)
        detail.reagents[position] = row
    end
    top = top + MAX_REAGENTS * REAGENT_HEIGHT + 10

    local economicsTitle = label(detail, "GameFontNormal")
    economicsTitle:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -top)
    economicsTitle:SetText(ns.L.PROFITABILITY)
    top = top + 20

    detail.economics = {}
    for position = 1, ECONOMICS_ROWS do
        local row = {}
        row.label = label(detail, "GameFontHighlightSmall")
        row.label:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -top - (position - 1) * ECONOMICS_HEIGHT)
        row.value = label(detail, "GameFontHighlightSmall", "RIGHT")
        row.value:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -2, -top - (position - 1) * ECONOMICS_HEIGHT)
        detail.economics[position] = row
    end
    top = top + ECONOMICS_ROWS * ECONOMICS_HEIGHT + 10

    local sourceTitle = label(detail, "GameFontNormal")
    sourceTitle:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -top)
    sourceTitle:SetText(ns.L.PRICE_SOURCE)
    detail.source = label(detail, "GameFontHighlightSmall")
    detail.source:SetPoint("TOPLEFT", sourceTitle, "BOTTOMLEFT", 0, -4)
    detail.source:SetPoint("RIGHT", detail, "RIGHT", 0, 0)

    detail.linkButton = ns.Compat.CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    detail.linkButton:SetSize(140, 22)
    detail.linkButton:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", 0, 0)
    detail.linkButton:SetText(ns.L.BUTTON_LINK)
    detail.linkButton:SetScript("OnClick", function()
        ns.Compat.InsertInChat(ns.View.ChatText(detail.use))
    end)

    detail.shopButton = ns.Compat.CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    detail.shopButton:SetSize(140, 22)
    detail.shopButton:SetPoint("RIGHT", detail.linkButton, "LEFT", -8, 0)
    detail.shopButton:SetText(ns.L.BUTTON_SHOP)
    detail.shopButton:SetScript("OnClick", function()
        ns.Shopping.Create(detail.use)
    end)
end

local function buildTabs(parent, widgets)
    widgets.tabs, widgets.pages = {}, {}
    local previous
    for _, tab in ipairs(TABS) do
        local button = ns.Compat.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetSize(110, 22)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
        else
            button:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, -TAB_TOP)
        end
        button:SetText(ns.L["TAB_" .. tab])
        button:SetScript("OnClick", function()
            Window:ShowTab(tab)
        end)
        widgets.tabs[tab], previous = button, button

        local page = CreateFrame("Frame", nil, parent)
        page:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -PAGE_TOP)
        page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        widgets.pages[tab] = page
    end
    for tab, page in pairs(widgets.pages) do
        if pageModules[tab] then
            pageModules[tab].Build(page)
        elseif tab ~= "item" then
            local soon = label(page, "GameFontDisable", "CENTER")
            soon:SetPoint("CENTER", page, "CENTER", 0, 0)
            soon:SetText(ns.L.TAB_COMING)
        end
    end
end

local function openFromText(text)
    local item = ns.Compat.ItemFromText(text)
    if item then
        Window:Open(item)
    else
        ns:Print(ns.L.ITEM_NOT_FOUND:format(text))
    end
end

-- The item field in the tab row: type a name or paste a link, or pick one of
-- the recent items listed under it while it has focus.
local function buildItemField(parent, widgets)
    local field = ns.Compat.CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    field:SetSize(200, 20)
    field:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -MARGIN, -TAB_TOP - 1)
    field:SetAutoFocus(false)
    field:SetFontObject("ChatFontNormal")
    widgets.itemField = field

    local caption = label(parent, "GameFontNormalSmall", "RIGHT")
    caption:SetPoint("RIGHT", field, "LEFT", -10, 0)
    caption:SetText(ns.L.ITEM_FIELD)

    local recents = CreateFrame("Frame", nil, parent)
    recents:SetFrameLevel(parent:GetFrameLevel() + 30)
    recents:SetPoint("TOPRIGHT", field, "BOTTOMRIGHT", 0, -2)
    recents:SetSize(206, 0)
    recents:EnableMouse(true)
    colorTexture(recents, "BACKGROUND", 0.04, 0.04, 0.1, 0.97):SetAllPoints(recents)
    recents.title = label(recents, "GameFontNormalSmall")
    recents.title:SetPoint("TOPLEFT", recents, "TOPLEFT", 8, -6)
    recents.rows = {}
    for position = 1, RECENT_ROWS do
        local row = CreateFrame("Button", nil, recents)
        row:SetHeight(RECENT_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", recents, "TOPLEFT", 4, -22 - (position - 1) * RECENT_ROW_HEIGHT)
        row:SetPoint("RIGHT", recents, "RIGHT", -4, 0)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.star = row:CreateTexture(nil, "ARTWORK")
        row.star:SetSize(12, 12)
        row.star:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.name = label(row, "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", row.star, "RIGHT", 4, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row:SetScript("OnClick", function(self)
            field:ClearFocus()
            recents:Hide()
            Window:Open(self.item)
        end)
        recents.rows[position] = row
    end
    recents:Hide()
    widgets.recents = recents

    field:SetScript("OnEditFocusGained", function(self)
        -- Selecting the current name lets the first keystroke replace it.
        self:HighlightText()
        local items = ns.History.List()
        recents.title:SetText(#items > 0 and ns.L.RECENTS or ns.L.NO_RECENTS)
        for position, row in ipairs(recents.rows) do
            local item = items[position]
            row.item = item
            row:SetShown(item ~= nil)
            if item then
                row.name:SetText(ns.Compat.ItemName(item) or ns.L.LOADING)
                ns.Widgets.SetStar(row.star, ns.Favorites.HasItem(item))
            end
        end
        recents:SetHeight(28 + #items * RECENT_ROW_HEIGHT)
        recents:Show()
    end)
    -- A click on a recent item takes the focus away before it lands; hiding
    -- the list at once would swallow that click.
    field:SetScript("OnEditFocusLost", function()
        C_Timer.After(FOCUS_LOST_HIDE_SECONDS, function()
            if not field:HasFocus() then
                recents:Hide()
            end
        end)
    end)
    field:SetScript("OnEnterPressed", function(self)
        local text = (self:GetText() or ""):match("^%s*(.-)%s*$")
        self:ClearFocus()
        recents:Hide()
        if text ~= "" then
            openFromText(text)
        end
    end)
    field:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        recents:Hide()
    end)
end

local function build()
    local Compat = ns.Compat
    local window = Compat.CreateFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(WIDTH, HEIGHT)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:Hide()

    if window.SetTitle then
        window:SetTitle("WarcraftBets")
    elseif window.TitleText then
        window.TitleText:SetText("WarcraftBets")
    else
        local title = label(window, "GameFontNormal", "CENTER")
        title:SetPoint("TOP", window, "TOP", 0, -6)
        title:SetText("WarcraftBets")
    end
    if not window.CloseButton then
        -- No native panel template on this client: draw a plain dark panel.
        colorTexture(window, "BACKGROUND", 0.05, 0.05, 0.05, 0.95):SetAllPoints(window)
        local close = Compat.CreateFrame("Button", nil, window, "UIPanelCloseButton")
        close:SetSize(24, 24)
        close:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
        close:SetScript("OnClick", function()
            window:Hide()
        end)
    end

    local widgets = {}
    window.widgets = widgets
    widgets.dragOverlay = buildDragOverlay(window)
    makeMovable(window, widgets.dragOverlay)
    buildTabs(window, widgets)
    buildItemField(window, widgets)
    local page = widgets.pages.item
    buildHeader(page, widgets)
    buildFilters(page, widgets)
    buildList(page, widgets)
    buildDetail(page, widgets)

    place(window)
    table.insert(UISpecialFrames, FRAME_NAME)
    return window
end

local function drawHeader(widgets)
    local L, Compat = ns.L, ns.Compat
    local item = state.item
    widgets.sourceButton:SetText(L.PRICE_BUTTON:format(L["SOURCE_" .. ns.db.settings.priceSource]))
    widgets.formulaButton:SetText(ns.View.FormulaLabel())
    widgets.formulaButton:SetShown(ns.Prices.IsAvailable("tsm"))
    widgets.filter:SetText(L["FILTER_" .. state.filter])
    widgets.itemStar:SetShown(item ~= nil)
    if not item then
        widgets.slot.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        widgets.name:SetText(L.NO_ITEM)
        widgets.summary:SetText("")
        widgets.profitColumn:SetText("")
        widgets.itemField:SetText("")
        return
    end
    local name = Compat.ItemName(item) or L.LOADING
    widgets.slot.icon:SetTexture(Compat.ItemIcon(item))
    widgets.name:SetText(name)
    widgets.profitColumn:SetText(L.COLUMN_PROFIT_PER:format(name))
    widgets.itemStar:SetStarred(ns.Favorites.HasItem(item))
    if not widgets.itemField:HasFocus() then
        widgets.itemField:SetText(name)
    end
    local parts = {}
    for _, line in ipairs(ns.View.PriceLines(item)) do
        table.insert(parts, line.left .. " " .. line.right)
    end
    widgets.summary:SetText(table.concat(parts, "     "))
end

local function drawRow(row, data)
    row.data = data
    if not data then
        row:Hide()
        return
    end
    row:Show()
    local isHeader = data.header ~= nil
    row:EnableMouse(not isHeader)
    row.header:SetShown(isHeader)
    row.headerBand:SetShown(isHeader)
    row.icon:SetShown(not isHeader)
    row.name:SetShown(not isHeader)
    row.profit:SetShown(not isHeader)
    if isHeader then
        row.selected:Hide()
        row.header:SetText(data.header)
        return
    end
    local use, Compat, colors = data.use, ns.Compat, ns.View.colors
    local product = use.recipe.product
    row.selected:SetShown(use.recipe.id == state.selected)
    row.icon:SetTexture(product and Compat.ItemIcon(product) or Compat.SpellIcon(use.recipe.id))
    row.icon:SetDesaturated(not data.status.known)
    row.name:SetText(data.name)
    if not data.status.known then
        row.name:SetTextColor(unpack(colors.unlearned))
    elseif product then
        row.name:SetTextColor(Compat.ItemQualityColor(product))
    else
        row.name:SetTextColor(unpack(colors.white))
    end
    if use.sellable then
        local text, color = ns.View.ProfitText(use.profitPerUnit)
        row.profit:SetText(text)
        row.profit:SetTextColor(unpack(color))
    else
        row.profit:SetText(use.cost and ns.Money.Format(use.cost) or ns.L.UNKNOWN_PRICE)
        row.profit:SetTextColor(unpack(colors.grey))
    end
end

local function drawDetail(widgets, selectedRow)
    local detail = widgets.detail
    detail:SetShown(selectedRow ~= nil)
    widgets.noSelection:SetShown(selectedRow == nil and #state.rows > 0)
    if not selectedRow then
        return
    end
    local Compat, colors = ns.Compat, ns.View.colors
    local use = selectedRow.use
    local product = use.recipe.product
    local view = ns.View.Detail(use, state.item)

    detail.icon:SetTexture(product and Compat.ItemIcon(product) or Compat.SpellIcon(use.recipe.id))
    detail.icon:SetDesaturated(not view.known)
    detail.name:SetText(view.name)
    detail.star:SetStarred(ns.Favorites.HasCraft(use.recipe.id))
    detail.skill:SetText(view.skill)
    detail.state:SetText(view.state)
    detail.state:SetTextColor(unpack(view.stateColor))

    for position, row in ipairs(detail.reagents) do
        local reagent = view.reagents[position]
        row.data = reagent
        row:SetShown(reagent ~= nil)
        if reagent then
            row.icon:SetTexture(Compat.ItemIcon(reagent.item))
            row.label:SetText(reagent.label)
            row.cost:SetText(reagent.origin and (reagent.cost .. "  " .. reagent.origin) or reagent.cost)
        end
    end

    for position, row in ipairs(detail.economics) do
        local entry = view.economics[position]
        row.label:SetShown(entry ~= nil)
        row.value:SetShown(entry ~= nil)
        if entry then
            local font = entry.strong and "GameFontNormal" or "GameFontHighlightSmall"
            row.label:SetFontObject(font)
            row.value:SetFontObject(font)
            row.label:SetText(entry.label)
            row.label:SetTextColor(unpack(colors.white))
            row.value:SetText(entry.value)
            row.value:SetTextColor(unpack(entry.color))
        end
    end

    detail.source:SetText(ns.View.PriceSourceText())
    detail.use = use
    detail.shopButton:SetShown(ns.Shopping.IsAvailable())
end

--- Redraws the window from the current item, search, filter and selection.
function Window:Refresh()
    if not (frame and frame:IsShown()) then
        return
    end
    local widgets = frame.widgets
    for tab, page in pairs(widgets.pages) do
        page:SetShown(tab == state.tab)
        if tab == state.tab then
            widgets.tabs[tab]:LockHighlight()
        else
            widgets.tabs[tab]:UnlockHighlight()
        end
    end
    if pageModules[state.tab] then
        pageModules[state.tab].Draw(widgets.pages[state.tab])
    end
    drawHeader(widgets)

    state.rows = state.item and ns.View.ListRows(state.item, state.search, state.filter) or {}
    local selectedRow, firstCraft
    for _, row in ipairs(state.rows) do
        if row.use then
            firstCraft = firstCraft or row
            if row.use.recipe.id == state.selected then
                selectedRow = row
            end
        end
    end
    selectedRow = selectedRow or firstCraft
    state.selected = selectedRow and selectedRow.use.recipe.id or nil

    local highest = math.max(0, #state.rows - VISIBLE_ROWS)
    state.offset = math.min(state.offset, highest)
    widgets.scrollbar:SetMinMaxValues(0, highest)
    widgets.scrollbar:SetValue(state.offset)
    widgets.scrollbar:SetShown(highest > 0)
    for position, row in ipairs(widgets.rows) do
        drawRow(row, state.rows[position + state.offset])
    end

    local hasFilter = state.search ~= "" or state.filter ~= "all"
    widgets.empty:SetShown(state.item ~= nil and #state.rows == 0)
    widgets.empty:SetText(hasFilter and ns.L.EMPTY_LIST or ns.L.NO_USES)
    drawDetail(widgets, selectedRow)
end

--- Opens the window on an item, or on the item it last showed when nil.
--- `recipe` selects one of the item's crafts.
function Window:Open(item, recipe)
    if ns.Compat.InCombat() then
        ns:Print(ns.L.IN_COMBAT)
        return
    end
    frame = frame or build()
    if item then
        ns.History.Add(item)
        state.tab = "item"
    end
    if item and item ~= state.item then
        state.item, state.offset, state.selected = item, 0, nil
        frame.widgets.search:SetText("")
        state.search = ""
    end
    state.selected = recipe or state.selected
    frame:Show()
    Window:Refresh()
end

--- Switches the window to one of its tabs: "item", "explorer" or "favorites".
function Window:ShowTab(tab)
    state.tab = tab
    Window:Refresh()
end

--- Closes the window if it is open, else opens it on the last hovered item.
function Window:Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        Window:Open(ns.lastItem)
    end
end

--- Forgets the saved position and moves the window back to the centre.
function Window:ResetPosition()
    ns.db.window = nil
    if frame then
        place(frame)
    end
end

ns:RegisterCommand("", function()
    Window:Toggle()
end)

ns:RegisterCommand("reset", function()
    Window:ResetPosition()
end)

ns:RegisterCommand("*", openFromText)

-- With the window open, a Shift-click on an item studies it; with the chat
-- box open, the click keeps its usual meaning and links the item there.
ns.Compat.OnChatLink(function(link)
    if not (frame and frame:IsShown()) or ns.Compat.ChatIsActive() or ns.Compat.InCombat() then
        return
    end
    local item = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if item then
        Window:Open(item)
    end
end)

ns:On("PLAYER_REGEN_DISABLED", function()
    if frame then
        frame:Hide()
    end
end)

local refreshQueued = false

-- Item names arrive from the server one event at a time; one redraw per
-- burst is enough.
ns:On("GET_ITEM_INFO_RECEIVED", function()
    if refreshQueued or not (frame and frame:IsShown()) then
        return
    end
    refreshQueued = true
    C_Timer.After(NAME_REFRESH_SECONDS, function()
        refreshQueued = false
        Window:Refresh()
    end)
end)

ns:OnMessage("ANALYSIS_CHANGED", function()
    Window:Refresh()
end)

ns:OnMessage("LEARNED_CHANGED", function()
    Window:Refresh()
end)

ns:OnMessage("FAVORITES_CHANGED", function()
    Window:Refresh()
end)
