local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI", true)
local LSM = LibStub("LibSharedMedia-3.0")

local function GetLSMKeys(mediaType)
    local list = LSM:List(mediaType)
    local out = {}
    for _, name in ipairs(list) do
        out[name] = name
    end
    return out
end

function ns.GetEncounterBarOptions()
    return {
        type = "group",
        name = L["Encounter Resource Bar"],
        order = 5,
        args = {
                    intro = {
                        type = "description",
                        name = L["Configure the custom Encounter Resource Bar. Position it via LibEditMode (Edit Mode)."],
                        order = 0,
                    },
                    enabled = {
                        type = "toggle",
                        name = L["Enable"],
                        desc  = L["Show the custom encounter resource bar (hides the Blizzard default)."],
                        order = 1,
                        width = "full",
                        get = function()
                            local db = RoithiUI.db.profile.EncounterResource
                            return db and db.enabled
                        end,
                        set = function(_, v)
                            local db = RoithiUI.db.profile
                            if not db.EncounterResource then db.EncounterResource = {} end
                            db.EncounterResource.enabled = v
                            local EB = RoithiUI:GetModule("EncounterBar")
                            if EB and EB.Toggle then EB:Toggle(v) end
                        end,
                    },
                    sizeGroup = {
                        type = "group",
                        name = L["Size"],
                        order = 10,
                        inline = true,
                        args = {
                            width = {
                                type = "range",
                                name = L["Width"],
                                order = 1,
                                min = 50, max = 700, step = 1,
                                get = function() return (RoithiUI.db.profile.EncounterResource or {}).width or 250 end,
                                set = function(_, v)
                                    local db = RoithiUI.db.profile.EncounterResource
                                    if db then db.width = v end
                                    local bar = _G.RoithiEncounterResource
                                    if bar then bar:SetWidth(v) end
                                end,
                            },
                            height = {
                                type = "range",
                                name = L["Height"],
                                order = 2,
                                min = 4, max = 60, step = 1,
                                get = function() return (RoithiUI.db.profile.EncounterResource or {}).height or 20 end,
                                set = function(_, v)
                                    local db = RoithiUI.db.profile.EncounterResource
                                    if db then db.height = v end
                                    local bar = _G.RoithiEncounterResource
                                    if bar then bar:SetHeight(v) end
                                end,
                            },
                        },
                    },
                    fontGroup = {
                        type = "group",
                        name = L["Text"],
                        order = 20,
                        inline = true,
                        args = {
                            fontSize = {
                                type = "range",
                                name = L["Font Size"],
                                order = 1,
                                min = 6, max = 24, step = 1,
                                get = function() return (RoithiUI.db.profile.EncounterResource or {}).fontSize or 12 end,
                                set = function(_, v)
                                    local db = RoithiUI.db.profile.EncounterResource
                                    if db then db.fontSize = v end
                                    local bar = _G.RoithiEncounterResource
                                    if bar and bar.Text then
                                        local LibR = LibStub("LibRoithi-1.0")
                                        if LibR then LibR.mixins:SetFont(bar.Text, "Friz Quadrata TT", v, "OUTLINE") end
                                    end
                                end,
                            },
                            texture = {
                                type = "select",
                                dialogControl = "LSM30_Statusbar",
                                name = L["Bar Texture"],
                                order = 2,
                                values = function() return GetLSMKeys("statusbar") end,
                                get = function() return (RoithiUI.db.profile.EncounterResource or {}).texture or "Solid" end,
                                set = function(_, v)
                                    local db = RoithiUI.db.profile.EncounterResource
                                    if db then db.texture = v end
                                    local bar = _G.RoithiEncounterResource
                                    if bar then
                                        bar:SetStatusBarTexture(
                                            LSM:Fetch("statusbar", v) or "Interface\\TargetingFrame\\UI-StatusBar"
                                        )
                                    end
                                end,
                            },
                        },
                    },
                    whitelistGroup = {
                        type = "group",
                        name = L["Widget Whitelist"],
                        order = 30,
                        inline = true,
                        args = {
                            addID = {
                                type = "input",
                                name = L["Add Widget ID"],
                                desc  = L["Enter a Widget ID to whitelist it."],
                                order = 1,
                                get = function() return "" end,
                                set = function(_, v)
                                    local id = tonumber(v)
                                    if id then
                                        local db = RoithiUI.db.profile.EncounterResource
                                        if not db.whitelist then db.whitelist = {} end
                                        db.whitelist[id] = true
                                    end
                                end,
                            },
                            removeID = {
                                type = "multiselect",
                                name = L["Whitelisted IDs"],
                                desc  = L["Uncheck an ID to remove it from the whitelist."],
                                order = 2,
                                values = function()
                                    local db = RoithiUI.db.profile.EncounterResource
                                    local out = {}
                                    if db and db.whitelist then
                                        for id, _ in pairs(db.whitelist) do
                                            out[id] = tostring(id)
                                        end
                                    end
                                    return out
                                end,
                                get = function(_, key) return true end,
                                set = function(_, key, value)
                                    if not value then
                                        local db = RoithiUI.db.profile.EncounterResource
                                        if db and db.whitelist then
                                            db.whitelist[key] = nil
                                        end
                                    end
                                end,
                                confirm = true,
                                hidden = function()
                                    local db = RoithiUI.db.profile.EncounterResource
                                    return not db or not db.whitelist or next(db.whitelist) == nil
                                end,
                            },
                        },
                    },
                    posNote = {
                        type = "description",
                        name = L["\n|cffffd100Tip:|r Use Edit Mode (default key: Alt+C) to drag and reposition the bar on screen."],
                        order = 30,
                    },
                },
    }
end

local encounterBarSchema = {
    name = L["Encounter Resource Bar"],
    order = 5,
    options = (ns.GetEncounterBarOptions and ns.GetEncounterBarOptions().args) or {}
}

if ns.OptionsEngine then
    ns.OptionsEngine:RegisterModuleOptions("encounterbar", encounterBarSchema)
end

-- ============================================================================
-- EDIT MODE (LIBEDITMODE) CONFIGURATION FOR ENCOUNTER BAR
-- Single Source of Truth - Moved from Config/LEMConfig/
-- ============================================================================

local LEM = LibStub("LibEditMode-Roithi", true)
local LibRoithi = LibStub("LibRoithi-1.0", true)

local function GetEncounterDB()
    return RoithiUI.db.profile.EncounterResource
end

local function GetEncounterBar()
    return _G.RoithiEncounterResource
end

local function ApplyBarToDB()
    local db = GetEncounterDB()
    local bar = GetEncounterBar()
    if not bar or not db then return end
    bar:SetSize(db.width or 250, db.height or 20)
    if LSM then
        bar:SetStatusBarTexture(LSM:Fetch("statusbar", db.texture or "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    end
    if LibRoithi and LibRoithi.mixins then
        LibRoithi.mixins:SetFont(bar.Text, "Friz Quadrata TT", db.fontSize or 12, "OUTLINE")
    end
    bar:ClearAllPoints()
    bar:SetPoint(db.point or "TOP", UIParent, db.point or "TOP", db.x or 0, db.y or 0)
end

function ns.InitEncounterBarLEM()
    if not LEM then return end
    local bar = GetEncounterBar()
    if not bar then return end

    bar.editModeName = "Encounter Resource Bar"
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    local db = GetEncounterDB()
    local defaults = { point = db.point or "TOP", x = db.x or 0, y = db.y or 0 }

    local function OnPositionChanged(f, _, point, x, y)
        local posDB = GetEncounterDB()
        posDB.point = point
        posDB.x = math.floor(x * 100 + 0.5) / 100
        posDB.y = math.floor(y * 100 + 0.5) / 100
        f:ClearAllPoints()
        f:SetPoint(point, UIParent, point, posDB.x, posDB.y)
        LEM:RefreshFrameSettings(f)
    end

    local function GetLEMEncounterSettings()
        return {
            {
                name = "Enabled",
                kind = LEM.SettingType.Checkbox,
                default = true,
                get = function() return GetEncounterDB().enabled end,
                set = function(_, value)
                    local EB = RoithiUI:GetModule("EncounterBar")
                    if EB and EB.Toggle then
                        EB:Toggle(value)
                    end
                end,
            },
            { kind = LEM.SettingType.Divider },
            {
                name = "Width",
                kind = LEM.SettingType.Slider,
                default = 250,
                minValue = 50,
                maxValue = 700,
                valueStep = 1,
                get = function() return GetEncounterDB().width or 250 end,
                set = function(_, value)
                    GetEncounterDB().width = value; ApplyBarToDB()
                end,
                formatter = function(v) return string.format("%.0f", v) end,
            },
            {
                name = "Height",
                kind = LEM.SettingType.Slider,
                default = 20,
                minValue = 4,
                maxValue = 60,
                valueStep = 1,
                get = function() return GetEncounterDB().height or 20 end,
                set = function(_, value)
                    GetEncounterDB().height = value; ApplyBarToDB()
                end,
                formatter = function(v) return string.format("%.0f", v) end,
            },
            {
                name = "Font Size",
                kind = LEM.SettingType.Slider,
                default = 12,
                minValue = 6,
                maxValue = 24,
                valueStep = 1,
                get = function() return GetEncounterDB().fontSize or 12 end,
                set = function(_, value)
                    GetEncounterDB().fontSize = value; ApplyBarToDB()
                end,
                formatter = function(v) return string.format("%.0f", v) end,
            },
            {
                name = "X Position",
                kind = LEM.SettingType.Slider,
                default = 0,
                minValue = -2500,
                maxValue = 2500,
                valueStep = 1,
                get = function() return GetEncounterDB().x or 0 end,
                set = function(_, value)
                    GetEncounterDB().x = value; ApplyBarToDB()
                end,
                formatter = function(v) return string.format("%.0f", v) end,
            },
            {
                name = "Y Position",
                kind = LEM.SettingType.Slider,
                default = -100,
                minValue = -1500,
                maxValue = 1500,
                valueStep = 1,
                get = function() return GetEncounterDB().y or -100 end,
                set = function(_, value)
                    GetEncounterDB().y = value; ApplyBarToDB()
                end,
                formatter = function(v) return string.format("%.0f", v) end,
            },
        }
    end

    LEM:AddFrame(bar, OnPositionChanged, defaults)
    LEM:AddFrameSettings(bar, GetLEMEncounterSettings())
    bar.extraButtons = nil
    LEM:AddFrameSettingsButtons(bar, {
        {
            text = "Open Full Settings",
            click = function()
                if LibStub("AceConfigDialog-3.0") then
                    LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "encounterbar")
                    LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                end
            end
        }
    })

    LEM:RegisterCallback("enter", function()
        if GetEncounterDB().enabled then
            bar.isInEditMode = true
            bar:Show()
            bar:SetAlpha(1)
            bar:SetMinMaxValues(0, 100)
            bar:SetValue(100)
            if bar.Text then bar.Text:SetText("Encounter Resource Bar 100/100") end
        end
    end)

    LEM:RegisterCallback("exit", function()
        bar.isInEditMode = false
        bar:Hide()
    end)
end
