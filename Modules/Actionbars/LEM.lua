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

        local defBar = ns.Defaults.profile.Actionbars[barKey]
        local defaults = { point = defBar.point, x = defBar.x, y = defBar.y }

        LEM:AddFrame(container, function(f, _, point, x, y)
            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)
            self.db[barKey] = self.db[barKey] or {}
            self.db[barKey].point = point
            self.db[barKey].x = x
            self.db[barKey].y = y
        end, defaults)

        if LEM.AddFrameSettings then
            local maxBarCount = self.BAR_CONFIGS and self.BAR_CONFIGS[barKey] and self.BAR_CONFIGS[barKey].count or 12
            local settings = {
                {
                    name = L["X Position"] or "X Position",
                    kind = LEM.SettingType.Slider,
                    minValue = -2500,
                    maxValue = 2500,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db[barKey] and self.db[barKey].x or defaults.x end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].x = val
                        if not InCombatLockdown() then
                            local pt = self.db[barKey].point or defaults.point
                            local py = self.db[barKey].y or defaults.y
                            container:ClearAllPoints()
                            container:SetPoint(pt, UIParent, pt, val, py)
                        end
                    end,
                },
                {
                    name = L["Y Position"] or "Y Position",
                    kind = LEM.SettingType.Slider,
                    minValue = -1500,
                    maxValue = 1500,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db[barKey] and self.db[barKey].y or defaults.y end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].y = val
                        if not InCombatLockdown() then
                            local pt = self.db[barKey].point or defaults.point
                            local px = self.db[barKey].x or defaults.x
                            container:ClearAllPoints()
                            container:SetPoint(pt, UIParent, pt, px, val)
                        end
                    end,
                },
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
                        self.db[barKey].numRows = nil
                        self:LayoutBar(barKey)
                    end,
                },
                {
                    name = L["Number of Rows"] or "Number of Rows",
                    kind = LEM.SettingType.Slider,
                    minValue = 1,
                    maxValue = 12,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db[barKey] and self.db[barKey].numRows or 1 end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].numRows = val
                        local maxBtn = self.db[barKey].maxButtons or maxBarCount
                        self.db[barKey].buttonsPerRow = math.ceil(maxBtn / val)
                        self:LayoutBar(barKey)
                    end,
                },
            }
            if maxBarCount > 1 then
                table.insert(settings, {
                    name = L["Max Buttons"],
                    kind = LEM.SettingType.Slider,
                    minValue = 1,
                    maxValue = maxBarCount,
                    valueStep = 1,
                    formatter = function(v) return string.format("%.0f", v) end,
                    get = function() return self.db[barKey] and self.db[barKey].maxButtons or maxBarCount end,
                    set = function(_, val)
                        self.db[barKey] = self.db[barKey] or {}
                        self.db[barKey].maxButtons = val
                        self:LayoutBar(barKey)
                    end,
                })
            end
            table.insert(settings, {
                name = L["Vertical Orientation"] or "Vertical Orientation",
                kind = LEM.SettingType.Checkbox,
                get = function() return self.db[barKey] and self.db[barKey].orientation == "VERTICAL" end,
                set = function(_, val)
                    self.db[barKey] = self.db[barKey] or {}
                    self.db[barKey].orientation = val and "VERTICAL" or "HORIZONTAL"
                    self:LayoutBar(barKey)
                end,
            })
            LEM:AddFrameSettings(container, settings)
        end
        if LEM.AddFrameSettingsButtons then
            LEM:AddFrameSettingsButtons(container, {
                {
                    text = L["Open Full Settings"] or "Open Full Settings",
                    click = function()
                        if RoithiUI and RoithiUI.OpenSettings then
                            RoithiUI:OpenSettings("actionbars")
                        elseif LibStub("AceConfigDialog-3.0") then
                            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "actionbars_group", "actionbars")
                            LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                        end
                    end,
                },
            })
        end
    end

    if LEM.RegisterCallback and not self.lemCallbackRegistered then
        LEM:RegisterCallback("enter", function()
            self:SetButtonsMouseInteractivity(false)
        end)
        LEM:RegisterCallback("exit", function()
            self:SetButtonsMouseInteractivity(true)
        end)
        self.lemCallbackRegistered = true
    end
end

function AB:TeardownLEM()
    if self.SetButtonsMouseInteractivity then
        self:SetButtonsMouseInteractivity(true)
    end
    if not LEM or not LEM.frameSelections then return end
    for _, container in pairs(self.bars) do
        local sel = LEM.frameSelections[container]
        if sel and sel.Hide then
            sel:Hide()
        end
    end
end
