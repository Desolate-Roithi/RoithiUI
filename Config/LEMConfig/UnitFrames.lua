local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local LEM = LibStub("LibEditMode-Roithi", true)

if not LEM then return end

local function GetDB(unit)
    if not RoithiUI.db.profile.UnitFrames[unit] then RoithiUI.db.profile.UnitFrames[unit] = {} end
    return RoithiUI.db.profile.UnitFrames[unit]
end

local function SafeNum(val, default)
    if val == nil then return default or 0 end
    if (issecretvalue and issecretvalue(val)) or (C_Secrets and C_Secrets.IsSecret and C_Secrets.IsSecret(val)) or type(val) == "userdata" then
        local str = tostring(val)
        local num = tonumber(str)
        if num then return num end
        return default or 0
    end
    local num = tonumber(val)
    return num or default or 0
end

-- ============================================================================
-- THE RIGHT-CLICK MENUS
-- This file controls the settings available when right-clicking a frame in Edit Mode.
-- It handles DETAILED configuration (size, position, etc.), NOT global enabling.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Helpers
-- ----------------------------------------------------------------------------
local function UpdateFrameFromSettings(unit)
    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
    if UF and UF.UpdateFrameFromSettings then
        UF:UpdateFrameFromSettings(unit)
    end
end


-- ----------------------------------------------------------------------------
-- 2. Granular Settings Generators
-- ----------------------------------------------------------------------------
local function GetSettingsForPower(unit)
    return {
        {
            name = "Enable",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function() return GetDB(unit).powerEnabled ~= false end,
            set = function(_, value)
                GetDB(unit).powerEnabled = value
                UpdateFrameFromSettings(unit)
                local AL = ns.AttachmentLogic
                if AL then AL:GlobalLayoutRefresh(unit) end
            end,
        },
        {
            name = "Height",
            kind = LEM.SettingType.Slider,
            default = 10,
            minValue = 2,
            maxValue = 50,
            valueStep = 1,
            get = function() return GetDB(unit).powerHeight or 10 end,
            set = function(_, value)
                GetDB(unit).powerHeight = value
                UpdateFrameFromSettings(unit)
            end,
        },
        {
            name = "Detached",
            kind = LEM.SettingType.Checkbox,
            default = false,
            get = function() return GetDB(unit).powerDetached end,
            set = function(_, value)
                -- Initialize separate width on first detach
                if value == true and not GetDB(unit).powerWidth then
                    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                    local frame = UF and UF.units and UF.units[unit]
                    if frame and frame.Power then
                        GetDB(unit).powerWidth = frame.Power:GetWidth()
                    end
                end

                GetDB(unit).powerDetached = value
                UpdateFrameFromSettings(unit)
                -- Refresh settings to show/hide Width
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.Power then LEM:RefreshFrameSettings(frame.Power) end

                local AL = ns.AttachmentLogic
                if AL then AL:GlobalLayoutRefresh(unit) end
            end,
        },
        {
            name = "X Position",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            get = function() return GetDB(unit).powerX or 0 end,
            set = function(_, value)
                GetDB(unit).powerX = value
                UpdateFrameFromSettings(unit)
                -- Force Update to ensure it moves visually immediately
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                ---@diagnostic disable-next-line: undefined-field
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
            end,
            formatter = function(v) return string.format("%.1f", v) end,
            hidden = function() return not GetDB(unit).powerDetached end,
        },
        {
            name = "Y Position",
            kind = LEM.SettingType.Slider,
            default = -50,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            get = function() return GetDB(unit).powerY or -50 end,
            set = function(_, value)
                GetDB(unit).powerY = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                ---@diagnostic disable-next-line: undefined-field
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
            end,
            formatter = function(v) return string.format("%.1f", v) end,
            hidden = function() return not GetDB(unit).powerDetached end,
        },

        {
            name = "Width",
            kind = LEM.SettingType.Slider,
            default = 200,
            minValue = 50,
            maxValue = 400,
            valueStep = 1,
            get = function() return GetDB(unit).powerWidth or 200 end,
            set = function(_, value)
                GetDB(unit).powerWidth = value
                UpdateFrameFromSettings(unit)
            end,
            hidden = function() return not GetDB(unit).powerDetached end,
        },
    }
end

local function GetSettingsForClassPower(unit)
    return {
        {
            name = "Enable",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function() return GetDB(unit).classPowerEnabled ~= false end,
            set = function(_, value)
                GetDB(unit).classPowerEnabled = value
                UpdateFrameFromSettings(unit)
                local AL = ns.AttachmentLogic
                if AL then AL:GlobalLayoutRefresh(unit) end
            end,
        },
        {
            name = "Height",
            kind = LEM.SettingType.Slider,
            default = 10,
            minValue = 2,
            maxValue = 50,
            valueStep = 1,
            get = function() return GetDB(unit).classPowerHeight or 10 end,
            set = function(_, value)
                GetDB(unit).classPowerHeight = value
                UpdateFrameFromSettings(unit)
            end,
        },
        {
            name = "Detached",
            kind = LEM.SettingType.Checkbox,
            default = false,
            get = function() return GetDB(unit).classPowerDetached end,
            set = function(_, value)
                -- Initialize separate width on first detach
                if value == true and not GetDB(unit).classPowerWidth then
                    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                    local frame = UF and UF.units and UF.units[unit]
                    if frame and frame.ClassPower then
                        GetDB(unit).classPowerWidth = frame.ClassPower:GetWidth()
                    end
                end

                GetDB(unit).classPowerDetached = value
                UpdateFrameFromSettings(unit)

                -- Refresh settings to show/hide Width
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.ClassPower then
                    LEM:RefreshFrameSettings(frame.ClassPower)
                end

                local AL = ns.AttachmentLogic
                if AL then AL:GlobalLayoutRefresh(unit) end
            end,
        },
        {
            name = "X Position",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            get = function() return GetDB(unit).classPowerX or 0 end,
            set = function(_, value)
                GetDB(unit).classPowerX = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                ---@diagnostic disable-next-line: undefined-field
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.UpdateClassPowerLayout then frame.UpdateClassPowerLayout() end
            end,
            formatter = function(v) return string.format("%.1f", v) end,
            hidden = function() return not GetDB(unit).classPowerDetached end,
        },
        {
            name = "Y Position",
            kind = LEM.SettingType.Slider,
            default = -50,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            get = function() return GetDB(unit).classPowerY or -50 end,
            set = function(_, value)
                GetDB(unit).classPowerY = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                ---@diagnostic disable-next-line: undefined-field
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.UpdateClassPowerLayout then frame.UpdateClassPowerLayout() end
            end,
            formatter = function(v) return string.format("%.1f", v) end,
            hidden = function() return not GetDB(unit).classPowerDetached end,
        },

        {
            name = "Width",
            kind = LEM.SettingType.Slider,
            default = 200,
            minValue = 50,
            maxValue = 400,
            valueStep = 1,
            get = function() return GetDB(unit).classPowerWidth or 200 end,
            set = function(_, value)
                GetDB(unit).classPowerWidth = value
                UpdateFrameFromSettings(unit)
            end,
            hidden = function() return not GetDB(unit).classPowerDetached end,
        },
    }
end

local function GetSettingsForAdditionalPower(unit)
    return {
        {
            name = "Enable",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function() return GetDB(unit).additionalPowerEnabled ~= false end,
            set = function(_, value)
                GetDB(unit).additionalPowerEnabled = value
                UpdateFrameFromSettings(unit)
                if ns.SetCastbarAttachment then
                    local cbDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar[unit]
                    if cbDB and not cbDB.detached then
                        ns.SetCastbarAttachment(unit, true)
                    end
                end
            end,
        },
        {
            name = "Height",
            kind = LEM.SettingType.Slider,
            default = 10,
            minValue = 2,
            maxValue = 50,
            valueStep = 1,
            get = function() return GetDB(unit).additionalPowerHeight or 10 end,
            set = function(_, value)
                GetDB(unit).additionalPowerHeight = value
                UpdateFrameFromSettings(unit)
            end,
        },
        {
            name = "Detached",
            kind = LEM.SettingType.Checkbox,
            default = false,
            get = function() return GetDB(unit).additionalPowerDetached end,
            set = function(_, value)
                -- Initialize separate width on first detach
                if value == true and not GetDB(unit).additionalPowerWidth then
                    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                    local frame = UF and UF.units and UF.units[unit]
                    if frame and frame.AdditionalPower then
                        GetDB(unit).additionalPowerWidth = frame.AdditionalPower:GetWidth()
                    end
                end

                GetDB(unit).additionalPowerDetached = value
                UpdateFrameFromSettings(unit)
                -- Refresh settings to show/hide Width
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.AdditionalPower then
                    LEM:RefreshFrameSettings(frame.AdditionalPower)
                end

                local AL = ns.AttachmentLogic
                if AL then AL:GlobalLayoutRefresh(unit) end
            end,
        },
        {
            name = "X Position",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            get = function() return GetDB(unit).additionalPowerX or 0 end,
            set = function(_, value)
                GetDB(unit).additionalPowerX = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                ---@diagnostic disable-next-line: undefined-field
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
            end,
            formatter = function(v) return string.format("%.1f", v) end,
            hidden = function() return not GetDB(unit).additionalPowerDetached end,
        },
        {
            name = "Y Position",
            kind = LEM.SettingType.Slider,
            default = -50,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            get = function() return GetDB(unit).additionalPowerY or -50 end,
            set = function(_, value)
                GetDB(unit).additionalPowerY = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                ---@diagnostic disable-next-line: undefined-field
                local frame = UF and UF.units and UF.units[unit]
                if frame and frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
            end,
            formatter = function(v) return string.format("%.1f", v) end,
            hidden = function() return not GetDB(unit).additionalPowerDetached end,
        },

        {
            name = "Width",
            kind = LEM.SettingType.Slider,
            default = 200,
            minValue = 50,
            maxValue = 400,
            valueStep = 1,
            get = function() return GetDB(unit).additionalPowerWidth or 200 end,
            set = function(_, value)
                GetDB(unit).additionalPowerWidth = value
                UpdateFrameFromSettings(unit)
            end,
            hidden = function() return not GetDB(unit).additionalPowerDetached end,
        },
    }
end

local function GetSettingsForAuras(unit, suffix)
    local isBuffs = (suffix == "Buffs")
    local isDebuffs = (suffix == "Debuffs")
    local isCombined = (suffix == "Combined")
    local keyPrefix = isBuffs and "buff" or (isDebuffs and "debuff" or "aura")

    local function isDetached()
        local db = GetDB(unit)
        return db[keyPrefix .. "Detached"] == true
    end

    local function UpdateAuras()
        local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
        local frame = UF and UF.units and UF.units[unit]
        if UF and UF.UpdateAuras and frame then
            UF:UpdateAuras(frame)
        end
        local AL = ns.AttachmentLogic
        if AL then AL:GlobalLayoutRefresh(unit) end
    end

    local function RefreshLEM()
        local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
        if UF and UF.AuraMovers then
            local moverKey = "RoithiAuraContainer_" .. unit .. "_" .. suffix .. "_Mover"
            local mover = UF.AuraMovers[moverKey]
            if mover then
                LEM:RefreshFrameSettings(mover)
            end
        end
    end

    return {
        -- 1. Detach on top
        {
            name = "Detach",
            kind = LEM.SettingType.Checkbox,
            default = false,
            get = function() return isDetached() end,
            set = function(_, value)
                GetDB(unit)[keyPrefix .. "Detached"] = value
                UpdateFrameFromSettings(unit)
                UpdateAuras()
                RefreshLEM()
            end,
        },
        -- 2. Size
        {
            name = "Size",
            kind = LEM.SettingType.Slider,
            default = 28,
            minValue = 12,
            maxValue = 64,
            valueStep = 1,
            get = function() return SafeNum(GetDB(unit)[keyPrefix .. "Size"] or GetDB(unit).auraSize, 28) end,
            set = function(_, value)
                GetDB(unit)[keyPrefix .. "Size"] = value
                UpdateFrameFromSettings(unit)
                UpdateAuras()
            end,
        },
        -- 3. Grow Direction
        {
            name = "Grow Direction",
            kind = LEM.SettingType.Dropdown,
            values = {
                { text = "Right then Down",                 value = "RIGHT_DOWN" },
                { text = "Right then Up",                   value = "RIGHT_UP" },
                { text = "Left then Down",                  value = "LEFT_DOWN" },
                { text = "Left then Up",                    value = "LEFT_UP" },
                { text = "Down then Right",                 value = "DOWN_RIGHT" },
                { text = "Down then Left",                  value = "DOWN_LEFT" },
                { text = "Up then Right",                   value = "UP_RIGHT" },
                { text = "Up then Left",                    value = "UP_LEFT" },
                { text = "Centered Horizontal",             value = "CENTER_HORIZONTAL" },
                -- { text = "Centered Horizontal (Grow Down)", value = "CENTER_HORIZONTAL_DOWN" },
                -- { text = "Centered Horizontal (Grow Up)",   value = "CENTER_HORIZONTAL_UP" },
                { text = "Centered Vertical",               value = "CENTER_VERTICAL" },
                -- { text = "Centered Vertical (Grow Right)",  value = "CENTER_VERTICAL_RIGHT" },
                -- { text = "Centered Vertical (Grow Left)",   value = "CENTER_VERTICAL_LEFT" },
            },
            get = function()
                return GetDB(unit)[keyPrefix .. "GrowDirection"] or GetDB(unit).auraGrowDirection or "RIGHT_DOWN"
            end,
            set = function(_, value)
                GetDB(unit)[keyPrefix .. "GrowDirection"] = value
                UpdateFrameFromSettings(unit)
                UpdateAuras()
            end,
        },
        -- 4.1. If detached
        {
            name = "X Offset (Detached)",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -2500,
            maxValue = 2500,
            valueStep = 1,
            formatter = function(v) return string.format("%.1f", v) end,
            get = function() return SafeNum(GetDB(unit)[keyPrefix .. "ScreenX"], 0) end,
            set = function(_, value)
                GetDB(unit)[keyPrefix .. "ScreenX"] = value
                UpdateFrameFromSettings(unit)
                UpdateAuras()
            end,
            hidden = function() return not isDetached() end,
        },
        {
            name = "Y Offset (Detached)",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -1500,
            maxValue = 1500,
            valueStep = 1,
            formatter = function(v) return string.format("%.1f", v) end,
            get = function() return SafeNum(GetDB(unit)[keyPrefix .. "ScreenY"], 0) end,
            set = function(_, value)
                GetDB(unit)[keyPrefix .. "ScreenY"] = value
                UpdateFrameFromSettings(unit)
                UpdateAuras()
            end,
            hidden = function() return not isDetached() end,
        },
        -- 4.2. If attached
        {
            name = "Anchor Point",
            kind = LEM.SettingType.Dropdown,
            values = {
                { text = "Top Left",     value = "TOPLEFT" },
                { text = "Left",         value = "LEFT" },
                { text = "Bottom Left",  value = "BOTTOMLEFT" },
                { text = "Top",          value = "TOP" },
                { text = "Center",       value = "CENTER" },
                { text = "Bottom",       value = "BOTTOM" },
                { text = "Top Right",    value = "TOPRIGHT" },
                { text = "Right",        value = "RIGHT" },
                { text = "Bottom Right", value = "BOTTOMRIGHT" },
            },
            get = function()
                local defaultAnchor = (unit == "target" and "TOPLEFT" or "BOTTOMLEFT")
                return GetDB(unit)[keyPrefix .. "Anchor"] or GetDB(unit).auraAnchor or defaultAnchor
            end,
            set = function(_, value)
                GetDB(unit)[keyPrefix .. "Anchor"] = value
                UpdateFrameFromSettings(unit)
                UpdateAuras()
            end,
            hidden = function() return isDetached() end,
        },
        {
            name = "X Offset (Attached)",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            formatter = function(v) return string.format("%.1f", v) end,
            get = function() return SafeNum(GetDB(unit)[keyPrefix .. "XOffset"] or GetDB(unit).auraX, 0) end,
            set = function(_, value)
                GetDB(unit)[keyPrefix .. "XOffset"] = value
                if isCombined then GetDB(unit).auraX = value end
                UpdateFrameFromSettings(unit)
                UpdateAuras()
            end,
            hidden = function() return isDetached() end,
        },
        {
            name = "Y Offset (Attached)",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -1000,
            maxValue = 1000,
            valueStep = 1,
            formatter = function(v) return string.format("%.1f", v) end,
            get = function()
                local defaultY = (unit == "target" and (isBuffs and -45 or -10) or 10)
                return SafeNum(GetDB(unit)[keyPrefix .. "YOffset"] or GetDB(unit).auraY, defaultY)
            end,
            set = function(_, value)
                GetDB(unit)[keyPrefix .. "YOffset"] = value
                if isCombined then GetDB(unit).auraY = value end
                UpdateFrameFromSettings(unit)
                UpdateAuras()
            end,
            hidden = function() return isDetached() end,
        },
    }
end
ns.GetSettingsForAuras = GetSettingsForAuras

local function GetSettingsForCustomAura(id)
    local function GetCustomDB()
        return RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.CustomAuraFrames and RoithiUI.db.profile.CustomAuraFrames[id] or {}
    end

    local function UpdateCustomAuras()
        local UF = RoithiUI:GetModule("UnitFrames")
        if UF and UF.UpdateCustomAura then
            UF:UpdateCustomAura(id)
        end
    end

    return {
        -- 1. Request Buffs From Unit
        {
            name = "Unit Target",
            kind = LEM.SettingType.Dropdown,
            values = {
                { text = "Player",           value = "player" },
                { text = "Target",           value = "target" },
                { text = "Focus",            value = "focus" },
                { text = "Pet",              value = "pet" },
                { text = "Target of Target", value = "targettarget" },
                { text = "Focus Target",     value = "focustarget" },
            },
            get = function() return GetCustomDB().unit or "player" end,
            set = function(_, value)
                GetCustomDB().unit = value
                UpdateCustomAuras()
            end,
        },
        -- 2. Size
        {
            name = "Size",
            kind = LEM.SettingType.Slider,
            default = 30,
            minValue = 10,
            maxValue = 100,
            valueStep = 1,
            get = function() return SafeNum(GetCustomDB().auraSize, 30) end,
            set = function(_, value)
                GetCustomDB().auraSize = value
                UpdateCustomAuras()
            end,
        },
        -- 3. Grow Direction
        {
            name = "Grow Direction",
            kind = LEM.SettingType.Dropdown,
            values = {
                { text = "Right then Down",                 value = "RIGHT_DOWN" },
                { text = "Right then Up",                   value = "RIGHT_UP" },
                { text = "Left then Down",                  value = "LEFT_DOWN" },
                { text = "Left then Up",                    value = "LEFT_UP" },
                { text = "Down then Right",                 value = "DOWN_RIGHT" },
                { text = "Down then Left",                  value = "DOWN_LEFT" },
                { text = "Up then Right",                   value = "UP_RIGHT" },
                { text = "Up then Left",                    value = "UP_LEFT" },
                { text = "Centered Horizontal",             value = "CENTER_HORIZONTAL" },
                -- { text = "Centered Horizontal (Grow Down)", value = "CENTER_HORIZONTAL_DOWN" },
                -- { text = "Centered Horizontal (Grow Up)",   value = "CENTER_HORIZONTAL_UP" },
                { text = "Centered Vertical",               value = "CENTER_VERTICAL" },
                -- { text = "Centered Vertical (Grow Right)",  value = "CENTER_VERTICAL_RIGHT" },
                -- { text = "Centered Vertical (Grow Left)",   value = "CENTER_VERTICAL_LEFT" },
            },
            get = function() return GetCustomDB().auraGrowDirection or "RIGHT_DOWN" end,
            set = function(_, value)
                GetCustomDB().auraGrowDirection = value
                UpdateCustomAuras()
            end,
        },
        -- 4. X Position
        {
            name = "X Position",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -2500,
            maxValue = 2500,
            valueStep = 1,
            formatter = function(v) return string.format("%.1f", v) end,
            get = function() return SafeNum(GetCustomDB().screenX or GetCustomDB().auraScreenX, 0) end,
            set = function(_, value)
                GetCustomDB().screenX = value
                GetCustomDB().auraScreenX = value
                UpdateCustomAuras()
            end,
        },
        -- 5. Y Position
        {
            name = "Y Position",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -1500,
            maxValue = 1500,
            valueStep = 1,
            formatter = function(v) return string.format("%.1f", v) end,
            get = function() return SafeNum(GetCustomDB().screenY or GetCustomDB().auraScreenY, 0) end,
            set = function(_, value)
                GetCustomDB().screenY = value
                GetCustomDB().auraScreenY = value
                UpdateCustomAuras()
            end,
        },
    }
end
ns.GetSettingsForCustomAura = GetSettingsForCustomAura



local function GetSettingsForMainFrame(unit, frame)
    local settings = {
        -- Enabled checkbox REMOVED as per user request (Use Dashboard)
        {
            name = "Width",
            kind = LEM.SettingType.Slider,
            default = 200,
            minValue = 50,
            maxValue = 400,
            valueStep = 1,
            get = function() return GetDB(unit).width end,
            set = function(_, value)
                GetDB(unit).width = value
                UpdateFrameFromSettings(unit)
                local AL = ns.AttachmentLogic
                if AL then AL:GlobalLayoutRefresh(unit) end
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
            get = function() return GetDB(unit).height end,
            set = function(_, value)
                GetDB(unit).height = value
                UpdateFrameFromSettings(unit)
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
            get = function() return GetDB(unit).x end,
            set = function(_, value)
                GetDB(unit).x = value
                UpdateFrameFromSettings(unit)
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
            get = function() return GetDB(unit).y end,
            set = function(_, value)
                GetDB(unit).y = value
                UpdateFrameFromSettings(unit)
            end,
            formatter = function(v) return string.format("%.1f", v) end,
        },


        -- Primary Power Settings (Shared Control)
        { kind = LEM.SettingType.Divider },
        {
            name = "Primary Power",
            kind = LEM.SettingType.Expander,
            get = function() return GetDB(unit).powerSectionExpanded end,
            set = function(_, value)
                GetDB(unit).powerSectionExpanded = value
                -- Refresh only the current frame settings to toggle visibility of items
                LEM:RefreshFrameSettings(frame)
            end,
        },
    }

    -- Insert Power Settings (Always, with dynamic visibility)
    local pSettings = GetSettingsForPower(unit)
    for _, s in ipairs(pSettings) do
        local originalHidden = s.hidden
        s.hidden = function()
            if not GetDB(unit).powerSectionExpanded then return true end
            if originalHidden then return originalHidden() end
            return false
        end
        table.insert(settings, s)
    end

    -- Secondary Power Settings (Shared Control)
    if unit == "player" then
        table.insert(settings, { kind = LEM.SettingType.Divider })
        table.insert(settings, {
            name = "Secondary Power",
            kind = LEM.SettingType.Expander,
            get = function() return GetDB(unit).classPowerSectionExpanded end,
            set = function(_, value)
                GetDB(unit).classPowerSectionExpanded = value
                LEM:RefreshFrameSettings(frame)
            end,
        })

        local cSettings = GetSettingsForClassPower(unit)
        for _, s in ipairs(cSettings) do
            local originalHidden = s.hidden
            s.hidden = function()
                if not GetDB(unit).classPowerSectionExpanded then return true end
                if originalHidden then return originalHidden() end
                return false
            end
            table.insert(settings, s)
        end

        -- Additional Power Settings (Shared Control)
        table.insert(settings, { kind = LEM.SettingType.Divider })
        table.insert(settings, {
            name = "Additional Power",
            kind = LEM.SettingType.Expander,
            get = function() return GetDB(unit).additionalPowerSectionExpanded end,
            set = function(_, value)
                GetDB(unit).additionalPowerSectionExpanded = value
                LEM:RefreshFrameSettings(frame)
            end,
        })

        local aSettings = GetSettingsForAdditionalPower(unit)
        for _, s in ipairs(aSettings) do
            local originalHidden = s.hidden
            s.hidden = function()
                if not GetDB(unit).additionalPowerSectionExpanded then return true end
                if originalHidden then return originalHidden() end
                return false
            end
            table.insert(settings, s)
        end
    end

    -- Removed internal SettingType.Button in favor of AddFrameSettingsButtons

    return settings
end



-- ----------------------------------------------------------------------------
-- 3. Position Callback
-- ----------------------------------------------------------------------------
local function OnPositionChanged(frame, layoutName, point, x, y)
    local unit = frame.unit
    x = math.floor(x * 10 + 0.5) / 10
    y = math.floor(y * 10 + 0.5) / 10

    local db = GetDB(unit)
    db.point = point
    db.x = x
    db.y = y

    -- Verify frame is actually valid before modifying
    if frame then
        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, point, x, y)
        LEM:RefreshFrameSettings(frame)
    end
end

-- ----------------------------------------------------------------------------
-- 4. Initialization
-- ----------------------------------------------------------------------------
function ns.InitializeUnitFrameConfig()
    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
    if not UF or not UF.units then return end

    for unit, frame in pairs(UF.units) do
        -- Skip Boss Frames (handled by BossFrames.lua)
        if not string.find(unit, "boss") then
            local db = GetDB(unit)
            if not db.width then db.width = frame:GetWidth() end
            if not db.height then db.height = frame:GetHeight() end

            -- EditMode Registration using LibEditMode
            if LEM then
                -- We Must Assign a Unique Name for Drag/Drop to work correctly
                frame.editModeName = "Roithi " .. unit:gsub("^%l", string.upper)

                -- Ensure Frame is Movable for LibEditMode to handle it
                frame:SetMovable(true)
                frame:SetClampedToScreen(true)

                local defaults = {
                    point = db.point or "CENTER",
                    x = db.x or 0,
                    y = db.y or 0
                }

                -- Ensure DB has defaults
                if not db.point then db.point = defaults.point end
                if not db.x then db.x = defaults.x end
                if not db.y then db.y = defaults.y end

                -- Add Frame FIRST, then Settings
                LEM:AddFrame(frame, OnPositionChanged, defaults)

                -- Add Main Settings
                pcall(function()
                    LEM:AddFrameSettings(frame, GetSettingsForMainFrame(unit, frame))
                    LEM:AddFrameSettingsButtons(frame, {
                        {
                            text = "Open Full Settings",
                            click = function()
                                if LibStub("AceConfigDialog-3.0") then
                                    LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "unitframes", unit)
                                    LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                                end
                            end
                        }
                    })
                end)

                -- Register Specific Settings for Sub-Frames safely
                if frame.Power then
                    pcall(function() LEM:AddFrameSettings(frame.Power, GetSettingsForPower(unit)) end)
                end
                if frame.ClassPower then
                    pcall(function() LEM:AddFrameSettings(frame.ClassPower, GetSettingsForClassPower(unit)) end)
                end
                if frame.AdditionalPower then
                    pcall(function() LEM:AddFrameSettings(frame.AdditionalPower, GetSettingsForAdditionalPower(unit)) end)
                end
                local buffContainer = frame.RoithiAuraContainer_Buffs
                if buffContainer and buffContainer.AuraMover then
                    pcall(function() LEM:AddFrameSettings(buffContainer.AuraMover, GetSettingsForAuras(unit, "Buffs")) end)
                end
                local debuffContainer = frame.RoithiAuraContainer_Debuffs
                if debuffContainer and debuffContainer.AuraMover then
                    pcall(function() LEM:AddFrameSettings(debuffContainer.AuraMover, GetSettingsForAuras(unit, "Debuffs")) end)
                end
                local combinedContainer = frame.RoithiAuraContainer_Combined
                if combinedContainer and combinedContainer.AuraMover then
                    pcall(function() LEM:AddFrameSettings(combinedContainer.AuraMover, GetSettingsForAuras(unit, "Combined")) end)
                end
            end

            UpdateFrameFromSettings(unit)
        end
    end
end

-- ----------------------------------------------------------------------------
-- 5. Edit Mode Visibility
-- ----------------------------------------------------------------------------
if LEM then
    LEM:RegisterCallback('enter', function()
        local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
        if not UF or not UF.units then return end
        for unit, frame in pairs(UF.units) do
            -- Skip boss frames here too if BossFrames.lua handles them (it does)
            if not string.find(unit, "boss") then
                local db = GetDB(unit)
                -- FIX: Always detach secure driver in Edit Mode to ensure we have manual control
                -- BUT ONLY IF NOT IN COMBAT to avoid Taint/Block
                local canTouchSecure = not InCombatLockdown()
                if canTouchSecure then
                    UnregisterUnitWatch(frame)
                end

                frame.isInEditMode = true

                if db and (db.enabled ~= false) then
                    -- If we are in combat and still have a secure watch, we CANNOT call Show/Hide
                    -- But if we are in combat and somehow got here, we best skip Show too.
                    if canTouchSecure then
                        frame:Show()
                        frame:SetAlpha(1)
                    end

                    if frame.EditModeOverlay then frame.EditModeOverlay:Show() end

                    -- Force Update Power Layout to ensure visibility in Edit Mode (Requested Feature)
                    if frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
                    -- Force Update Class/Additional Power too just in case
                    if frame.UpdateClassPowerLayout then frame.UpdateClassPowerLayout() end
                    if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
                    if UF.UpdateAuras then UF:UpdateAuras(frame) end
                else
                    -- Disabled: Force Hide
                    if canTouchSecure then
                        frame:Hide()
                    end
                    if frame.EditModeOverlay then frame.EditModeOverlay:Hide() end
                end
            end
        end
    end)

    LEM:RegisterCallback('exit', function()
        local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
        if not UF or not UF.units then return end
        for unit, frame in pairs(UF.units) do
            if not string.find(unit, "boss") then
                frame.isInEditMode = false
                if frame.EditModeOverlay then frame.EditModeOverlay:Hide() end
                if UF.UpdateAuras then UF:UpdateAuras(frame) end

                -- We don't Hide() unitframes on exit like Castbars; they might need to stay shown if they have a target.
                -- UF:ToggleFrame handles normal visibility.
                UF:ToggleFrame(unit, UF:IsUnitEnabled(unit))
                if not InCombatLockdown() then
                    RegisterUnitWatch(frame) -- Re-register secure driver
                end
            end
        end
    end)
end
