local helpers = require("spec.helpers")

describe("locales", function()
    local locales

    before_each(function()
        locales = helpers.newGame():Load("Locales/enUS.lua", "Locales/frFR.lua").locales
    end)

    it("define the same keys in French and English", function()
        for key in pairs(locales.enUS) do
            assert.is_string(locales.frFR[key], "frFR is missing " .. key)
        end
        for key in pairs(locales.frFR) do
            assert.is_string(locales.enUS[key], "enUS is missing " .. key)
        end
    end)

    it("name every profession of the recipe data", function()
        local data = helpers.newGame():Load("Data/Recipes.lua").RecipeData
        for skill in pairs(data.skills) do
            assert.is_string(locales.enUS["PROFESSION_" .. skill], "no name for profession " .. skill)
        end
    end)

    it("keep the same format placeholders in both languages", function()
        local function placeholders(text)
            local found = {}
            for spec in text:gmatch("%%[ds]") do
                table.insert(found, spec)
            end
            return table.concat(found)
        end
        for key, text in pairs(locales.enUS) do
            assert.are.equal(placeholders(text), placeholders(locales.frFR[key]), key)
        end
    end)
end)
