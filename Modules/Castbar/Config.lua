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
        }
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
function ns.InitializeConfig()
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
-- 5. Global Enable Menu (Anchored to EditModeManagerFrame)
-- ----------------------------------------------------------------------------
local globalMenu
local function CreateGlobalEnableMenu()
    if globalMenu then return globalMenu end

    -- Main Container
    local f = CreateFrame("Frame", "MidnightCastbarsGlobalMenu", UIParent, "BackdropTemplate")
    f:SetSize(170, 40) -- Start collapsed-ish height, or expand on init
    f:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", 2, 0)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })

    -- State
    f.isExpanded = true
    f:SetHeight(130)

    -- Header / Toggle Button
    local header = CreateFrame("Button", nil, f)
    header:SetPoint("TOPLEFT", 5, -5)
    header:SetPoint("TOPRIGHT", -5, -5)
    header:SetHeight(30)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("CENTER", header, "CENTER", 0, 0)
    title:SetText("Midnight Castbars")

    local arrow = header:CreateTexture(nil, "ARTWORK")
    arrow:SetAtlas("Options-List-Expand-Up") -- Points up when expanded? Or down?
    -- Logic: Expanded -> "Collapse" (Up arrow or Minus), Collapsed -> "Expand" (Down arrow)
    -- Blizzard convention: 'Options-List-Expand-Up' usually means "Click to collapse" (points up/open)
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    f.menuArrow = arrow

    -- Checkboxes Container (for hiding/showing)
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 0, -35)
    content:SetPoint("BOTTOMRIGHT", 0, 0)
    f.content = content

    -- Toggling Logic
    header:SetScript("OnClick", function()
        f.isExpanded = not f.isExpanded
        if f.isExpanded then
            f:SetHeight(200)
            content:Show()
            arrow:SetAtlas("Options-List-Expand-Up")
        else
            f:SetHeight(40)
            content:Hide()
            arrow:SetAtlas("Options-List-Expand-Down")
        end
    end)

    -- Checkbox Helper (Standard UICheckButtonTemplate with EditMode styling)
    local function CreateCheck(unit, label, yOffset)
        -- Using UICheckButtonTemplate as it's reliable.
        -- EditModeSettingCheckboxTemplate is likely internal or requires complex setup.
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 15, yOffset)
        cb:SetSize(24, 24) -- Standard size

        -- Style text to match Edit Mode (White, Highlight)
        cb.text:SetFontObject("GameFontHighlight")
        cb.text:SetText(label)

        cb:SetScript("OnShow", function(self)
            self:SetChecked(GetDB(unit).enabled)
        end)

        cb:SetScript("OnClick", function(self)
            local enabled = self:GetChecked()
            GetDB(unit).enabled = enabled

            -- Play Sound
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)

            -- Update Blizzard Frames visibility
            ns.UpdateBlizzardVisibility()

            -- Update our bar visibility
            local bar = ns.bars[unit]
            if enabled then
                -- Re-enable interaction with Edit Mode
                bar.isInEditMode = true
                bar:Show()
                LEM:RefreshFrameSettings(bar)
            else
                bar.isInEditMode = false
                bar:Hide()
            end

            ns.UpdateCast(bar)
        end)
        return cb
    end

    f.checkPlayer       = CreateCheck("player", "Player Bar", -10)
    f.checkTarget       = CreateCheck("target", "Target Bar", -35)
    f.checkFocus        = CreateCheck("focus", "Focus Bar", -60)

    f.checkPet          = CreateCheck("pet", "Pet Bar", -85)
    f.checkTargetTarget = CreateCheck("targettarget", "ToT Bar", -110)
    f.checkFocusTarget  = CreateCheck("focustarget", "Focus Target", -135)

    -- Adjust height for more items (6 items * 25px approx + padding) -> 130 + 75 = 205
    -- We need to update the height logic in the header click

    f:Hide()
    globalMenu = f
    return f
end


-- ----------------------------------------------------------------------------
-- 6. Edit Mode Callbacks
-- ----------------------------------------------------------------------------
LEM:RegisterCallback('enter', function()
    -- Create/Show Global Menu
    local menu = CreateGlobalEnableMenu()
    menu:Show()

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
    if globalMenu then globalMenu:Hide() end

    for _, bar in pairs(ns.bars) do
        bar.isInEditMode = false
        bar:Hide()
    end
end)
