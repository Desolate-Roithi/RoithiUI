local addonName, ns = ...
local RoithiUI = _G.RoithiUI
local LEM = LibStub("LibEditMode-Roithi", true)

if not LEM then return end

-- Helper Accessor
local function GetDB(unit)
    return RoithiUI.db.profile.Castbar[unit]
end

-- Helper to update bars
local function UpdateBar(unit)
    -- Layout Update Logic
    local db = RoithiUI.db.profile.Castbar[unit]
    local bar = ns.bars[unit]
    if not bar then return end

    -- Enforce Attachment State
    if ns.SetCastbarAttachment then
        ns.SetCastbarAttachment(unit, not db.detached)
    end

    local finalWidth = db.width
    local finalHeight = db.height
    local iconSize = finalHeight * (db.iconScale or 1.0)

    if not db.detached then
        -- ATTACHED MODE: Match UnitFrame Width
        local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
        ---@diagnostic disable-next-line: undefined-field
        local uFrame = UF and UF.units and UF.units[unit]

        if uFrame then
            finalWidth = uFrame:GetWidth()

            -- Subtract Icon Width if shown
            if db.showIcon then
                finalWidth = finalWidth - iconSize
                if finalWidth < 1 then finalWidth = 1 end
            end
        end

        local AL = ns.AttachmentLogic
        if AL then AL:GlobalLayoutRefresh(unit) end
    elseif not ns.SetCastbarAttachment and db.detached then
        -- Fallback for dragging in detached mode
        if not bar.isInEditMode then
            bar:ClearAllPoints()
            bar:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 0, db.y or 0)
        end
    end

    bar:SetSize(finalWidth, finalHeight)

    -- Icon
    if db.showIcon then
        bar.Icon:Show()
        bar.Icon:SetSize(iconSize, iconSize)
    else
        bar.Icon:Hide()
    end
    bar.Spark:SetSize(20, db.height * 2.2)
    bar.Text:SetFont(ns.STANDARD_TEXT_FONT, db.fontSize or 12, "OUTLINE")
end

-- Global UI State for Colors
local colorSectionsExpanded = {
    player = false,
    target = false,
    focus = false,
    pet = false,
    boss1 = false,
    boss2 = false,
    boss3 = false,
    boss4 = false,
    boss5 = false
}

function ns.ApplyLEMCastbarConfiguration(bar, unit)
    -- Settings Generator Function
    local function GetSettings()
        local settings = {
            {
                name = "Detached",
                kind = LEM.SettingType.Checkbox,
                default = false,
                get = function() return GetDB(unit).detached end,
                set = function(_, value)
                    local db = GetDB(unit)
                    -- Smart Detach Logic (Seamless Transition like Power Bars)
                    if value == true and not db.detached then
                        -- Switching to Detached: Calculate current visual position to avoid jumps
                        if bar then
                            local cX, cY = bar:GetCenter()
                            local uScale = UIParent:GetEffectiveScale()
                            if cX and cY then
                                local screenWidth, screenHeight = UIParent:GetSize()
                                local finalX = (cX / uScale) - (screenWidth / 2)
                                local finalY = (cY / uScale) - (screenHeight / 2)

                                db.point = "CENTER"
                                db.x = finalX
                                db.y = finalY
                            end
                        end
                    elseif value == false then
                        -- Re-attaching: Reset coordinates effectively resetting offset to 0
                        db.x = 0
                        db.y = 0
                        db.point = "CENTER"
                    end

                    db.detached = value
                    UpdateBar(unit) -- Triggers SetCastbarAttachment
                end,
            },
            {
                name = "Width",
                kind = LEM.SettingType.Slider,
                default = 200,
                minValue = 50,
                maxValue = 600,
                valueStep = 1,
                get = function() return GetDB(unit).width end,
                set = function(_, value)
                    GetDB(unit).width = value; UpdateBar(unit)
                end,
                isHidden = function() return not GetDB(unit).detached end,
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
                    GetDB(unit).height = value; UpdateBar(unit)
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
                    GetDB(unit).x = value; UpdateBar(unit)
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
                    GetDB(unit).y = value; UpdateBar(unit)
                end,
                formatter = function(v) return string.format("%.1f", v) end,
            },
            {
                name = "Font Size",
                kind = LEM.SettingType.Slider,
                defaultValue = 12,
                minValue = 8,
                maxValue = 32,
                valueStep = 1,
                get = function() return GetDB(unit).fontSize or 12 end,
                set = function(_, value)
                    GetDB(unit).fontSize = value; UpdateBar(unit)
                end,
            },
            {
                name = "Show Icon",
                kind = LEM.SettingType.Checkbox,
                default = true,
                get = function() return GetDB(unit).showIcon end,
                set = function(_, value)
                    GetDB(unit).showIcon = value; UpdateBar(unit)
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
                    GetDB(unit).iconScale = value; UpdateBar(unit)
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
                    -- Trigger Refresh
                    LEM:AddFrameSettings(bar, GetSettings())
                    LEM:RefreshFrameSettings(bar)
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
                        -- Simple visual update for Edit Mode:
                        if bar.isInEditMode and info.key == "cast" then
                            bar:SetStatusBarColor(r, g, b, 1)
                        end
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
                        UpdateBar(unit)
                    end,
                })
            end
            table.insert(settings, empowerRow)
        end

        return settings
    end

    LEM:AddFrameSettings(bar, GetSettings())
end

-- ----------------------------------------------------------------------------
-- 5. Initialization (Replaces logic previously in Config/Castbars.lua)
-- ----------------------------------------------------------------------------
function ns.InitializeCastbarConfig()
    if not ns.bars then return end

    for unit, bar in pairs(ns.bars) do
        local db = GetDB(unit)
        bar.editModeName = "Roithi " .. unit:gsub("^%l", string.upper) .. " Castbar"

        local defaults = { point = db.point or "CENTER", x = db.x or 0, y = db.y or 0 }

        -- Position Callback
        local function OnPositionChanged(bar, layoutName, point, x, y)
            -- Only save position if detached.
            local db = GetDB(unit)
            if not db.detached then
                -- SNAP BACK: If dragged while attached, force reset to attached position
                UpdateBar(unit)
                return
            end

            x = math.floor(x * 100 + 0.5) / 100
            y = math.floor(y * 100 + 0.5) / 100

            db.point = point
            db.x = x
            db.y = y

            bar:ClearAllPoints()
            bar:SetPoint(point, UIParent, point, x, y)

            -- Refresh settings dialog if open
            LEM:RefreshFrameSettings(bar)
        end

        LEM:AddFrame(bar, OnPositionChanged, defaults)

        -- Apply Settings
        ns.ApplyLEMCastbarConfiguration(bar, unit)

        -- Initial Layout Update
        UpdateBar(unit)
    end
end

-- ----------------------------------------------------------------------------
-- 6. Edit Mode Visibility
-- ----------------------------------------------------------------------------
LEM:RegisterCallback('enter', function()
    -- Enable bars for Edit Mode
    if not ns.bars then return end
    for unit, bar in pairs(ns.bars) do
        local db = GetDB(unit)
        if db and db.enabled then
            bar.isInEditMode = true
            bar:Show()      -- Show immediately
            bar:SetAlpha(1) -- Ensure visible

            bar:SetMinMaxValues(0, 1); bar:SetValue(1)
            local c = db.colors.cast
            bar:SetStatusBarColor(c[1], c[2], c[3], 1)
            if bar.Background then bar.Background:SetColorTexture(0, 0, 0, 0.5) end
            if bar.Icon and db.showIcon then
                bar.Icon:SetTexture(136243); bar.Icon:Show()
            elseif bar.Icon then
                bar.Icon:Hide()
            end
            bar.Text:SetText(unit:upper() .. " CASTBAR")

            -- If attached, ensure it's attached!
            UpdateBar(unit)
        end
    end
end)

LEM:RegisterCallback('exit', function()
    -- Hide bars
    if not ns.bars then return end
    for _, bar in pairs(ns.bars) do
        bar.isInEditMode = false
        bar:Hide()
    end
end)
