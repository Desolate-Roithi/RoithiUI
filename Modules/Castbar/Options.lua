local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI", true)
local ColorPickerFrame = _G.ColorPickerFrame

local function GetCastbarDB(unit)
    if not RoithiUI.db.profile.Castbar then RoithiUI.db.profile.Castbar = {} end
    if not RoithiUI.db.profile.Castbar[unit] then RoithiUI.db.profile.Castbar[unit] = {} end
    return RoithiUI.db.profile.Castbar[unit]
end

local UpdateBar

local function UpdateCastbar(unit)
    if UpdateBar then UpdateBar(unit) end
    if ns.UpdateCast and ns.bars and ns.bars[unit] then
        ns.UpdateCast(ns.bars[unit])
    end
end

local nonBossUnits = { "player", "target", "targettarget", "focus", "focustarget", "pet" }
local bossUnits    = { "boss1", "boss2", "boss3", "boss4", "boss5" }

local castbarLabels = {
    player       = L["Player Castbar"],
    target       = L["Target Castbar"],
    targettarget = L["Target of Target Castbar"],
    focus        = L["Focus Castbar"],
    focustarget  = L["Focus Target Castbar"],
    pet          = L["Pet Castbar"],
    boss1        = L["Boss 1 Castbar"],
    boss2        = L["Boss 2 Castbar"],
    boss3        = L["Boss 3 Castbar"],
    boss4        = L["Boss 4 Castbar"],
    boss5        = L["Boss 5 Castbar"],
}

--- Build one castbar settings group for a given uKey
local function BuildCastbarGroup(uKey, orderIdx)
    return {
        type = "group",
        name = castbarLabels[uKey] or (uKey .. " Castbar"),
        order = orderIdx,
        args = {
            enabled = {
                type = "toggle",
                name = L["Enable Castbar"],
                order = 1,
                scope = "both",
                get = function() return GetCastbarDB(uKey).enabled ~= false end,
                set = function(_, v)
                    GetCastbarDB(uKey).enabled = v
                    UpdateCastbar(uKey)
                end,
            },
            detached = {
                type = "toggle",
                name = L["Detach (Move in Edit Mode)"],
                order = 2,
                scope = "both",
                get = function() return GetCastbarDB(uKey).detached == true end,
                set = function(_, v)
                    local db = GetCastbarDB(uKey)
                    if v and (db.x == nil or db.y == nil) then
                        local bar = ns.bars and ns.bars[uKey]
                        if bar then
                            local cX, cY = bar:GetCenter()
                            local uScale = UIParent:GetEffectiveScale()
                            if cX and cY then
                                local screenWidth, screenHeight = UIParent:GetSize()
                                db.point = "CENTER"
                                db.x = math.floor((cX / uScale) - (screenWidth / 2) + 0.5)
                                db.y = math.floor((cY / uScale) - (screenHeight / 2) + 0.5)
                            else
                                db.point = "CENTER"
                                db.x = 0
                                db.y = 0
                            end
                        end
                    end
                    db.detached = v
                    UpdateBar(uKey)
                end,
            },
            width = {
                type = "range",
                name = L["Width"],
                order = 3,
                min = 50, max = 600, step = 1,
                scope = "both",
                get = function() return GetCastbarDB(uKey).width or 250 end,
                set = function(_, v)
                    GetCastbarDB(uKey).width = v
                    UpdateCastbar(uKey)
                end,
            },
            height = {
                type = "range",
                name = L["Height"],
                order = 4,
                min = 10, max = 80, step = 1,
                scope = "both",
                get = function() return GetCastbarDB(uKey).height or 25 end,
                set = function(_, v)
                    GetCastbarDB(uKey).height = v
                    UpdateCastbar(uKey)
                end,
            },
            showIcon = {
                type = "toggle",
                name = L["Show Spell Icon"],
                order = 5,
                scope = "both",
                get = function() return GetCastbarDB(uKey).showIcon ~= false end,
                set = function(_, v)
                    GetCastbarDB(uKey).showIcon = v
                    UpdateCastbar(uKey)
                end,
            },
            fontSize = {
                type = "range",
                name = L["Font Size"],
                order = 6,
                min = 8, max = 32, step = 1,
                scope = "ace",
                get = function() return GetCastbarDB(uKey).fontSize or 12 end,
                set = function(_, v)
                    GetCastbarDB(uKey).fontSize = v
                    UpdateCastbar(uKey)
                end,
            },
            colorOnInterruptCD = (uKey ~= "player") and {
                type = "toggle",
                name = L["Color when Interrupt on Cooldown"],
                desc = L["Change the castbar color if the cast is interruptible but your interrupt ability is currently on cooldown."],
                order = 7,
                scope = "both",
                get = function() return GetCastbarDB(uKey).colorOnInterruptCD == true end,
                set = function(_, v)
                    GetCastbarDB(uKey).colorOnInterruptCD = v
                    UpdateCastbar(uKey)
                end,
            } or nil,
            colorsGroup = {
                type = "group",
                name = L["Colors"],
                order = 10,
                inline = true,
                scope = "ace",
                args = {
                    castColor = {
                        type = "color",
                        name = L["Cast Color"],
                        order = 1,
                        hasAlpha = true,
                        get = function()
                            local c = GetCastbarDB(uKey).colors and GetCastbarDB(uKey).colors.cast or { 1, 1, 0, 1 }
                            return c[1], c[2], c[3], c[4] or 1
                        end,
                        set = function(_, r, g, b, a)
                            local db = GetCastbarDB(uKey)
                            if not db.colors then db.colors = {} end
                            db.colors.cast = { r, g, b, a }
                            UpdateCastbar(uKey)
                        end,
                    },
                    channelColor = {
                        type = "color",
                        name = L["Channel Color"],
                        order = 2,
                        hasAlpha = true,
                        get = function()
                            local c = GetCastbarDB(uKey).colors and GetCastbarDB(uKey).colors.channel or { 0, 0.98, 1, 1 }
                            return c[1], c[2], c[3], c[4] or 1
                        end,
                        set = function(_, r, g, b, a)
                            local db = GetCastbarDB(uKey)
                            if not db.colors then db.colors = {} end
                            db.colors.channel = { r, g, b, a }
                            UpdateCastbar(uKey)
                        end,
                    },
                    interruptedColor = {
                        type = "color",
                        name = L["Interrupted Color"],
                        order = 3,
                        hasAlpha = true,
                        get = function()
                            local c = GetCastbarDB(uKey).colors and GetCastbarDB(uKey).colors.interrupted or { 1, 0, 0, 1 }
                            return c[1], c[2], c[3], c[4] or 1
                        end,
                        set = function(_, r, g, b, a)
                            local db = GetCastbarDB(uKey)
                            if not db.colors then db.colors = {} end
                            db.colors.interrupted = { r, g, b, a }
                            UpdateCastbar(uKey)
                        end,
                    },
                    shieldColor = {
                        type = "color",
                        name = L["Shield Color"],
                        order = 4,
                        hasAlpha = true,
                        get = function()
                            local c = GetCastbarDB(uKey).colors and GetCastbarDB(uKey).colors.shield or { 0.5, 0.5, 0.5, 1 }
                            return c[1], c[2], c[3], c[4] or 1
                        end,
                        set = function(_, r, g, b, a)
                            local db = GetCastbarDB(uKey)
                            if not db.colors then db.colors = {} end
                            db.colors.shield = { r, g, b, a }
                            UpdateCastbar(uKey)
                        end,
                    },
                    interruptOnCDColor = (uKey ~= "player") and {
                        type = "color",
                        name = L["Interrupt on Cooldown Color"],
                        order = 5,
                        hasAlpha = true,
                        get = function()
                            local c = GetCastbarDB(uKey).colors and GetCastbarDB(uKey).colors.interruptOnCD or { 0.9, 0.5, 0.1, 1 }
                            return c[1], c[2], c[3], c[4] or 1
                        end,
                        set = function(_, r, g, b, a)
                            local db = GetCastbarDB(uKey)
                            if not db.colors then db.colors = {} end
                            db.colors.interruptOnCD = { r, g, b, a }
                            UpdateCastbar(uKey)
                        end,
                    } or nil,
                    empowerGroup = {
                        type = "group",
                        name = L["Empower Stage Colors"],
                        order = 6,
                        inline = true,
                        scope = "ace",
                        args = {
                            empower1 = {
                                type = "color",
                                name = " ",
                                desc = L["Empower Stage 1"],
                                order = 1,
                                hasAlpha = true,
                                width = 0.25,
                                get = function()
                                    local c = GetCastbarDB(uKey).colors and GetCastbarDB(uKey).colors.empower1 or { 0.8, 0.5, 0.1, 1 }
                                    return c[1], c[2], c[3], c[4] or 1
                                end,
                                set = function(_, r, g, b, a)
                                    local db = GetCastbarDB(uKey)
                                    if not db.colors then db.colors = {} end
                                    db.colors.empower1 = { r, g, b, a }
                                    UpdateCastbar(uKey)
                                end,
                            },
                            empower2 = {
                                type = "color",
                                name = " ",
                                desc = L["Empower Stage 2"],
                                order = 2,
                                hasAlpha = true,
                                width = 0.25,
                                get = function()
                                    local c = GetCastbarDB(uKey).colors and GetCastbarDB(uKey).colors.empower2 or { 0.9, 0.9, 0.2, 1 }
                                    return c[1], c[2], c[3], c[4] or 1
                                end,
                                set = function(_, r, g, b, a)
                                    local db = GetCastbarDB(uKey)
                                    if not db.colors then db.colors = {} end
                                    db.colors.empower2 = { r, g, b, a }
                                    UpdateCastbar(uKey)
                                end,
                            },
                            empower3 = {
                                type = "color",
                                name = " ",
                                desc = L["Empower Stage 3"],
                                order = 3,
                                hasAlpha = true,
                                width = 0.25,
                                get = function()
                                    local c = GetCastbarDB(uKey).colors and GetCastbarDB(uKey).colors.empower3 or { 0.2, 0.7, 0.1, 1 }
                                    return c[1], c[2], c[3], c[4] or 1
                                end,
                                set = function(_, r, g, b, a)
                                    local db = GetCastbarDB(uKey)
                                    if not db.colors then db.colors = {} end
                                    db.colors.empower3 = { r, g, b, a }
                                    UpdateCastbar(uKey)
                                end,
                            },
                            empower4 = {
                                type = "color",
                                name = " ",
                                desc = L["Empower Stage 4"],
                                order = 4,
                                hasAlpha = true,
                                width = 0.25,
                                get = function()
                                    local c = GetCastbarDB(uKey).colors and GetCastbarDB(uKey).colors.empower4 or { 0.6, 0.2, 0.8, 1 }
                                    return c[1], c[2], c[3], c[4] or 1
                                end,
                                set = function(_, r, g, b, a)
                                    local db = GetCastbarDB(uKey)
                                    if not db.colors then db.colors = {} end
                                    db.colors.empower4 = { r, g, b, a }
                                    UpdateCastbar(uKey)
                                end,
                            },
                        },
                    },
                },
            },
            quickLinks = {
                type = "group",
                name = L["Quick Links"],
                inline = true,
                order = 999,
                args = {
                    unitframe = {
                        type = "execute",
                        name = L["> Unit Frames"],
                        order = 1,
                        func = function() LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "unitframes", uKey) end,
                    },
                    auras = {
                        type = "execute",
                        name = L["> Auras"],
                        order = 2,
                        func = function()
                            local isBoss = uKey:match("^boss%d$")
                            if isBoss then
                                LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "auras", "units", "bossFrames", uKey)
                            else
                                LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "auras", "units", uKey)
                            end
                        end,
                    },
                }
            },
        }
    }
end

local castbarOptionsArgs = {}

for idx, uKey in ipairs(nonBossUnits) do
    castbarOptionsArgs[uKey] = BuildCastbarGroup(uKey, idx)
end

-- Boss castbars grouped under a single parent at the bottom
castbarOptionsArgs.bosses = {
    type = "group",
    name = L["Boss Castbars"],
    order = 99,
    args = {}
}
for idx, uKey in ipairs(bossUnits) do
    castbarOptionsArgs.bosses.args[uKey] = BuildCastbarGroup(uKey, idx)
end

ns.GetCastbarOptions = function()
    return castbarOptionsArgs
end


local castbarSchema = {
    name = L["Castbars"],
    order = 3,
    options = castbarOptionsArgs,
}

if ns.OptionsEngine then
    ns.OptionsEngine:RegisterModuleOptions("castbars", castbarSchema)
end

-- ============================================================================
-- EDIT MODE (LIBEDITMODE) CONFIGURATION FOR CASTBARS
-- Single Source of Truth - Moved from Config/LEMConfig/
-- ============================================================================

local LEM = LibStub("LibEditMode-Roithi", true)

if LEM and not LEM.SettingType.ColorRow then
    LEM.SettingType.ColorRow = "colorrow"

    local function onRowSwatchClick(swatch)
        local parent = swatch:GetParent()
        local idx = swatch.swatchIndex
        local colorInfo = parent.colorInfos and parent.colorInfos[idx]
        if colorInfo then
            ColorPickerFrame:SetupColorPickerAndShow(colorInfo)
        end
    end

    local colorRowMixin = {}
    function colorRowMixin:Setup(data)
        self.setting = data
        self.Label:SetText(data.name or "Empower")
        self.colorInfos = {}
        self:Show()
        self:Refresh()

        local layoutName = LEM:GetActiveLayoutName()
        for i = 1, 4 do
            local swatch = self.Swatches[i]
            local item = data.colors and data.colors[i]
            if item and swatch then
                swatch:Show()
                local val = item.get and item.get(layoutName) or CreateColor(1, 1, 1, 1)
                local r, g, b, a = val:GetRGBA()

                local function onColorChanged()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = item.hasOpacity and ColorPickerFrame:GetColorAlpha() or 1
                    local newColor = CreateColor(nr, ng, nb, na)
                    if item.set then item.set(layoutName, newColor, false) end
                    swatch:SetColorRGB(nr, ng, nb)
                end

                self.colorInfos[i] = {
                    swatchFunc = onColorChanged,
                    opacityFunc = onColorChanged,
                    cancelFunc = onColorChanged,
                    r = r, g = g, b = b, opacity = a,
                    hasOpacity = item.hasOpacity ~= false,
                }
                swatch:SetColorRGB(r, g, b)
            elseif swatch then
                swatch:Hide()
            end
        end
    end

    function colorRowMixin:Refresh()
        local data = self.setting
        if not data then return end
        if type(data.hidden) == "function" then
            self:SetShown(not data.hidden(LEM:GetActiveLayoutName()))
        else
            self:SetShown(not data.hidden)
        end
    end

    LEM.internal:CreatePool(LEM.SettingType.ColorRow, function()
        local frame = CreateFrame("Frame", nil, UIParent, "ResizeLayoutFrame")
        frame.fixedHeight = 32
        frame:Hide()

        local Label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
        Label:SetPoint("LEFT")
        Label:SetSize(100, 32)
        Label:SetJustifyH("LEFT")
        frame.Label = Label

        frame.Swatches = {}
        local prev = Label
        for i = 1, 4 do
            local swatch = CreateFrame("Button", nil, frame, "ColorSwatchTemplate")
            swatch:SetSize(24, 24)
            swatch:SetPoint("LEFT", prev, "RIGHT", i == 1 and 5 or 6, 0)
            swatch.swatchIndex = i
            swatch:SetScript("OnClick", onRowSwatchClick)
            frame.Swatches[i] = swatch
            prev = swatch
        end

        return Mixin(frame, colorRowMixin)
    end, function(_, frame)
        frame:Hide()
        frame.layoutIndex = nil
    end)
end

function UpdateBar(unit)
    local db = RoithiUI.db.profile.Castbar and RoithiUI.db.profile.Castbar[unit]
    local bar = ns.bars and ns.bars[unit]
    if not bar or not db then return end

    if ns.SetCastbarAttachment then
        ns.SetCastbarAttachment(unit, not db.detached)
    end

    local finalWidth = db.width or 200
    local finalHeight = db.height or 20
    local iconScale = db.iconScale or 1.0
    local iconSize = finalHeight * iconScale

    if not db.detached then
        local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
        ---@diagnostic disable-next-line: undefined-field
        local uFrame = UF and UF.units and UF.units[unit]
        if uFrame then
            finalWidth = uFrame:GetWidth()
            if db.showIcon ~= false then
                finalWidth = finalWidth - iconSize
                if finalWidth < 1 then finalWidth = 1 end
            end
        end
        local AL = ns.AttachmentLogic
        if AL then AL:GlobalLayoutRefresh(unit) end
    elseif not ns.SetCastbarAttachment and db.detached then
        if not bar.isInEditMode then
            bar:ClearAllPoints()
            bar:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 0, db.y or 0)
        end
    end

    bar:SetSize(finalWidth, finalHeight)

    if db.showIcon ~= false and bar.Icon then
        bar.Icon:Show()
        bar.Icon:SetSize(iconSize, iconSize)
        if bar.isInEditMode then bar.Icon:SetTexture(136243) end
    elseif bar.Icon then
        bar.Icon:Hide()
    end

    if bar.Spark then bar.Spark:SetSize(20, finalHeight * 2.2) end

    -- Real-time Font Update
    local LSM = LibStub("LibSharedMedia-3.0")
    local general = RoithiUI.db and RoithiUI.db.profile and RoithiUI.db.profile.General
    local font = (LSM and LSM:Fetch("font", (general and general.font) or "Friz Quadrata TT")) or [[Fonts\FRIZQT__.TTF]]
    local fontSize = db.fontSize or 12
    if bar.Text then bar.Text:SetFont(font, fontSize, "OUTLINE") end
    if bar.TimeFS then bar.TimeFS:SetFont(font, fontSize, "OUTLINE") end

    -- Real-time Edit Mode Color & Preview Update
    if bar.isInEditMode then
        local c = db.colors and db.colors.cast or { 1, 1, 0, 1 }
        bar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
        if LEM and LEM.RefreshFrame then
            LEM:RefreshFrame(bar)
        end
    end
end

local colorSectionsExpanded = {}

function ns.ApplyLEMCastbarConfiguration(bar, unit)
    if not LEM then return end

    local function GetSettings()
        local db = GetCastbarDB(unit)
        local settings = {
            {
                name = "Detached",
                kind = LEM.SettingType.Checkbox,
                default = false,
                get = function() return db.detached end,
                set = function(_, value)
                    if value == true and not db.detached then
                        if db.x == nil or db.y == nil then
                            if bar then
                                local cX, cY = bar:GetCenter()
                                local uScale = UIParent:GetEffectiveScale()
                                if cX and cY then
                                    local screenWidth, screenHeight = UIParent:GetSize()
                                    db.point = "CENTER"
                                    db.x = math.floor((cX / uScale) - (screenWidth / 2) + 0.5)
                                    db.y = math.floor((cY / uScale) - (screenHeight / 2) + 0.5)
                                else
                                    db.point = "CENTER"
                                    db.x = 0
                                    db.y = 0
                                end
                            end
                        end
                    end
                    db.detached = value
                    UpdateBar(unit)
                    LEM:AddFrameSettings(bar, GetSettings())
                    LEM:RefreshFrameSettings(bar)
                end,
            },
        }

        if db.detached then
            table.insert(settings, {
                name = "Width",
                kind = LEM.SettingType.Slider,
                default = 200,
                minValue = 50,
                maxValue = 600,
                valueStep = 1,
                get = function() return db.width or 200 end,
                set = function(_, value)
                    db.width = value
                    UpdateBar(unit)
                end,
                formatter = function(v) return string.format("%.1f", v) end,
            })

            table.insert(settings, {
                name = "X Position",
                kind = LEM.SettingType.Slider,
                default = 0,
                minValue = -2500,
                maxValue = 2500,
                valueStep = 1,
                get = function() return db.x or 0 end,
                set = function(_, value)
                    db.x = value
                    UpdateBar(unit)
                end,
                formatter = function(v) return string.format("%.1f", v) end,
            })

            table.insert(settings, {
                name = "Y Position",
                kind = LEM.SettingType.Slider,
                default = 0,
                minValue = -1500,
                maxValue = 1500,
                valueStep = 1,
                get = function() return db.y or 0 end,
                set = function(_, value)
                    db.y = value
                    UpdateBar(unit)
                end,
                formatter = function(v) return string.format("%.1f", v) end,
            })
        end

        table.insert(settings, {
            name = "Height",
            kind = LEM.SettingType.Slider,
            default = 20,
            minValue = 10,
            maxValue = 100,
            valueStep = 1,
            get = function() return db.height or 20 end,
            set = function(_, value)
                db.height = value
                UpdateBar(unit)
            end,
            formatter = function(v) return string.format("%.1f", v) end,
        })

        table.insert(settings, {
            name = "Font Size",
            kind = LEM.SettingType.Slider,
            defaultValue = 12,
            minValue = 8,
            maxValue = 32,
            valueStep = 1,
            get = function() return db.fontSize or 12 end,
            set = function(_, value)
                db.fontSize = value
                UpdateBar(unit)
            end,
        })

        table.insert(settings, {
            name = "Show Icon",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function() return db.showIcon ~= false end,
            set = function(_, value)
                db.showIcon = value
                UpdateBar(unit)
                if LEM then
                    LEM:AddFrameSettings(bar, GetSettings())
                    LEM:RefreshFrameSettings(bar)
                end
            end,
        })

        if db.showIcon ~= false then
            table.insert(settings, {
                name = "Icon Scale",
                kind = LEM.SettingType.Slider,
                default = 1.0,
                minValue = 0.5,
                maxValue = 2.5,
                valueStep = 0.05,
                get = function() return db.iconScale or 1.0 end,
                set = function(_, value)
                    db.iconScale = value
                    UpdateBar(unit)
                end,
                formatter = function(v) return string.format("%.2f", v) end,
            })
        end

        if unit ~= "player" then
            table.insert(settings, {
                name = L["Color when Interrupt on Cooldown"] or "Color when Interrupt on Cooldown",
                kind = LEM.SettingType.Checkbox,
                default = false,
                get = function() return db.colorOnInterruptCD == true end,
                set = function(_, value)
                    db.colorOnInterruptCD = value
                    UpdateBar(unit)
                end,
            })
        end

        table.insert(settings, { kind = LEM.SettingType.Divider })

        table.insert(settings, {
            name = "Colors",
            expandedLabel = "Collapse colors",
            collapsedLabel = "Expand colors",
            kind = LEM.SettingType.Expander,
            default = false,
            get = function() return colorSectionsExpanded[unit] end,
            set = function(_, value)
                colorSectionsExpanded[unit] = value
                LEM:AddFrameSettings(bar, GetSettings())
                LEM:RefreshFrameSettings(bar)
            end,
        })

        if colorSectionsExpanded[unit] then
            local colorKeys = {
                { key = "cast",        name = "Cast" },
                { key = "channel",     name = "Channel" },
                { key = "interrupted", name = "Interrupted" },
                { key = "shield",      name = "Shield" },
            }
            if unit ~= "player" then
                table.insert(colorKeys, { key = "interruptOnCD", name = L["Interrupt on CD"] or "Interrupt on CD" })
            end

            for _, info in ipairs(colorKeys) do
                table.insert(settings, {
                    name = info.name,
                    kind = LEM.SettingType.ColorPicker,
                    hasOpacity = true,
                    get = function()
                        local c = db.colors and db.colors[info.key] or { 1, 1, 1, 1 }
                        return CreateColor(c[1], c[2], c[3], c[4] or 1)
                    end,
                    set = function(_, color)
                        local r, g, b, a = color:GetRGBA()
                        if not db.colors then db.colors = {} end
                        db.colors[info.key] = { r, g, b, a }
                        if bar.isInEditMode and info.key == "cast" then
                            bar:SetStatusBarColor(r, g, b, 1)
                        end
                        UpdateBar(unit)
                    end,
                })
            end

            local empowerRow = {
                name = "Empower",
                kind = LEM.SettingType.ColorRow,
                colors = {}
            }
            for i = 1, 4 do
                local key = "empower" .. i
                table.insert(empowerRow.colors, {
                    hasOpacity = true,
                    get = function()
                        local c = db.colors and db.colors[key] or { 1, 1, 1, 1 }
                        return CreateColor(c[1], c[2], c[3], c[4] or 1)
                    end,
                    set = function(_, color)
                        local r, g, b, a = color:GetRGBA()
                        if not db.colors then db.colors = {} end
                        db.colors[key] = { r, g, b, a }
                        UpdateBar(unit)
                    end,
                })
            end
            table.insert(settings, empowerRow)
        end

        return settings
    end

    LEM:AddFrameSettings(bar, GetSettings())
    bar.extraButtons = nil
    LEM:AddFrameSettingsButtons(bar, {
        {
            text = "Open Full Settings",
            click = function()
                if LibStub("AceConfigDialog-3.0") then
                    LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "castbars", unit)
                    LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                end
            end
        }
    })
end

function ns.InitializeCastbarConfig()
    if not ns.bars or not LEM then return end

    for unit, bar in pairs(ns.bars) do
        local db = GetCastbarDB(unit)
        bar.editModeName = "Roithi " .. unit:gsub("^%l", string.upper) .. " Castbar"

        local defaults = { point = db.point or "CENTER", x = db.x or 0, y = db.y or 0 }

        local function OnPositionChanged(movedBar, _, point, x, y)
            local posDB = GetCastbarDB(unit)
            if not posDB.detached then
                UpdateBar(unit)
                return
            end

            x = math.floor(x * 100 + 0.5) / 100
            y = math.floor(y * 100 + 0.5) / 100

            posDB.point = point
            posDB.x = x
            posDB.y = y

            movedBar:ClearAllPoints()
            movedBar:SetPoint(point, UIParent, point, x, y)
            LEM:RefreshFrameSettings(movedBar)
        end

        LEM:AddFrame(bar, OnPositionChanged, defaults)
        ns.ApplyLEMCastbarConfiguration(bar, unit)
        UpdateBar(unit)
    end
end

if LEM then
    LEM:RegisterCallback('enter', function()
        if not ns.bars then return end
        for unit, bar in pairs(ns.bars) do
            local db = GetCastbarDB(unit)
            if db and db.enabled then
                bar.isInEditMode = true
                bar:Show()
                bar:SetAlpha(1)
                bar:SetMinMaxValues(0, 1)
                bar:SetValue(1)
                local c = db.colors and db.colors.cast or { 1, 1, 0, 1 }
                bar:SetStatusBarColor(c[1], c[2], c[3], 1)
                if bar.Background then bar.Background:SetColorTexture(0, 0, 0, 0.5) end
                if bar.Icon and db.showIcon then
                    bar.Icon:SetTexture(136243)
                    bar.Icon:Show()
                elseif bar.Icon then
                    bar.Icon:Hide()
                end
                if bar.Text then bar.Text:SetText(unit:upper() .. " CASTBAR") end
                UpdateBar(unit)
            end
        end
    end)

    LEM:RegisterCallback('exit', function()
        if not ns.bars then return end
        for _, bar in pairs(ns.bars) do
            bar.isInEditMode = false
            bar:Hide()
        end
    end)
end
