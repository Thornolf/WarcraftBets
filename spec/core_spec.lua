local helpers = require("spec.helpers")

describe("core", function()
    local game, ns

    before_each(function()
        game = helpers.newGame("frFR")
        ns = game:Load("Locales/enUS.lua", "Locales/frFR.lua", "Core.lua")
    end)

    it("lists every Lua file of the TOC on disk", function()
        for _, path in ipairs(helpers.tocFiles()) do
            assert.is_truthy(io.open(path), path .. " is listed in the TOC but missing")
        end
    end)

    it("carries the version written in the TOC", function()
        local tocVersion
        for line in io.lines("WarcraftBets.toc") do
            tocVersion = tocVersion or line:match("^## Version: (%S+)")
        end
        assert.are.equal(tocVersion, ns.version)
    end)

    it("uses the client language and falls back to English", function()
        assert.are.equal("/wsb : ouvre ou ferme la fenêtre", ns.L.HELP_OPEN)
        ns.locales.frFR.HELP_OPEN = nil
        assert.are.equal("/wsb: open or close the window", ns.L.HELP_OPEN)
    end)

    it("fills in default settings without overwriting saved ones", function()
        _G.WarcraftBetsDB = { settings = { depth = 5 } }
        game:Fire("ADDON_LOADED", "WarcraftBets")
        assert.are.equal(5, ns.db.settings.depth)
        assert.are.equal(5, ns.db.settings.cut)
        assert.are.equal("auto", ns.db.settings.priceSource)
    end)

    it("ignores other add-ons loading", function()
        game:Fire("ADDON_LOADED", "SomethingElse")
        assert.is_nil(ns.db)
    end)

    it("ignores events the client does not know", function()
        assert.has_no.errors(function()
            ns:On("UNKNOWN_EVENT", function() end)
        end)
    end)

    it("registers /wsb and /wb", function()
        assert.are.equal("/wsb", _G.SLASH_WARCRAFTBETS1)
        assert.are.equal("/wb", _G.SLASH_WARCRAFTBETS2)
    end)

    it("prints help for a bare command until a module takes it over", function()
        _G.SlashCmdList.WARCRAFTBETS("")
        assert.are.equal(5, #game.chat)
        assert.is_truthy(game.chat[1]:find("1.1.0", 1, true))
    end)

    it("routes sub-commands and free text", function()
        local seen = {}
        ns:RegisterCommand("reset", function()
            seen.reset = true
        end)
        ns:RegisterCommand("*", function(text)
            seen.text = text
        end)
        _G.SlashCmdList.WARCRAFTBETS(" RESET ")
        _G.SlashCmdList.WARCRAFTBETS("Copper Ore")
        assert.is_true(seen.reset)
        assert.are.equal("Copper Ore", seen.text)
    end)

    it("tells modules when a setting changes", function()
        game:Fire("ADDON_LOADED", "WarcraftBets")
        local changed
        ns:OnMessage("SETTINGS_CHANGED", function(key)
            changed = key
        end)
        ns:Set("cut", 10)
        assert.are.equal("cut", changed)
        assert.are.equal(10, ns.db.settings.cut)
    end)
end)
