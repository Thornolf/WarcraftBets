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
    "CreateFrame",
    "DEFAULT_CHAT_FRAME",
    "Enum",
    "GameTooltip",
    "GetCraftItemLink",
    "GetItemInfo",
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
    "GetTime",
    "GetTradeSkillRecipeLink",
    "InCombatLockdown",
    "IsPlayerSpell",
    "IsShiftKeyDown",
    "IsSpellKnown",
    "ItemRefTooltip",
    "TSM_API",
    "TooltipDataProcessor",
    "UnitName",
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
