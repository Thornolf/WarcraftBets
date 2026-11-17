std = "lua51"
self = false
max_line_length = 110
exclude_files = { "dist", "tools" }

globals = {
    "WarcraftBetsDB",
    "SlashCmdList",
    "SLASH_WARCRAFTBETS1",
    "SLASH_WARCRAFTBETS2",
}

read_globals = {
    "CreateFrame",
    "DEFAULT_CHAT_FRAME",
    "GetLocale",
}

files["spec"] = {
    std = "+busted",
    globals = { "CreateFrame", "DEFAULT_CHAT_FRAME", "GetLocale" },
}

files["Data/Recipes.lua"] = {
    max_line_length = false,
}
