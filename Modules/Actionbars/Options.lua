local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local AB = RoithiUI:GetModule("Actionbars")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

function AB:GetOptions()
    self.selectedBar = self.selectedBar or "bar1"

    local barChoices = {
        ["bar1"] = L["Action Bar 1"] or "Action Bar 1",
        ["bar2"] = L["Action Bar 2"] or "Action Bar 2",
        ["bar3"] = L["Action Bar 3"] or "Action Bar 3",
        ["bar4"] = L["Action Bar 4"] or "Action Bar 4",
        ["bar5"] = L["Action Bar 5"] or "Action Bar 5",
        ["bar6"] = L["Action Bar 6"] or "Action Bar 6",
        ["bar7"] = L["Action Bar 7"] or "Action Bar 7",
        ["bar8"] = L["Action Bar 8"] or "Action Bar 8",
        ["pet"] = L["Pet Action Bar"] or "Pet Action Bar",
        ["stance"] = L["Stance / Shapeshift Bar"] or "Stance / Shapeshift Bar",
        ["extraAction"] = L["Extra Action Button"] or "Extra Action Button",
        ["zoneAction"] = L["Zone Ability Button"] or "Zone Ability Button",
    }

    local textPositions = {
        ["TOPLEFT"] = "TOPLEFT",
        ["TOP"] = "TOP",
        ["TOPRIGHT"] = "TOPRIGHT",
        ["LEFT"] = "LEFT",
        ["CENTER"] = "CENTER",
        ["RIGHT"] = "RIGHT",
        ["BOTTOMLEFT"] = "BOTTOMLEFT",
        ["BOTTOM"] = "BOTTOM",
        ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
    }

    local outlineValues = {
        ["NONE"] = L["None"] or "None",
        ["OUTLINE"] = L["Outline"] or "Outline",
        ["THICKOUTLINE"] = L["Thick Outline"] or "Thick Outline",
        ["MONOCHROME"] = L["Monochrome"] or "Monochrome",
    }

    local function GetFontValues()
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        return LSM and LSM:HashTable("font") or (AceGUIWidgetLSMlists and AceGUIWidgetLSMlists.font) or { ["Roithi Thick"] = "Roithi Thick", ["Friz Quadrata TT"] = "Friz Quadrata TT" }
    end

    local options = {
        type = "group",
        name = L["Action Bars"] or "Action Bars",
        order = 90,
        args = {
            general = {
                type = "group",
                name = L["General"] or "General",
                order = 1,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable Action Bars"] or "Enable Action Bars",
                        order = 1,
                        get = function()
                            local mmEnabled = true
                            if RoithiUI.ModuleManager and RoithiUI.ModuleManager.IsModuleEnabled then
                                mmEnabled = RoithiUI.ModuleManager:IsModuleEnabled("Actionbars")
                            end
                            return mmEnabled and self.db.enabled ~= false
                        end,
                        set = function(_, val)
                            self.db.enabled = val
                            if RoithiUI.ModuleManager and RoithiUI.ModuleManager.SetModuleEnabled then
                                RoithiUI.ModuleManager:SetModuleEnabled("Actionbars", val)
                            else
                                if val then
                                    self:Enable()
                                else
                                    self:Disable()
                                end
                            end
                        end,
                    },
                    quickKeybind = {
                        type = "execute",
                        name = L["Quick Keybind Mode"] or "Quick Keybind Mode",
                        desc = L["Toggle quick keybinding mode to hover over action buttons and bind keys."] or "Toggle quick keybinding mode.",
                        order = 2,
                        func = function()
                            AB:ToggleQuickKeybind()
                        end,
                    },
                    gameplayHeader = {
                        type = "header",
                        name = L["Behavior & Gameplay"] or "Behavior & Gameplay",
                        order = 3,
                    },
                    disableBarPaging = {
                        type = "toggle",
                        name = L["Disable Action Bar Paging"] or "Disable Action Bar Paging",
                        desc = L["Prevents accidental action page switching via mouse wheel or keybind paging."] or "Prevents accidental action page switching.",
                        order = 4,
                        get = function() return self.db.disableBarPaging ~= false end,
                        set = function(_, val)
                            self.db.disableBarPaging = val
                            if val then
                                self:DisableActionPageSwitching()
                            end
                        end,
                    },
                    hideEmpty = {
                        type = "toggle",
                        name = L["Hide Empty Buttons"] or "Hide Empty Buttons",
                        desc = L["Hide empty button slots across all action bars when not dragging an action."] or "Hide empty button slots across all action bars.",
                        order = 5,
                        get = function() return self.db.hideEmpty ~= false end,
                        set = function(_, val)
                            self.db.hideEmpty = val
                            for barKey in pairs(self.BAR_CONFIGS or {}) do
                                if self.db[barKey] then
                                    self.db[barKey].hideEmpty = val
                                end
                            end
                            self:UpdateAllEmptyButtons()
                        end,
                    },
                    outOfRangeColoring = {
                        type = "toggle",
                        name = L["Out of Range Coloring"] or "Out of Range Coloring",
                        desc = L["Tints action button icons red when your target is out of spell or ability range."] or "Tints action button icons red when out of range.",
                        order = 6,
                        get = function() return self.db.outOfRangeColoring ~= false end,
                        set = function(_, val)
                            self.db.outOfRangeColoring = val
                            self:UpdateRangeColoringState()
                        end,
                    },
                },
            },
            bars = {
                type = "group",
                name = L["Bar Configuration"] or "Bar Configuration",
                order = 2,
                args = {
                    selectBar = {
                        type = "select",
                        name = L["Select Action Bar"] or "Select Action Bar",
                        order = 1,
                        values = barChoices,
                        get = function() return self.selectedBar or "bar1" end,
                        set = function(_, val) self.selectedBar = val end,
                    },
                    enabled = {
                        type = "toggle",
                        name = L["Enable"],
                        order = 2,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return self.db[bKey] and self.db[bKey].enabled ~= false
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].enabled = val
                            self:LayoutBar(bKey)
                        end,
                    },
                    hideEmpty = {
                        type = "toggle",
                        name = L["Hide Empty Buttons"],
                        desc = L["Hide empty button slots when not dragging an action."],
                        order = 3,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return self:IsHideEmpty(bKey)
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].hideEmpty = val
                            self:UpdateEmptyButtons(bKey)
                        end,
                    },
                    alpha = {
                        type = "range",
                        name = L["Bar Opacity"] or "Bar Opacity",
                        order = 4,
                        min = 0.1,
                        max = 1.0,
                        step = 0.05,
                        isPercent = true,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return self.db[bKey] and self.db[bKey].alpha or 1.0
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].alpha = val
                            self:UpdateBarMouseover(bKey)
                        end,
                    },
                    buttonSize = {
                        type = "range",
                        name = L["Button Size"] or "Button Size",
                        order = 5,
                        min = 20,
                        max = 60,
                        step = 1,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return self.db[bKey] and self.db[bKey].buttonSize or 36
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].buttonSize = val
                            self:LayoutBar(bKey)
                        end,
                    },
                    spacing = {
                        type = "range",
                        name = L["Button Spacing"] or "Button Spacing",
                        order = 6,
                        min = 0,
                        max = 20,
                        step = 1,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return self.db[bKey] and self.db[bKey].spacing or 4
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].spacing = val
                            self:LayoutBar(bKey)
                        end,
                    },
                    orientation = {
                        type = "select",
                        name = L["Orientation"] or "Orientation",
                        order = 7,
                        values = {
                            ["HORIZONTAL"] = L["Horizontal"] or "Horizontal",
                            ["VERTICAL"] = L["Vertical"] or "Vertical",
                        },
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return self.db[bKey] and self.db[bKey].orientation or "HORIZONTAL"
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].orientation = val
                            self:LayoutBar(bKey)
                        end,
                    },
                    numRows = {
                        type = "select",
                        name = L["Number of Rows"] or "Number of Rows",
                        order = 8,
                        values = function()
                            local bKey = self.selectedBar or "bar1"
                            local cfg = self.BAR_CONFIGS and self.BAR_CONFIGS[bKey]
                            local maxBtn = (self.db[bKey] and self.db[bKey].maxButtons) or (cfg and cfg.count) or 12
                            local divisors = self:GetValidDivisors(maxBtn)
                            local vals = {}
                            for _, d in ipairs(divisors) do
                                vals[d] = tostring(d)
                            end
                            return vals
                        end,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            local cfg = self.BAR_CONFIGS and self.BAR_CONFIGS[bKey]
                            local maxBtn = (self.db[bKey] and self.db[bKey].maxButtons) or (cfg and cfg.count) or 12
                            local cur = self.db[bKey] and self.db[bKey].numRows or 1
                            return self:GetNearestDivisor(cur, maxBtn)
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            local cfg = self.BAR_CONFIGS and self.BAR_CONFIGS[bKey]
                            local maxBtn = (self.db[bKey] and self.db[bKey].maxButtons) or (cfg and cfg.count) or 12
                            val = self:GetNearestDivisor(val, maxBtn)
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].numRows = val
                            self.db[bKey].buttonsPerRow = math.floor(maxBtn / val)
                            self:LayoutBar(bKey)
                        end,
                    },
                    maxButtons = {
                        type = "range",
                        name = L["Max Buttons"] or "Max Buttons",
                        order = 9,
                        min = 1,
                        max = 12,
                        step = 1,
                        hidden = function()
                            local bKey = self.selectedBar or "bar1"
                            return bKey == "extraAction" or bKey == "zoneAction"
                        end,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            local cfg = self.BAR_CONFIGS and self.BAR_CONFIGS[bKey]
                            local defaultCount = cfg and cfg.count or 12
                            return self.db[bKey] and self.db[bKey].maxButtons or defaultCount
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            local cfg = self.BAR_CONFIGS and self.BAR_CONFIGS[bKey]
                            local maxCount = cfg and cfg.count or 12
                            local clampedVal = math.min(val, maxCount)
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].maxButtons = clampedVal
                            local curRows = self.db[bKey].numRows or 1
                            local newRows = self:GetNearestDivisor(curRows, clampedVal)
                            self.db[bKey].numRows = newRows
                            self.db[bKey].buttonsPerRow = math.floor(clampedVal / newRows)
                            self:LayoutBar(bKey)
                        end,
                    },
                },
            },
            appearance = {
                type = "group",
                name = L["Appearance"] or "Appearance",
                order = 3,
                args = {
                    iconZoom = {
                        type = "range",
                        name = L["Icon Zoom"] or "Icon Zoom",
                        desc = L["Crop / zoom button icons for a borderless square style."] or "Crop / zoom button icons.",
                        order = 1,
                        min = 0,
                        max = 0.20,
                        step = 0.01,
                        isPercent = true,
                        get = function() return self.db.iconZoom or 0.07 end,
                        set = function(_, val)
                            self.db.iconZoom = val
                            self:StyleAllBars()
                        end,
                    },
                    borderColor = {
                        type = "color",
                        name = L["Border Color"] or "Border Color",
                        order = 2,
                        hasAlpha = true,
                        get = function()
                            local c = self.db.borderColor or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }
                            return c.r, c.g, c.b, c.a
                        end,
                        set = function(_, r, g, b, a)
                            self.db.borderColor = { r = r, g = g, b = b, a = a }
                            self:StyleAllBars()
                        end,
                    },
                },
            },
            typography = {
                type = "group",
                name = L["Typography"] or "Typography",
                order = 4,
                args = {
                    globalHeader = {
                        type = "header",
                        name = L["Global Fallbacks"] or "Global Fallbacks",
                        order = 1,
                    },
                    font = {
                        type = "select",
                        dialogControl = "LSM30_Font",
                        name = L["Font"] or "Font",
                        order = 2,
                        values = GetFontValues,
                        get = function() return self.db.font or "Roithi Thick" end,
                        set = function(_, val)
                            self.db.font = val
                            self:StyleAllBars()
                        end,
                    },
                    fontOutline = {
                        type = "select",
                        name = L["Font Outline"] or "Font Outline",
                        order = 3,
                        values = outlineValues,
                        get = function() return self.db.fontOutline or "OUTLINE" end,
                        set = function(_, val)
                            self.db.fontOutline = val
                            self:StyleAllBars()
                        end,
                    },
                    showFontShadow = {
                        type = "toggle",
                        name = L["Text Shadow"] or "Text Shadow",
                        order = 4,
                        get = function() return self.db.showFontShadow == true end,
                        set = function(_, val)
                            self.db.showFontShadow = val
                            self:StyleAllBars()
                        end,
                    },

                    hotkeyHeader = {
                        type = "header",
                        name = L["Keybind Text (Hotkeys)"] or "Keybind Text (Hotkeys)",
                        order = 10,
                    },
                    showHotkeys = {
                        type = "toggle",
                        name = L["Show Keybind Text"] or "Show Keybind Text",
                        order = 11,
                        get = function() return self.db.showHotkeys ~= false end,
                        set = function(_, val)
                            self.db.showHotkeys = val
                            self:StyleAllBars()
                        end,
                    },
                    hotkeyFontSize = {
                        type = "range",
                        name = L["Hotkey Font Size"] or "Hotkey Font Size",
                        order = 12,
                        min = 8,
                        max = 20,
                        step = 1,
                        get = function() return self.db.hotkeyFontSize or self.db.fontSize or 11 end,
                        set = function(_, val)
                            self.db.hotkeyFontSize = val
                            self:StyleAllBars()
                        end,
                    },
                    hotkeyPosition = {
                        type = "select",
                        name = L["Hotkey Position"] or "Hotkey Position",
                        order = 13,
                        values = textPositions,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return (self.db[bKey] and self.db[bKey].hotkeyPosition) or "TOPRIGHT"
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].hotkeyPosition = val
                            self:StyleAllBars()
                        end,
                    },
                    hotkeyOffsetX = {
                        type = "range",
                        name = L["Hotkey X Offset"] or "Hotkey X Offset",
                        order = 14,
                        min = -20,
                        max = 20,
                        step = 1,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return (self.db[bKey] and self.db[bKey].hotkeyOffsetX) or 0
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].hotkeyOffsetX = val
                            self:StyleAllBars()
                        end,
                    },
                    hotkeyOffsetY = {
                        type = "range",
                        name = L["Hotkey Y Offset"] or "Hotkey Y Offset",
                        order = 15,
                        min = -20,
                        max = 20,
                        step = 1,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return (self.db[bKey] and self.db[bKey].hotkeyOffsetY) or -2
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].hotkeyOffsetY = val
                            self:StyleAllBars()
                        end,
                    },

                    macroHeader = {
                        type = "header",
                        name = L["Macro Text"] or "Macro Text",
                        order = 20,
                    },
                    showMacroText = {
                        type = "toggle",
                        name = L["Show Macro Text"] or "Show Macro Text",
                        order = 21,
                        get = function() return self.db.showMacroText ~= false end,
                        set = function(_, val)
                            self.db.showMacroText = val
                            self:StyleAllBars()
                        end,
                    },
                    macroFontSize = {
                        type = "range",
                        name = L["Macro Font Size"] or "Macro Font Size",
                        order = 22,
                        min = 8,
                        max = 18,
                        step = 1,
                        get = function() return self.db.macroFontSize or 9 end,
                        set = function(_, val)
                            self.db.macroFontSize = val
                            self:StyleAllBars()
                        end,
                    },
                    macroPosition = {
                        type = "select",
                        name = L["Macro Text Position"] or "Macro Text Position",
                        order = 23,
                        values = textPositions,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return (self.db[bKey] and self.db[bKey].macroPosition) or "BOTTOM"
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].macroPosition = val
                            self:StyleAllBars()
                        end,
                    },
                    macroOffsetX = {
                        type = "range",
                        name = L["Macro Text X Offset"] or "Macro Text X Offset",
                        order = 24,
                        min = -20,
                        max = 20,
                        step = 1,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return (self.db[bKey] and self.db[bKey].macroOffsetX) or 0
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].macroOffsetX = val
                            self:StyleAllBars()
                        end,
                    },
                    macroOffsetY = {
                        type = "range",
                        name = L["Macro Text Y Offset"] or "Macro Text Y Offset",
                        order = 25,
                        min = -20,
                        max = 20,
                        step = 1,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return (self.db[bKey] and self.db[bKey].macroOffsetY) or 2
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].macroOffsetY = val
                            self:StyleAllBars()
                        end,
                    },

                    countHeader = {
                        type = "header",
                        name = L["Item / Charge Count"] or "Item / Charge Count",
                        order = 30,
                    },
                    showCount = {
                        type = "toggle",
                        name = L["Show Item / Charge Count"] or "Show Item / Charge Count",
                        order = 31,
                        get = function() return self.db.showCount ~= false end,
                        set = function(_, val)
                            self.db.showCount = val
                            self:StyleAllBars()
                        end,
                    },
                    countFontSize = {
                        type = "range",
                        name = L["Count Font Size"] or "Count Font Size",
                        order = 32,
                        min = 8,
                        max = 20,
                        step = 1,
                        get = function() return self.db.countFontSize or 10 end,
                        set = function(_, val)
                            self.db.countFontSize = val
                            self:StyleAllBars()
                        end,
                    },
                    countPosition = {
                        type = "select",
                        name = L["Count Position"] or "Count Position",
                        order = 33,
                        values = textPositions,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return (self.db[bKey] and self.db[bKey].countPosition) or "BOTTOMRIGHT"
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].countPosition = val
                            self:StyleAllBars()
                        end,
                    },
                    countOffsetX = {
                        type = "range",
                        name = L["Count X Offset"] or "Count X Offset",
                        order = 34,
                        min = -20,
                        max = 20,
                        step = 1,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return (self.db[bKey] and self.db[bKey].countOffsetX) or -2
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].countOffsetX = val
                            self:StyleAllBars()
                        end,
                    },
                    countOffsetY = {
                        type = "range",
                        name = L["Count Y Offset"] or "Count Y Offset",
                        order = 35,
                        min = -20,
                        max = 20,
                        step = 1,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return (self.db[bKey] and self.db[bKey].countOffsetY) or 2
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].countOffsetY = val
                            self:StyleAllBars()
                        end,
                    },
                },
            },
            fader = {
                type = "group",
                name = L["Fader & Mouseover"] or "Fader & Mouseover",
                order = 5,
                args = {
                    enableFader = {
                        type = "toggle",
                        name = L["Enable Out-of-Combat Fader"] or "Enable Out-of-Combat Fader",
                        desc = L["Fade action bars to a lower opacity when idle (out of combat, no target, not casting, and not hovering)."] or "Fade action bars to a lower opacity when idle.",
                        order = 1,
                        get = function() return self.db.enableFader == true end,
                        set = function(_, val)
                            self.db.enableFader = val
                            self:UpdateAllBarFaders()
                        end,
                    },
                    faderIdleAlpha = {
                        type = "range",
                        name = L["Idle Opacity"] or "Idle Opacity",
                        desc = L["The opacity of action bars when idle out of combat."] or "The opacity of action bars when idle out of combat.",
                        order = 2,
                        min = 0,
                        max = 1,
                        step = 0.05,
                        isPercent = true,
                        disabled = function() return not self.db.enableFader end,
                        get = function() return self.db.faderIdleAlpha or 0.3 end,
                        set = function(_, val)
                            self.db.faderIdleAlpha = val
                            self:UpdateAllBarFaders()
                        end,
                    },
                    mouseoverHeader = {
                        type = "header",
                        name = L["Mouseover Fade"] or "Mouseover Fade",
                        order = 3,
                    },
                    mouseoverBar = {
                        type = "select",
                        name = L["Select Action Bar"] or "Select Action Bar",
                        order = 4,
                        values = barChoices,
                        get = function() return self.selectedBar or "bar1" end,
                        set = function(_, val) self.selectedBar = val end,
                    },
                    mouseover = {
                        type = "toggle",
                        name = L["Enable Mouseover Fade"] or "Enable Mouseover Fade",
                        desc = L["Only show the bar when hovering over it with the cursor."] or "Only show the bar when hovering.",
                        order = 5,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return self.db[bKey] and self.db[bKey].mouseover == true
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].mouseover = val
                            self:UpdateBarMouseover(bKey)
                        end,
                    },
                    mouseoverAlpha = {
                        type = "range",
                        name = L["Mouseover Min Opacity"] or "Mouseover Min Opacity",
                        desc = L["Opacity of the bar when the cursor is NOT hovering over it."] or "Opacity when not hovering.",
                        order = 6,
                        min = 0,
                        max = 0.9,
                        step = 0.05,
                        isPercent = true,
                        disabled = function()
                            local bKey = self.selectedBar or "bar1"
                            return not (self.db[bKey] and self.db[bKey].mouseover)
                        end,
                        get = function()
                            local bKey = self.selectedBar or "bar1"
                            return self.db[bKey] and self.db[bKey].mouseoverAlpha or 0.0
                        end,
                        set = function(_, val)
                            local bKey = self.selectedBar or "bar1"
                            self.db[bKey] = self.db[bKey] or {}
                            self.db[bKey].mouseoverAlpha = val
                            self:UpdateBarMouseover(bKey)
                        end,
                    },
                },
            },
        },
    }

    local legacyBars = { "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8", "pet", "stance", "extraAction", "zoneAction" }
    for _, bKey in ipairs(legacyBars) do
        options.args[bKey] = {
            type = "group",
            name = barChoices[bKey] or bKey,
            guiHidden = true,
            args = {
                enabled = {
                    type = "toggle",
                    name = L["Enable"],
                    get = function() return self.db[bKey] and self.db[bKey].enabled ~= false end,
                    set = function(_, val)
                        self.db[bKey] = self.db[bKey] or {}
                        self.db[bKey].enabled = val
                        self:LayoutBar(bKey)
                    end,
                },
            },
        }
    end

    return options
end
