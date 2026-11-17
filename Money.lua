local _, ns = ...

local Money = {}
ns.Money = Money

local COPPER_PER_SILVER, COPPER_PER_GOLD = 100, 10000
local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

local function coins(copper, gold, silver, bronze)
    copper = math.floor(math.abs(copper) + 0.5)
    local parts = {}
    local goldCount = math.floor(copper / COPPER_PER_GOLD)
    local silverCount = math.floor(copper % COPPER_PER_GOLD / COPPER_PER_SILVER)
    local copperCount = copper % COPPER_PER_SILVER
    if goldCount > 0 then
        table.insert(parts, goldCount .. gold)
    end
    if silverCount > 0 then
        table.insert(parts, silverCount .. silver)
    end
    if copperCount > 0 or #parts == 0 then
        table.insert(parts, copperCount .. bronze)
    end
    return table.concat(parts, " ")
end

--- An amount of copper as coins with the game's coin icons, for frames.
function Money.Format(copper)
    return (copper < 0 and "-" or "") .. coins(copper, GOLD_ICON, SILVER_ICON, COPPER_ICON)
end

--- Like Format, with an explicit "+" on gains, for profits.
function Money.Signed(copper)
    return (copper < 0 and "-" or "+") .. coins(copper, GOLD_ICON, SILVER_ICON, COPPER_ICON)
end

--- An amount of copper as plain text, for chat, where icons are not allowed.
function Money.Text(copper)
    local L = ns.L
    return (copper < 0 and "-" or "") .. coins(copper, L.GOLD_SUFFIX, L.SILVER_SUFFIX, L.COPPER_SUFFIX)
end
