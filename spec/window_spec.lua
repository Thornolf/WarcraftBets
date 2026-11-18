local helpers = require("spec.helpers")
local fixture = require("spec.fixture")

local items, recipes = fixture.items, fixture.recipes

describe("window", function()
    local game, ns, slash

    local function plain(text)
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        return (text:gsub("|T.-UI%-(%a)%a+Icon.-|t", function(initial)
            return initial:lower()
        end))
    end

    local function widgets()
        return WarcraftBetsFrame.widgets
    end

    local function rowTexts()
        local out = {}
        for _, row in ipairs(widgets().rows) do
            if row:IsShown() then
                table.insert(out, row.header:IsShown() and ("# " .. row.header:GetText()) or row.name:GetText())
            end
        end
        return out
    end

    local function rowNamed(name)
        for _, row in ipairs(widgets().rows) do
            if row:IsShown() and row.name:IsShown() and row.name:GetText() == name then
                return row
            end
        end
    end

    local function start(configure)
        game = helpers.newGame()
        fixture.populate(game)
        if configure then
            configure(game)
        end
        ns = helpers.loadAddon(game, fixture.data())
        slash = SlashCmdList.WARCRAFTBETS
    end

    before_each(function()
        start()
    end)

    it("is not built until it is first opened", function()
        assert.is_nil(WarcraftBetsFrame)
    end)

    it("explains how to pick an item when opened without one", function()
        slash("")
        assert.is_true(WarcraftBetsFrame:IsShown())
        assert.are.equal("Drop an item on the slot, or Shift-click one in your bags.", widgets().name:GetText())
        assert.are.same({}, rowTexts())
        assert.is_false(widgets().detail:IsShown())
    end)

    it("opens on the last hovered item", function()
        ns.lastItem = items.ORE
        slash("")
        assert.are.equal("Copper Ore", widgets().name:GetText())
        assert.are.equal("icon-" .. items.ORE, widgets().slot.icon.texture)
        assert.are.equal("Profit per Copper Ore", widgets().profitColumn:GetText())
        assert.are.equal("TSM, raw 6s     Transformed (Copper Bar) 8s", plain(widgets().summary:GetText()))
        assert.are.same({
            "# Directly",
            "Copper Bar",
            "# With Copper Bar",
            "Copper Chain Belt",
            "Runed Copper Rod",
            "Copper Tube",
            "Rough Copper Bomb",
            "Runed Copper Bracers",
            "Copper Axe",
            "Mystery Box",
            "# Not sellable",
            "Copper Badge",
            "Enchant Bracer",
        }, rowTexts())
    end)

    it("opens on an item link or a cached item name", function()
        slash("|cffffffff|Hitem:2::::::::60:::::|h[Copper Bar]|h|r")
        assert.are.equal("Copper Bar", widgets().name:GetText())
        slash("Copper Ore")
        assert.are.equal("Copper Ore", widgets().name:GetText())
    end)

    it("says when it cannot find the item", function()
        slash("Thunderfury")
        assert.is_nil(WarcraftBetsFrame)
        assert.is_truthy(game.chat[#game.chat]:find("Item not found: Thunderfury", 1, true))
    end)

    it("closes on a second /wsb and reopens on the same item", function()
        ns.lastItem = items.ORE
        slash("")
        slash("")
        assert.is_false(WarcraftBetsFrame:IsShown())
        slash("")
        assert.is_true(WarcraftBetsFrame:IsShown())
        assert.are.equal("Copper Ore", widgets().name:GetText())
    end)

    it("closes with Escape like the native panels", function()
        slash("Copper Ore")
        assert.are.same({ "WarcraftBetsFrame" }, UISpecialFrames)
    end)

    describe("item slot", function()
        it("opens an item dropped on it and takes it off the cursor", function()
            slash("")
            game.cursorItem = items.BAR
            widgets().slot:Run("OnReceiveDrag")
            assert.are.equal("Copper Bar", widgets().name:GetText())
            assert.is_nil(game.cursorItem)
        end)

        it("opens an item clicked onto it", function()
            slash("Copper Ore")
            game.cursorItem = items.BAR
            widgets().slot:Run("OnClick", "LeftButton")
            assert.are.equal("Copper Bar", widgets().name:GetText())
        end)

        it("ignores a click with nothing on the cursor", function()
            slash("Copper Ore")
            widgets().slot:Run("OnClick", "LeftButton")
            assert.are.equal("Copper Ore", widgets().name:GetText())
        end)

        it("explains itself on hover", function()
            slash("")
            widgets().slot:Run("OnEnter")
            assert.are.equal("Drop an item here, or Shift-click one in your bags", GameTooltip.lines[1].left)
        end)
    end)

    describe("Shift-click on an item", function()
        local BAR_LINK = "|cffffffff|Hitem:2::::::::60:::::|h[Copper Bar]|h|r"

        it("opens the item when the window is open", function()
            slash("Copper Ore")
            ChatEdit_InsertLink(BAR_LINK)
            assert.are.equal("Copper Bar", widgets().name:GetText())
            assert.are.same({}, game.chatBox)
        end)

        it("is left to the chat when the chat box is open", function()
            slash("Copper Ore")
            game.chatBoxOpen = true
            ChatEdit_InsertLink(BAR_LINK)
            assert.are.equal("Copper Ore", widgets().name:GetText())
            assert.are.same({ BAR_LINK }, game.chatBox)
        end)

        it("does nothing when the window is closed", function()
            slash("Copper Ore")
            WarcraftBetsFrame:Hide()
            ChatEdit_InsertLink(BAR_LINK)
            assert.is_false(WarcraftBetsFrame:IsShown())
        end)

        it("ignores links that are not items", function()
            slash("Copper Ore")
            ChatEdit_InsertLink("|Henchant:2657|h[Smelt Copper]|h")
            assert.are.equal("Copper Ore", widgets().name:GetText())
        end)

        it("hooks the newer chat API when the client has it", function()
            start(function()
                _G.ChatFrameUtil = {
                    InsertLink = function()
                        return false
                    end,
                    GetActiveWindow = function() end,
                    OpenChat = function() end,
                }
            end)
            slash("Copper Ore")
            ChatFrameUtil.InsertLink(BAR_LINK)
            assert.are.equal("Copper Bar", widgets().name:GetText())
        end)
    end)

    describe("item field", function()
        it("shows the name of the item being studied", function()
            slash("Copper Ore")
            assert.are.equal("Copper Ore", widgets().itemField:GetText())
        end)

        it("opens the item typed into it", function()
            slash("Copper Ore")
            widgets().itemField:SetFocus()
            widgets().itemField:SetText("  Copper Bar ")
            widgets().itemField:Run("OnEnterPressed")
            assert.are.equal("Copper Bar", widgets().name:GetText())
            assert.is_false(widgets().itemField:HasFocus())
        end)

        it("says when it cannot find what was typed and keeps the current item", function()
            slash("Copper Ore")
            widgets().itemField:SetFocus()
            widgets().itemField:SetText("Thunderfury")
            widgets().itemField:Run("OnEnterPressed")
            assert.are.equal("Copper Ore", widgets().name:GetText())
            assert.is_truthy(game.chat[#game.chat]:find("Item not found: Thunderfury", 1, true))
        end)

        it("lists recent items, most recent first, while it has focus", function()
            slash("Copper Ore")
            slash("Copper Bar")
            slash("Copper Chain Belt")
            slash("Copper Bar")
            local recents = widgets().recents
            assert.is_false(recents:IsShown())
            widgets().itemField:SetFocus()
            assert.is_true(recents:IsShown())
            assert.are.equal("Recent", recents.title:GetText())
            local names = {}
            for _, row in ipairs(recents.rows) do
                if row:IsShown() then
                    table.insert(names, row.name:GetText())
                end
            end
            assert.are.same({ "Copper Bar", "Copper Chain Belt", "Copper Ore" }, names)
        end)

        it("opens a recent item that is clicked", function()
            slash("Copper Ore")
            slash("Copper Bar")
            widgets().itemField:SetFocus()
            widgets().recents.rows[2]:Run("OnClick", "LeftButton")
            assert.are.equal("Copper Ore", widgets().name:GetText())
            assert.is_false(widgets().recents:IsShown())
        end)

        it("keeps the list up long enough for a click when focus is lost, then hides it", function()
            slash("Copper Ore")
            widgets().itemField:SetFocus()
            widgets().itemField:ClearFocus()
            assert.is_true(widgets().recents:IsShown())
            game:RunTimers()
            assert.is_false(widgets().recents:IsShown())
        end)

        it("closes the list on Escape", function()
            slash("Copper Ore")
            widgets().itemField:SetFocus()
            widgets().itemField:Run("OnEscapePressed")
            assert.is_false(widgets().recents:IsShown())
        end)

        it("says so when nothing was opened yet", function()
            slash("")
            widgets().itemField:SetFocus()
            assert.are.equal("No item opened yet", widgets().recents.title:GetText())
        end)

        it("does not overwrite what is being typed when the window redraws", function()
            slash("Copper Ore")
            widgets().itemField:SetFocus()
            widgets().itemField:SetText("Copp")
            ns:Set("cut", 10)
            assert.are.equal("Copp", widgets().itemField:GetText())
        end)
    end)

    describe("recent items", function()
        it("are saved with the account and capped at ten", function()
            for item = 20, 32 do
                game.itemNames[item] = "Item " .. item
                slash("Item " .. item)
            end
            assert.are.equal(10, #ns.db.recents)
            assert.are.equal(32, ns.db.recents[1])
            assert.are.equal(23, ns.db.recents[10])
        end)

        it("are restored from the saved variables", function()
            game = helpers.newGame()
            fixture.populate(game)
            _G.WarcraftBetsDB = { recents = { items.BAR, items.ORE } }
            helpers.loadAddon(game, fixture.data())
            SlashCmdList.WARCRAFTBETS("")
            widgets().itemField:SetFocus()
            assert.are.equal("Copper Bar", widgets().recents.rows[1].name:GetText())
        end)
    end)

    describe("tabs", function()
        before_each(function()
            slash("Copper Ore")
        end)

        it("start on the item tab", function()
            assert.is_true(widgets().pages.item:IsShown())
            assert.is_false(widgets().pages.explorer:IsShown())
            assert.is_false(widgets().pages.favorites:IsShown())
            assert.is_true(widgets().tabs.item.highlightLocked)
            assert.is_false(widgets().tabs.explorer.highlightLocked)
        end)

        it("switch page when a tab is clicked", function()
            widgets().tabs.explorer:Run("OnClick")
            assert.is_false(widgets().pages.item:IsShown())
            assert.is_true(widgets().pages.explorer:IsShown())
            assert.is_true(widgets().tabs.explorer.highlightLocked)
            assert.is_false(widgets().tabs.item.highlightLocked)
        end)

        it("come back to the item tab when an item is opened", function()
            widgets().tabs.favorites:Run("OnClick")
            slash("Copper Bar")
            assert.is_true(widgets().pages.item:IsShown())
        end)

        it("stay on the same tab when the window is closed and reopened", function()
            widgets().tabs.explorer:Run("OnClick")
            slash("")
            ns.lastItem = nil
            slash("")
            assert.is_true(widgets().pages.explorer:IsShown())
        end)
    end)

    describe("craft list", function()
        before_each(function()
            slash("Copper Ore")
        end)

        it("shows the profit per unit in green or red", function()
            local belt, axe = rowNamed("Copper Chain Belt"), rowNamed("Copper Axe")
            assert.are.equal("+13s", plain(belt.profit:GetText()))
            assert.are.same(ns.View.colors.gain, belt.profit.textColor)
            assert.are.equal("-1s", plain(axe.profit:GetText()))
            assert.are.same(ns.View.colors.loss, axe.profit.textColor)
            assert.are.equal("?", rowNamed("Mystery Box").profit:GetText())
        end)

        it("shows the cost of unsellable crafts in grey", function()
            local badge = rowNamed("Copper Badge")
            assert.are.equal("12s", plain(badge.profit:GetText()))
            assert.are.same(ns.View.colors.grey, badge.profit.textColor)
        end)

        it("greys out unlearned crafts and colours learned ones by quality", function()
            game.knownSpells[recipes.TUBE], game.ranks[fixture.SMITHING] = true, 100
            game:Fire("PLAYER_LOGIN")
            game:RunTimers()
            local tube, belt = rowNamed("Copper Tube"), rowNamed("Copper Chain Belt")
            assert.is_false(tube.icon.desaturated)
            assert.are.same({ 0.12, 1, 0 }, tube.name.textColor)
            assert.is_true(belt.icon.desaturated)
            assert.are.same(ns.View.colors.unlearned, belt.name.textColor)
        end)

        it("uses the spell icon for a craft that makes no item", function()
            assert.are.equal("spell-" .. recipes.ENCHANT, rowNamed("Enchant Bracer").icon.texture)
        end)

        it("does not let group headers be clicked", function()
            assert.is_false(widgets().rows[1].mouse)
            assert.is_true(widgets().rows[2].mouse)
        end)

        it("filters by search text", function()
            widgets().search:SetText("runed")
            assert.are.same({ "# With Copper Bar", "Runed Copper Rod", "Runed Copper Bracers" }, rowTexts())
        end)

        it("says when nothing matches", function()
            widgets().search:SetText("zzz")
            assert.are.same({}, rowTexts())
            assert.is_true(widgets().empty:IsShown())
            assert.are.equal("No craft matches.", widgets().empty:GetText())
            assert.is_false(widgets().detail:IsShown())
        end)

        it("says when no recipe uses the item", function()
            slash("Copper Chain Belt")
            assert.are.equal("No recipe uses this item.", widgets().empty:GetText())
        end)

        it("cycles the learned filter forwards and backwards", function()
            local filter = widgets().filter
            assert.are.equal("All", filter:GetText())
            filter:Run("OnClick", "LeftButton")
            assert.are.equal("Learned (this character)", filter:GetText())
            assert.are.same({}, rowTexts())
            filter:Run("OnClick", "RightButton")
            filter:Run("OnClick", "RightButton")
            assert.are.equal("Learnable now", filter:GetText())
        end)

        it("clears the search when another item is opened", function()
            widgets().search:SetText("runed")
            slash("Copper Bar")
            assert.are.equal("", widgets().search:GetText())
            assert.are.equal(11, #rowTexts())
        end)

        it("shows the game tooltip of the product under the mouse", function()
            rowNamed("Copper Chain Belt"):Run("OnEnter")
            assert.are.equal(items.BELT, GameTooltip.item)
            rowNamed("Copper Chain Belt"):Run("OnLeave")
            assert.is_false(GameTooltip:IsShown())
        end)
    end)

    describe("scrolling", function()
        before_each(function()
            game = helpers.newGame()
            fixture.populate(game)
            local data = fixture.data()
            for extra = 1, 20 do
                data.recipes[500 + extra] = { fixture.SMITHING, 30, 60, 0, 600 + extra, 1, items.BAR, 1 }
                game.itemNames[600 + extra] = "Trinket " .. extra
            end
            ns = helpers.loadAddon(game, data)
            SlashCmdList.WARCRAFTBETS("Copper Ore")
        end)

        it("shows a scrollbar only when the list overflows", function()
            assert.is_true(widgets().scrollbar:IsShown())
            assert.are.same({ 0, 17 }, { widgets().scrollbar:GetMinMaxValues() })
            widgets().search:SetText("belt")
            assert.is_false(widgets().scrollbar:IsShown())
        end)

        it("scrolls with the mouse wheel and stops at both ends", function()
            widgets().list:Run("OnMouseWheel", -1)
            assert.are.equal("Copper Chain Belt", widgets().rows[1].name:GetText())
            for _ = 1, 20 do
                widgets().list:Run("OnMouseWheel", -1)
            end
            assert.are.equal("Enchant Bracer", widgets().rows[16].name:GetText())
            for _ = 1, 20 do
                widgets().list:Run("OnMouseWheel", 1)
            end
            assert.are.equal("Directly", widgets().rows[1].header:GetText())
        end)

        it("scrolls when the scrollbar is dragged", function()
            widgets().scrollbar:SetValue(17)
            assert.are.equal("Enchant Bracer", widgets().rows[16].name:GetText())
        end)
    end)

    describe("detail panel", function()
        before_each(function()
            slash("Copper Ore")
        end)

        it("shows the best craft first", function()
            local detail = widgets().detail
            assert.is_true(detail:IsShown())
            assert.are.equal("Copper Bar", detail.name:GetText())
            assert.is_true(widgets().rows[2].selected:IsShown())
        end)

        it("shows the craft that is clicked", function()
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
            local detail = widgets().detail
            assert.are.equal("Copper Chain Belt", detail.name:GetText())
            assert.are.equal("Blacksmithing · requires skill 35", detail.skill:GetText())
            assert.are.equal("Recipe not learned", detail.state:GetText())
            assert.is_true(detail.icon.desaturated)
            assert.is_true(rowNamed("Copper Chain Belt").selected:IsShown())
            assert.is_false(widgets().rows[2].selected:IsShown())
        end)

        it("lists reagents and hides unused reagent rows", function()
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
            local reagents = widgets().detail.reagents
            assert.are.equal("Copper Bar x6", reagents[1].label:GetText())
            assert.are.equal("buy 48s  ·  craft 36s", plain(reagents[1].cost:GetText()))
            assert.is_true(reagents[1]:IsShown())
            assert.is_false(reagents[2]:IsShown())
        end)

        it("breaks the profit down", function()
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
            local economics = widgets().detail.economics
            assert.are.equal("Profit per craft", economics[4].label:GetText())
            assert.are.equal("+78s", plain(economics[4].values[3]:GetText()))
            assert.are.equal("Profit per Copper Ore", economics[5].label:GetText())
            assert.are.equal("+13s", plain(economics[5].values[3]:GetText()))
        end)

        it("shows the three cost modes side by side and stresses the active one", function()
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
            local detail = widgets().detail
            assert.are.equal("For me", detail.modeHeaders[1]:GetText())
            assert.are.equal("Buy all", detail.modeHeaders[2]:GetText())
            assert.are.equal("Craft all", detail.modeHeaders[3]:GetText())
            assert.are.same(ns.View.colors.title, detail.modeHeaders[3].textColor)
            assert.are.same(ns.View.colors.grey, detail.modeHeaders[1].textColor)
            local profit = detail.economics[4].values
            assert.are.equal("+66s", plain(profit[1]:GetText()))
            assert.are.equal("+66s", plain(profit[2]:GetText()))
            assert.are.equal("+78s", plain(profit[3]:GetText()))
            assert.are.equal("GameFontNormal", profit[3].font)
            assert.are.equal("GameFontHighlightSmall", profit[1].font)
            assert.are.equal(1, profit[3].alpha)
            assert.are.equal(0.7, profit[1].alpha)
        end)

        it("hides the sale statistics when TSM has none and shows them when it does", function()
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
            assert.is_false(widgets().detail.sales:IsShown())
            local market = _G.TSM_API.GetCustomPriceValue
            _G.TSM_API.GetCustomPriceValue = function(formula, itemString)
                if formula == "DBRegionSaleRate*1000" then
                    return 481
                elseif formula == "DBRegionSoldPerDay*1000" then
                    return 4810
                elseif formula == "DBRegionSaleAvg" or formula == "DBMinBuyout" then
                    return 5319
                end
                return market(formula, itemString)
            end
            ns:Set("cut", 5)
            assert.is_true(widgets().detail.sales:IsShown())
            assert.are.equal("4.8 a day, 48%", widgets().detail.sales.rows[1].value:GetText())
        end)

        it("hides the profit rows an unsellable craft does not have", function()
            rowNamed("Copper Badge"):Run("OnClick", "LeftButton")
            local economics = widgets().detail.economics
            assert.are.equal("Cannot be sold", economics[1].label:GetText())
            assert.is_true(economics[2].label:IsShown())
            assert.is_false(economics[3].label:IsShown())
        end)

        it("names the price source", function()
            assert.are.equal("Price source: TSM (Market value)", widgets().detail.source:GetText())
        end)

        it("opens the window on a reagent that is clicked", function()
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
            widgets().detail.reagents[1]:Run("OnClick", "LeftButton")
            assert.are.equal("Copper Bar", widgets().name:GetText())
        end)

        it("shows the alternatives of a reagent in its tooltip", function()
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
            widgets().detail.reagents[1]:Run("OnEnter")
            assert.are.equal(items.BAR, GameTooltip.item)
            assert.are.equal("auction house", GameTooltip.lines[2].left)
            assert.are.equal("crafted", GameTooltip.lines[3].left)
        end)

        it("keeps the selection when the list is filtered around it", function()
            rowNamed("Runed Copper Rod"):Run("OnClick", "LeftButton")
            widgets().search:SetText("runed")
            assert.are.equal("Runed Copper Rod", widgets().detail.name:GetText())
            widgets().search:SetText("belt")
            assert.are.equal("Copper Chain Belt", widgets().detail.name:GetText())
        end)
    end)

    describe("link in chat button", function()
        before_each(function()
            slash("Copper Ore")
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
        end)

        it("opens the chat box with the item link, cost, sale price and profit", function()
            widgets().detail.linkButton:Run("OnClick")
            assert.are.same(
                { "|Hitem:3|h[Copper Chain Belt]|h: cost 36s, sells for 1g 20s, profit 78s" },
                game.chatBox
            )
        end)

        it("inserts into a chat box that is already open", function()
            game.chatBoxOpen = true
            widgets().detail.linkButton:Run("OnClick")
            assert.are.equal(1, #game.chatBox)
        end)

        it("links only the cost of an unsellable craft", function()
            rowNamed("Copper Badge"):Run("OnClick", "LeftButton")
            widgets().detail.linkButton:Run("OnClick")
            assert.are.same({ "|Hitem:9|h[Copper Badge]|h: cost 12s" }, game.chatBox)
        end)

        it("names the spell of a craft that makes no item", function()
            rowNamed("Enchant Bracer"):Run("OnClick", "LeftButton")
            widgets().detail.linkButton:Run("OnClick")
            assert.are.same({ "Enchant Bracer: cost 6s" }, game.chatBox)
        end)

        it("writes question marks for missing prices", function()
            rowNamed("Mystery Box"):Run("OnClick", "LeftButton")
            widgets().detail.linkButton:Run("OnClick")
            assert.are.same({ "|Hitem:10|h[Mystery Box]|h: cost 6s, sells for ?, profit ?" }, game.chatBox)
        end)

        it("uses the newer chat API when the client has it", function()
            local inserted
            _G.ChatFrameUtil = {
                InsertLink = function(text)
                    inserted = text
                    return true
                end,
            }
            widgets().detail.linkButton:Run("OnClick")
            assert.is_truthy(inserted:find("profit 78s", 1, true))
            assert.are.same({}, game.chatBox)
        end)
    end)

    describe("shopping list button", function()
        local lists

        local function installAuctionator(v1)
            lists = {}
            v1.CreateShoppingList = v1.CreateShoppingList
                or function(caller, name, terms)
                    table.insert(lists, { caller = caller, name = name, terms = terms })
                end
            _G.Auctionator = { API = { v1 = v1 } }
        end

        it("is hidden without Auctionator", function()
            slash("Copper Ore")
            assert.is_false(widgets().detail.shopButton:IsShown())
        end)

        it("creates a list of what to buy, with exact names and quantities", function()
            installAuctionator({
                ConvertToSearchString = function(_, term)
                    return term.searchString .. ";" .. tostring(term.isExact) .. ";" .. term.quantity
                end,
            })
            slash("Copper Ore")
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
            assert.is_true(widgets().detail.shopButton:IsShown())
            widgets().detail.shopButton:Run("OnClick")
            assert.are.same({
                { caller = "WarcraftBets", name = "WarcraftBets: Copper Chain Belt", terms = { "Copper Ore;true;6" } },
            }, lists)
            assert.is_truthy(game.chat[#game.chat]:find("WarcraftBets: Copper Chain Belt", 1, true))
        end)

        it("falls back to plain names on an older Auctionator", function()
            installAuctionator({})
            slash("Copper Ore")
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
            widgets().detail.shopButton:Run("OnClick")
            assert.are.same({ "Copper Ore" }, lists[1].terms)
        end)

        it("falls back to plain names when Auctionator cannot build a search term", function()
            installAuctionator({
                ConvertToSearchString = function()
                    error("unsupported")
                end,
            })
            slash("Copper Ore")
            rowNamed("Copper Chain Belt"):Run("OnClick", "LeftButton")
            widgets().detail.shopButton:Run("OnClick")
            assert.are.same({ "Copper Ore" }, lists[1].terms)
        end)

        it("says when Auctionator refuses the list", function()
            installAuctionator({
                CreateShoppingList = function()
                    error("list exists")
                end,
            })
            slash("Copper Ore")
            widgets().detail.shopButton:Run("OnClick")
            assert.is_truthy(game.chat[#game.chat]:find("Auctionator refused the shopping list.", 1, true))
        end)

        it("says when the craft needs nothing from the auction house", function()
            installAuctionator({})
            game.itemNames[items.ORE] = nil
            slash("|Hitem:1|h[x]|h")
            widgets().detail.shopButton:Run("OnClick")
            assert.are.same({}, lists)
            assert.is_truthy(game.chat[#game.chat]:find("Nothing to buy", 1, true))
        end)
    end)

    describe("price source button", function()
        it("cycles the source and redraws", function()
            slash("Copper Ore")
            local button = widgets().sourceButton
            assert.are.equal("Prices: Auto", button:GetText())
            button:Run("OnClick")
            assert.are.equal("tsm", ns.db.settings.priceSource)
            assert.are.equal("Prices: TSM", button:GetText())
            button:Run("OnClick")
            assert.are.equal("Prices: Auctionator", button:GetText())
            assert.are.equal("?", rowNamed("Copper Chain Belt").profit:GetText())
            button:Run("OnClick")
            assert.are.equal("Prices: Auto", button:GetText())
        end)
    end)

    describe("cost mode selector", function()
        before_each(function()
            slash("Copper Ore")
        end)

        it("marks the active mode", function()
            assert.is_true(widgets().modes.all.highlightLocked)
            assert.is_false(widgets().modes.mine.highlightLocked)
        end)

        it("switches mode, re-ranks the list and saves the choice", function()
            assert.are.equal("+13s", plain(rowNamed("Copper Chain Belt").profit:GetText()))
            widgets().modes.buy:Run("OnClick")
            assert.are.equal("buy", ns.db.settings.costMode)
            assert.is_true(widgets().modes.buy.highlightLocked)
            assert.is_false(widgets().modes.all.highlightLocked)
            assert.are.equal("+11s", plain(rowNamed("Copper Chain Belt").profit:GetText()))
        end)

        it("explains each mode on hover", function()
            widgets().modes.mine:Run("OnEnter")
            assert.is_truthy(GameTooltip.lines[1].left:find("recipes your characters know", 1, true))
        end)

        it("drives the tooltip too", function()
            widgets().modes.buy:Run("OnClick")
            local lines = ns.View.TooltipLines(items.ORE, false)
            assert.are.equal("Copper Chain Belt", lines[4].left)
            assert.are.equal("+11s", plain(lines[4].right))
        end)
    end)

    describe("TSM price button", function()
        local minBuyout

        before_each(function()
            minBuyout = { [items.ORE] = 500, [items.BAR] = 700, [items.BELT] = 9000 }
            _G.TSM_API.GetCustomPriceValue = function(formula, itemString)
                local item = tonumber(itemString:match("%d+"))
                if formula == "DBMinBuyout" then
                    return minBuyout[item]
                end
                return game.prices[item]
            end
            slash("Copper Ore")
        end)

        it("switches between market value and minimum buyout and recomputes profits", function()
            local button = widgets().formulaButton
            assert.are.equal("Market value", button:GetText())
            assert.are.equal("+13s", plain(rowNamed("Copper Chain Belt").profit:GetText()))
            button:Run("OnClick")
            assert.are.equal("DBMinBuyout", ns.db.settings.tsmFormula)
            assert.are.equal("Min buyout", button:GetText())
            assert.are.equal("+9s 25c", plain(rowNamed("Copper Chain Belt").profit:GetText()))
            assert.are.equal("TSM, raw 5s     Transformed (Copper Bar) 7s", plain(widgets().summary:GetText()))
            button:Run("OnClick")
            assert.are.equal("DBMarket", ns.db.settings.tsmFormula)
            assert.are.equal("+13s", plain(rowNamed("Copper Chain Belt").profit:GetText()))
        end)

        it("shows a question mark for an item with no auction right now", function()
            widgets().formulaButton:Run("OnClick")
            assert.are.equal("?", rowNamed("Copper Tube").profit:GetText())
        end)

        it("says when a custom formula is in use and goes back to market value on click", function()
            ns:Set("tsmFormula", "min(DBMarket, DBRegionMarketAvg)")
            assert.are.equal("Custom formula", widgets().formulaButton:GetText())
            widgets().formulaButton:Run("OnClick")
            assert.are.equal("DBMarket", ns.db.settings.tsmFormula)
        end)

        it("is hidden without TSM", function()
            _G.TSM_API = nil
            ns:Set("priceSource", "auto")
            assert.is_false(widgets().formulaButton:IsShown())
        end)
    end)

    describe("moving", function()
        before_each(function()
            slash("Copper Ore")
        end)

        it("starts centred", function()
            assert.are.same({ "CENTER", UIParent, "CENTER", 0, 0 }, WarcraftBetsFrame.point)
        end)

        it("shows the green overlay only while dragged", function()
            local overlay = widgets().dragOverlay
            assert.is_false(overlay:IsShown())
            WarcraftBetsFrame:Run("OnDragStart")
            assert.is_true(overlay:IsShown())
            WarcraftBetsFrame:Run("OnDragStop")
            assert.is_false(overlay:IsShown())
        end)

        it("remembers where it was dropped", function()
            WarcraftBetsFrame:Run("OnDragStart")
            WarcraftBetsFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -80)
            WarcraftBetsFrame:Run("OnDragStop")
            assert.are.same({ point = "TOPLEFT", relativePoint = "TOPLEFT", x = 120, y = -80 }, ns.db.window)
        end)

        it("drops cleanly when closed in the middle of a drag", function()
            WarcraftBetsFrame:Run("OnDragStart")
            WarcraftBetsFrame:Hide()
            assert.is_false(widgets().dragOverlay:IsShown())
            assert.is_table(ns.db.window)
        end)

        it("goes back to the centre on /wsb reset", function()
            WarcraftBetsFrame:Run("OnDragStart")
            WarcraftBetsFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -80)
            WarcraftBetsFrame:Run("OnDragStop")
            slash("reset")
            assert.is_nil(ns.db.window)
            assert.are.same({ "CENTER", UIParent, "CENTER", 0, 0 }, WarcraftBetsFrame.point)
        end)
    end)

    it("restores the saved position when first built", function()
        game = helpers.newGame()
        _G.WarcraftBetsDB = { window = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 50, y = -60 } }
        helpers.loadAddon(game, fixture.data())
        SlashCmdList.WARCRAFTBETS("")
        assert.are.same({ "TOPLEFT", UIParent, "TOPLEFT", 50, -60 }, WarcraftBetsFrame.point)
    end)

    describe("in combat", function()
        it("closes when combat starts", function()
            slash("Copper Ore")
            game:Fire("PLAYER_REGEN_DISABLED")
            assert.is_false(WarcraftBetsFrame:IsShown())
        end)

        it("refuses to open", function()
            game.inCombat = true
            slash("Copper Ore")
            assert.is_nil(WarcraftBetsFrame)
            assert.is_truthy(game.chat[#game.chat]:find("Not available in combat.", 1, true))
        end)
    end)

    it("redraws once when item names finish loading", function()
        game.itemNames[items.BELT] = nil
        slash("Copper Ore")
        assert.is_truthy(rowNamed("Loading..."))
        game.itemNames[items.BELT] = "Copper Chain Belt"
        game:Fire("GET_ITEM_INFO_RECEIVED", items.BELT, true)
        game:Fire("GET_ITEM_INFO_RECEIVED", items.BELT, true)
        assert.are.equal(1, #game.timers)
        game:RunTimers()
        assert.is_truthy(rowNamed("Copper Chain Belt"))
    end)

    it("redraws when a recipe is learned", function()
        slash("Copper Ore")
        game.knownSpells[recipes.BELT], game.ranks[fixture.SMITHING] = true, 100
        game:Fire("NEW_RECIPE_LEARNED")
        game:RunTimers()
        assert.is_false(rowNamed("Copper Chain Belt").icon.desaturated)
    end)

    it("still opens on a client without the native panel templates", function()
        start(function(fresh)
            fresh.missingTemplates = {
                BasicFrameTemplateWithInset = true,
                UIPanelButtonTemplate = true,
                SearchBoxTemplate = true,
                InputBoxTemplate = true,
                UIPanelCloseButton = true,
            }
        end)
        slash("Copper Ore")
        assert.is_true(WarcraftBetsFrame:IsShown())
        assert.are.equal("Copper Ore", widgets().name:GetText())
    end)
end)
