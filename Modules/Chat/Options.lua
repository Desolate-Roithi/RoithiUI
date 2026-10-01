local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local ChatMod = RoithiUI:GetModule("Chat")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

function ChatMod:GetOptions()
    return {
        type = "group",
        name = L["Chat"] or "Chat",
        order = 40,
        args = {
            general = {
                type = "group",
                name = L["General Settings"] or "General Settings",
                order = 1,
                inline = true,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable Chat Skin"] or "Enable Chat Skin",
                        desc = L["Enables modern restyling for the Blizzard chat frames."] or "Enables modern restyling for the Blizzard chat frames.",
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
                    hideBlizzardChrome = {
                        type = "toggle",
                        name = L["Hide Blizzard Chrome"] or "Hide Blizzard Chrome",
                        desc = L["Hides the chat menu, channel, and social quick join buttons."] or "Hides the chat menu, channel, and social quick join buttons.",
                        order = 2,
                        get = function() return self.db.hideBlizzardChrome ~= false end,
                        set = function(_, val)
                            self.db.hideBlizzardChrome = val
                            self:RefreshSettings()
                        end,
                    },
                },
            },
            background = {
                type = "group",
                name = L["Background Panel"] or "Background Panel",
                order = 2,
                inline = true,
                args = {
                    showBackground = {
                        type = "toggle",
                        name = L["Show Background"] or "Show Background",
                        desc = L["Shows a dark unified background panel behind the chat frame and input."] or "Shows a dark unified background panel behind the chat frame and input.",
                        order = 1,
                        get = function() return self.db.showBackground ~= false end,
                        set = function(_, val)
                            self.db.showBackground = val
                            self:UpdateBackgroundStyle()
                        end,
                    },
                    backgroundColor = {
                        type = "color",
                        name = L["Background Color"] or "Background Color",
                        hasAlpha = true,
                        order = 2,
                        get = function()
                            local c = self.db.backgroundColor or self.defaultSettings.backgroundColor
                            return c.r or 0.03, c.g or 0.045, c.b or 0.05, c.a or 0.65
                        end,
                        set = function(_, r, g, b, a)
                            self.db.backgroundColor = { r = r, g = g, b = b, a = a }
                            self:UpdateBackgroundStyle()
                        end,
                        disabled = function() return not self.db.showBackground end,
                    },
                    showBorder = {
                        type = "toggle",
                        name = L["Show 1px Border"] or "Show 1px Border",
                        order = 3,
                        get = function() return self.db.showBorder ~= false end,
                        set = function(_, val)
                            self.db.showBorder = val
                            self:UpdateBackgroundStyle()
                        end,
                        disabled = function() return not self.db.showBackground end,
                    },
                    borderColor = {
                        type = "color",
                        name = L["Border Color"] or "Border Color",
                        hasAlpha = true,
                        order = 4,
                        get = function()
                            local c = self.db.borderColor or self.defaultSettings.borderColor
                            return c.r or 0.15, c.g or 0.15, c.b or 0.15, c.a or 1.0
                        end,
                        set = function(_, r, g, b, a)
                            self.db.borderColor = { r = r, g = g, b = b, a = a }
                            self:UpdateBackgroundStyle()
                        end,
                        disabled = function() return not self.db.showBackground or not self.db.showBorder end,
                    },
                },
            },
            typography = {
                type = "group",
                name = L["Typography"] or "Typography",
                order = 3,
                inline = true,
                args = {
                    fontSize = {
                        type = "range",
                        name = L["Font Size"] or "Font Size",
                        order = 1,
                        min = 8,
                        max = 24,
                        step = 1,
                        get = function() return self.db.fontSize or 12 end,
                        set = function(_, val)
                            self.db.fontSize = val
                            self:SkinAllChatFrames()
                        end,
                    },
                    fontOutline = {
                        type = "select",
                        name = L["Font Outline"] or "Font Outline",
                        order = 2,
                        values = {
                            ["NONE"] = L["None"] or "None",
                            ["OUTLINE"] = L["Outline"] or "Outline",
                            ["THICKOUTLINE"] = L["Thick Outline"] or "Thick Outline",
                        },
                        get = function() return self.db.fontOutline or "OUTLINE" end,
                        set = function(_, val)
                            self.db.fontOutline = val
                            self:SkinAllChatFrames()
                        end,
                    },
                },
            },
            editBox = {
                type = "group",
                name = L["Edit Box (Input)"] or "Edit Box (Input)",
                order = 4,
                inline = true,
                args = {
                    editBoxPosition = {
                        type = "select",
                        name = L["Position"] or "Position",
                        order = 1,
                        values = {
                            ["BOTTOM"] = L["Bottom"] or "Bottom",
                            ["TOP"] = L["Top"] or "Top",
                        },
                        get = function() return self.db.editBoxPosition or "BOTTOM" end,
                        set = function(_, val)
                            self.db.editBoxPosition = val
                            self:UpdateBackgroundPosition()
                            self:SkinAllChatFrames()
                        end,
                    },
                    editBoxHeight = {
                        type = "range",
                        name = L["Height"] or "Height",
                        order = 2,
                        min = 18,
                        max = 40,
                        step = 1,
                        get = function() return self.db.editBoxHeight or 24 end,
                        set = function(_, val)
                            self.db.editBoxHeight = val
                            self:UpdateBackgroundPosition()
                            self:SkinAllChatFrames()
                        end,
                    },
                    editBoxBgColor = {
                        type = "color",
                        name = L["Input Background Color"] or "Input Background Color",
                        hasAlpha = true,
                        order = 3,
                        get = function()
                            local c = self.db.editBoxBgColor or self.defaultSettings.editBoxBgColor
                            return c.r or 0.05, c.g or 0.065, c.b or 0.08, c.a or 0.9
                        end,
                        set = function(_, r, g, b, a)
                            self.db.editBoxBgColor = { r = r, g = g, b = b, a = a }
                            self:SkinAllChatFrames()
                        end,
                    },
                    editBoxBorderColor = {
                        type = "color",
                        name = L["Input Border Color"] or "Input Border Color",
                        hasAlpha = true,
                        order = 4,
                        get = function()
                            local c = self.db.editBoxBorderColor or self.defaultSettings.editBoxBorderColor
                            return c.r or 0.2, c.g or 0.2, c.b or 0.2, c.a or 1.0
                        end,
                        set = function(_, r, g, b, a)
                            self.db.editBoxBorderColor = { r = r, g = g, b = b, a = a }
                            self:SkinAllChatFrames()
                        end,
                    },
                },
            },
            tabs = {
                type = "group",
                name = L["Tabs"] or "Tabs",
                order = 5,
                inline = true,
                args = {
                    styleTabs = {
                        type = "toggle",
                        name = L["Style Tabs"] or "Style Tabs",
                        desc = L["Apply clean minimalist styling to chat tabs."] or "Apply clean minimalist styling to chat tabs.",
                        order = 1,
                        get = function() return self.db.styleTabs ~= false end,
                        set = function(_, val)
                            self.db.styleTabs = val
                            self:SkinAllChatFrames()
                        end,
                    },
                    tabHeight = {
                        type = "range",
                        name = L["Tab Height"] or "Tab Height",
                        order = 2,
                        min = 16,
                        max = 36,
                        step = 1,
                        get = function() return self.db.tabHeight or 22 end,
                        set = function(_, val)
                            self.db.tabHeight = val
                            self:SkinAllChatFrames()
                        end,
                    },
                    tabFontSize = {
                        type = "range",
                        name = L["Tab Font Size"] or "Tab Font Size",
                        order = 3,
                        min = 8,
                        max = 18,
                        step = 1,
                        get = function() return self.db.tabFontSize or 11 end,
                        set = function(_, val)
                            self.db.tabFontSize = val
                            self:SkinAllChatFrames()
                        end,
                    },
                    tabAlphaInactive = {
                        type = "range",
                        name = L["Inactive Tab Alpha"] or "Inactive Tab Alpha",
                        order = 4,
                        min = 0.1,
                        max = 1.0,
                        step = 0.05,
                        isPercent = true,
                        get = function() return self.db.tabAlphaInactive or 0.5 end,
                        set = function(_, val)
                            self.db.tabAlphaInactive = val
                            self:SkinAllChatFrames()
                        end,
                    },
                },
            },
        },
    }
end
