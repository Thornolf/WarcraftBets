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

--- Resets the fake game globals and returns a fresh add-on namespace.
function helpers.newGame(locale)
    local game = { frames = {}, chat = {}, timers = {}, character = "Thrall" }
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
