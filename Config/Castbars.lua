local addonName, ns = ...
local function GetDB(unit)
    return RoithiUIDB.Castbar[unit]
end

local RoithiUI = _G.RoithiUI
-- Local alias will be resolved in functions
local LEM = LibStub("LibEditMode")

-- Global UI State
local colorSectionsExpanded = {
    player = false,
    target = false,
    focus = false,
}

-- ----------------------------------------------------------------------------
-- 1. Helpers
-- ----------------------------------------------------------------------------
local function UpdateBarFromSettings(unit)
    local db = RoithiUIDB.Castbar[unit]
    local bar = ns.bars[unit]
    if not bar then return end

    bar:SetSize(db.width, db.height)

    -- Position
    bar:ClearAllPoints()
    -- Ensure relative point matches point, as OnPositionChanged saves it this way
    bar:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 0, db.y or 0)

    -- Appearance
    bar.Text:SetFont(ns.STANDARD_TEXT_FONT, db.fontSize or 12, "OUTLINE")
    if db.showIcon then
        bar.Icon:Show()
        local size = db.height * (db.iconScale or 1.0)
        bar.Icon:SetSize(size, size)
    else
        bar.Icon:Hide()
    end

    bar.Spark:SetSize(20, db.height * 2.2)

    if bar.StageTicks then
        for _, tick in pairs(bar.StageTicks) do
            tick:SetHeight(db.height)
        end
    end

    -- Initial color (will be overwritten by cast events)
    local c = db.colors.cast
    bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
    if bar.Background then bar.Background:SetColorTexture(0, 0, 0, 0.5) end
end

-- ----------------------------------------------------------------------------
-- 2. Settings Generator
-- ----------------------------------------------------------------------------
local function GetSettingsForUnit(unit)
    local settings = {

        {
            name = "Width",
            kind = LEM.SettingType.Slider,
            default = 200,
            minValue = 50,
            maxValue = 600,
            valueStep = 1,
            get = function() return GetDB(unit).width end,
            set = function(_, value)
                GetDB(unit).width = value
                UpdateBarFromSettings(unit)
            end,
            formatter = function(v) return string.format("%.1f", v) end,
        },

        {
            name = "Height",
            kind = LEM.SettingType.Slider,
            default = 20,
            minValue = 10,
            maxValue = 100,
            valueStep = 1,
            get = function() return GetDB(unit).height end,
            set = function(_, value)
                GetDB(unit).height = value
                UpdateBarFromSettings(unit)
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
                UpdateBarFromSettings(unit)
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
                UpdateBarFromSettings(unit)
            end,
            formatter = function(v) return string.format("%.1f", v) end,
        },
        {
            name = "Font Size",
            maxValue = 32,
            valueStep = 1,
            get = function() return GetDB(unit).fontSize or 12 end,
            set = function(_, value)
                GetDB(unit).fontSize = value
                UpdateBarFromSettings(unit)
            end,
        },
        {
            name = "Show Icon",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function() return GetDB(unit).showIcon end,
            set = function(_, value)
                GetDB(unit).showIcon = value
                UpdateBarFromSettings(unit)
            end,
        },
        {
            name = "Icon Scale",
            kind = LEM.SettingType.Slider,
            default = 1.0,
            minValue = 0.5,
            maxValue = 2.5,
            valueStep = 0.05,
            get = function() return GetDB(unit).iconScale or 1.0 end,
            set = function(_, value)
                GetDB(unit).iconScale = value
                UpdateBarFromSettings(unit)
            end,
            formatter = function(v) return string.format("%.2f", v) end,
        },
        {
            kind = LEM.SettingType.Divider,
        },
        {
            name = colorSectionsExpanded[unit] and "Collapse colors" or "Expand colors",
            kind = LEM.SettingType.CollapsibleHeader,
            default = false,
            get = function() return colorSectionsExpanded[unit] end,
            set = function(_, value)
                colorSectionsExpanded[unit] = value
                LEM:AddFrameSettings(ns.bars[unit], GetSettingsForUnit(unit))
                LEM:RefreshFrameSettings(ns.bars[unit])
            end,
        },
    }

    if colorSectionsExpanded[unit] then
        local colorKeys = {
            { key = "cast",        name = "Cast" },
            { key = "channel",     name = "Channel" },
            { key = "interrupted", name = "Interrupted" },
            { key = "shield",      name = "Shield" },
        }

        for _, info in ipairs(colorKeys) do
            table.insert(settings, {
                name = info.name,
                kind = LEM.SettingType.ColorPicker,
                hasOpacity = true,
                get = function()
                    local c = GetDB(unit).colors[info.key]
                    return CreateColor(c[1], c[2], c[3], c[4] or 1)
                end,
                set = function(_, color)
                    local r, g, b, a = color:GetRGBA()
                    GetDB(unit).colors[info.key] = { r, g, b, a }
                    UpdateBarFromSettings(unit)
                end,
            })
        end

        -- Generic Color Row for Empower states
        local empowerRow = {
            name = "Empower",
            kind = LEM.SettingType.ColorRow,
            colors = {}
        }
        for i = 1, 4 do
            local key = "empower" .. i
            table.insert(empowerRow.colors, {
                get = function()
                    local c = GetDB(unit).colors[key]
                    return CreateColor(c[1], c[2], c[3], c[4] or 1)
                end,
                set = function(_, color)
                    local r, g, b, a = color:GetRGBA()
                    GetDB(unit).colors[key] = { r, g, b, a }
                    UpdateBarFromSettings(unit)
                end,
            })
        end
        table.insert(settings, empowerRow)
    end

    table.insert(settings, {
        kind = LEM.SettingType.Divider,
    })

    return settings
end

-- ----------------------------------------------------------------------------
-- 4. Position Callback
-- ----------------------------------------------------------------------------
local function OnPositionChanged(bar, layoutName, point, x, y)
    local unit = bar.unit
    x = math.floor(x * 100 + 0.5) / 100
    y = math.floor(y * 100 + 0.5) / 100

    local db = GetDB(unit)
    db.point = point
    db.x = x
    db.y = y

    bar:ClearAllPoints()
    bar:SetPoint(point, UIParent, point, x, y)

    -- Refresh settings dialog if open to update sliders
    LEM:RefreshFrameSettings(bar)
end

-- ----------------------------------------------------------------------------
-- 5. Initialization
-- ----------------------------------------------------------------------------
function ns.InitializeCastbarConfig()
    for unit, bar in pairs(ns.bars) do
        local db = GetDB(unit)
        bar.editModeName = "Midnight " .. unit:gsub("^%l", string.upper) .. " Bar"

        local defaults = { point = db.point or "CENTER", x = db.x or 0, y = db.y or 0 }

        LEM:AddFrame(bar, OnPositionChanged, defaults)
        LEM:AddFrameSettings(bar, GetSettingsForUnit(unit))

        UpdateBarFromSettings(unit)
    end
end

-- ----------------------------------------------------------------------------
-- 6. Edit Mode Callbacks
-- ----------------------------------------------------------------------------
LEM:RegisterCallback('enter', function()
    -- Enable bars for Edit Mode
    for unit, bar in pairs(ns.bars) do
        local db = GetDB(unit)
        if db and db.enabled then
            bar.isInEditMode = true
            bar:Show()
            bar:SetMinMaxValues(0, 1); bar:SetValue(1)
            local c = db.colors.cast
            bar:SetStatusBarColor(c[1], c[2], c[3], 1)
            if bar.Background then bar.Background:SetColorTexture(0, 0, 0, 0.5) end
            if bar.Icon then
                bar.Icon:SetTexture(136243); bar.Icon:Show()
            end
            bar.Text:SetText(unit:upper() .. " CASTBAR")
        end
    end
end)

LEM:RegisterCallback('exit', function()
    -- Hide bars
    for _, bar in pairs(ns.bars) do
        bar.isInEditMode = false
        bar:Hide()
    end
end)
