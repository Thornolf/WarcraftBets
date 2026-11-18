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
    "C_Item",
    "C_MerchantFrame",
    "C_Spell",
    "C_SpellBook",
    "C_Timer",
    "C_TradeSkillUI",
    "ChatEdit_GetActiveWindow",
    "ChatEdit_InsertLink",
    "ChatFrameUtil",
    "ChatFrame_OpenChat",
    "ClearCursor",
    "CreateFrame",
    "DEFAULT_CHAT_FRAME",
    "Enum",
    "GameTooltip",
    "GetCraftItemLink",
    "GetCursorInfo",
    "GetItemIcon",
    "GetItemInfo",
    "GetItemInfoInstant",
    "GetLocale",
    "GetMerchantItemID",
    "GetMerchantItemInfo",
    "GetMerchantNumItems",
    "GetNumCrafts",
    "GetNumSkillLines",
    "GetNumTradeSkills",
    "GetProfessionInfo",
    "GetProfessions",
    "GetRealmName",
    "GetSkillLineInfo",
    "GetSpellInfo",
    "GetSpellTexture",
    "GetTime",
    "GetTradeSkillRecipeLink",
    "ITEM_QUALITY_COLORS",
    "InCombatLockdown",
    "InterfaceOptions_AddCategory",
    "IsPlayerSpell",
    "IsShiftKeyDown",
    "IsSpellKnown",
    "ItemRefTooltip",
    "Settings",
    "TSM_API",
    "TooltipDataProcessor",
    "UIParent",
    "UISpecialFrames",
    "UnitName",
    "hooksecurefunc",
}

-- The specs replace the game API with fakes, so they write what the add-on only reads.
files["spec"] = {
    std = "+busted",
    allow_defined_top = true,
    max_line_length = 130,
    ignore = { "121", "122", "131" },
    read_globals = { "WarcraftBetsFrame", "WarcraftBetsSettingsFrame" },
}

files["Data/Recipes.lua"] = {
    max_line_length = false,
}
