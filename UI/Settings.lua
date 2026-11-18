local _, ns = ...

local SettingsWindow = {}
ns.SettingsWindow = SettingsWindow

local FRAME_NAME = "WarcraftBetsSettingsFrame"
local WIDTH, HEIGHT = 420, 332
local MARGIN, FIRST_ROW, ROW_HEIGHT = 20, 40, 32
local VALUE_COLUMN = 250
local PRICE_SOURCES = { "auto", "tsm", "auctionator" }

local STEPPERS = {
    { key = "cut", label = "OPTION_CUT", lowest = 5, highest = 15 },
    { key = "depth", label = "OPTION_DEPTH", lowest = 1, highest = 5 },
    { key = "tooltipCount", label = "OPTION_COUNT", lowest = 1, highest = 10 },
    { key = "tooltipShiftCount", label = "OPTION_SHIFT_COUNT", lowest = 1, highest = 15 },
}

local frame

local function rowLabel(parent, row, text)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, -FIRST_ROW - (row - 1) * ROW_HEIGHT - 4)
    label:SetText(text)
    return label
end

local function valueAnchor(control, parent, row)
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", VALUE_COLUMN, -FIRST_ROW - (row - 1) * ROW_HEIGHT)
end

local function button(parent, width, text)
    local control = ns.Compat.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(width, 22)
    control:SetText(text)
    return control
end

local function buildStepper(parent, row, option)
    rowLabel(parent, row, ns.L[option.label])
    local stepper = {}
    stepper.less = button(parent, 24, "-")
    valueAnchor(stepper.less, parent, row)
    stepper.value = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    stepper.value:SetPoint("LEFT", stepper.less, "RIGHT", 0, 0)
    stepper.value:SetWidth(40)
    stepper.value:SetJustifyH("CENTER")
    stepper.more = button(parent, 24, "+")
    stepper.more:SetPoint("LEFT", stepper.value, "RIGHT", 0, 0)
    local function step(change)
        local value = ns.db.settings[option.key] + change
        ns:Set(option.key, math.max(option.lowest, math.min(option.highest, value)))
    end
    stepper.less:SetScript("OnClick", function()
        step(-1)
    end)
    stepper.more:SetScript("OnClick", function()
        step(1)
    end)
    return stepper
end

local function build()
    local L, Compat = ns.L, ns.Compat
    local window = Compat.CreateFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:Hide()
    if window.SetTitle then
        window:SetTitle(L.OPTIONS_TITLE)
    elseif window.TitleText then
        window.TitleText:SetText(L.OPTIONS_TITLE)
    end
    if not window.CloseButton then
        local background = window:CreateTexture(nil, "BACKGROUND")
        background:SetColorTexture(0.05, 0.05, 0.05, 0.95)
        background:SetAllPoints(window)
        local close = button(window, 24, "x")
        close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function()
            window:Hide()
        end)
    end

    local controls = {}
    window.controls = controls

    controls.tooltip = Compat.CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    controls.tooltip:SetSize(24, 24)
    valueAnchor(controls.tooltip, window, 1)
    rowLabel(window, 1, L.OPTION_TOOLTIP)
    controls.tooltip:SetScript("OnClick", function(self)
        ns:Set("tooltipEnabled", self:GetChecked() and true or false)
    end)

    rowLabel(window, 2, L.OPTION_SOURCE)
    controls.source = button(window, 130, "")
    valueAnchor(controls.source, window, 2)
    controls.source:SetScript("OnClick", function()
        local current = ns.db.settings.priceSource
        for position, source in ipairs(PRICE_SOURCES) do
            if source == current then
                ns:Set("priceSource", PRICE_SOURCES[position % #PRICE_SOURCES + 1])
                return
            end
        end
    end)

    rowLabel(window, 3, L.OPTION_TSM_PRICE)
    controls.preset = button(window, 130, "")
    valueAnchor(controls.preset, window, 3)
    controls.preset:SetScript("OnClick", function()
        ns.Prices.ToggleFormulaPreset()
    end)

    rowLabel(window, 4, L.OPTION_FORMULA)
    controls.formula = Compat.CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    controls.formula:SetSize(130, 20)
    controls.formula:SetAutoFocus(false)
    controls.formula:SetFontObject("ChatFontNormal")
    valueAnchor(controls.formula, window, 4)
    local function commitFormula(self)
        local text = (self:GetText() or ""):match("^%s*(.-)%s*$")
        if text ~= "" and text ~= ns.db.settings.tsmFormula then
            ns:Set("tsmFormula", text)
        end
        self:ClearFocus()
    end
    controls.formula:SetScript("OnEnterPressed", commitFormula)
    controls.formula:SetScript("OnEditFocusLost", commitFormula)
    controls.formula:SetScript("OnEscapePressed", function(self)
        self:SetText(ns.db.settings.tsmFormula)
        self:ClearFocus()
    end)

    controls.steppers = {}
    for position, option in ipairs(STEPPERS) do
        controls.steppers[option.key] = buildStepper(window, 4 + position, option)
    end

    window:SetScript("OnShow", function()
        SettingsWindow:Refresh()
    end)
    table.insert(UISpecialFrames, FRAME_NAME)
    return window
end

--- Shows the current settings in the controls.
function SettingsWindow:Refresh()
    if not (frame and frame:IsShown()) then
        return
    end
    local settings, controls = ns.db.settings, frame.controls
    controls.tooltip:SetChecked(settings.tooltipEnabled)
    controls.source:SetText(ns.L["SOURCE_" .. settings.priceSource])
    controls.preset:SetText(ns.View.FormulaLabel())
    if not controls.formula:HasFocus() then
        controls.formula:SetText(settings.tsmFormula)
    end
    for key, stepper in pairs(controls.steppers) do
        stepper.value:SetText(tostring(settings[key]))
    end
end

--- Opens the settings window.
function SettingsWindow:Open()
    frame = frame or build()
    frame:Show()
    SettingsWindow:Refresh()
end

ns:RegisterCommand("options", function()
    SettingsWindow:Open()
end)

ns:OnMessage("SETTINGS_CHANGED", function()
    SettingsWindow:Refresh()
end)

-- The game's options panel gets an entry that opens the window, so the
-- settings are where players look for them. The registration API differs
-- between client generations and is not worth an error at load.
ns:OnMessage("READY", function()
    local panel = CreateFrame("Frame")
    panel.name = "WarcraftBets"
    local open = button(panel, 260, ns.L.OPTIONS_OPEN)
    open:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    open:SetScript("OnClick", function()
        SettingsWindow:Open()
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        pcall(function()
            Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
        end)
    elseif InterfaceOptions_AddCategory then
        pcall(InterfaceOptions_AddCategory, panel)
    end
end)
