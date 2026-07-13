local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local LEM = LibStub("LibEditMode-Roithi", true)

if not LEM then return end

local function UpdateBossFrame(unit)
    local UF = RoithiUI:GetModule("UnitFrames")
    if UF and UF.UpdateFrameFromSettings then
        UF:UpdateFrameFromSettings(unit)
    end
end

function ns.ApplyLEMBossConfiguration(frame, unit)
    local function GetBossDB()
        if not RoithiUI.db.profile.UnitFrames["boss1"] then RoithiUI.db.profile.UnitFrames["boss1"] = {} end
        return RoithiUI.db.profile.UnitFrames["boss1"]
    end

    local function OpenBossSettings()
        if LibStub("AceConfigDialog-3.0") then
            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "unitframes", "boss1")
            LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
        end
    end

    local function GetBossSettings()
        local settings = {}

        table.insert(settings, {
            kind = LEM.SettingType.CollapsibleHeader,
            name = "Size & Spacing",
            get = function() return GetBossDB().sizeSectionExpanded end,
            set = function(_, v)
                GetBossDB().sizeSectionExpanded = v
                LEM:AddFrameSettings(frame, GetBossSettings())
                LEM:RefreshFrameSettings(frame)
            end,
        })

        if GetBossDB().sizeSectionExpanded then
            local sizeSettings = {
                {
                    name = "Width",
                    kind = LEM.SettingType.Slider,
                    default = 200,
                    minValue = 50,
                    maxValue = 400,
                    valueStep = 1,
                    get = function() return GetBossDB().width or 200 end,
                    set = function(_, value)
                        GetBossDB().width = value
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                },
                {
                    name = "Height",
                    kind = LEM.SettingType.Slider,
                    default = 50,
                    minValue = 20,
                    maxValue = 150,
                    valueStep = 1,
                    get = function() return GetBossDB().height or 50 end,
                    set = function(_, value)
                        GetBossDB().height = value
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                },
                {
                    name = "X Position",
                    kind = LEM.SettingType.Slider,
                    default = 0,
                    minValue = -2500,
                    maxValue = 2500,
                    valueStep = 1,
                    get = function() return GetBossDB().x end,
                    set = function(_, value)
                        GetBossDB().x = value
                        local UF = RoithiUI:GetModule("UnitFrames")
                        if UF and UF.UpdateBossAnchors then UF:UpdateBossAnchors() end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                },
                {
                    name = "Y Position",
                    kind = LEM.SettingType.Slider,
                    default = 0,
                    minValue = -1500,
                    maxValue = 1500,
                    valueStep = 1,
                    get = function() return GetBossDB().y end,
                    set = function(_, value)
                        GetBossDB().y = value
                        local UF = RoithiUI:GetModule("UnitFrames")
                        if UF and UF.UpdateBossAnchors then UF:UpdateBossAnchors() end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                },
                {
                    kind = LEM.SettingType.Slider,
                    name = "Spacing",
                    get = function() return GetBossDB().spacing or 30 end,
                    set = function(_, v)
                        GetBossDB().spacing = v
                        local UF = RoithiUI:GetModule("UnitFrames")
                        if UF and UF.UpdateBossAnchors then
                            UF:UpdateBossAnchors()
                        end
                    end,
                    minValue = 0,
                    maxValue = 100,
                    valueStep = 1,
                },
            }
            for _, s in ipairs(sizeSettings) do table.insert(settings, s) end
        end

        table.insert(settings, { kind = LEM.SettingType.Divider })

        table.insert(settings, {
            kind = LEM.SettingType.CollapsibleHeader,
            name = "Power",
            get = function() return GetBossDB().powerSectionExpanded end,
            set = function(_, v)
                GetBossDB().powerSectionExpanded = v
                LEM:AddFrameSettings(frame, GetBossSettings())
                LEM:RefreshFrameSettings(frame)
            end,
        })

        if GetBossDB().powerSectionExpanded then
            local powerSettings = {
                {
                    name = "Enable Power",
                    kind = LEM.SettingType.Checkbox,
                    get = function() return GetBossDB().powerEnabled ~= false end,
                    set = function(_, v)
                        GetBossDB().powerEnabled = v
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                },
                {
                    name = "Power Height",
                    kind = LEM.SettingType.Slider,
                    get = function() return GetBossDB().powerHeight or 10 end,
                    set = function(_, v)
                        GetBossDB().powerHeight = v
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                    minValue = 1,
                    maxValue = 50,
                    valueStep = 1,
                },
                {
                    name = "Detached",
                    kind = LEM.SettingType.Checkbox,
                    get = function() return GetBossDB().powerDetached end,
                    set = function(_, value)
                        GetBossDB().powerDetached = value
                        if value == true and not GetBossDB().powerWidth then
                            GetBossDB().powerWidth = 180
                        end
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                        LEM:AddFrameSettings(frame, GetBossSettings())
                        LEM:RefreshFrameSettings(frame)
                    end,
                },
            }
            for _, s in ipairs(powerSettings) do table.insert(settings, s) end

            if GetBossDB().powerDetached then
                table.insert(settings, {
                    name = "Power Width",
                    kind = LEM.SettingType.Slider,
                    get = function() return GetBossDB().powerWidth or 180 end,
                    set = function(_, v)
                        GetBossDB().powerWidth = v
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                    minValue = 50,
                    maxValue = 400,
                    valueStep = 1,
                })
            end
        end

        table.insert(settings, { kind = LEM.SettingType.Divider })

        table.insert(settings, {
            kind = LEM.SettingType.CollapsibleHeader,
            name = "Auras",
            get = function() return GetBossDB().aurasSectionExpanded end,
            set = function(_, v)
                GetBossDB().aurasSectionExpanded = v
                LEM:AddFrameSettings(frame, GetBossSettings())
                LEM:RefreshFrameSettings(frame)
            end,
        })

        if GetBossDB().aurasSectionExpanded then
            local auraSettings = {
                {
                    kind = LEM.SettingType.Checkbox,
                    name = "Enable Auras",
                    get = function() return GetBossDB().aurasEnabled ~= false end,
                    set = function(_, v)
                        GetBossDB().aurasEnabled = v
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                },
                {
                    kind = LEM.SettingType.Checkbox,
                    name = "Show Buffs",
                    get = function() return GetBossDB().showBuffs ~= false end,
                    set = function(_, v)
                        GetBossDB().showBuffs = v
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                },
                {
                    kind = LEM.SettingType.Checkbox,
                    name = "Show Debuffs",
                    get = function() return GetBossDB().showDebuffs ~= false end,
                    set = function(_, v)
                        GetBossDB().showDebuffs = v
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                },
                {
                    kind = LEM.SettingType.Checkbox,
                    name = "Show Only My Auras",
                    get = function() return GetBossDB().ShowOnlyPlayer end,
                    set = function(_, v)
                        GetBossDB().ShowOnlyPlayer = v
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                },
                {
                    kind = LEM.SettingType.Slider,
                    name = "Aura Size",
                    get = function() return GetBossDB().auraSize or 20 end,
                    set = function(_, v)
                        GetBossDB().auraSize = v
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                    minValue = 10,
                    maxValue = 40,
                    valueStep = 1,
                },
                {
                    kind = LEM.SettingType.Slider,
                    name = "Max Auras",
                    get = function() return GetBossDB().maxAuras or 4 end,
                    set = function(_, v)
                        GetBossDB().maxAuras = v
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                    minValue = 1,
                    maxValue = 20,
                    valueStep = 1,
                },
                {
                    kind = LEM.SettingType.Dropdown,
                    name = "Anchor Point",
                    values = {
                        { text = "Top",    value = "TOP" },
                        { text = "Bottom", value = "BOTTOM" },
                        { text = "Left",   value = "LEFT" },
                        { text = "Right",  value = "RIGHT" },
                    },
                    get = function() return GetBossDB().auraAnchor or "BOTTOM" end,
                    set = function(_, v)
                        GetBossDB().auraAnchor = v
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                },
                {
                    kind = LEM.SettingType.Dropdown,
                    name = "Grow Direction",
                    values = {
                        { text = "Left to Right", value = "RIGHT" },
                        { text = "Right to Left", value = "LEFT" },
                    },
                    get = function() return GetBossDB().auraGrowDirection or "RIGHT" end,
                    set = function(_, v)
                        GetBossDB().auraGrowDirection = v
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                },
                {
                    kind = LEM.SettingType.Slider,
                    name = "Aura X",
                    default = 0,
                    minValue = -100,
                    maxValue = 100,
                    valueStep = 1,
                    get = function() return GetBossDB().auraX or 0 end,
                    set = function(_, v)
                        GetBossDB().auraX = v
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                    formatter = function(v) return string.format("%.0f", v) end,
                },
                {
                    kind = LEM.SettingType.Slider,
                    name = "Aura Y",
                    default = 4,
                    minValue = -100,
                    maxValue = 100,
                    valueStep = 1,
                    get = function() return GetBossDB().auraY or 4 end,
                    set = function(_, v)
                        GetBossDB().auraY = v
                        for i = 1, 5 do UpdateBossFrame("boss" .. i) end
                    end,
                    formatter = function(v) return string.format("%.0f", v) end,
                },
            }
            for _, s in ipairs(auraSettings) do table.insert(settings, s) end
        end

        return settings
    end

    LEM:AddFrameSettings(frame, GetBossSettings())

    local buttons = {
        {
            name = "Open Settings",
            click = OpenBossSettings
        }
    }
    LEM:AddFrameSettingsButtons(frame, buttons)
end
