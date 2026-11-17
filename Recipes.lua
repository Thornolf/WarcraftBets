local _, ns = ...

local Recipes = {}
ns.Recipes = Recipes

local function byId(a, b)
    return a.id < b.id
end

--- Turns the generated data into recipe records, plus the lookups by product
--- and by reagent that the engine walks.
function Recipes.Build(data)
    local index = {
        byId = {},
        byProduct = {},
        byReagent = {},
        vendor = data.vendor,
        unsellable = {},
        skills = data.skills,
    }
    for _, item in ipairs(data.unsellable) do
        index.unsellable[item] = true
    end
    for spell, raw in pairs(data.recipes) do
        local recipe = {
            id = spell,
            skill = raw[1],
            yellowAt = raw[2],
            greyAt = raw[3],
            learnAt = raw[4] > 0 and raw[4] or nil,
            product = raw[5] > 0 and raw[5] or nil,
            yield = raw[6],
            reagents = {},
        }
        for i = 7, #raw, 2 do
            local item = raw[i]
            table.insert(recipe.reagents, { item = item, count = raw[i + 1] })
            index.byReagent[item] = index.byReagent[item] or {}
            table.insert(index.byReagent[item], recipe)
        end
        if recipe.product then
            index.byProduct[recipe.product] = index.byProduct[recipe.product] or {}
            table.insert(index.byProduct[recipe.product], recipe)
        end
        index.byId[spell] = recipe
    end
    -- pairs() order is arbitrary; sorting keeps rankings stable between sessions.
    for _, lookup in ipairs({ index.byProduct, index.byReagent }) do
        for _, list in pairs(lookup) do
            table.sort(list, byId)
        end
    end
    return index
end
