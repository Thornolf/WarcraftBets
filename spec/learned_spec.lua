local helpers = require("spec.helpers")

local MINING, BLACKSMITHING = 186, 164
local SMELT_COPPER, SMELT_BRONZE, COPPER_CHAIN_BELT, COPPER_CHAIN_VEST = 2657, 2659, 2661, 2667

describe("learned recipes", function()
    local game, ns, Learned, index, spells, ranks

    local function login(character)
        game.character = character
        game:Fire("PLAYER_LOGIN")
        game:RunTimers()
    end

    before_each(function()
        game = helpers.newGame()
        spells, ranks = {}, {}
        _G.IsPlayerSpell = function(spell)
            return spells[spell] == true
        end
        _G.C_SpellBook, _G.IsSpellKnown = nil, nil
        _G.GetProfessions, _G.GetProfessionInfo = nil, nil
        _G.GetNumSkillLines, _G.GetSkillLineInfo = nil, nil
        _G.GetNumTradeSkills, _G.GetTradeSkillRecipeLink = nil, nil
        _G.GetNumCrafts, _G.GetCraftItemLink = nil, nil
        _G.C_TradeSkillUI = {
            GetProfessionInfoBySkillLineID = function(skill)
                return { skillLevel = ranks[skill] or 0 }
            end,
        }
        ns = game:Load(
            "Locales/enUS.lua",
            "Locales/frFR.lua",
            "Core.lua",
            "Data/Recipes.lua",
            "Recipes.lua",
            "Learned.lua"
        )
        game:Fire("ADDON_LOADED", "WarcraftBets")
        Learned = ns.Learned
        index = ns.Recipes.Build(ns.RecipeData)
    end)

    it("marks a recipe the character knows as known", function()
        spells[SMELT_COPPER], ranks[MINING] = true, 80
        login("Thrall")
        local status = Learned.Status(index.byId[SMELT_COPPER])
        assert.is_true(status.known)
        assert.is_false(status.learnable)
        assert.are.same({}, status.alts)
    end)

    it("names the other characters that know a recipe", function()
        spells[SMELT_COPPER], ranks[MINING] = true, 80
        login("Thrall")
        login("Jaina")
        spells, ranks = {}, {}
        login("Garrosh")
        local status = Learned.Status(index.byId[SMELT_COPPER])
        assert.is_false(status.known)
        assert.are.same({ "Jaina", "Thrall" }, status.alts)
    end)

    it("marks a recipe as learnable once the rank reaches its requirement", function()
        ranks[BLACKSMITHING] = 89
        login("Thrall")
        assert.is_false(Learned.Status(index.byId[COPPER_CHAIN_VEST]).learnable)
        ranks[BLACKSMITHING] = 90
        login("Thrall")
        assert.is_true(Learned.Status(index.byId[COPPER_CHAIN_VEST]).learnable)
    end)

    it("waits for the yellow threshold when the requirement is unknown", function()
        assert.is_nil(index.byId[COPPER_CHAIN_BELT].learnAt)
        ranks[BLACKSMITHING] = 69
        login("Thrall")
        assert.is_false(Learned.Status(index.byId[COPPER_CHAIN_BELT]).learnable)
        ranks[BLACKSMITHING] = 70
        login("Thrall")
        assert.is_true(Learned.Status(index.byId[COPPER_CHAIN_BELT]).learnable)
    end)

    it("leaves a recipe of a profession the character lacks as not learned", function()
        ranks[MINING] = 300
        login("Thrall")
        local status = Learned.Status(index.byId[COPPER_CHAIN_BELT])
        assert.is_false(status.known)
        assert.is_false(status.learnable)
        assert.are.same({}, status.alts)
    end)

    it("forgets the recipes of a dropped profession", function()
        spells[SMELT_COPPER], ranks[MINING], ranks[BLACKSMITHING] = true, 80, 10
        login("Thrall")
        spells[SMELT_COPPER], ranks[MINING] = nil, nil
        login("Thrall")
        assert.is_false(Learned.Status(index.byId[SMELT_COPPER]).known)
    end)

    it("keeps what it knows when the client reports no rank at all", function()
        spells[SMELT_COPPER], ranks[MINING] = true, 80
        login("Thrall")
        spells, ranks = {}, {}
        login("Thrall")
        assert.is_true(Learned.Status(index.byId[SMELT_COPPER]).known)
    end)

    it("reads the recipes listed by an open profession window", function()
        ranks[MINING] = 80
        _G.C_TradeSkillUI.GetAllRecipeIDs = function()
            return { SMELT_COPPER, SMELT_BRONZE }
        end
        _G.C_TradeSkillUI.GetRecipeInfo = function(spell)
            return { learned = spell == SMELT_BRONZE }
        end
        game:Fire("TRADE_SKILL_SHOW")
        game:RunTimers()
        assert.is_true(Learned.Status(index.byId[SMELT_BRONZE]).known)
        assert.is_false(Learned.Status(index.byId[SMELT_COPPER]).known)
    end)

    it("reads the rank from the child skill line the client keeps it on", function()
        local CHILD_BLACKSMITHING = 2938
        assert.are.equal(BLACKSMITHING, ns.RecipeData.childSkills[CHILD_BLACKSMITHING])
        ranks[CHILD_BLACKSMITHING] = 90
        login("Thrall")
        assert.are.equal(90, ns.db.chars["Sulfuron-Thrall"].skills[BLACKSMITHING])
        assert.is_true(Learned.Status(index.byId[COPPER_CHAIN_VEST]).learnable)
    end)

    it("reads the filtered list when the client has no full recipe list", function()
        ranks[MINING] = 80
        _G.C_TradeSkillUI.GetFilteredRecipeIDs = function()
            return { SMELT_BRONZE }
        end
        _G.C_TradeSkillUI.GetRecipeInfo = function(spell)
            return { learned = spell == SMELT_BRONZE }
        end
        game:Fire("TRADE_SKILL_SHOW")
        game:RunTimers()
        assert.is_true(Learned.Status(index.byId[SMELT_BRONZE]).known)
    end)

    it("asks the client about each recipe of the character's professions", function()
        ranks[MINING] = 80
        local asked = {}
        _G.C_TradeSkillUI.GetRecipeInfo = function(spell)
            asked[spell] = true
            return { learned = spell == SMELT_COPPER }
        end
        login("Thrall")
        assert.is_true(Learned.Status(index.byId[SMELT_COPPER]).known)
        assert.is_false(Learned.Status(index.byId[SMELT_BRONZE]).known)
        assert.is_nil(asked[COPPER_CHAIN_BELT])
    end)

    it("reads recipe links and skill lines on an older client", function()
        _G.C_TradeSkillUI = nil
        _G.GetNumSkillLines = function()
            return 2
        end
        _G.GetSkillLineInfo = function(line)
            if line == 1 then
                return "Professions", true
            end
            return "Mining", false, false, 120
        end
        _G.GetNumTradeSkills = function()
            return 2
        end
        _G.GetTradeSkillRecipeLink = function(line)
            return line == 2 and "|cffffd000|Henchant:2659|h[Smelt Bronze]|h|r" or nil
        end
        game:Fire("TRADE_SKILL_SHOW")
        game:RunTimers()
        assert.is_true(Learned.Status(index.byId[SMELT_BRONZE]).known)
        assert.are.equal(120, ns.db.chars["Sulfuron-Thrall"].skills[MINING])
    end)

    it("scans once for a burst of events and reports changes once", function()
        spells[SMELT_COPPER], ranks[MINING] = true, 80
        local fired = 0
        ns:OnMessage("LEARNED_CHANGED", function()
            fired = fired + 1
        end)
        game:Fire("TRADE_SKILL_LIST_UPDATE")
        game:Fire("TRADE_SKILL_LIST_UPDATE")
        assert.are.equal(1, #game.timers)
        game:RunTimers()
        login("Thrall")
        assert.are.equal(1, fired)
    end)
end)
