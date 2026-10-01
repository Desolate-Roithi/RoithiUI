local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local AB = RoithiUI:GetModule("Actionbars")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

function AB:GetOptions()
    local options = {
        type = "group",
        name = L["Action Bars"],
        order = 90,
        args = {
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                inline = true,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable Action Bars"],
                        order = 0,
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
                    showHotkeys = {
                        type = "toggle",
                        name = L["Show Keybind Text"],
                        order = 1,
                        get = function() return self.db.showHotkeys ~= false end,
                        set = function(_, val)
                            self.db.showHotkeys = val
                            self:StyleAllBars()
                        end,
                    },
                    showMacroText = {
                        type = "toggle",
                        name = L["Show Macro Text"],
                        order = 2,
                        get = function() return self.db.showMacroText ~= false end,
                        set = function(_, val)
                            self.db.showMacroText = val
                            self:StyleAllBars()
                        end,
                    },
                    showCount = {
                        type = "toggle",
                        name = L["Show Item / Charge Count"],
                        order = 3,
                        get = function() return self.db.showCount ~= false end,
                        set = function(_, val)
                            self.db.showCount = val
                            self:StyleAllBars()
                        end,
                    },
                    iconZoom = {
                        type = "range",
                        name = L["Icon Zoom"],
                        desc = L["Crop / zoom button icons for a borderless square style."],
                        order = 4,
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
                    fontSize = {
                        type = "range",
                        name = L["Font Size"],
                        order = 5,
                        min = 8,
                        max = 20,
                        step = 1,
                        get = function() return self.db.fontSize or 11 end,
                        set = function(_, val)
                            self.db.fontSize = val
                            self:StyleAllBars()
                        end,
                    },
                    borderColor = {
                        type = "color",
                        name = L["Border Color"],
                        order = 6,
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
        },
    }

    self.selectedBar = self.selectedBar or "bar1"

    options.args.general.args.quickKeybind = {
        type = "execute",
        name = L["Quick Keybind Mode"] or "Quick Keybind Mode",
        desc = L["Toggle quick keybinding mode to hover over action buttons and bind keys."] or "Toggle quick keybinding mode.",
        order = 0.5,
        func = function()
            AB:ToggleQuickKeybind()
        end,
    }

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

    options.args.barSettings = {
        type = "group",
        name = L["Action Bar Configuration"] or "Action Bar Configuration",
        order = 2,
        inline = true,
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
                    return self.db[bKey] and self.db[bKey].hideEmpty == true
                end,
                set = function(_, val)
                    local bKey = self.selectedBar or "bar1"
                    self.db[bKey] = self.db[bKey] or {}
                    self.db[bKey].hideEmpty = val
                    self:UpdateEmptyButtons(bKey)
                end,
            },
            mouseover = {
                type = "toggle",
                name = L["Mouseover Fade"],
                desc = L["Only show the bar when hovering over it with the cursor."],
                order = 4,
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
                name = L["Mouseover Min Opacity"],
                desc = L["Opacity of the bar when the cursor is NOT hovering over it."],
                order = 5,
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
            alpha = {
                type = "range",
                name = L["Bar Opacity"],
                order = 6,
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
                name = L["Button Size"],
                order = 7,
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
                name = L["Button Spacing"],
                order = 8,
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
                order = 8.5,
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
            buttonsPerRow = {
                type = "range",
                name = L["Buttons Per Row"],
                order = 9,
                min = 1,
                max = 12,
                step = 1,
                get = function()
                    local bKey = self.selectedBar or "bar1"
                    return self.db[bKey] and self.db[bKey].buttonsPerRow or 12
                end,
                set = function(_, val)
                    local bKey = self.selectedBar or "bar1"
                    self.db[bKey] = self.db[bKey] or {}
                    self.db[bKey].buttonsPerRow = val
                    self:LayoutBar(bKey)
                end,
            },
            maxButtons = {
                type = "range",
                name = L["Max Buttons"],
                order = 9.5,
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
                    self.db[bKey] = self.db[bKey] or {}
                    self.db[bKey].maxButtons = math.min(val, maxCount)
                    self:LayoutBar(bKey)
                end,
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
