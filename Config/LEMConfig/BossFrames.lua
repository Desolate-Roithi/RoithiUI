local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LEM = LibStub("LibEditMode-Roithi", true)

if not LEM then return end

-- Helper to update frames
local function UpdateFrame(unit)
    local UF = RoithiUI:GetModule("UnitFrames")
    if UF and UF.UpdateFrameFromSettings then
        UF:UpdateFrameFromSettings(unit)
    end
end

function ns.ApplyLEMBossConfiguration(frame, unit)
    -- This function handles Boss Frames specifically
    -- We target "boss1" DB for shared settings (Width/Height/Spacing/etc)

    local function GetDB()
        if not RoithiUI.db.profile.UnitFrames["boss1"] then RoithiUI.db.profile.UnitFrames["boss1"] = {} end
        return RoithiUI.db.profile.UnitFrames["boss1"]
    end

    local function OpenSettings()
        if LibStub("AceConfigDialog-3.0") then
            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "unitframes", "boss1")
            LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
        end
    end

    -- Dynamic Settings Generator
    local function GetBossSettings()
        local settings = {}

        -- ====================================================================
        -- 1. Size & Spacing
        -- ====================================================================
        table.insert(settings, {
            kind = LEM.SettingType.CollapsibleHeader,
            name = "Size & Spacing",
            get = function() return GetDB().sizeSectionExpanded end,
            set = function(_, v)
                GetDB().sizeSectionExpanded = v
                LEM:AddFrameSettings(frame, GetBossSettings())
                LEM:RefreshFrameSettings(frame)
            end,
        })

        if GetDB().sizeSectionExpanded then
            local sizeSettings = {
                {
                    name = "Width",
                    kind = LEM.SettingType.Slider,
                    default = 200,
                    minValue = 50,
                    maxValue = 400,
                    valueStep = 1,
                    get = function() return GetDB().width or 200 end,
                    set = function(_, value)
                        GetDB().width = value
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
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
                    get = function() return GetDB().height or 50 end,
                    set = function(_, value)
                        GetDB().height = value
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
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
                    get = function() return GetDB().x end,
                    set = function(_, value)
                        GetDB().x = value
                        -- Update Anchor (Mainly moves Boss1, others follow)
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
                    get = function() return GetDB().y end,
                    set = function(_, value)
                        GetDB().y = value
                        local UF = RoithiUI:GetModule("UnitFrames")
                        if UF and UF.UpdateBossAnchors then UF:UpdateBossAnchors() end
                    end,
                    formatter = function(v) return string.format("%.1f", v) end,
                },
                {
                    kind = LEM.SettingType.Slider,
                    name = "Spacing",
                    get = function() return GetDB().spacing or 30 end,
                    set = function(_, v)
                        GetDB().spacing = v
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

        -- ====================================================================
        -- 2. Power
        -- ====================================================================
        table.insert(settings, {
            kind = LEM.SettingType.CollapsibleHeader,
            name = "Power",
            get = function() return GetDB().powerSectionExpanded end,
            set = function(_, v)
                GetDB().powerSectionExpanded = v
                LEM:AddFrameSettings(frame, GetBossSettings())
                LEM:RefreshFrameSettings(frame)
            end,
        })

        if GetDB().powerSectionExpanded then
            local powerSettings = {
                {
                    name = "Enable Power",
                    kind = LEM.SettingType.Checkbox,
                    get = function() return GetDB().powerEnabled ~= false end,
                    set = function(_, v)
                        GetDB().powerEnabled = v
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
                    end,
                },
                {
                    name = "Power Height",
                    kind = LEM.SettingType.Slider,
                    get = function() return GetDB().powerHeight or 10 end,
                    set = function(_, v)
                        GetDB().powerHeight = v
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
                    end,
                    minValue = 1,
                    maxValue = 50,
                    valueStep = 1,
                },
                {
                    name = "Detached",
                    kind = LEM.SettingType.Checkbox,
                    get = function() return GetDB().powerDetached end,
                    set = function(_, value)
                        GetDB().powerDetached = value
                        if value == true and not GetDB().powerWidth then
                            GetDB().powerWidth = 180
                        end
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
                        LEM:AddFrameSettings(frame, GetBossSettings())
                        LEM:RefreshFrameSettings(frame)
                    end,
                },
            }
            for _, s in ipairs(powerSettings) do table.insert(settings, s) end

            if GetDB().powerDetached then
                table.insert(settings, {
                    name = "Power Width",
                    kind = LEM.SettingType.Slider,
                    get = function() return GetDB().powerWidth or 180 end,
                    set = function(_, v)
                        GetDB().powerWidth = v
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
                    end,
                    minValue = 50,
                    maxValue = 400,
                    valueStep = 1,
                })
            end
        end

        table.insert(settings, { kind = LEM.SettingType.Divider })

        -- ====================================================================
        -- 3. Auras
        -- ====================================================================
        table.insert(settings, {
            kind = LEM.SettingType.CollapsibleHeader,
            name = "Auras",
            get = function() return GetDB().aurasSectionExpanded end,
            set = function(_, v)
                GetDB().aurasSectionExpanded = v
                LEM:AddFrameSettings(frame, GetBossSettings())
                LEM:RefreshFrameSettings(frame)
            end,
        })

        if GetDB().aurasSectionExpanded then
            local auraSettings = {
                {
                    kind = LEM.SettingType.Checkbox,
                    name = "Enable Auras",
                    get = function() return GetDB().aurasEnabled ~= false end,
                    set = function(_, v)
                        GetDB().aurasEnabled = v
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
                    end,
                },
                {
                    kind = LEM.SettingType.Checkbox,
                    name = "Show Buffs",
                    get = function() return GetDB().showBuffs ~= false end,
                    set = function(_, v)
                        GetDB().showBuffs = v
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
                    end,
                },
                {
                    kind = LEM.SettingType.Checkbox,
                    name = "Show Debuffs",
                    get = function() return GetDB().showDebuffs ~= false end,
                    set = function(_, v)
                        GetDB().showDebuffs = v
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
                    end,
                },
                {
                    kind = LEM.SettingType.Checkbox,
                    name = "Show Only My Auras",
                    get = function() return GetDB().ShowOnlyPlayer end,
                    set = function(_, v)
                        GetDB().ShowOnlyPlayer = v
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
                    end,
                },
                {
                    kind = LEM.SettingType.Slider,
                    name = "Aura Size",
                    get = function() return GetDB().auraSize or 20 end,
                    set = function(_, v)
                        GetDB().auraSize = v
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
                    end,
                    minValue = 10,
                    maxValue = 40,
                    valueStep = 1,
                },
                {
                    kind = LEM.SettingType.Slider,
                    name = "Max Auras",
                    get = function() return GetDB().maxAuras or 4 end,
                    set = function(_, v)
                        GetDB().maxAuras = v
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
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
                    get = function() return GetDB().auraAnchor or "BOTTOM" end,
                    set = function(_, v)
                        GetDB().auraAnchor = v
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
                    end,
                },
                {
                    kind = LEM.SettingType.Dropdown,
                    name = "Grow Direction",
                    values = {
                        { text = "Left to Right", value = "RIGHT" },
                        { text = "Right to Left", value = "LEFT" },
                    },
                    get = function() return GetDB().auraGrowDirection or "RIGHT" end,
                    set = function(_, v)
                        GetDB().auraGrowDirection = v
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
                    end,
                },
                {
                    kind = LEM.SettingType.Slider,
                    name = "Aura X",
                    default = 0,
                    minValue = -100,
                    maxValue = 100,
                    valueStep = 1,
                    get = function() return GetDB().auraX or 0 end,
                    set = function(_, v)
                        GetDB().auraX = v
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
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
                    get = function() return GetDB().auraY or 4 end,
                    set = function(_, v)
                        GetDB().auraY = v
                        for i = 1, 5 do UpdateFrame("boss" .. i) end
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
            click = OpenSettings
        }
    }
    LEM:AddFrameSettingsButtons(frame, buttons)
end
