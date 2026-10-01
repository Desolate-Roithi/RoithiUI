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
    bar6 = "Action Bar 6",
    bar7 = "Action Bar 7",
    bar8 = "Action Bar 8",
    pet = "Pet Action Bar",
    stance = "Stance / Shapeshift Bar",
    extraAction = "Extra Action Button",
    zoneAction = "Zone Ability Button",
}

function AB:SetupLEM()
    if not LEM then return end

    for barKey, container in pairs(self.bars) do
        local displayName = L[BAR_DISPLAY_NAMES[barKey] or barKey] or barKey
        container.editModeName = displayName

        local defaults = { point = "BOTTOM", x = 0, y = 30 }
        if barKey == "bar2" then defaults.y = 70
        elseif barKey == "bar3" then defaults.y = 110
        elseif barKey == "bar4" then defaults.y = 150
        elseif barKey == "bar5" then defaults.y = 190
        elseif barKey == "bar6" then defaults.y = 230
        elseif barKey == "bar7" then defaults.y = 270
        elseif barKey == "bar8" then defaults.y = 310
        elseif barKey == "pet" then defaults.y = 230
        elseif barKey == "stance" then defaults.y = 265
        elseif barKey == "extraAction" then defaults.point = "CENTER"; defaults.x = 0; defaults.y = -100
        elseif barKey == "zoneAction" then defaults.point = "CENTER"; defaults.x = 0; defaults.y = -160
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
                {
                    name = L["Vertical Orientation"] or "Vertical Orientation",
                    kind = LEM.SettingType.Checkbox,
                    get = function() return self.db[barKey] and self.db[barKey].orientation == "VERTICAL" end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].orientation = val and "VERTICAL" or "HORIZONTAL"
                        self:LayoutBar(barKey)
                    end,
                },
            }
            LEM:AddFrameSettings(container, settings)
        end
    end
end

function AB:TeardownLEM()
    if not LEM or not LEM.frameSelections then return end
    for _, container in pairs(self.bars) do
        local sel = LEM.frameSelections[container]
        if sel and sel.Hide then
            sel:Hide()
        end
    end
end
