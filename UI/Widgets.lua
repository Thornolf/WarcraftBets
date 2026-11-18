local _, ns = ...

-- Small building blocks shared by the window and its tab pages.
local Widgets = {}
ns.Widgets = Widgets

--- A single-line font string that truncates instead of wrapping.
function Widgets.Label(parent, font, justify)
    local text = parent:CreateFontString(nil, "ARTWORK", font)
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    return text
end

--- A texture filled with a flat colour.
function Widgets.ColorTexture(parent, layer, r, g, b, a)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetColorTexture(r, g, b, a)
    return texture
end

local STAR_TEXTURE = "Interface\\Common\\ReputationStar"

--- A star, lit when `starred`. The texture holds the lit star in its top-left
--- quarter and the outline in its top-right quarter.
function Widgets.SetStar(texture, starred)
    texture:SetTexture(STAR_TEXTURE)
    if starred then
        texture:SetTexCoord(0, 0.5, 0, 0.5)
    else
        texture:SetTexCoord(0.5, 1, 0, 0.5)
    end
    texture:SetDesaturated(not starred)
    texture:SetAlpha(starred and 1 or 0.6)
end

--- A clickable star button; call `button:SetStarred(bool)` to light it.
function Widgets.StarButton(parent, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button.star = button:CreateTexture(nil, "ARTWORK")
    button.star:SetAllPoints(button)
    function button:SetStarred(starred)
        self.starred = starred
        Widgets.SetStar(self.star, starred)
    end
    button:SetStarred(false)
    return button
end
