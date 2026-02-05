local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LEM = LibStub("LibEditMode-Roithi", true)

if not LEM then return end

local function GetDB(unit)
    if not RoithiUI.db.profile.UnitFrames[unit] then RoithiUI.db.profile.UnitFrames[unit] = {} end
    return RoithiUI.db.profile.UnitFrames[unit]
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
                -- Smart Detach Logic
                if value == true and not GetDB(unit).powerDetached then
                    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                    local frame = UF and UF.units and UF.units[unit]
                    if frame and frame.Power then
                        local cX, cY = frame.Power:GetCenter()
                        local uScale = UIParent:GetEffectiveScale()
                        if cX and cY then
                            local screenWidth, screenHeight = UIParent:GetSize()
                            local finalX = (cX / uScale) - (screenWidth / 2)
                            local finalY = (cY / uScale) - (screenHeight / 2)

                            GetDB(unit).powerPoint = "CENTER"
                            GetDB(unit).powerX = finalX
                            GetDB(unit).powerY = finalY

                            -- Initialize separate width on first detach
                            if not GetDB(unit).powerWidth then
                                GetDB(unit).powerWidth = frame:GetWidth()
                            end
                        end
                    end
                elseif value == false then
                    GetDB(unit).powerWidth = nil
                end

                GetDB(unit).powerDetached = value
                UpdateFrameFromSettings(unit)
                -- Refresh settings to show/hide Width
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                local frame = UF and UF.frames and UF.frames[unit]
                if frame and frame.Power then LEM:RefreshFrameSettings(frame.Power) end

                if ns.SetCastbarAttachment then
                    local cbDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar[unit]
                    if cbDB and not cbDB.detached then
                        ns.SetCastbarAttachment(unit, true)
                    end
                end
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
                local UF = RoithiUI:GetModule("UnitFrames")
                local frame = UF and UF.frames and UF.frames[unit]
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
                local UF = RoithiUI:GetModule("UnitFrames")
                local frame = UF and UF.frames and UF.frames[unit]
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
                -- Smart Detach Logic
                if value == true and not GetDB(unit).classPowerDetached then
                    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                    local frame = UF and UF.units and UF.units[unit]
                    if frame and frame.ClassPower then
                        local cX, cY = frame.ClassPower:GetCenter()
                        local uScale = UIParent:GetEffectiveScale()
                        if cX and cY then
                            local screenWidth, screenHeight = UIParent:GetSize()
                            local finalX = (cX / uScale) - (screenWidth / 2)
                            local finalY = (cY / uScale) - (screenHeight / 2)

                            GetDB(unit).classPowerPoint = "CENTER"
                            GetDB(unit).classPowerX = finalX
                            GetDB(unit).classPowerY = finalY

                            -- Initialize separate width on first detach
                            if not GetDB(unit).classPowerWidth then
                                GetDB(unit).classPowerWidth = frame.ClassPower:GetWidth()
                            end
                        end
                    end
                elseif value == false then
                    GetDB(unit).classPowerWidth = nil
                end

                GetDB(unit).classPowerDetached = value
                print("DEBUG_DETACH: DB Set. Calling UpdateFrameFromSettings...")
                UpdateFrameFromSettings(unit)

                print("DEBUG_DETACH: Calling LEM Refresh...")
                -- Refresh settings to show/hide Width
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                local frame = UF and UF.frames and UF.frames[unit]
                if frame and frame.ClassPower then
                    LEM:RefreshFrameSettings(frame.ClassPower)
                    print("DEBUG_DETACH: LEM Refresh Done. Forcing Layout Update...")
                    -- Fix: Re-apply layout AFTER refresh to ensure Attachment overrides LEM positioning
                    if frame.UpdateClassPowerLayout then frame.UpdateClassPowerLayout() end
                    if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
                end

                print("DEBUG_DETACH: Sequence Complete.")

                if ns.SetCastbarAttachment then
                    local cbDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar[unit]
                    if cbDB and not cbDB.detached then
                        ns.SetCastbarAttachment(unit, true)
                    end
                end
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
                local UF = RoithiUI:GetModule("UnitFrames")
                local frame = UF and UF.frames and UF.frames[unit]
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
                local UF = RoithiUI:GetModule("UnitFrames")
                local frame = UF and UF.frames and UF.frames[unit]
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
                -- Smart Detach Logic
                if value == true and not GetDB(unit).additionalPowerDetached then
                    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                    local frame = UF and UF.units and UF.units[unit]
                    if frame and frame.AdditionalPower then
                        local cX, cY = frame.AdditionalPower:GetCenter()
                        local uScale = UIParent:GetEffectiveScale()
                        if cX and cY then
                            local screenWidth, screenHeight = UIParent:GetSize()
                            local finalX = (cX / uScale) - (screenWidth / 2)
                            local finalY = (cY / uScale) - (screenHeight / 2)

                            GetDB(unit).additionalPowerPoint = "CENTER"
                            GetDB(unit).additionalPowerX = finalX
                            GetDB(unit).additionalPowerY = finalY

                            -- Initialize separate width on first detach
                            if not GetDB(unit).additionalPowerWidth then
                                GetDB(unit).additionalPowerWidth = frame.AdditionalPower:GetWidth()
                            end
                        end
                    end
                elseif value == false then
                    GetDB(unit).additionalPowerWidth = nil
                end

                GetDB(unit).additionalPowerDetached = value
                UpdateFrameFromSettings(unit)
                -- Refresh settings to show/hide Width
                local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
                local frame = UF and UF.frames and UF.frames[unit]
                if frame and frame.AdditionalPower then
                    LEM:RefreshFrameSettings(frame.AdditionalPower)
                    -- Fix: Re-apply layout AFTER refresh
                    if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
                end

                if ns.SetCastbarAttachment then
                    local cbDB = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar[unit]
                    if cbDB and not cbDB.detached then
                        ns.SetCastbarAttachment(unit, true)
                    end
                end
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
                local UF = RoithiUI:GetModule("UnitFrames")
                local frame = UF and UF.frames and UF.frames[unit]
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
                local UF = RoithiUI:GetModule("UnitFrames")
                local frame = UF and UF.frames and UF.frames[unit]
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





local function GetSettingsForMainFrame(unit, frame)
    local function OpenSettings()
        -- Ensure AceConfig dialog is ready
        if LibStub("AceConfigDialog-3.0") then
            LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "unitframes", unit)
            LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
        end
    end

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

    -- Internal Settings Button
    table.insert(settings, { kind = LEM.SettingType.Divider })
    table.insert(settings, {
        name = "Open Detailed Settings",
        kind = LEM.SettingType.Button,
        func = OpenSettings
    })

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
                local success, err = pcall(function()
                    LEM:AddFrameSettings(frame, GetSettingsForMainFrame(unit, frame))
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
                if not InCombatLockdown() then
                    UnregisterUnitWatch(frame)
                end
                frame.isInEditMode = true

                if db and (db.enabled ~= false) then
                    frame:Show()
                    frame:SetAlpha(1)

                    if frame.EditModeOverlay then frame.EditModeOverlay:Show() end

                    -- Force Update Power Layout to ensure visibility in Edit Mode (Requested Feature)
                    if frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
                    -- Force Update Class/Additional Power too just in case
                    if frame.UpdateClassPowerLayout then frame.UpdateClassPowerLayout() end
                    if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
                else
                    -- Disabled: Force Hide
                    frame:Hide()
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
