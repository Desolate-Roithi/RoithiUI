local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local CDM = RoithiUI:GetModule("CooldownManager")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

function CDM:GetOptions()
    return {
        type = "group",
        name = L["Cooldown Manager"] or "Cooldown Manager",
        order = 95,
        args = {
            general = {
                type = "group",
                name = L["General Settings"] or "General Settings",
                order = 1,
                inline = true,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable"] or "Enable",
                        order = 1,
                        get = function() return self.db.enabled ~= false end,
                        set = function(_, val)
                            self.db.enabled = val
                            if val then self:Enable() else self:Disable() end
                        end,
                    },
                    cropIcons = {
                        type = "toggle",
                        name = L["Crop Icons (Square)"] or "Crop Icons (Square)",
                        desc = L["Crops icon textures for a clean, modern square look."] or "Crops icon textures for a modern square look.",
                        order = 2,
                        get = function() return self.db.cropIcons ~= false end,
                        set = function(_, val)
                            self.db.cropIcons = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    borderSize = {
                        type = "range",
                        name = L["Border Size"] or "Border Size",
                        order = 3,
                        min = 1,
                        max = 4,
                        step = 1,
                        get = function() return self.db.borderSize or 1 end,
                        set = function(_, val)
                            self.db.borderSize = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    borderColor = {
                        type = "color",
                        name = L["Border Color"] or "Border Color",
                        order = 4,
                        hasAlpha = true,
                        get = function()
                            local c = self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.borderColor = { r = r, g = g, b = b, a = a }
                            self:StyleAllActiveItems()
                        end,
                    },
                    font = {
                        type = "select",
                        dialogControl = "LSM30_Font",
                        name = L["Font"] or "Font",
                        order = 5,
                        values = AceGUIWidgetLSMlists and AceGUIWidgetLSMlists.font or {},
                        get = function() return self.db.font or "Friz Quadrata TT" end,
                        set = function(_, val)
                            self.db.font = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    centerIncompleteRows = {
                        type = "toggle",
                        name = L["Center Incomplete Rows"] or "Center Incomplete Rows",
                        desc = L["Horizontally center rows in cooldown viewers that are not completely full."] or "Horizontally center rows in cooldown viewers that are not completely full.",
                        order = 6,
                        get = function() return self.db.centerIncompleteRows ~= false end,
                        set = function(_, val)
                            self.db.centerIncompleteRows = val
                            self:RefreshAllViewerLayouts()
                        end,
                    },
                },
            },
            stackSettings = {
                type = "group",
                name = L["Charges & Stack Counter"] or "Charges & Stack Counter",
                order = 2,
                inline = true,
                args = {
                    stackAnchor = {
                        type = "select",
                        name = L["Anchor Point"] or "Anchor Point",
                        order = 1,
                        values = {
                            ["TOPLEFT"] = "TOPLEFT",
                            ["TOP"] = "TOP",
                            ["TOPRIGHT"] = "TOPRIGHT",
                            ["LEFT"] = "LEFT",
                            ["CENTER"] = "CENTER",
                            ["RIGHT"] = "RIGHT",
                            ["BOTTOMLEFT"] = "BOTTOMLEFT",
                            ["BOTTOM"] = "BOTTOM",
                            ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                        },
                        get = function() return self.db.stackAnchor or "BOTTOMRIGHT" end,
                        set = function(_, val)
                            self.db.stackAnchor = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    stackFontSize = {
                        type = "range",
                        name = L["Font Size"] or "Font Size",
                        order = 2,
                        min = 8,
                        max = 24,
                        step = 1,
                        get = function() return self.db.stackFontSize or 11 end,
                        set = function(_, val)
                            self.db.stackFontSize = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    stackFontOutline = {
                        type = "select",
                        name = L["Outline"] or "Outline",
                        order = 3,
                        values = {
                            ["NONE"] = "NONE",
                            ["OUTLINE"] = "OUTLINE",
                            ["THICKOUTLINE"] = "THICKOUTLINE",
                        },
                        get = function() return self.db.stackFontOutline or "OUTLINE" end,
                        set = function(_, val)
                            self.db.stackFontOutline = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    stackOffsetX = {
                        type = "range",
                        name = L["Offset X"] or "Offset X",
                        order = 4,
                        min = -20,
                        max = 20,
                        step = 1,
                        get = function() return self.db.stackOffsetX or -2 end,
                        set = function(_, val)
                            self.db.stackOffsetX = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    stackOffsetY = {
                        type = "range",
                        name = L["Offset Y"] or "Offset Y",
                        order = 5,
                        min = -20,
                        max = 20,
                        step = 1,
                        get = function() return self.db.stackOffsetY or 2 end,
                        set = function(_, val)
                            self.db.stackOffsetY = val
                            self:StyleAllActiveItems()
                        end,
                    },
                },
            },
            viewers = {
                type = "group",
                name = L["Viewers"] or "Viewers",
                order = 3,
                inline = true,
                args = {
                    essentialSize = {
                        type = "range",
                        name = L["Essential Cooldowns Size"] or "Essential Cooldowns Size",
                        order = 1,
                        min = 24,
                        max = 80,
                        step = 2,
                        get = function()
                            return self.db.viewers and self.db.viewers.Essential and self.db.viewers.Essential.iconSize or 50
                        end,
                        set = function(_, val)
                            if not self.db.viewers then self.db.viewers = {} end
                            if not self.db.viewers.Essential then self.db.viewers.Essential = {} end
                            self.db.viewers.Essential.iconSize = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    utilitySize = {
                        type = "range",
                        name = L["Utility Cooldowns Size"] or "Utility Cooldowns Size",
                        order = 2,
                        min = 20,
                        max = 60,
                        step = 2,
                        get = function()
                            return self.db.viewers and self.db.viewers.Utility and self.db.viewers.Utility.iconSize or 32
                        end,
                        set = function(_, val)
                            if not self.db.viewers then self.db.viewers = {} end
                            if not self.db.viewers.Utility then self.db.viewers.Utility = {} end
                            self.db.viewers.Utility.iconSize = val
                            self:StyleAllActiveItems()
                        end,
                    },
                    buffIconSize = {
                        type = "range",
                        name = L["Buff Icons Size"] or "Buff Icons Size",
                        order = 3,
                        min = 20,
                        max = 60,
                        step = 2,
                        get = function()
                            return self.db.viewers and self.db.viewers.BuffIcon and self.db.viewers.BuffIcon.iconSize or 40
                        end,
                        set = function(_, val)
                            if not self.db.viewers then self.db.viewers = {} end
                            if not self.db.viewers.BuffIcon then self.db.viewers.BuffIcon = {} end
                            self.db.viewers.BuffIcon.iconSize = val
                            self:StyleAllActiveItems()
                        end,
                    },
                },
            },
        },
    }
end
