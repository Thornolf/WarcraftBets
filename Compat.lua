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

--- Icon of an item, usable by Texture:SetTexture.
function Compat.ItemIcon(item)
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(item)
    end
    return GetItemIcon(item)
end

--- Icon of a recipe spell, for recipes that make no item.
function Compat.SpellIcon(spell)
    if C_Spell and C_Spell.GetSpellTexture then
        return (C_Spell.GetSpellTexture(spell))
    end
    return (GetSpellTexture(spell))
end

--- Colour of an item's quality as r, g, b; white while the item is loading.
function Compat.ItemQualityColor(item)
    local quality
    if C_Item and C_Item.GetItemQualityByID then
        quality = C_Item.GetItemQualityByID(item)
    else
        quality = select(3, GetItemInfo(item))
    end
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

--- Item id named by a chat link or by an item name the client has cached.
function Compat.ItemFromText(text)
    local linked = tonumber(text:match("item:(%d+)"))
    if linked then
        return linked
    end
    local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    return (instant(text))
end

--- Creates a frame from the first template this client has, so the window
--- keeps the native look where it can and still opens where it cannot.
function Compat.CreateFrame(frameType, name, parent, ...)
    for position = 1, select("#", ...) do
        local ok, frame = pcall(CreateFrame, frameType, name, parent, (select(position, ...)))
        if ok and frame then
            return frame
        end
    end
    return CreateFrame(frameType, name, parent)
end

--- Shows the game's own tooltip for an item next to a frame.
function Compat.ShowItemTooltip(owner, item)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(item)
    else
        GameTooltip:SetHyperlink("item:" .. item)
    end
    GameTooltip:Show()
end

--- Chat link of an item, or its bracketed name while the link is loading.
function Compat.ItemLink(item)
    local info = C_Item and C_Item.GetItemInfo or GetItemInfo
    local name, link = info(item)
    return link or ("[" .. (name or Compat.ItemName(item) or item) .. "]")
end

--- Puts text in the chat edit box: at the cursor if the box is open, else in
--- a newly opened box.
function Compat.InsertInChat(text)
    local insert = ChatFrameUtil and ChatFrameUtil.InsertLink or ChatEdit_InsertLink
    if insert and insert(text) then
        return
    end
    local open = ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
    open(text)
end
