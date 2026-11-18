-- Loads add-on files outside the game, against a minimal stand-in for the WoW API.

local helpers = {}

-- A stand-in for any game widget: it records text, visibility, scripts and
-- the few values the add-on reads back, and accepts every other call.
local widgetMethods = {}

local function newWidget(kind, parent)
    local widget = { kind = kind, parent = parent, events = {}, scripts = {}, shown = true }
    return setmetatable(widget, {
        -- Widget methods are capitalised; anything else is a field the add-on
        -- set itself, and reads as nil until it does.
        __index = function(_, key)
            if widgetMethods[key] then
                return widgetMethods[key]
            end
            if type(key) == "string" and key:match("^%u") then
                return function() end
            end
        end,
    })
end

function widgetMethods:RegisterEvent(event)
    if event:match("^UNKNOWN") then
        error("unknown event " .. event)
    end
    self.events[event] = true
end

function widgetMethods:Fire(event, ...)
    if self.events[event] then
        self.scripts.OnEvent(self, event, ...)
    end
end

function widgetMethods:SetScript(name, fn)
    self.scripts[name] = fn
end

function widgetMethods:HookScript(name, fn)
    local previous = self.scripts[name]
    self.scripts[name] = previous and function(...)
        previous(...)
        fn(...)
    end or fn
end

function widgetMethods:GetScript(name)
    return self.scripts[name]
end

function widgetMethods:Run(name, ...)
    return self.scripts[name](self, ...)
end

function widgetMethods:Show()
    local wasShown = self.shown
    self.shown = true
    if not wasShown and self.scripts.OnShow then
        self.scripts.OnShow(self)
    end
end

function widgetMethods:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then
        self.scripts.OnHide(self)
    end
end

function widgetMethods:SetShown(shown)
    if shown then
        self:Show()
    else
        self:Hide()
    end
end

function widgetMethods:IsShown()
    return self.shown
end

function widgetMethods:SetText(text)
    self.text = text
    if self.kind == "EditBox" and self.scripts.OnTextChanged then
        self.scripts.OnTextChanged(self)
    end
end

function widgetMethods:GetText()
    return self.text
end

function widgetMethods:SetTextColor(r, g, b)
    self.textColor = { r, g, b }
end

function widgetMethods:SetTexture(texture)
    self.texture = texture
end

function widgetMethods:SetDesaturated(desaturated)
    self.desaturated = desaturated
end

function widgetMethods:SetFontObject(font)
    self.font = font
end

function widgetMethods:EnableMouse(enabled)
    self.mouse = enabled
end

function widgetMethods:SetPoint(point, relativeTo, relativePoint, x, y)
    self.point = { point, relativeTo, relativePoint, x, y }
end

function widgetMethods:GetPoint()
    return unpack(self.point or {}, 1, 5)
end

function widgetMethods:GetFrameLevel()
    return 1
end

function widgetMethods:SetMinMaxValues(lowest, highest)
    self.range = { lowest, highest }
end

function widgetMethods:GetMinMaxValues()
    return unpack(self.range or { 0, 0 })
end

function widgetMethods:SetValue(value)
    if value ~= self.value then
        self.value = value
        if self.scripts.OnValueChanged then
            self.scripts.OnValueChanged(self, value)
        end
    end
end

function widgetMethods:SetChecked(checked)
    self.checked = checked
end

function widgetMethods:GetChecked()
    return self.checked
end

function widgetMethods:HasFocus()
    return self.focused == true
end

function widgetMethods:SetFocus()
    if not self.focused then
        self.focused = true
        if self.scripts.OnEditFocusGained then
            self.scripts.OnEditFocusGained(self)
        end
    end
end

function widgetMethods:ClearFocus()
    if self.focused then
        self.focused = false
        if self.scripts.OnEditFocusLost then
            self.scripts.OnEditFocusLost(self)
        end
    end
end

function widgetMethods:LockHighlight()
    self.highlightLocked = true
end

function widgetMethods:UnlockHighlight()
    self.highlightLocked = false
end

function widgetMethods:CreateFontString()
    return newWidget("FontString", self)
end

function widgetMethods:CreateTexture()
    return newWidget("Texture", self)
end

local function newTooltip()
    local tooltip = { lines = {}, hooks = {}, shown = false }
    function tooltip:AddLine(text, r, g, b)
        table.insert(self.lines, { left = text, leftColor = { r, g, b } })
    end
    function tooltip:AddDoubleLine(left, right, r, g, b, r2, g2, b2)
        local line = { left = left, right = right, leftColor = { r, g, b }, rightColor = { r2, g2, b2 } }
        table.insert(self.lines, line)
    end
    function tooltip:Show()
        self.shown = true
    end
    function tooltip:IsShown()
        return self.shown
    end
    function tooltip:HookScript(name, fn)
        self.hooks[name] = fn
    end
    function tooltip:SetOwner(owner)
        self.owner = owner
        self.lines = {}
    end
    function tooltip:SetItemByID(item)
        self.item = item
    end
    function tooltip:Hide()
        self.shown = false
    end
    return tooltip
end

--- Resets the fake game globals and returns a fresh add-on namespace.
function helpers.newGame(locale)
    local game = {
        frames = {},
        chat = {},
        timers = {},
        character = "Thrall",
        time = 0,
        inCombat = false,
        shift = false,
        itemNames = {},
        spellNames = {},
        knownSpells = {},
        ranks = {},
        prices = {},
        missingTemplates = {},
        chatBox = {},
        chatBoxOpen = false,
    }
    _G.WarcraftBetsDB = nil
    _G.SlashCmdList = {}
    _G.GetLocale = function()
        return locale or "enUS"
    end
    _G.CreateFrame = function(kind, name, parent, template)
        if template and game.missingTemplates[template] then
            error("Couldn't find inherited node: " .. template)
        end
        local frame = newWidget(kind, parent)
        frame.template = template
        if template == "BasicFrameTemplateWithInset" then
            frame.CloseButton = newWidget("Button", frame)
            frame.TitleText = newWidget("FontString", frame)
        end
        if name then
            _G[name] = frame
        end
        table.insert(game.frames, frame)
        return frame
    end
    _G.UIParent = newWidget("Frame")
    _G.UISpecialFrames = {}
    _G.WarcraftBetsFrame, _G.WarcraftBetsSettingsFrame = nil, nil
    _G.Settings, _G.InterfaceOptions_AddCategory, _G.ChatFrameUtil = nil, nil, nil
    _G.ChatEdit_InsertLink = function(text)
        if game.chatBoxOpen then
            table.insert(game.chatBox, text)
            return true
        end
        return false
    end
    _G.ChatEdit_GetActiveWindow = function()
        return game.chatBoxOpen and {} or nil
    end
    _G.hooksecurefunc = function(owner, name, hook)
        if type(owner) == "string" then
            owner, name, hook = _G, owner, name
        end
        local original = owner[name]
        owner[name] = function(...)
            local results = { original(...) }
            hook(...)
            return unpack(results)
        end
    end
    _G.GetCursorInfo = function()
        if game.cursorItem then
            return "item", game.cursorItem
        end
    end
    _G.ClearCursor = function()
        game.cursorItem = nil
    end
    _G.ChatFrame_OpenChat = function(text)
        game.chatBoxOpen = true
        table.insert(game.chatBox, text)
    end
    _G.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, text)
            table.insert(game.chat, text)
        end,
    }
    _G.UnitName = function()
        return game.character
    end
    _G.GetRealmName = function()
        return "Sulfuron"
    end
    _G.C_Timer = {
        After = function(_, fn)
            table.insert(game.timers, fn)
        end,
    }
    _G.GetTime = function()
        return game.time
    end
    _G.InCombatLockdown = function()
        return game.inCombat
    end
    _G.IsShiftKeyDown = function()
        return game.shift
    end
    _G.C_Item = {
        GetItemNameByID = function(item)
            return game.itemNames[item]
        end,
        GetItemIconByID = function(item)
            return "icon-" .. item
        end,
        GetItemQualityByID = function()
            return 2
        end,
        GetItemInfo = function(item)
            local name = game.itemNames[item]
            return name, name and ("|Hitem:" .. item .. "|h[" .. name .. "]|h")
        end,
        GetItemInfoInstant = function(text)
            for item, name in pairs(game.itemNames) do
                if name == text then
                    return item
                end
            end
        end,
    }
    _G.ITEM_QUALITY_COLORS = { [2] = { r = 0.12, g = 1, b = 0 } }
    _G.C_Spell = {
        GetSpellName = function(spell)
            return game.spellNames[spell]
        end,
        GetSpellTexture = function(spell)
            return "spell-" .. spell
        end,
    }
    _G.IsPlayerSpell = function(spell)
        return game.knownSpells[spell] == true
    end
    _G.C_TradeSkillUI = {
        GetProfessionInfoBySkillLineID = function(skill)
            return { skillLevel = game.ranks[skill] or 0 }
        end,
    }
    _G.TSM_API = {
        GetCustomPriceValue = function(_, itemString)
            return game.prices[tonumber(itemString:match("%d+"))]
        end,
    }
    _G.Auctionator, _G.C_MerchantFrame, _G.TooltipDataProcessor, _G.Enum = nil, nil, nil, nil
    _G.C_SpellBook, _G.IsSpellKnown, _G.GetProfessions, _G.GetNumSkillLines = nil, nil, nil, nil
    _G.GetNumTradeSkills, _G.GetNumCrafts = nil, nil
    _G.GameTooltip, _G.ItemRefTooltip = newTooltip(), newTooltip()
    game.ns = {}
    --- Runs every pending timer, as if their delay had elapsed.
    function game:RunTimers()
        local due = self.timers
        self.timers = {}
        for _, fn in ipairs(due) do
            fn()
        end
    end
    --- Sends a game event to every frame the add-on created.
    function game:Fire(event, ...)
        for _, frame in ipairs(self.frames) do
            frame:Fire(event, ...)
        end
    end
    --- Loads add-on files in order, as the client does from the TOC.
    function game:Load(...)
        for _, path in ipairs({ ... }) do
            assert(loadfile(path))("WarcraftBets", self.ns)
        end
        return self.ns
    end
    return game
end

--- Loads the whole add-on as the TOC lists it, with `data` standing in for
--- the generated recipe file, and fires ADDON_LOADED.
function helpers.loadAddon(game, data)
    local ns = game.ns
    for _, path in ipairs(helpers.tocFiles()) do
        if path == "Data/Recipes.lua" and data then
            ns.RecipeData = data
        else
            game:Load(path)
        end
    end
    game:Fire("ADDON_LOADED", "WarcraftBets")
    return ns
end

--- The Lua files listed in the TOC, in load order.
function helpers.tocFiles()
    local files = {}
    for line in io.lines("WarcraftBets.toc") do
        if line:match("%.lua$") then
            table.insert(files, line)
        end
    end
    return files
end

return helpers
