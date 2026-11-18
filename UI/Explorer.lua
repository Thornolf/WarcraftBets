local _, ns = ...

-- The explore tab: a table of the crafts that pay and really sell.
local Page = {}

local MARGIN = 14
local FILTER_WIDTH = 205
local TABLE_TOP = 52
local ROW_HEIGHT = 24
local VISIBLE_ROWS = 17
local SCROLLBAR_WIDTH = 14
local WHEEL_ROWS = 3
local PER_DAY_STEPS = { 0, 1, 2, 5, 10, 20, 50 }
local RATE_STEPS = { 0, 10, 20, 30, 40, 50, 60, 70, 80, 90 }

-- Right edge of each numeric column, measured from the right of the table.
local COLUMNS = {
    { key = "profit", title = "EXPLORER_COLUMN_PROFIT", right = 345, sortable = true },
    { key = "price", title = "EXPLORER_COLUMN_PRICE", right = 245 },
    { key = "perDay", title = "EXPLORER_COLUMN_PER_DAY", right = 185 },
    { key = "rate", title = "EXPLORER_COLUMN_RATE", right = 130 },
    { key = "profitPerDay", title = "EXPLORER_COLUMN_DAILY", right = 22, sortable = true },
}
local SKILL_RIGHT, SKILL_WIDTH = 445, 100

local label, colorTexture = ns.Widgets.Label, ns.Widgets.ColorTexture

local view = { rows = {}, offset = 0 }
local built

local function cycle(list, current, backwards)
    for position, value in ipairs(list) do
        if value == current then
            return list[(position + (backwards and -2 or 0)) % #list + 1]
        end
    end
    return list[1]
end

local function button(parent, width, text)
    local control = ns.Compat.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(width, 22)
    control:SetText(text or "")
    return control
end

local function filterSlot(page, position, caption)
    local left = MARGIN + (position - 1) * (FILTER_WIDTH + 8)
    local text = label(page, "GameFontNormalSmall")
    text:SetPoint("TOPLEFT", page, "TOPLEFT", left, -4)
    text:SetText(caption)
    return left
end

local function cycleFilter(page, position, caption, list, setting)
    local left = filterSlot(page, position, caption)
    local control = button(page, FILTER_WIDTH)
    control:SetPoint("TOPLEFT", page, "TOPLEFT", left, -20)
    control:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    control:SetScript("OnClick", function(_, mouseButton)
        ns:Set(setting, cycle(list, ns.db.settings[setting], mouseButton == "RightButton"))
    end)
    return control
end

local function stepFilter(page, position, caption, steps, setting)
    local left = filterSlot(page, position, caption)
    local stepper = {}
    stepper.less = button(page, 24, "-")
    stepper.less:SetPoint("TOPLEFT", page, "TOPLEFT", left, -20)
    stepper.more = button(page, 24, "+")
    stepper.more:SetPoint("TOPLEFT", page, "TOPLEFT", left + FILTER_WIDTH - 24, -20)
    stepper.value = label(page, "GameFontHighlight", "CENTER")
    stepper.value:SetPoint("LEFT", stepper.less, "RIGHT", 0, 0)
    stepper.value:SetPoint("RIGHT", stepper.more, "LEFT", 0, 0)
    local function move(direction)
        local current = ns.db.settings[setting]
        local target = current
        for position2 = direction > 0 and 1 or #steps, direction > 0 and #steps or 1, direction do
            local candidate = steps[position2]
            if (direction > 0 and candidate > current) or (direction < 0 and candidate < current) then
                target = candidate
                break
            end
        end
        if target ~= current then
            ns:Set(setting, target)
        end
    end
    stepper.less:SetScript("OnClick", function()
        move(-1)
    end)
    stepper.more:SetScript("OnClick", function()
        move(1)
    end)
    return stepper
end

local function buildRow(list, position)
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(position - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", list, "RIGHT", -SCROLLBAR_WIDTH - 2, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.star = ns.Widgets.StarButton(row, 16)
    row.star:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.star:SetScript("OnClick", function()
        local recipe = row.data.recipe
        ns.Favorites.ToggleCraft(recipe.id, recipe.reagents[1].item)
    end)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row.star, "RIGHT", 6, 0)
    row.values = {}
    for _, column in ipairs(COLUMNS) do
        local value = label(row, "GameFontHighlightSmall", "RIGHT")
        value:SetPoint("RIGHT", row, "RIGHT", -column.right + SCROLLBAR_WIDTH + 2, 0)
        row.values[column.key] = value
    end
    row.skill = label(row, "GameFontDisableSmall")
    row.skill:SetPoint("RIGHT", row, "RIGHT", -SKILL_RIGHT + SCROLLBAR_WIDTH + 2, 0)
    row.skill:SetWidth(SKILL_WIDTH)
    row.name = label(row, "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.skill, "LEFT", -6, 0)
    row:SetScript("OnClick", function(self)
        local recipe = self.data.recipe
        ns.Window:Open(recipe.reagents[1].item, recipe.id)
    end)
    row:SetScript("OnEnter", function(self)
        ns.Compat.ShowItemTooltip(self, self.data.recipe.product)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns.L.EXPLORER_ROW_HINT, 0.62, 0.62, 0.62)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return row
end

--- Builds the explore page once, when the window is first opened.
function Page.Build(page)
    local L = ns.L
    built = page
    page.filter = cycleFilter(page, 1, L.EXPLORER_RECIPES, ns.View.FILTERS, "explorerFilter")
    page.mode = cycleFilter(page, 2, L.MODE_LABEL, ns.Analysis.MODES, "costMode")
    page.perDay = stepFilter(page, 3, L.EXPLORER_MIN_PER_DAY, PER_DAY_STEPS, "explorerMinPerDay")
    page.rate = stepFilter(page, 4, L.EXPLORER_MIN_RATE, RATE_STEPS, "explorerMinRate")

    local list = CreateFrame("Frame", nil, page)
    list:SetPoint("TOPLEFT", page, "TOPLEFT", MARGIN, -TABLE_TOP - 22)
    list:SetPoint("RIGHT", page, "RIGHT", -MARGIN, 0)
    list:SetHeight(VISIBLE_ROWS * ROW_HEIGHT)
    page.list = list

    local band = colorTexture(page, "BACKGROUND", 1, 1, 1, 0.06)
    band:SetPoint("TOPLEFT", page, "TOPLEFT", MARGIN, -TABLE_TOP)
    band:SetPoint("RIGHT", page, "RIGHT", -MARGIN, 0)
    band:SetHeight(20)
    local craftTitle = label(page, "GameFontNormalSmall")
    craftTitle:SetPoint("LEFT", band, "LEFT", 52, 0)
    craftTitle:SetText(L.EXPLORER_COLUMN_CRAFT)
    local skillTitle = label(page, "GameFontNormalSmall")
    skillTitle:SetPoint("LEFT", band, "RIGHT", -SKILL_RIGHT - SKILL_WIDTH, 0)
    skillTitle:SetText(L.EXPLORER_COLUMN_SKILL)
    page.headers = {}
    for _, column in ipairs(COLUMNS) do
        local header = CreateFrame("Button", nil, page)
        header:SetSize(100, 20)
        header:SetPoint("RIGHT", band, "RIGHT", -column.right, 0)
        header.text = label(header, "GameFontNormalSmall", "RIGHT")
        header.text:SetPoint("RIGHT", header, "RIGHT", 0, 0)
        if column.sortable then
            header:SetScript("OnClick", function()
                -- Sorting needs no new scan, so it bypasses the settings message.
                ns.db.settings.explorerSort = column.key
                view.offset = 0
                Page.Draw(page)
            end)
        else
            header:EnableMouse(false)
        end
        page.headers[column.key] = header
    end

    page.rows = {}
    for position = 1, VISIBLE_ROWS do
        page.rows[position] = buildRow(list, position)
    end

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
        if offset ~= view.offset then
            view.offset = offset
            Page.Draw(page)
        end
    end)
    page.scrollbar = bar
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        local _, highest = bar:GetMinMaxValues()
        bar:SetValue(math.max(0, math.min(highest, view.offset - delta * WHEEL_ROWS)))
    end)

    page.message = label(page, "GameFontDisable", "CENTER")
    page.message:SetPoint("TOP", list, "TOP", 0, -60)
    page.message:SetPoint("LEFT", list, "LEFT", 20, 0)
    page.message:SetPoint("RIGHT", list, "RIGHT", -20, 0)
    page.message:SetWordWrap(true)

    page.progress = label(page, "GameFontHighlightSmall")
    page.progress:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", MARGIN, MARGIN + 16)
    page.discarded = label(page, "GameFontDisableSmall")
    page.discarded:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", MARGIN, MARGIN)
    page.refresh = button(page, 120, L.EXPLORER_REFRESH)
    page.refresh:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -MARGIN, MARGIN)
    page.refresh:SetScript("OnClick", function()
        ns.Explorer.Scan()
    end)
end

local function drawRow(row, entry)
    row.data = entry
    row:SetShown(entry ~= nil)
    if not entry then
        return
    end
    local L, Money, colors = ns.L, ns.Money, ns.View.colors
    local recipe = entry.recipe
    local known = ns.Learned.Status(recipe).known
    row.star:SetStarred(ns.Favorites.HasCraft(recipe.id))
    row.icon:SetTexture(ns.Compat.ItemIcon(recipe.product))
    row.icon:SetDesaturated(not known)
    row.name:SetText(ns.View.RecipeName(recipe))
    row.name:SetTextColor(unpack(known and colors.white or colors.unlearned))
    row.skill:SetText(ns.Learned.ProfessionName(recipe.skill))
    row.values.profit:SetText(Money.Signed(entry.profit))
    row.values.profit:SetTextColor(unpack(colors.gain))
    row.values.price:SetText(Money.Format(entry.price))
    row.values.perDay:SetText((("%.1f"):format(entry.perDay):gsub("%.", L.DECIMAL_SEPARATOR)))
    row.values.rate:SetText(L.EXPLORER_RATE_VALUE:format(math.floor(entry.rate * 100 + 0.5)))
    row.values.profitPerDay:SetText(Money.Signed(entry.profitPerDay))
    row.values.profitPerDay:SetTextColor(unpack(colors.gain))
end

local function messageFor(scan)
    local L = ns.L
    if scan.unavailable then
        return L.EXPLORER_NO_TSM
    end
    if scan.running or #scan.results > 0 then
        return nil
    end
    -- Nothing kept and nothing rejected on its sales: TSM gave no sale data at all.
    local discarded = scan.discarded
    if discarded.unpriced > 0 and discarded.slow == 0 and discarded.loss == 0 then
        return L.EXPLORER_NO_DATA
    end
    return L.EXPLORER_EMPTY
end

--- Redraws the explore page, starting a scan first if the last one is out of date.
function Page.Draw(page)
    local L, settings = ns.L, ns.db.settings
    ns.Explorer.EnsureFresh()
    local scan = ns.Explorer.State()

    page.filter:SetText(L["FILTER_" .. settings.explorerFilter])
    page.mode:SetText(L["MODE_" .. settings.costMode])
    page.perDay.value:SetText(L.EXPLORER_PER_DAY_VALUE:format(settings.explorerMinPerDay))
    page.rate.value:SetText(L.EXPLORER_RATE_VALUE:format(settings.explorerMinRate))
    for _, column in ipairs(COLUMNS) do
        local title = L[column.title]
        local sorted = column.key == settings.explorerSort
        page.headers[column.key].text:SetText(sorted and L.EXPLORER_SORT_MARK:format(title) or title)
        page.headers[column.key].text:SetTextColor(unpack(sorted and { 1, 1, 1 } or { 1, 0.82, 0 }))
    end

    view.rows = ns.Explorer.Sorted(settings.explorerSort)
    local highest = math.max(0, #view.rows - VISIBLE_ROWS)
    view.offset = math.min(view.offset, highest)
    page.scrollbar:SetMinMaxValues(0, highest)
    page.scrollbar:SetValue(view.offset)
    page.scrollbar:SetShown(highest > 0)
    for position, row in ipairs(page.rows) do
        drawRow(row, view.rows[position + view.offset])
    end

    local message = messageFor(scan)
    page.message:SetShown(message ~= nil)
    page.message:SetText(message or "")

    local kept = #scan.results
    if scan.running then
        page.progress:SetText(L.EXPLORER_PROGRESS:format(scan.done, scan.total, kept))
    else
        page.progress:SetText(L.EXPLORER_DONE:format(scan.done, kept))
    end
    local discarded = scan.discarded
    page.discarded:SetText(L.EXPLORER_DISCARDED:format(discarded.slow, discarded.unpriced, discarded.loss))
end

ns.Window:RegisterPage("explorer", Page)

-- Scan progress and favourite changes redraw the page only while it is on
-- screen; a hidden page catches up when its tab is opened.
local function redrawIfVisible()
    if built and ns.Window:IsShowing("explorer") then
        Page.Draw(built)
    end
end

ns:OnMessage("EXPLORER_CHANGED", redrawIfVisible)
