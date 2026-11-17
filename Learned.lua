local _, ns = ...

local Learned = {}
ns.Learned = Learned

local SCAN_DELAY_SECONDS = 0.5

local function currentCharacter()
    local name, realm = UnitName("player"), GetRealmName()
    local key = realm .. "-" .. name
    local chars = ns.db.chars
    chars[key] = chars[key] or { name = name, realm = realm, recipes = {}, skills = {} }
    return chars[key], key
end

local function spellIsKnown(spell)
    if IsPlayerSpell and IsPlayerSpell(spell) then
        return true
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spell) then
        return true
    end
    return IsSpellKnown ~= nil and IsSpellKnown(spell) or false
end

--- Localised name of a profession, from the client when it can tell.
function Learned.ProfessionName(skill)
    local display = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName
    return display and display(skill) or ns.L["PROFESSION_" .. skill]
end

-- The three generations of the client expose profession ranks differently;
-- each reader fills what it can and the results are merged.
local function readSkills()
    local skills = {}
    local bySkillLine = C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID
    if bySkillLine then
        for skill in pairs(ns.RecipeData.skills) do
            local info = bySkillLine(skill)
            if info and (info.skillLevel or 0) > 0 then
                skills[skill] = info.skillLevel
            end
        end
    end
    if GetProfessions and GetProfessionInfo then
        for _, index in pairs({ GetProfessions() }) do
            local _, _, level, _, _, _, skill = GetProfessionInfo(index)
            if skill and ns.RecipeData.skills[skill] and (level or 0) > 0 then
                skills[skill] = level
            end
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        local byName = {}
        for skill in pairs(ns.RecipeData.skills) do
            byName[Learned.ProfessionName(skill)] = skill
        end
        for line = 1, GetNumSkillLines() do
            local name, isHeader, _, level = GetSkillLineInfo(line)
            if not isHeader and byName[name] and (level or 0) > 0 then
                skills[byName[name]] = level
            end
        end
    end
    return skills
end

local function spellFromLink(link)
    return link and tonumber(link:match("enchant:(%d+)"))
end

-- Recipes listed by an open profession window. Older clients only know the
-- recipes of the window that is open, so this adds to the record and never
-- removes from it.
local function readOpenWindow(known)
    local api = C_TradeSkillUI
    if api and api.GetAllRecipeIDs and api.GetRecipeInfo then
        for _, spell in ipairs(api.GetAllRecipeIDs() or {}) do
            local info = api.GetRecipeInfo(spell)
            if info and info.learned then
                known[spell] = true
            end
        end
    end
    if GetNumTradeSkills and GetTradeSkillRecipeLink then
        for line = 1, GetNumTradeSkills() do
            local spell = spellFromLink(GetTradeSkillRecipeLink(line))
            if spell then
                known[spell] = true
            end
        end
    end
    if GetNumCrafts and GetCraftItemLink then
        for line = 1, GetNumCrafts() do
            local spell = spellFromLink(GetCraftItemLink(line))
            if spell then
                known[spell] = true
            end
        end
    end
end

local function sameSet(a, b)
    for key, value in pairs(a) do
        if b[key] ~= value then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

--- Records what the logged-in character knows: profession ranks and learned
--- recipes. Recipes of a profession the character dropped are forgotten.
function Learned.Scan()
    local char = currentCharacter()
    local skills = readSkills()
    local known = {}
    for spell in pairs(char.recipes) do
        known[spell] = true
    end
    readOpenWindow(known)
    -- No rank at all means the client gave nothing to read, not that every
    -- profession was dropped.
    local ranksRead = next(skills) ~= nil
    for spell, raw in pairs(ns.RecipeData.recipes) do
        if spellIsKnown(spell) then
            known[spell] = true
        end
        if ranksRead and known[spell] and not skills[raw[1]] then
            known[spell] = nil
        end
    end
    if sameSet(known, char.recipes) and sameSet(skills, char.skills) then
        return
    end
    char.recipes, char.skills = known, skills
    ns:Fire("LEARNED_CHANGED")
end

--- What is known about one recipe: whether this character knows it, which
--- other characters do, and whether this character could learn it now.
--- Without the exact requirement, "learnable" waits for the yellow threshold,
--- which is never below it.
function Learned.Status(recipe)
    local char, currentKey = currentCharacter()
    local status = { known = char.recipes[recipe.id] == true, alts = {}, learnable = false }
    for key, other in pairs(ns.db.chars) do
        if key ~= currentKey and other.recipes[recipe.id] then
            table.insert(status.alts, other.name)
        end
    end
    table.sort(status.alts)
    local rank = char.skills[recipe.skill]
    if rank and not status.known then
        status.learnable = rank >= (recipe.learnAt or recipe.yellowAt)
    end
    return status
end

local scanQueued = false

-- Profession windows fire a burst of list updates; one scan after the burst is enough.
local function queueScan()
    if scanQueued then
        return
    end
    scanQueued = true
    C_Timer.After(SCAN_DELAY_SECONDS, function()
        scanQueued = false
        Learned.Scan()
    end)
end

for _, event in ipairs({
    "PLAYER_LOGIN",
    "SKILL_LINES_CHANGED",
    "NEW_RECIPE_LEARNED",
    "TRADE_SKILL_SHOW",
    "TRADE_SKILL_LIST_UPDATE",
    "CRAFT_SHOW",
    "CRAFT_UPDATE",
}) do
    ns:On(event, queueScan)
end
