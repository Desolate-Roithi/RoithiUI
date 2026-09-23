local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local MenuMod = RoithiUI:GetModule("Menu")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

function MenuMod:GetOptions()
    return {
        type = "group",
        name = L["Menu"],
        order = 85,
        args = {
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                inline = true,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable"],
                        order = 1,
                        get = function() return self.db.enabled ~= false end,
                        set = function(_, val)
                            self.db.enabled = val
                            if val then self:Enable() else self:Disable() end
                        end,
                    },
                    styleMicroMenu = {
                        type = "toggle",
                        name = L["Style Micro Menu"],
                        desc = L["Modern borderless styling for the Micro Menu buttons."],
                        order = 2,
                        get = function() return self.db.styleMicroMenu ~= false end,
                        set = function(_, val)
                            self.db.styleMicroMenu = val
                            if val then self:LayoutMicroMenu() else self:RestoreMicroButtons() end
                        end,
                    },
                },
            },
            microMenu = {
                type = "group",
                name = L["Micro Menu Settings"],
                order = 2,
                inline = true,
                disabled = function() return not (self.db.enabled and self.db.styleMicroMenu) end,
                args = {
                    orientation = {
                        type = "select",
                        name = L["Orientation"],
                        order = 1,
                        values = {
                            ["HORIZONTAL"] = L["Horizontal"],
                            ["VERTICAL"] = L["Vertical"],
                        },
                        get = function() return self.db.orientation or "HORIZONTAL" end,
                        set = function(_, val)
                            self.db.orientation = val
                            self:LayoutMicroMenu()
                        end,
                    },
                    buttonWidth = {
                        type = "range",
                        name = L["Button Width"],
                        order = 2,
                        min = 16,
                        max = 48,
                        step = 1,
                        get = function() return self.db.buttonWidth or 24 end,
                        set = function(_, val)
                            self.db.buttonWidth = val
                            self:LayoutMicroMenu()
                        end,
                    },
                    buttonHeight = {
                        type = "range",
                        name = L["Button Height"],
                        order = 3,
                        min = 16,
                        max = 48,
                        step = 1,
                        get = function() return self.db.buttonHeight or 32 end,
                        set = function(_, val)
                            self.db.buttonHeight = val
                            self:LayoutMicroMenu()
                        end,
                    },
                    spacing = {
                        type = "range",
                        name = L["Button Spacing"],
                        order = 4,
                        min = 0,
                        max = 10,
                        step = 1,
                        get = function() return self.db.spacing or 2 end,
                        set = function(_, val)
                            self.db.spacing = val
                            self:LayoutMicroMenu()
                        end,
                    },
                    alpha = {
                        type = "range",
                        name = L["Opacity"],
                        order = 5,
                        min = 0.1,
                        max = 1.0,
                        step = 0.05,
                        isPercent = true,
                        get = function() return self.db.alpha or 1.0 end,
                        set = function(_, val)
                            self.db.alpha = val
                            self:UpdateMicroMenuAlpha()
                        end,
                    },
                    mouseover = {
                        type = "toggle",
                        name = L["Mouseover Fade"],
                        order = 6,
                        get = function() return self.db.mouseover == true end,
                        set = function(_, val)
                            self.db.mouseover = val
                            self:UpdateMicroMenuAlpha()
                        end,
                    },
                    mouseoverAlpha = {
                        type = "range",
                        name = L["Mouseover Min Opacity"],
                        order = 7,
                        min = 0.0,
                        max = 0.9,
                        step = 0.05,
                        isPercent = true,
                        disabled = function() return not self.db.mouseover end,
                        get = function() return self.db.mouseoverAlpha or 0.0 end,
                        set = function(_, val)
                            self.db.mouseoverAlpha = val
                            self:UpdateMicroMenuAlpha()
                        end,
                    },
                },
            },
        },
    }
end
