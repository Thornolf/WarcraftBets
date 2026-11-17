-- A small crafting world shared by the view and window specs: copper ore is
-- smelted into bars, and bars go into a few blacksmithing crafts.

local fixture = {}

fixture.MINING, fixture.SMITHING, fixture.ENCHANTING = 186, 164, 333

local items = {
    ORE = 1,
    BAR = 2,
    BELT = 3,
    ROD = 4,
    TUBE = 5,
    BOMB = 6,
    BRACERS = 7,
    AXE = 8,
    BADGE = 9,
    MYSTERY = 10,
}
fixture.items = items

local recipes = {
    SMELT = 100,
    BELT = 101,
    ROD = 102,
    TUBE = 103,
    BOMB = 104,
    BRACERS = 105,
    AXE = 106,
    BADGE = 107,
    ENCHANT = 108,
    MYSTERY = 109,
}
fixture.recipes = recipes

--- Recipe data in the generated format.
function fixture.data()
    local smithing = fixture.SMITHING
    return {
        skills = {
            [fixture.MINING] = "Mining",
            [smithing] = "Blacksmithing",
            [fixture.ENCHANTING] = "Enchanting",
        },
        recipes = {
            [recipes.SMELT] = { fixture.MINING, 25, 70, 0, items.BAR, 1, items.ORE, 1 },
            [recipes.BELT] = { smithing, 70, 110, 35, items.BELT, 1, items.BAR, 6 },
            [recipes.ROD] = { smithing, 30, 60, 0, items.ROD, 1, items.BAR, 4 },
            [recipes.TUBE] = { smithing, 30, 60, 0, items.TUBE, 1, items.BAR, 2 },
            [recipes.BOMB] = { smithing, 30, 60, 0, items.BOMB, 1, items.BAR, 1 },
            [recipes.BRACERS] = { smithing, 30, 60, 0, items.BRACERS, 1, items.BAR, 2 },
            [recipes.AXE] = { smithing, 30, 60, 0, items.AXE, 1, items.BAR, 3 },
            [recipes.BADGE] = { smithing, 30, 60, 0, items.BADGE, 1, items.BAR, 2 },
            [recipes.ENCHANT] = { fixture.ENCHANTING, 30, 60, 0, 0, 1, items.BAR, 1 },
            [recipes.MYSTERY] = { smithing, 30, 60, 0, items.MYSTERY, 1, items.BAR, 1 },
        },
        childSkills = { [2938] = smithing },
        vendor = {},
        unsellable = { items.BADGE },
    }
end

--- Fills a fake game with names and auction prices. Per ore, the crafts earn:
--- belt 13s, rod 10s, tube 8s, bomb 5s, bracers 3s, smelting 1s60c, axe -1s;
--- the mystery item has no price.
function fixture.populate(game)
    game.itemNames = {
        [items.ORE] = "Copper Ore",
        [items.BAR] = "Copper Bar",
        [items.BELT] = "Copper Chain Belt",
        [items.ROD] = "Runed Copper Rod",
        [items.TUBE] = "Copper Tube",
        [items.BOMB] = "Rough Copper Bomb",
        [items.BRACERS] = "Runed Copper Bracers",
        [items.AXE] = "Copper Axe",
        [items.BADGE] = "Copper Badge",
        [items.MYSTERY] = "Mystery Box",
    }
    game.spellNames = { [recipes.ENCHANT] = "Enchant Bracer" }
    game.prices = {
        [items.ORE] = 600,
        [items.BAR] = 800,
        [items.BELT] = 12000,
        [items.ROD] = 6737,
        [items.TUBE] = 2947,
        [items.BOMB] = 1158,
        [items.BRACERS] = 1895,
        [items.AXE] = 1579,
    }
end

return fixture
