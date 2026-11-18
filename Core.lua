local ADDON, ns = ...

ns.version = "1.1.0"

local DEFAULT_SETTINGS = {
    priceSource = "auto",
    tsmFormula = "DBMarket",
    cut = 5,
    depth = 3,
    tooltipCount = 2,
    tooltipShiftCount = 5,
    tooltipEnabled = true,
}

local activeLocale = ns.locales[GetLocale()] or ns.locales.enUS

--- Localised strings; a key missing from the active locale falls back to English.
ns.L = setmetatable({}, {
    __index = function(_, key)
        return activeLocale[key] or ns.locales.enUS[key] or key
    end,
})

local frame = CreateFrame("Frame")
local eventHandlers = {}
local messageHandlers = {}

--- Runs fn on a game event. Events this client does not know are ignored.
function ns:On(event, fn)
    if not eventHandlers[event] then
        if not pcall(frame.RegisterEvent, frame, event) then
            return
        end
        eventHandlers[event] = {}
    end
    table.insert(eventHandlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(eventHandlers[event]) do
        fn(...)
    end
end)

--- Runs fn when another module fires the internal message.
function ns:OnMessage(message, fn)
    messageHandlers[message] = messageHandlers[message] or {}
    table.insert(messageHandlers[message], fn)
end

--- Fires an internal message to every module listening for it.
function ns:Fire(message, ...)
    for _, fn in ipairs(messageHandlers[message] or {}) do
        fn(...)
    end
end

--- Prints a line to the chat frame, prefixed with the add-on name.
function ns:Print(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100WarcraftBets|r " .. text)
end

--- Changes one setting and tells the modules that depend on it.
function ns:Set(key, value)
    ns.db.settings[key] = value
    ns:Fire("SETTINGS_CHANGED", key)
end

ns:On("ADDON_LOADED", function(name)
    if name ~= ADDON then
        return
    end
    WarcraftBetsDB = WarcraftBetsDB or {}
    local db = WarcraftBetsDB
    db.settings = db.settings or {}
    for key, value in pairs(DEFAULT_SETTINGS) do
        if db.settings[key] == nil then
            db.settings[key] = value
        end
    end
    db.chars = db.chars or {}
    db.vendor = db.vendor or {}
    db.recents = db.recents or {}
    db.favorites = db.favorites or {}
    db.favorites.items = db.favorites.items or {}
    db.favorites.crafts = db.favorites.crafts or {}
    ns.db = db
    ns:Fire("READY")
end)

local commands = {}

--- Registers a /wsb sub-command. The empty name handles a bare /wsb, and
--- "*" handles any text that is not a sub-command.
function ns:RegisterCommand(name, fn)
    commands[name] = fn
end

local function printHelp()
    local L = ns.L
    ns:Print(L.HELP_HEADER:format(ns.version))
    for _, key in ipairs({ "HELP_OPEN", "HELP_ITEM", "HELP_OPTIONS", "HELP_RESET" }) do
        ns:Print(L[key])
    end
end

ns:RegisterCommand("help", printHelp)

SLASH_WARCRAFTBETS1 = "/wsb"
SLASH_WARCRAFTBETS2 = "/wb"
SlashCmdList.WARCRAFTBETS = function(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    local handler = commands[text:lower()] or (text ~= "" and commands["*"])
    if handler then
        handler(text)
    else
        printHelp()
    end
end
