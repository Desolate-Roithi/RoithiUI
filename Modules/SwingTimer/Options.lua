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
                    barOrder = {
                        type = "select",
                        name = L["Bar Order"] or "Bar Order",
                        desc = L["Choose whether Main Hand or Off Hand is positioned on top."] or "Choose whether Main Hand or Off Hand is positioned on top.",
                        values = {
                            MAIN_TOP = L["Main Hand Top, Off Hand Bottom"] or "Main Hand Top, Off Hand Bottom",
                            OFF_TOP = L["Off Hand Top, Main Hand Bottom"] or "Off Hand Top, Main Hand Bottom",
                        },
                        order = 2.5,
                        get = function() return self.db.player.barOrder or "MAIN_TOP" end,
                        set = function(_, val)
                            self.db.player.barOrder = val
                            self:UpdateLayout()
                        end,
                    },
                    showLabel = {
                        type = "toggle",
                        name = L["Show Label"] or "Show Label",
                        desc = L["Display weapon labels."] or "Display weapon labels.",
                        order = 3,
                        get = function() return (self.db.player.showLabel ~= nil) and self.db.player.showLabel or (self.db.player.showText ~= false) end,
                        set = function(_, val)
                            self.db.player.showLabel = val
                            self:UpdateLayout()
                        end,
                    },
                    showTimer = {
                        type = "toggle",
                        name = L["Show Timer"] or "Show Timer",
                        desc = L["Display remaining swing duration text."] or "Display remaining swing duration text.",
                        order = 3.1,
                        get = function() return (self.db.player.showTimer ~= nil) and self.db.player.showTimer or (self.db.player.showText ~= false) end,
                        set = function(_, val)
                            self.db.player.showTimer = val
                            self:UpdateLayout()
                        end,
                    },
                    labelAnchor = {
                        type = "select",
                        name = L["Label Anchor"] or "Label Anchor",
                        values = { LEFT = "LEFT", CENTER = "CENTER", RIGHT = "RIGHT" },
                        order = 3.2,
                        get = function() return self.db.player.labelAnchor or "LEFT" end,
                        set = function(_, val)
                            self.db.player.labelAnchor = val
                            self:UpdateLayout()
                        end,
                    },
                    labelX = {
                        type = "range",
                        name = L["Label X Offset"] or "Label X Offset",
                        min = -50,
                        max = 50,
                        step = 1,
                        order = 3.3,
                        get = function() return self.db.player.labelX or 4 end,
                        set = function(_, val)
                            self.db.player.labelX = val
                            self:UpdateLayout()
                        end,
                    },
                    labelY = {
                        type = "range",
                        name = L["Label Y Offset"] or "Label Y Offset",
                        min = -50,
                        max = 50,
                        step = 1,
                        order = 3.4,
                        get = function() return self.db.player.labelY or 0 end,
                        set = function(_, val)
                            self.db.player.labelY = val
                            self:UpdateLayout()
                        end,
                    },
                    timerAnchor = {
                        type = "select",
                        name = L["Timer Anchor"] or "Timer Anchor",
                        values = { LEFT = "LEFT", CENTER = "CENTER", RIGHT = "RIGHT" },
                        order = 3.5,
                        get = function() return self.db.player.timerAnchor or "RIGHT" end,
                        set = function(_, val)
                            self.db.player.timerAnchor = val
                            self:UpdateLayout()
                        end,
                    },
                    timerX = {
                        type = "range",
                        name = L["Timer X Offset"] or "Timer X Offset",
                        min = -50,
                        max = 50,
                        step = 1,
                        order = 3.6,
                        get = function() return self.db.player.timerX or -4 end,
                        set = function(_, val)
                            self.db.player.timerX = val
                            self:UpdateLayout()
                        end,
                    },
                    timerY = {
                        type = "range",
                        name = L["Timer Y Offset"] or "Timer Y Offset",
                        min = -50,
                        max = 50,
                        step = 1,
                        order = 3.7,
                        get = function() return self.db.player.timerY or 0 end,
                        set = function(_, val)
                            self.db.player.timerY = val
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
                    showLabel = {
                        type = "toggle",
                        name = L["Show Label"] or "Show Label",
                        desc = L["Display target label."] or "Display target label.",
                        order = 2,
                        get = function() return (self.db.target.showLabel ~= nil) and self.db.target.showLabel or (self.db.target.showText ~= false) end,
                        set = function(_, val)
                            self.db.target.showLabel = val
                            self:UpdateLayout()
                        end,
                    },
                    showTimer = {
                        type = "toggle",
                        name = L["Show Timer"] or "Show Timer",
                        desc = L["Display remaining swing duration text."] or "Display remaining swing duration text.",
                        order = 2.1,
                        get = function() return (self.db.target.showTimer ~= nil) and self.db.target.showTimer or (self.db.target.showText ~= false) end,
                        set = function(_, val)
                            self.db.target.showTimer = val
                            self:UpdateLayout()
                        end,
                    },
                    labelAnchor = {
                        type = "select",
                        name = L["Label Anchor"] or "Label Anchor",
                        values = { LEFT = "LEFT", CENTER = "CENTER", RIGHT = "RIGHT" },
                        order = 2.2,
                        get = function() return self.db.target.labelAnchor or "LEFT" end,
                        set = function(_, val)
                            self.db.target.labelAnchor = val
                            self:UpdateLayout()
                        end,
                    },
                    labelX = {
                        type = "range",
                        name = L["Label X Offset"] or "Label X Offset",
                        min = -50,
                        max = 50,
                        step = 1,
                        order = 2.3,
                        get = function() return self.db.target.labelX or 4 end,
                        set = function(_, val)
                            self.db.target.labelX = val
                            self:UpdateLayout()
                        end,
                    },
                    labelY = {
                        type = "range",
                        name = L["Label Y Offset"] or "Label Y Offset",
                        min = -50,
                        max = 50,
                        step = 1,
                        order = 2.4,
                        get = function() return self.db.target.labelY or 0 end,
                        set = function(_, val)
                            self.db.target.labelY = val
                            self:UpdateLayout()
                        end,
                    },
                    timerAnchor = {
                        type = "select",
                        name = L["Timer Anchor"] or "Timer Anchor",
                        values = { LEFT = "LEFT", CENTER = "CENTER", RIGHT = "RIGHT" },
                        order = 2.5,
                        get = function() return self.db.target.timerAnchor or "RIGHT" end,
                        set = function(_, val)
                            self.db.target.timerAnchor = val
                            self:UpdateLayout()
                        end,
                    },
                    timerX = {
                        type = "range",
                        name = L["Timer X Offset"] or "Timer X Offset",
                        min = -50,
                        max = 50,
                        step = 1,
                        order = 2.6,
                        get = function() return self.db.target.timerX or -4 end,
                        set = function(_, val)
                            self.db.target.timerX = val
                            self:UpdateLayout()
                        end,
                    },
                    timerY = {
                        type = "range",
                        name = L["Timer Y Offset"] or "Timer Y Offset",
                        min = -50,
                        max = 50,
                        step = 1,
                        order = 2.7,
                        get = function() return self.db.target.timerY or 0 end,
                        set = function(_, val)
                            self.db.target.timerY = val
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

function SwingTimer:GetPlayerLEMFrameSettings()
    local LEM = LibStub and LibStub("LibEditMode-Roithi", true)
    if not LEM then return {} end
    local sliderType = (LEM.SettingType and LEM.SettingType.Slider) or 2
    local checkType = (LEM.SettingType and LEM.SettingType.Checkbox) or 1
    local dropType = (LEM.SettingType and LEM.SettingType.Dropdown) or 3

    local ANCHOR_VALUES = {
        { text = "LEFT", value = "LEFT" },
        { text = "CENTER", value = "CENTER" },
        { text = "RIGHT", value = "RIGHT" },
    }

    local pCfg = self.db.player or self.defaultSettings.player

    return {
        {
            name = L["X Position"] or "X Position",
            kind = sliderType,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return pCfg.x or 0 end,
            set = function(_, val)
                pCfg.x = val
                self:UpdateLayout()
            end,
        },
        {
            name = L["Y Position"] or "Y Position",
            kind = sliderType,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return pCfg.y or -140 end,
            set = function(_, val)
                pCfg.y = val
                self:UpdateLayout()
            end,
        },
        {
            name = L["Width"] or "Width",
            kind = sliderType,
            minValue = 100,
            maxValue = 400,
            valueStep = 5,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return pCfg.width or 200 end,
            set = function(_, val)
                pCfg.width = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Height"] or "Height",
            kind = sliderType,
            minValue = 6,
            maxValue = 30,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return pCfg.height or 12 end,
            set = function(_, val)
                pCfg.height = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Show Off-Hand Bar"] or "Show Off-Hand Bar",
            kind = checkType,
            get = function() return pCfg.showOffhand ~= false end,
            set = function(_, val)
                pCfg.showOffhand = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Off Hand on Top"] or "Off Hand on Top",
            kind = checkType,
            get = function() return pCfg.barOrder == "OFF_TOP" end,
            set = function(_, val)
                pCfg.barOrder = val and "OFF_TOP" or "MAIN_TOP"
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Show Label"] or "Show Label",
            kind = checkType,
            get = function()
                if pCfg.showLabel ~= nil then return pCfg.showLabel == true end
                return pCfg.showText ~= false
            end,
            set = function(_, val)
                pCfg.showLabel = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Show Timer"] or "Show Timer",
            kind = checkType,
            get = function()
                if pCfg.showTimer ~= nil then return pCfg.showTimer == true end
                return pCfg.showText ~= false
            end,
            set = function(_, val)
                pCfg.showTimer = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Label Anchor"] or "Label Anchor",
            kind = dropType,
            values = ANCHOR_VALUES,
            get = function() return pCfg.labelAnchor or "LEFT" end,
            set = function(_, val)
                pCfg.labelAnchor = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Timer Anchor"] or "Timer Anchor",
            kind = dropType,
            values = ANCHOR_VALUES,
            get = function() return pCfg.timerAnchor or "RIGHT" end,
            set = function(_, val)
                pCfg.timerAnchor = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Label X Offset"] or "Label X Offset",
            kind = sliderType,
            minValue = -50,
            maxValue = 50,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return pCfg.labelX or 4 end,
            set = function(_, val)
                pCfg.labelX = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Label Y Offset"] or "Label Y Offset",
            kind = sliderType,
            minValue = -50,
            maxValue = 50,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return pCfg.labelY or 0 end,
            set = function(_, val)
                pCfg.labelY = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Timer X Offset"] or "Timer X Offset",
            kind = sliderType,
            minValue = -50,
            maxValue = 50,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return pCfg.timerX or -4 end,
            set = function(_, val)
                pCfg.timerX = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Timer Y Offset"] or "Timer Y Offset",
            kind = sliderType,
            minValue = -50,
            maxValue = 50,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return pCfg.timerY or 0 end,
            set = function(_, val)
                pCfg.timerY = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
    }
end

function SwingTimer:GetTargetLEMFrameSettings()
    local LEM = LibStub and LibStub("LibEditMode-Roithi", true)
    if not LEM then return {} end
    local sliderType = (LEM.SettingType and LEM.SettingType.Slider) or 2
    local checkType = (LEM.SettingType and LEM.SettingType.Checkbox) or 1
    local dropType = (LEM.SettingType and LEM.SettingType.Dropdown) or 3

    local ANCHOR_VALUES = {
        { text = "LEFT", value = "LEFT" },
        { text = "CENTER", value = "CENTER" },
        { text = "RIGHT", value = "RIGHT" },
    }

    local tCfg = self.db.target or self.defaultSettings.target

    return {
        {
            name = L["X Position"] or "X Position",
            kind = sliderType,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return tCfg.x or 0 end,
            set = function(_, val)
                tCfg.x = val
                self:UpdateLayout()
            end,
        },
        {
            name = L["Y Position"] or "Y Position",
            kind = sliderType,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return tCfg.y or -160 end,
            set = function(_, val)
                tCfg.y = val
                self:UpdateLayout()
            end,
        },
        {
            name = L["Width"] or "Width",
            kind = sliderType,
            minValue = 100,
            maxValue = 400,
            valueStep = 5,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return tCfg.width or 200 end,
            set = function(_, val)
                tCfg.width = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Height"] or "Height",
            kind = sliderType,
            minValue = 6,
            maxValue = 30,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return tCfg.height or 12 end,
            set = function(_, val)
                tCfg.height = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Show Label"] or "Show Label",
            kind = checkType,
            get = function()
                if tCfg.showLabel ~= nil then return tCfg.showLabel == true end
                return tCfg.showText ~= false
            end,
            set = function(_, val)
                tCfg.showLabel = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Show Timer"] or "Show Timer",
            kind = checkType,
            get = function()
                if tCfg.showTimer ~= nil then return tCfg.showTimer == true end
                return tCfg.showText ~= false
            end,
            set = function(_, val)
                tCfg.showTimer = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Label Anchor"] or "Label Anchor",
            kind = dropType,
            values = ANCHOR_VALUES,
            get = function() return tCfg.labelAnchor or "LEFT" end,
            set = function(_, val)
                tCfg.labelAnchor = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Timer Anchor"] or "Timer Anchor",
            kind = dropType,
            values = ANCHOR_VALUES,
            get = function() return tCfg.timerAnchor or "RIGHT" end,
            set = function(_, val)
                tCfg.timerAnchor = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Label X Offset"] or "Label X Offset",
            kind = sliderType,
            minValue = -50,
            maxValue = 50,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return tCfg.labelX or 4 end,
            set = function(_, val)
                tCfg.labelX = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Label Y Offset"] or "Label Y Offset",
            kind = sliderType,
            minValue = -50,
            maxValue = 50,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return tCfg.labelY or 0 end,
            set = function(_, val)
                tCfg.labelY = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Timer X Offset"] or "Timer X Offset",
            kind = sliderType,
            minValue = -50,
            maxValue = 50,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return tCfg.timerX or -4 end,
            set = function(_, val)
                tCfg.timerX = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
        {
            name = L["Timer Y Offset"] or "Timer Y Offset",
            kind = sliderType,
            minValue = -50,
            maxValue = 50,
            valueStep = 1,
            formatter = function(v) return string.format("%.0f", v) end,
            get = function() return tCfg.timerY or 0 end,
            set = function(_, val)
                tCfg.timerY = val
                self:UpdateLayout()
                if self.isInEditMode then self:ShowSampleBars(true) end
            end,
        },
    }
end

