local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local ObjectivesMod = RoithiUI:GetModule("Objectives")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

function ObjectivesMod:GetOptions()
    return {
        type = "group",
        name = L["Objectives"] or "Objectives",
        order = 45,
        args = {
            general = {
                type = "group",
                name = L["General Settings"] or "General Settings",
                order = 1,
                inline = true,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable Objectives Skin"] or "Enable Objectives Skin",
                        desc = L["Enables modern restyling for the Blizzard Objective Tracker."] or "Enables modern restyling for the Blizzard Objective Tracker.",
                        order = 1,
                        get = function() return self.db.enabled ~= false end,
                        set = function(_, val)
                            self.db.enabled = val
                            if val then
                                self:OnEnable()
                            else
                                self:OnDisable()
                            end
                        end,
                    },
                    hideMasterHeader = {
                        type = "toggle",
                        name = L["Hide 'All Objectives' Header"] or "Hide 'All Objectives' Header",
                        desc = L["Hides the top master header to save vertical space."] or "Hides the top master header to save vertical space.",
                        order = 2,
                        get = function() return self.db.hideMasterHeader == true end,
                        set = function(_, val)
                            self.db.hideMasterHeader = val
                            self:ApplyMasterHeaderVisibility()
                        end,
                    },
                    showAccentDivider = {
                        type = "toggle",
                        name = L["Show Accent Divider"] or "Show Accent Divider",
                        desc = L["Displays a 1px colored accent line underneath section headers."] or "Displays a 1px colored accent line underneath section headers.",
                        order = 3,
                        get = function() return self.db.showAccentDivider ~= false end,
                        set = function(_, val)
                            self.db.showAccentDivider = val
                            self:SkinAllExisting()
                        end,
                    },
                    skinProgressBars = {
                        type = "toggle",
                        name = L["Skin Progress Bars"] or "Skin Progress Bars",
                        desc = L["Apply modern flat styling and 1px borders to quest progress bars."] or "Apply modern flat styling and 1px borders to quest progress bars.",
                        order = 4,
                        get = function() return self.db.skinProgressBars ~= false end,
                        set = function(_, val)
                            self.db.skinProgressBars = val
                            self:SkinAllExisting()
                        end,
                    },
                },
            },
            typography = {
                type = "group",
                name = L["Typography"] or "Typography",
                order = 2,
                inline = true,
                args = {
                    headerFontSize = {
                        type = "range",
                        name = L["Header Font Size"] or "Header Font Size",
                        order = 1,
                        min = 9,
                        max = 20,
                        step = 1,
                        get = function() return self.db.headerFontSize or 13 end,
                        set = function(_, val)
                            self.db.headerFontSize = val
                            self:SkinAllExisting()
                        end,
                    },
                    titleFontSize = {
                        type = "range",
                        name = L["Title Font Size"] or "Title Font Size",
                        order = 2,
                        min = 9,
                        max = 20,
                        step = 1,
                        get = function() return self.db.titleFontSize or 12 end,
                        set = function(_, val)
                            self.db.titleFontSize = val
                            self:SkinAllExisting()
                        end,
                    },
                    objectiveFontSize = {
                        type = "range",
                        name = L["Objective Font Size"] or "Objective Font Size",
                        order = 3,
                        min = 8,
                        max = 18,
                        step = 1,
                        get = function() return self.db.objectiveFontSize or 11 end,
                        set = function(_, val)
                            self.db.objectiveFontSize = val
                            self:SkinAllExisting()
                        end,
                    },
                    fontOutline = {
                        type = "select",
                        name = L["Font Outline"] or "Font Outline",
                        order = 4,
                        values = {
                            ["NONE"] = L["None"] or "None",
                            ["OUTLINE"] = L["Outline"] or "Outline",
                            ["THICKOUTLINE"] = L["Thick Outline"] or "Thick Outline",
                        },
                        get = function() return self.db.fontOutline or "OUTLINE" end,
                        set = function(_, val)
                            self.db.fontOutline = val
                            self:SkinAllExisting()
                        end,
                    },
                },
            },
            colors = {
                type = "group",
                name = L["Colors"] or "Colors",
                order = 3,
                inline = true,
                args = {
                    headerColor = {
                        type = "color",
                        name = L["Header Color"] or "Header Color",
                        hasAlpha = true,
                        order = 1,
                        get = function()
                            local c = self.db.headerColor or self.defaultSettings.headerColor
                            return c.r or 0.05, c.g or 0.82, c.b or 0.61, c.a or 1.0
                        end,
                        set = function(_, r, g, b, a)
                            self.db.headerColor = { r = r, g = g, b = b, a = a }
                            self:SkinAllExisting()
                        end,
                    },
                    titleColor = {
                        type = "color",
                        name = L["Title Color"] or "Title Color",
                        hasAlpha = true,
                        order = 2,
                        get = function()
                            local c = self.db.titleColor or self.defaultSettings.titleColor
                            return c.r or 1.0, c.g or 0.85, c.b or 0.35, c.a or 1.0
                        end,
                        set = function(_, r, g, b, a)
                            self.db.titleColor = { r = r, g = g, b = b, a = a }
                            self:SkinAllExisting()
                        end,
                    },
                    objectiveColor = {
                        type = "color",
                        name = L["Objective Color"] or "Objective Color",
                        hasAlpha = true,
                        order = 3,
                        get = function()
                            local c = self.db.objectiveColor or self.defaultSettings.objectiveColor
                            return c.r or 0.8, c.g or 0.8, c.b or 0.8, c.a or 1.0
                        end,
                        set = function(_, r, g, b, a)
                            self.db.objectiveColor = { r = r, g = g, b = b, a = a }
                            self:SkinAllExisting()
                        end,
                    },
                },
            },
        },
    }
end
