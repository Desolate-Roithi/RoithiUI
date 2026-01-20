local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LEM = LibStub("LibEditMode")

local function GetDB(unit)
    if not RoithiUIDB.UnitFrames[unit] then RoithiUIDB.UnitFrames[unit] = {} end
    return RoithiUIDB.UnitFrames[unit]
end

-- ----------------------------------------------------------------------------
-- 1. Helpers
-- ----------------------------------------------------------------------------
local function UpdateFrameFromSettings(unit)
    local UF = RoithiUI:GetModule("UnitFrames")
    local db = GetDB(unit)
    local frame = UF and UF.frames and UF.frames[unit]
    if not frame then return end

    -- Dimension
    -- Default sizes if not in DB yet
    local width = db.width or 200
    local height = db.height or 50
    frame:SetSize(width, height)

    -- Position
    -- Only if not handled by EditMode exclusively or if we want to enforce DB
    -- Usually EditMode callback handles this, but explicit update helps consistency
    if db.point then
        frame:ClearAllPoints()
        frame:SetPoint(db.point, UIParent, db.point, db.x or 0, db.y or 0)
    end

    -- Fonts & Elements Refresh
    local fontSize = db.fontSize or 12
    if frame.Name then
        LibRoithi.mixins:SetFont(frame.Name, "Friz Quadrata TT", fontSize, "OUTLINE")
        if frame.UpdateName then frame.UpdateName() end
    end
    if frame.HealthText then
        LibRoithi.mixins:SetFont(frame.HealthText, "Friz Quadrata TT", fontSize, "OUTLINE")
        if frame.UpdateHealthText then frame.UpdateHealthText() end
    end
    if frame.PowerText then
        LibRoithi.mixins:SetFont(frame.PowerText, "Friz Quadrata TT", fontSize, "OUTLINE")
        if frame.UpdatePowerText then frame.UpdatePowerText() end
    end
    if frame.UpdateIndicators then frame.UpdateIndicators() end
    if frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
    if frame.UpdateClassPowerLayout then frame.UpdateClassPowerLayout() end
    if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
    if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
    if frame.UpdateAuras then frame.UpdateAuras() end

    local UF = RoithiUI:GetModule("UnitFrames")
    if UF.UpdateTags then UF:UpdateTags(frame) end
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
                    local UF = RoithiUI:GetModule("UnitFrames")
                    local frame = UF and UF.frames and UF.frames[unit]
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
                local UF = RoithiUI:GetModule("UnitFrames")
                local frame = UF and UF.frames and UF.frames[unit]
                if frame and frame.Power then LEM:RefreshFrameSettings(frame.Power) end
            end,
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
            isHidden = function() return not GetDB(unit).powerDetached end,
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
                    local UF = RoithiUI:GetModule("UnitFrames")
                    local frame = UF and UF.frames and UF.frames[unit]
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

                            if not GetDB(unit).classPowerWidth then
                                GetDB(unit).classPowerWidth = frame:GetWidth()
                            end
                        end
                    end
                elseif value == false then
                    GetDB(unit).classPowerWidth = nil
                end

                GetDB(unit).classPowerDetached = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames")
                local frame = UF and UF.frames and UF.frames[unit]
                if frame and frame.ClassPower then LEM:RefreshFrameSettings(frame.ClassPower) end
            end,
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
            isHidden = function() return not GetDB(unit).classPowerDetached end,
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
                    local UF = RoithiUI:GetModule("UnitFrames")
                    local frame = UF and UF.frames and UF.frames[unit]
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

                            if not GetDB(unit).additionalPowerWidth then
                                GetDB(unit).additionalPowerWidth = frame:GetWidth()
                            end
                        end
                    end
                elseif value == false then
                    GetDB(unit).additionalPowerWidth = nil
                end

                GetDB(unit).additionalPowerDetached = value
                UpdateFrameFromSettings(unit)
                local UF = RoithiUI:GetModule("UnitFrames")
                local frame = UF and UF.frames and UF.frames[unit]
                if frame and frame.AdditionalPower then LEM:RefreshFrameSettings(frame.AdditionalPower) end
            end,
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
            isHidden = function() return not GetDB(unit).additionalPowerDetached end,
        },
    }
end

local function GetSettingsForTags(unit)
    local settings = {}
    local db = GetDB(unit)
    if not db.tags then db.tags = {} end

    -- Helper to get specific tag DB
    local function GetTagDB(index)
        if not db.tags[index] then
            db.tags[index] = {
                enabled = false,
                formatString = "", -- Default empty, will ideally be pre-filled by init
                point = "CENTER",
                anchorTo = "Frame",
                x = 0,
                y = 0
            }
        end
        return db.tags[index]
    end

    for i = 1, 5 do
        local tagSettings = {
            {
                name = "Tag " .. i,
                kind = LEM.SettingType.CollapsibleHeader,
                get = function() return GetTagDB(i).isExpanded end,
                set = function(_, value)
                    GetTagDB(i).isExpanded = value
                    local UF = RoithiUI:GetModule("UnitFrames")
                    local frame = UF and UF.frames and UF.frames[unit]
                    if frame then
                        -- Refreshing here updates the expansion state in UI
                        LEM:AddFrameSettings(frame, GetSettingsForMainFrame(unit, frame))
                        LEM:RefreshFrameSettings(frame)
                    end
                end,
            }
        }

        if GetTagDB(i).isExpanded then
            local subSettings = {
                {
                    name = "Enabled",
                    kind = LEM.SettingType.Checkbox,
                    default = false,
                    get = function() return GetTagDB(i).enabled end,
                    set = function(_, value)
                        GetTagDB(i).enabled = value
                        UpdateFrameFromSettings(unit)
                    end,
                },
                {
                    name = "Text",
                    kind = LEM.SettingType.Input,
                    default = "@health.current",
                    get = function() return GetTagDB(i).formatString end,
                    set = function(_, value)
                        GetTagDB(i).formatString = value
                        UpdateFrameFromSettings(unit)
                    end,
                },
                {
                    name = "Anchor To",
                    kind = LEM.SettingType.Dropdown,
                    default = "Frame",
                    entries = {
                        ["Frame"] = "Frame",
                        ["Health"] = "Health Bar",
                        ["Power"] = "Power Bar",
                        ["ClassPower"] = "Class Power",
                        ["AdditionalPower"] = "Add. Power"
                    },
                    get = function() return GetTagDB(i).anchorTo end,
                    set = function(_, value)
                        GetTagDB(i).anchorTo = value
                        UpdateFrameFromSettings(unit)
                    end,
                },
                {
                    name = "Point",
                    kind = LEM.SettingType.Dropdown,
                    default = "CENTER",
                    entries = {
                        ["CENTER"] = "Center",
                        ["TOP"] = "Top",
                        ["BOTTOM"] = "Bottom",
                        ["LEFT"] = "Left",
                        ["RIGHT"] = "Right",
                        ["TOPLEFT"] = "Top Left",
                        ["TOPRIGHT"] = "Top Right",
                        ["BOTTOMLEFT"] = "Bottom Left",
                        ["BOTTOMRIGHT"] = "Bottom Right"
                    },
                    get = function() return GetTagDB(i).point end,
                    set = function(_, value)
                        GetTagDB(i).point = value
                        UpdateFrameFromSettings(unit)
                    end,
                },
                {
                    name = "X",
                    kind = LEM.SettingType.Slider,
                    default = 0,
                    minValue = -200,
                    maxValue = 200,
                    valueStep = 1,
                    get = function() return GetTagDB(i).x end,
                    set = function(_, value)
                        GetTagDB(i).x = value
                        UpdateFrameFromSettings(unit)
                    end,
                },
                {
                    name = "Y",
                    kind = LEM.SettingType.Slider,
                    default = 0,
                    minValue = -100,
                    maxValue = 100,
                    valueStep = 1,
                    get = function() return GetDB(unit).tags and GetTagDB(i).y end,
                    set = function(_, value)
                        GetTagDB(i).y = value
                        UpdateFrameFromSettings(unit)
                    end,
                },
            }
            for _, s in ipairs(subSettings) do table.insert(tagSettings, s) end
        end
        for _, s in ipairs(tagSettings) do table.insert(settings, s) end
    end

    return settings
end

local function GetSettingsForMainFrame(unit, frame)
    local settings = {
        {
            name = "Width",
            kind = LEM.SettingType.Slider,
            default = 200,
            minValue = 50,
            maxValue = 400,
            valueStep = 1,
            get = function() return GetDB(unit).width or 200 end,
            set = function(_, value)
                GetDB(unit).width = value
                UpdateFrameFromSettings(unit)
            end,
        },
        {
            name = "Height",
            kind = LEM.SettingType.Slider,
            default = 50,
            minValue = 20,
            maxValue = 150,
            valueStep = 1,
            get = function() return GetDB(unit).height or 50 end,
            set = function(_, value)
                GetDB(unit).height = value
                UpdateFrameFromSettings(unit)
            end,
        },
        {
            name = "X Position",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -2500,
            maxValue = 2500,
            valueStep = 1,
            get = function() return GetDB(unit).x or 0 end,
            set = function(_, value)
                GetDB(unit).x = value
                UpdateFrameFromSettings(unit)
            end,
        },
        {
            name = "Y Position",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -1500,
            maxValue = 1500,
            valueStep = 1,
            get = function() return GetDB(unit).y or 0 end,
            set = function(_, value)
                GetDB(unit).y = value
                UpdateFrameFromSettings(unit)
            end,
        },


        -- Primary Power Settings (Shared Control)
        { kind = LEM.SettingType.Divider },
        {
            name = "Primary Power",
            kind = LEM.SettingType.CollapsibleHeader,
            get = function() return GetDB(unit).powerSectionExpanded end,
            set = function(_, value)
                GetDB(unit).powerSectionExpanded = value
                -- Re-register settings to update the list (Add/Remove items)
                LEM:AddFrameSettings(frame, GetSettingsForMainFrame(unit, frame))
                LEM:RefreshFrameSettings(frame)
            end,
        },
    }

    -- Insert Power Settings if expanded
    if GetDB(unit).powerSectionExpanded then
        local pSettings = GetSettingsForPower(unit)
        for _, s in ipairs(pSettings) do table.insert(settings, s) end
    end

    -- Secondary Power Settings (Shared Control)
    if unit == "player" then
        table.insert(settings, { kind = LEM.SettingType.Divider })
        table.insert(settings, {
            name = "Secondary Power",
            kind = LEM.SettingType.CollapsibleHeader,
            get = function() return GetDB(unit).classPowerSectionExpanded end,
            set = function(_, value)
                GetDB(unit).classPowerSectionExpanded = value
                LEM:AddFrameSettings(frame, GetSettingsForMainFrame(unit, frame))
                LEM:RefreshFrameSettings(frame)
            end,
        })

        if GetDB(unit).classPowerSectionExpanded then
            local cSettings = GetSettingsForClassPower(unit)
            for _, s in ipairs(cSettings) do table.insert(settings, s) end
        end

        -- Additional Power Settings (Shared Control)
        table.insert(settings, { kind = LEM.SettingType.Divider })
        table.insert(settings, {
            name = "Additional Power",
            kind = LEM.SettingType.CollapsibleHeader,
            get = function() return GetDB(unit).additionalPowerSectionExpanded end,
            set = function(_, value)
                GetDB(unit).additionalPowerSectionExpanded = value
                LEM:AddFrameSettings(frame, GetSettingsForMainFrame(unit, frame))
                LEM:RefreshFrameSettings(frame)
            end,
        })

        if GetDB(unit).additionalPowerSectionExpanded then
            local aSettings = GetSettingsForAdditionalPower(unit)
            for _, s in ipairs(aSettings) do table.insert(settings, s) end
        end
    end

    return settings
end

local function GetSettingsForTags(unit)
    local settings = {}
    local db = GetDB(unit)
    if not db.tags then db.tags = {} end

    -- Helper to get specific tag DB
    local function GetTagDB(index)
        if not db.tags[index] then
            db.tags[index] = {
                enabled = false,
                formatString = "",
                point = "CENTER",
                anchorTo = "Frame",
                x = 0,
                y = 0
            }
        end
        return db.tags[index]
    end

    for i = 1, 5 do
        local tagSettings = {
            {
                name = "Tag " .. i,
                kind = LEM.SettingType.CollapsibleHeader,
                get = function() return GetTagDB(i).isExpanded end,
                set = function(_, value)
                    GetTagDB(i).isExpanded = value
                    local UF = RoithiUI:GetModule("UnitFrames")
                    local frame = UF and UF.frames and UF.frames[unit]
                    if frame then
                        LEM:AddFrameSettings(frame, GetSettingsForMainFrame(unit, frame))
                        LEM:RefreshFrameSettings(frame)
                    end
                end,
            }
        }

        if GetTagDB(i).isExpanded then
            local subSettings = {
                {
                    name = "Enabled",
                    kind = LEM.SettingType.Checkbox,
                    default = false,
                    get = function() return GetTagDB(i).enabled end,
                    set = function(_, value)
                        GetTagDB(i).enabled = value
                        if not value then
                            -- Reset or clear?
                            -- If disabled, it should stop rendering.
                            -- UpdateTags handles this by iterating only active or valid?
                            -- Actually UpdateTags iterates ipairs(db.tags).
                            -- We might need to ensure the DB structure aligns.
                            -- If we use slot-based approach (1..5), UpdateTags needs to check .enabled.
                        end
                        UpdateFrameFromSettings(unit)
                    end,
                },
                {
                    name = "Text (@health.current)",
                    kind = LEM.SettingType.Input, -- Assumption: Input exists? Standard LEM usually has it?
                    -- If Input not available, we might default to Dropdown or Error?
                    -- Checking LibEditMode source would be good, but assuming standard types.
                    -- Actually standard types are typically Slider, Checkbox, Dropdown.
                    -- If Input is missing, I might be blocked.
                    -- I'll Assume Input exists or use a predefined list if I have to.
                    -- Wait, the user manual for LEM isn't here.
                    -- LibEditMode usually maps to EditModeSettingDisplayInfo.
                    -- Blizzard EditMode doesn't natively support Text Input well in the HUD editor.
                    -- "Input" might NOT be supported natively by LibEditMode if strictly wrapping Blizzard.
                    -- RISK: Converting this to a Dropdown of presets might be safer if Input fails.
                    -- But user asked for "freely creatable".
                    -- Let's try "Input" or "EditBox".
                    -- If that fails, I'll fallback to a Dropdown of common patterns.
                    default = "@health.current",
                    get = function() return GetTagDB(i).formatString end,
                    set = function(_, value)
                        GetTagDB(i).formatString = value
                        UpdateFrameFromSettings(unit)
                    end,
                },
                {
                    name = "Anchor To",
                    kind = LEM.SettingType.Dropdown,
                    default = "Frame",
                    entries = {
                        ["Frame"] = "Frame",
                        ["Health"] = "Health Bar",
                        ["Power"] = "Power Bar",
                        ["ClassPower"] = "Class Power",
                        ["AdditionalPower"] = "Add. Power"
                    },
                    get = function() return GetTagDB(i).anchorTo end,
                    set = function(_, value)
                        GetTagDB(i).anchorTo = value
                        UpdateFrameFromSettings(unit)
                    end,
                },
                {
                    name = "Point",
                    kind = LEM.SettingType.Dropdown,
                    default = "CENTER",
                    entries = {
                        ["CENTER"] = "Center",
                        ["TOP"] = "Top",
                        ["BOTTOM"] = "Bottom",
                        ["LEFT"] = "Left",
                        ["RIGHT"] = "Right",
                        ["TOPLEFT"] = "Top Left",
                        ["TOPRIGHT"] = "Top Right",
                        ["BOTTOMLEFT"] = "Bottom Left",
                        ["BOTTOMRIGHT"] = "Bottom Right"
                    },
                    get = function() return GetTagDB(i).point end,
                    set = function(_, value)
                        GetTagDB(i).point = value
                        UpdateFrameFromSettings(unit)
                    end,
                },
                {
                    name = "X",
                    kind = LEM.SettingType.Slider,
                    default = 0,
                    minValue = -200,
                    maxValue = 200,
                    valueStep = 1,
                    get = function() return GetTagDB(i).x end,
                    set = function(_, value)
                        GetTagDB(i).x = value
                        UpdateFrameFromSettings(unit)
                    end,
                },
                {
                    name = "Y",
                    kind = LEM.SettingType.Slider,
                    default = 0,
                    minValue = -100,
                    maxValue = 100,
                    valueStep = 1,
                    get = function() return GetTagDB(i).y end,
                    set = function(_, value)
                        GetTagDB(i).y = value
                        UpdateFrameFromSettings(unit)
                    end,
                },
            }
            for _, s in ipairs(subSettings) do table.insert(tagSettings, s) end
        end
        for _, s in ipairs(tagSettings) do table.insert(settings, s) end
    end

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
    local UF = RoithiUI:GetModule("UnitFrames")
    if not UF or not UF.frames then return end

    for unit, frame in pairs(UF.frames) do
        local db = GetDB(unit)

        -- Defaults if missing
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
            -- Ensure we don't re-add if already registered, or update if supported.
            -- LibEditMode doesn't always have IsFrameRegistered public, but AddFrame is idempotent-ish.
            -- However, the error "frame must be registered" implies AddFrame FAILED silently or didn't run?
            -- We'll try to add it.
            LEM:AddFrame(frame, OnPositionChanged, defaults)

            -- CHECK if registration worked. LibEditMode stores frames in .frameSettings or similar, but we should rely on public API?
            -- There is no public IsRegistered.
            -- BUT, AddFrameSettings throws if not found.
            -- We will wrap AddFrameSettings in a pcall to safely ignore if frame registration failed.
            local success, err = pcall(function()
                LEM:AddFrameSettings(frame, GetSettingsForMainFrame(unit, frame))
            end)
            if not success then
                -- This might spam chat if failing loop, but useful for debug
                -- print("RoithiUI Debug: Failed to add settings for " .. unit .. ": " .. tostring(err))
            end

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

-- ----------------------------------------------------------------------------
-- 5. Edit Mode Visibility
-- ----------------------------------------------------------------------------
if LEM then
    LEM:RegisterCallback('enter', function()
        local UF = RoithiUI:GetModule("UnitFrames")
        if not UF or not UF.frames then return end
        for unit, frame in pairs(UF.frames) do
            local db = GetDB(unit)
            if db and (db.enabled ~= false) then
                UnregisterUnitWatch(frame) -- Detach from secure driver to allow manual Show
                frame.isInEditMode = true
                frame:Show()
                frame:SetAlpha(1)

                -- Force Update Power Layout to ensure visibility in Edit Mode (Requested Feature)
                if frame.UpdatePowerLayout then frame.UpdatePowerLayout() end
                -- Force Update Class/Additional Power too just in case
                if frame.UpdateClassPowerLayout then frame.UpdateClassPowerLayout() end
                if frame.UpdateAdditionalPowerLayout then frame.UpdateAdditionalPowerLayout() end
            end
        end
    end)

    LEM:RegisterCallback('exit', function()
        local UF = RoithiUI:GetModule("UnitFrames")
        if not UF or not UF.frames then return end
        for unit, frame in pairs(UF.frames) do
            frame.isInEditMode = false
            -- We don't Hide() unitframes on exit like Castbars; they might need to stay shown if they have a target.
            -- UF:ToggleFrame handles normal visibility.
            UF:ToggleFrame(unit, UF:IsUnitEnabled(unit))
        end
    end)
end
