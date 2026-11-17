local _, ns = ...

-- The Forever client mixes API generations; each function here asks the
-- newer namespace first and falls back to the older global.
local Compat = {}
ns.Compat = Compat

--- Localised item name, or nil while the client is still loading the item.
function Compat.ItemName(item)
    if C_Item and C_Item.GetItemNameByID then
        local name = C_Item.GetItemNameByID(item)
        if not name and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(item)
        end
        return name
    end
    return (GetItemInfo(item))
end

--- Localised name of a recipe spell, or nil.
function Compat.SpellName(spell)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spell)
    end
    return (GetSpellInfo(spell))
end

--- Whether the player is in combat, when add-on frames must stay quiet.
function Compat.InCombat()
    return InCombatLockdown()
end
