local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local AB = RoithiUI:GetModule("Actionbars")
local LEM = LibStub("LibEditMode-Roithi", true)
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

local BAR_DISPLAY_NAMES = {
    bar1 = "Action Bar 1",
    bar2 = "Action Bar 2",
    bar3 = "Action Bar 3",
    bar4 = "Action Bar 4",
    bar5 = "Action Bar 5",
    pet = "Pet Action Bar",
    stance = "Stance / Shapeshift Bar",
}

function AB:SetupLEM()
    if not LEM then return end

    for barKey, container in pairs(self.bars) do
        local displayName = L[BAR_DISPLAY_NAMES[barKey] or barKey] or barKey
        container.editModeName = displayName

        local defaults = { point = "BOTTOM", x = 0, y = 30 }
        if barKey == "bar2" then defaults.y = 70
        elseif barKey == "bar3" then defaults.y = 110
        elseif barKey == "bar4" then defaults.point = "RIGHT"; defaults.x = -40; defaults.y = 0
        elseif barKey == "bar5" then defaults.point = "RIGHT"; defaults.x = 0; defaults.y = 0
        elseif barKey == "pet" then defaults.y = 150
        elseif barKey == "stance" then defaults.y = 190
        end

        LEM:AddFrame(container, function(f, _, point, x, y)
            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)
            self.db[barKey] = self.db[barKey] or {}
            self.db[barKey].point = point
            self.db[barKey].x = x
            self.db[barKey].y = y
        end, defaults)

        if LEM.AddFrameSettings then
            local settings = {
                {
                    name = L["Button Size"],
                    kind = LEM.SettingType.Slider,
                    minValue = 20,
                    maxValue = 60,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db[barKey] and self.db[barKey].buttonSize or 36 end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].buttonSize = val
                        self:LayoutBar(barKey)
                    end,
                },
                {
                    name = L["Button Spacing"],
                    kind = LEM.SettingType.Slider,
                    minValue = 0,
                    maxValue = 20,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db[barKey] and self.db[barKey].spacing or 4 end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].spacing = val
                        self:LayoutBar(barKey)
                    end,
                },
                {
                    name = L["Buttons Per Row"],
                    kind = LEM.SettingType.Slider,
                    minValue = 1,
                    maxValue = 12,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db[barKey] and self.db[barKey].buttonsPerRow or 12 end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].buttonsPerRow = val
                        self:LayoutBar(barKey)
                    end,
                },
            }
            LEM:AddFrameSettings(container, settings)
        end
    end
end
