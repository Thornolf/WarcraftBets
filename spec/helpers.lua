-- Loads add-on files outside the game, against a minimal stand-in for the WoW API.

local helpers = {}

local function newFrame()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event)
        if event:match("^UNKNOWN") then
            error("unknown event " .. event)
        end
        self.events[event] = true
    end
    function frame:SetScript(name, fn)
        self.scripts[name] = fn
    end
    function frame:Fire(event, ...)
        if self.events[event] then
            self.scripts.OnEvent(self, event, ...)
        end
    end
    return frame
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
    }
    _G.WarcraftBetsDB = nil
    _G.SlashCmdList = {}
    _G.GetLocale = function()
        return locale or "enUS"
    end
    _G.CreateFrame = function()
        local frame = newFrame()
        table.insert(game.frames, frame)
        return frame
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
    }
    _G.C_Spell = {
        GetSpellName = function(spell)
            return game.spellNames[spell]
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
