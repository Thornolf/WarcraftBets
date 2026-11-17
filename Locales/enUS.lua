local _, ns = ...

ns.locales = ns.locales or {}

ns.locales.enUS = {
    HELP_HEADER = "WarcraftBets %s",
    HELP_OPEN = "/wsb: open or close the window",
    HELP_ITEM = "/wsb <item link or name>: open the window on that item",
    HELP_OPTIONS = "/wsb options: open the settings",
    HELP_RESET = "/wsb reset: move the window back to the centre",

    TT_RAW = "%s, raw",
    TT_TRANSFORMED = "Transformed (%s)",
    TT_CRAFT_COST = "Crafting cost",
    TT_HEADER = "WarcraftBets: best crafts",
    PER_UNIT = "per unit",
    TT_MORE_SHIFT = "+%d more · Shift to see more",
    TT_MORE_COMMAND = "+%d more · /wsb to see all",
    SOURCE_tsm = "TSM",
    SOURCE_auctionator = "Auctionator",
    LOADING = "Loading...",
    UNKNOWN_PRICE = "?",
    GOLD_SUFFIX = "g",
    SILVER_SUFFIX = "s",
    COPPER_SUFFIX = "c",

    -- Used when the client cannot name a profession itself.
    PROFESSION_40 = "Poisons",
    PROFESSION_129 = "First Aid",
    PROFESSION_142 = "Survival",
    PROFESSION_164 = "Blacksmithing",
    PROFESSION_165 = "Leatherworking",
    PROFESSION_171 = "Alchemy",
    PROFESSION_182 = "Herbalism",
    PROFESSION_185 = "Cooking",
    PROFESSION_186 = "Mining",
    PROFESSION_197 = "Tailoring",
    PROFESSION_202 = "Engineering",
    PROFESSION_333 = "Enchanting",
    PROFESSION_356 = "Fishing",
    PROFESSION_393 = "Skinning",
    PROFESSION_3012 = "Comprehension",
}
