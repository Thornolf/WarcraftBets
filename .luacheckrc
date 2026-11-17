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
    "Auctionator",
    "C_MerchantFrame",
    "CreateFrame",
    "DEFAULT_CHAT_FRAME",
    "GetLocale",
    "GetMerchantItemID",
    "GetMerchantItemInfo",
    "GetMerchantNumItems",
    "TSM_API",
}

-- The specs replace the game API with fakes, so they write what the add-on only reads.
files["spec"] = {
    std = "+busted",
    allow_defined_top = true,
    ignore = { "121", "122", "131" },
}

files["Data/Recipes.lua"] = {
    max_line_length = false,
}
