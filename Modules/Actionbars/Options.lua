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

    local barList = {
        { key = "bar1", name = L["Action Bar 1"], order = 10 },
        { key = "bar2", name = L["Action Bar 2"], order = 11 },
        { key = "bar3", name = L["Action Bar 3"], order = 12 },
        { key = "bar4", name = L["Action Bar 4"], order = 13 },
        { key = "bar5", name = L["Action Bar 5"], order = 14 },
        { key = "pet", name = L["Pet Action Bar"], order = 15 },
        { key = "stance", name = L["Stance / Shapeshift Bar"], order = 16 },
    }

    for _, b in ipairs(barList) do
        local barKey = b.key
        options.args[barKey] = {
            type = "group",
            name = b.name,
            order = b.order,
            inline = true,
            args = {
                enabled = {
                    type = "toggle",
                    name = L["Enable"],
                    order = 1,
                    get = function() return self.db[barKey] and self.db[barKey].enabled ~= false end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].enabled = val
                        self:LayoutBar(barKey)
                    end,
                },
                hideEmpty = {
                    type = "toggle",
                    name = L["Hide Empty Buttons"],
                    desc = L["Hide empty button slots when not dragging an action."],
                    order = 2,
                    get = function() return self.db[barKey] and self.db[barKey].hideEmpty == true end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].hideEmpty = val
                        self:UpdateEmptyButtons(barKey)
                    end,
                },
                mouseover = {
                    type = "toggle",
                    name = L["Mouseover Fade"],
                    desc = L["Only show the bar when hovering over it with the cursor."],
                    order = 3,
                    get = function() return self.db[barKey] and self.db[barKey].mouseover == true end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].mouseover = val
                        self:UpdateBarMouseover(barKey)
                    end,
                },
                mouseoverAlpha = {
                    type = "range",
                    name = L["Mouseover Min Opacity"],
                    desc = L["Opacity of the bar when the cursor is NOT hovering over it."],
                    order = 4,
                    min = 0,
                    max = 0.9,
                    step = 0.05,
                    isPercent = true,
                    disabled = function() return not (self.db[barKey] and self.db[barKey].mouseover) end,
                    get = function() return self.db[barKey] and self.db[barKey].mouseoverAlpha or 0.0 end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].mouseoverAlpha = val
                        self:UpdateBarMouseover(barKey)
                    end,
                },
                alpha = {
                    type = "range",
                    name = L["Bar Opacity"],
                    order = 5,
                    min = 0.1,
                    max = 1.0,
                    step = 0.05,
                    isPercent = true,
                    get = function() return self.db[barKey] and self.db[barKey].alpha or 1.0 end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].alpha = val
                        self:UpdateBarMouseover(barKey)
                    end,
                },
                buttonSize = {
                    type = "range",
                    name = L["Button Size"],
                    order = 6,
                    min = 20,
                    max = 60,
                    step = 1,
                    get = function() return self.db[barKey] and self.db[barKey].buttonSize or 36 end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].buttonSize = val
                        self:LayoutBar(barKey)
                    end,
                },
                spacing = {
                    type = "range",
                    name = L["Button Spacing"],
                    order = 7,
                    min = 0,
                    max = 20,
                    step = 1,
                    get = function() return self.db[barKey] and self.db[barKey].spacing or 4 end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].spacing = val
                        self:LayoutBar(barKey)
                    end,
                },
                buttonsPerRow = {
                    type = "range",
                    name = L["Buttons Per Row"],
                    order = 8,
                    min = 1,
                    max = 12,
                    step = 1,
                    get = function() return self.db[barKey] and self.db[barKey].buttonsPerRow or 12 end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].buttonsPerRow = val
                        self:LayoutBar(barKey)
                    end,
                },
            },
        }
    end

    return options
end
