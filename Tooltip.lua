local _, ns = ...

local blockShown = false

local function addBlock(tooltip, item)
    if not (item and ns.db and ns.db.settings.tooltipEnabled) or ns.Compat.InCombat() then
        return
    end
    ns.lastItem = item
    local lines = ns.View.TooltipLines(item, IsShiftKeyDown())
    if not lines then
        return
    end
    tooltip:AddLine(" ")
    for _, line in ipairs(lines) do
        local r, g, b = unpack(line.leftColor)
        if line.right then
            tooltip:AddDoubleLine(line.left, line.right, r, g, b, unpack(line.rightColor))
        else
            tooltip:AddLine(line.left, r, g, b)
        end
    end
    -- Lines added after the tooltip was laid out need a new layout pass.
    tooltip:Show()
    blockShown = tooltip == GameTooltip
end

local function itemFromLink(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function isItemTooltip(tooltip)
    return tooltip == GameTooltip or tooltip == ItemRefTooltip
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if isItemTooltip(tooltip) then
            addBlock(tooltip, data and data.id)
        end
    end)
else
    for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
        tooltip:HookScript("OnTooltipSetItem", function(self)
            local _, link = self:GetItem()
            addBlock(self, itemFromLink(link))
        end)
    end
end

GameTooltip:HookScript("OnTooltipCleared", function()
    blockShown = false
end)

-- Holding Shift changes how many crafts are listed; the tooltip has to be
-- built again without waiting for the mouse to move.
ns:On("MODIFIER_STATE_CHANGED", function(key)
    if not (blockShown and key and key:find("SHIFT")) or not GameTooltip:IsShown() then
        return
    end
    if GameTooltip.RefreshData then
        GameTooltip:RefreshData()
        return
    end
    local owner = GameTooltip:GetOwner()
    local onEnter = owner and owner:GetScript("OnEnter")
    if onEnter then
        onEnter(owner)
    end
end)
