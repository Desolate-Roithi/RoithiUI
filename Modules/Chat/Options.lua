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
                    timestampFormat = {
                        type = "select",
                        name = L["Timestamps"] or "Timestamps",
                        desc = L["Display message timestamps using native taint-free engine formatting."] or "Display message timestamps using native taint-free engine formatting.",
                        order = 3,
                        values = {
                            ["none"] = L["None"] or "None",
                            ["%H:%M "] = "14:35 (24-hour)",
                            ["[%H:%M] "] = "[14:35] (24-hour bracketed)",
                            ["%H:%M:%S "] = "14:35:00 (24-hour with seconds)",
                            ["[%H:%M:%S] "] = "[14:35:00] (24-hour bracketed with seconds)",
                            ["%I:%M %p "] = "02:35 PM (12-hour)",
                            ["[%I:%M %p] "] = "[02:35 PM] (12-hour bracketed)",
                            ["%I:%M:%S %p "] = "02:35:00 PM (12-hour with seconds)",
                            ["[%I:%M:%S %p] "] = "[02:35:00 PM] (12-hour bracketed with seconds)",
                        },
                        get = function() return self.db.timestampFormat or "%H:%M " end,
                        set = function(_, val)
                            self.db.timestampFormat = val
                            self:ApplyTimestampFormat()
                        end,
                    },
                    buttonDockPosition = {
                        type = "select",
                        name = L["Action Buttons Dock"] or "Action Buttons Dock",
                        desc = L["Position for the Chattynator-style action icons (Channels, Quick Chat, Voice, Social)."] or "Position for the Chattynator-style action icons (Channels, Quick Chat, Voice, Social).",
                        order = 4,
                        values = {
                            ["INSIDE_TOP_RIGHT"] = L["Top-Right (Tab Line)"] or "Top-Right (Tab Line)",
                            ["INSIDE_TOP_LEFT"] = L["Inside Top-Left"] or "Inside Top-Left",
                            ["ABOVE_CHAT"] = L["Above Chat"] or "Above Chat",
                            ["OUTSIDE_LEFT"] = L["Outside Left"] or "Outside Left",
                            ["HIDDEN"] = L["Hidden"] or "Hidden",
                        },
                        get = function() return self.db.buttonDockPosition or "INSIDE_TOP_RIGHT" end,
                        set = function(_, val)
                            self.db.buttonDockPosition = val
                            self:UpdateButtonsDock()
                        end,
                    },
                    shortenChannels = {
                        type = "toggle",
                        name = L["Shorten Channel Names"] or "Shorten Channel Names",
                        desc = L["Shorten standard channels (e.g. [1. General] -> [1], [Guild] -> [G])."] or "Shorten standard channels (e.g. [1. General] -> [1], [Guild] -> [G]).",
                        order = 5,
                        get = function() return self.db.shortenChannels ~= false end,
                        set = function(_, val)
                            self.db.shortenChannels = val
                        end,
                    },
                    linkURLs = {
                        type = "toggle",
                        name = L["Clickable URLs"] or "Clickable URLs",
                        desc = L["Turn web URLs in chat into clickable links that can be copied with Ctrl+C."] or "Turn web URLs in chat into clickable links that can be copied with Ctrl+C.",
                        order = 6,
                        get = function() return self.db.linkURLs ~= false end,
                        set = function(_, val)
                            self.db.linkURLs = val
                        end,
                    },
                    showClassIcons = {
                        type = "toggle",
                        name = L["Show Class Icons"] or "Show Class Icons",
                        desc = L["Displays class icons before player names in chat messages."] or "Displays class icons before player names in chat messages.",
                        order = 7,
                        get = function() return self.db.showClassIcons ~= false end,
                        set = function(_, val)
                            self.db.showClassIcons = val
                        end,
                    },
                    showRaceIcons = {
                        type = "toggle",
                        name = L["Show Race Icons"] or "Show Race Icons",
                        desc = L["Displays race icons before player names in chat messages."] or "Displays race icons before player names in chat messages.",
                        order = 8,
                        get = function() return self.db.showRaceIcons ~= false end,
                        set = function(_, val)
                            self.db.showRaceIcons = val
                        end,
                    },
                    chatIconSize = {
                        type = "range",
                        name = L["Chat Icon Size"] or "Chat Icon Size",
                        desc = L["Size in pixels of race and class icons in chat."] or "Size in pixels of race and class icons in chat.",
                        order = 9,
                        min = 10,
                        max = 24,
                        step = 1,
                        get = function() return self.db.chatIconSize or 14 end,
                        set = function(_, val)
                            self.db.chatIconSize = val
                        end,
                        disabled = function() return not (self.db.showClassIcons or self.db.showRaceIcons) end,
                    },
                },
            },
            position = {
                type = "group",
                name = L["Position & Dimensions"] or "Position & Dimensions",
                order = 1.5,
                inline = true,
                args = {
                    x = {
                        type = "range",
                        name = L["X Position"] or "X Position",
                        desc = L["Horizontal offset from the anchor point."] or "Horizontal offset from the anchor point.",
                        order = 1,
                        min = -2500,
                        max = 2500,
                        step = 1,
                        get = function() return self.db.x or 0 end,
                        set = function(_, val)
                            self.db.x = val
                            if self.ApplyChatPosition then self:ApplyChatPosition() end
                        end,
                    },
                    y = {
                        type = "range",
                        name = L["Y Position"] or "Y Position",
                        desc = L["Vertical offset from the anchor point."] or "Vertical offset from the anchor point.",
                        order = 2,
                        min = -1500,
                        max = 1500,
                        step = 1,
                        get = function() return self.db.y or 30 end,
                        set = function(_, val)
                            self.db.y = val
                            if self.ApplyChatPosition then self:ApplyChatPosition() end
                        end,
                    },
                    width = {
                        type = "range",
                        name = L["Width"] or "Width",
                        desc = L["Width of the main chat frame."] or "Width of the main chat frame.",
                        order = 3,
                        min = 200,
                        max = 1000,
                        step = 5,
                        get = function() return self.db.width or 460 end,
                        set = function(_, val)
                            self.db.width = val
                            if self.ApplyChatPosition then self:ApplyChatPosition() end
                        end,
                    },
                    height = {
                        type = "range",
                        name = L["Height"] or "Height",
                        desc = L["Height of the main chat frame."] or "Height of the main chat frame.",
                        order = 4,
                        min = 100,
                        max = 800,
                        step = 5,
                        get = function() return self.db.height or 200 end,
                        set = function(_, val)
                            self.db.height = val
                            if self.ApplyChatPosition then self:ApplyChatPosition() end
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
                    backgroundPaddingX = {
                        type = "range",
                        name = L["Horizontal Padding"] or "Horizontal Padding",
                        desc = L["Horizontal breathing room for the background panel around the chat frame. Set to 0 for flush edges."] or "Horizontal breathing room for the background panel around the chat frame. Set to 0 for flush edges.",
                        order = 5,
                        min = 0,
                        max = 30,
                        step = 1,
                        get = function() return (self.db.backgroundPaddingX ~= nil) and self.db.backgroundPaddingX or 4 end,
                        set = function(_, val)
                            self.db.backgroundPaddingX = val
                            self:UpdateBackgroundPosition()
                        end,
                        disabled = function() return not self.db.showBackground end,
                    },
                    backgroundPaddingY = {
                        type = "range",
                        name = L["Vertical Padding"] or "Vertical Padding",
                        desc = L["Vertical padding for the background panel. Set to 0 for flush edges."] or "Vertical padding for the background panel. Set to 0 for flush edges.",
                        order = 6,
                        min = 0,
                        max = 20,
                        step = 1,
                        get = function() return (self.db.backgroundPaddingY ~= nil) and self.db.backgroundPaddingY or 4 end,
                        set = function(_, val)
                            self.db.backgroundPaddingY = val
                            self:UpdateBackgroundPosition()
                        end,
                        disabled = function() return not self.db.showBackground end,
                    },
                    includeEditBoxInBackground = {
                        type = "toggle",
                        name = L["Include Edit Box in Background"] or "Include Edit Box in Background",
                        desc = L["Extend the background panel down to encompass the edit box area below the chat frame."] or "Extend the background panel down to encompass the edit box area below the chat frame.",
                        order = 7,
                        get = function() return self.db.includeEditBoxInBackground == true end,
                        set = function(_, val)
                            self.db.includeEditBoxInBackground = val
                            self:UpdateBackgroundPosition()
                        end,
                        disabled = function() return not self.db.showBackground end,
                    },
                    clampToScreen = {
                        type = "toggle",
                        name = L["Clamp to Screen"] or "Clamp to Screen",
                        desc = L["Constrain chat frames inside screen boundaries. Disable to freely move the chat frame directly against or past the monitor edges."] or "Constrain chat frames inside screen boundaries. Disable to freely move the chat frame directly against or past the monitor edges.",
                        order = 8,
                        get = function() return self.db.clampToScreen == true end,
                        set = function(_, val)
                            self.db.clampToScreen = val
                            if self.ApplyScreenClamping then
                                self:ApplyScreenClamping()
                            end
                        end,
                    },
                },
            },
            typography = {
                type = "group",
                name = L["Typography"] or "Typography",
                order = 3,
                inline = true,
                args = {
                    font = {
                        type = "select",
                        dialogControl = "LSM30_Font",
                        name = L["Font"] or "Font",
                        order = 1,
                        values = function()
                            local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                            return (LSM and LSM:HashTable("font")) or (_G.AceGUIWidgetLSMlists and _G.AceGUIWidgetLSMlists.font) or {}
                        end,
                        get = function()
                            local f = self.db and self.db.font
                            if not f or f == "" or f:find("\\") or f:find("%.ttf$") then
                                if self.db then self.db.font = "Expressway" end
                                return "Expressway"
                            end
                            return f
                        end,
                        set = function(_, val)
                            self.db.font = val
                            self:SkinAllChatFrames()
                        end,
                    },
                    fontSize = {
                        type = "range",
                        name = L["Font Size"] or "Font Size",
                        order = 2,
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
                        order = 3,
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
                    showFontShadow = {
                        type = "toggle",
                        name = L["Enable Text Shadow"] or "Enable Text Shadow",
                        desc = L["Enables Blizzard's default offset text shadow. Keep disabled when Outline is active for crisp typography."] or "Enables Blizzard's default offset text shadow. Keep disabled when Outline is active for crisp typography.",
                        order = 4,
                        get = function() return self.db.showFontShadow == true end,
                        set = function(_, val)
                            self.db.showFontShadow = val
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

function ChatMod:GetLEMFrameSettings()
    local LEM = LibStub("LibEditMode-Roithi", true) or LibStub("LibEditMode-1.0", true)
    if not LEM or not LEM.SettingType then return {} end

    return {
        {
            name = L["X Position"] or "X Position",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -2500,
            maxValue = 2500,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return self.db.x or 0 end,
            set = function(_, val)
                self.db.x = val
                if self.ApplyChatPosition then self:ApplyChatPosition() end
            end,
        },
        {
            name = L["Y Position"] or "Y Position",
            kind = LEM.SettingType.Slider,
            default = 30,
            minValue = -1500,
            maxValue = 1500,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return self.db.y or 30 end,
            set = function(_, val)
                self.db.y = val
                if self.ApplyChatPosition then self:ApplyChatPosition() end
            end,
        },
        {
            name = L["Width"] or "Width",
            kind = LEM.SettingType.Slider,
            default = 460,
            minValue = 200,
            maxValue = 1000,
            valueStep = 5,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return self.db.width or 460 end,
            set = function(_, val)
                self.db.width = val
                if self.ApplyChatPosition then self:ApplyChatPosition() end
            end,
        },
        {
            name = L["Height"] or "Height",
            kind = LEM.SettingType.Slider,
            default = 200,
            minValue = 100,
            maxValue = 800,
            valueStep = 5,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return self.db.height or 200 end,
            set = function(_, val)
                self.db.height = val
                if self.ApplyChatPosition then self:ApplyChatPosition() end
            end,
        },
        {
            name = L["Show Background"] or "Show Background",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function() return self.db.showBackground ~= false end,
            set = function(_, val)
                self.db.showBackground = val
                if self.UpdateBackgroundStyle then self:UpdateBackgroundStyle() end
            end,
        },
        {
            name = L["Clamp to Screen"] or "Clamp to Screen",
            kind = LEM.SettingType.Checkbox,
            default = false,
            get = function() return self.db.clampToScreen == true end,
            set = function(_, val)
                self.db.clampToScreen = val
                if self.ApplyScreenClamping then self:ApplyScreenClamping() end
            end,
        },
    }
end
