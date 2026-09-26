local addonName, ns = ...
if ns.skipLoad then return end
if not ns.IsForever and not ns.isTestEnvironment then return end
local RoithiUI = _G.RoithiUI
local SwingTimer = RoithiUI:GetModule("SwingTimer", true)
if not SwingTimer then return end
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

function SwingTimer:GetOptions()
    local options = {
        type = "group",
        name = L["Swing Timer"],
        order = 96,
        args = {
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                inline = true,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable Swing Timer"],
                        desc = L["Enables the dedicated weapon swing timer module for Forever."],
                        order = 1,
                        get = function() return self.db.enabled ~= false end,
                        set = function(_, val)
                            self.db.enabled = val
                            if val then self:Enable() else self:Disable() end
                        end,
                    },
                },
            },
            player = {
                type = "group",
                name = L["Player Swing Timer"],
                order = 2,
                inline = true,
                disabled = function() return not self.db.enabled end,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable Player Timer"],
                        order = 1,
                        get = function() return self.db.player.enabled ~= false end,
                        set = function(_, val)
                            self.db.player.enabled = val
                            self:UpdateLayout()
                        end,
                    },
                    showOffhand = {
                        type = "toggle",
                        name = L["Show Off-Hand Bar"],
                        desc = L["Display a second swing bar when dual wielding."],
                        order = 2,
                        get = function() return self.db.player.showOffhand ~= false end,
                        set = function(_, val)
                            self.db.player.showOffhand = val
                            self:UpdateLayout()
                        end,
                    },
                    showText = {
                        type = "toggle",
                        name = L["Show Text"],
                        desc = L["Display weapon labels and remaining swing time."],
                        order = 3,
                        get = function() return self.db.player.showText ~= false end,
                        set = function(_, val)
                            self.db.player.showText = val
                            self:UpdateLayout()
                        end,
                    },
                    width = {
                        type = "range",
                        name = L["Width"],
                        min = 100,
                        max = 400,
                        step = 5,
                        order = 4,
                        get = function() return self.db.player.width or 200 end,
                        set = function(_, val)
                            self.db.player.width = val
                            self:UpdateLayout()
                        end,
                    },
                    height = {
                        type = "range",
                        name = L["Height"],
                        min = 6,
                        max = 30,
                        step = 1,
                        order = 5,
                        get = function() return self.db.player.height or 12 end,
                        set = function(_, val)
                            self.db.player.height = val
                            self:UpdateLayout()
                        end,
                    },
                    colorMain = {
                        type = "color",
                        name = L["Main Hand Color"],
                        hasAlpha = true,
                        order = 6,
                        get = function()
                            local c = self.db.player.colorMain or { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
                            return c.r, c.g, c.b, c.a or 1.0
                        end,
                        set = function(_, r, g, b, a)
                            self.db.player.colorMain = { r = r, g = g, b = b, a = a }
                            self:UpdateLayout()
                        end,
                    },
                    colorOff = {
                        type = "color",
                        name = L["Off Hand Color"],
                        hasAlpha = true,
                        order = 7,
                        get = function()
                            local c = self.db.player.colorOff or { r = 0.35, g = 0.75, b = 1.0, a = 1.0 }
                            return c.r, c.g, c.b, c.a or 1.0
                        end,
                        set = function(_, r, g, b, a)
                            self.db.player.colorOff = { r = r, g = g, b = b, a = a }
                            self:UpdateLayout()
                        end,
                    },
                    colorRanged = {
                        type = "color",
                        name = L["Ranged Color"],
                        hasAlpha = true,
                        order = 8,
                        get = function()
                            local c = self.db.player.colorRanged or { r = 0.2, g = 0.85, b = 0.35, a = 1.0 }
                            return c.r, c.g, c.b, c.a or 1.0
                        end,
                        set = function(_, r, g, b, a)
                            self.db.player.colorRanged = { r = r, g = g, b = b, a = a }
                            self:UpdateLayout()
                        end,
                    },
                },
            },
            target = {
                type = "group",
                name = L["Target Swing Timer"],
                order = 3,
                inline = true,
                disabled = function() return not self.db.enabled end,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable Target Timer"],
                        order = 1,
                        get = function() return self.db.target.enabled ~= false end,
                        set = function(_, val)
                            self.db.target.enabled = val
                            self:UpdateLayout()
                        end,
                    },
                    showText = {
                        type = "toggle",
                        name = L["Show Text"],
                        desc = L["Display target label and remaining swing time."],
                        order = 2,
                        get = function() return self.db.target.showText ~= false end,
                        set = function(_, val)
                            self.db.target.showText = val
                            self:UpdateLayout()
                        end,
                    },
                    width = {
                        type = "range",
                        name = L["Width"],
                        min = 100,
                        max = 400,
                        step = 5,
                        order = 3,
                        get = function() return self.db.target.width or 200 end,
                        set = function(_, val)
                            self.db.target.width = val
                            self:UpdateLayout()
                        end,
                    },
                    height = {
                        type = "range",
                        name = L["Height"],
                        min = 6,
                        max = 30,
                        step = 1,
                        order = 4,
                        get = function() return self.db.target.height or 12 end,
                        set = function(_, val)
                            self.db.target.height = val
                            self:UpdateLayout()
                        end,
                    },
                    color = {
                        type = "color",
                        name = L["Target Bar Color"],
                        hasAlpha = true,
                        order = 5,
                        get = function()
                            local c = self.db.target.color or { r = 0.85, g = 0.25, b = 0.25, a = 1.0 }
                            return c.r, c.g, c.b, c.a or 1.0
                        end,
                        set = function(_, r, g, b, a)
                            self.db.target.color = { r = r, g = g, b = b, a = a }
                            self:UpdateLayout()
                        end,
                    },
                },
            },
        },
    }
    return options
end
