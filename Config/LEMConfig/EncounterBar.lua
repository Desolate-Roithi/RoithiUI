local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local LEM = LibStub("LibEditMode-Roithi", true)
local LibRoithi = LibStub("LibRoithi-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

if not LEM then return end

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────
local function GetDB()
    return RoithiUI.db.profile.EncounterResource
end

local function GetBar()
    return _G.RoithiEncounterResource
end

local function ApplyBarToDB()
    local db = GetDB()
    local bar = GetBar()
    if not bar or not db then return end
    bar:SetSize(db.width or 250, db.height or 20)
    bar:SetStatusBarTexture(LSM:Fetch("statusbar", db.texture or "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    LibRoithi.mixins:SetFont(bar.Text, "Friz Quadrata TT", db.fontSize or 12, "OUTLINE")
    bar:ClearAllPoints()
    bar:SetPoint(db.point or "TOP", UIParent, db.point or "TOP", db.x or 0, db.y or 0)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- LEM Settings
-- ─────────────────────────────────────────────────────────────────────────────
local function GetSettings()
    return {
        {
            name = "Enabled",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function() return GetDB().enabled end,
            set = function(_, value)
                local EB = RoithiUI:GetModule("EncounterBar")
                if EB and EB.Toggle then
                    EB:Toggle(value)
                end
            end,
        },
        {
            kind = LEM.SettingType.Divider,
        },
        {
            name = "Width",
            kind = LEM.SettingType.Slider,
            default = 250,
            minValue = 50,
            maxValue = 700,
            valueStep = 1,
            get = function() return GetDB().width or 250 end,
            set = function(_, value)
                GetDB().width = value; ApplyBarToDB()
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
            get = function() return GetDB().height or 20 end,
            set = function(_, value)
                GetDB().height = value; ApplyBarToDB()
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
            get = function() return GetDB().fontSize or 12 end,
            set = function(_, value)
                GetDB().fontSize = value; ApplyBarToDB()
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
            get = function() return GetDB().x or 0 end,
            set = function(_, value)
                GetDB().x = value; ApplyBarToDB()
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
            get = function() return GetDB().y or -100 end,
            set = function(_, value)
                GetDB().y = value; ApplyBarToDB()
            end,
            formatter = function(v) return string.format("%.0f", v) end,
        },
    }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Registration — called once the bar frame exists
-- ─────────────────────────────────────────────────────────────────────────────
function ns.InitEncounterBarLEM()
    local bar = GetBar()
    if not bar then return end

    bar.editModeName = "Encounter Resource Bar"

    local db = GetDB()
    local defaults = { point = db.point or "TOP", x = db.x or 0, y = db.y or 0 }

    local function OnPositionChanged(f, _, point, x, y)
        local posDB = GetDB()
        posDB.point = point
        posDB.x = math.floor(x * 100 + 0.5) / 100
        posDB.y = math.floor(y * 100 + 0.5) / 100
        f:ClearAllPoints()
        f:SetPoint(point, UIParent, point, posDB.x, posDB.y)
        LEM:RefreshFrameSettings(f)
    end

    LEM:AddFrame(bar, OnPositionChanged, defaults)
    LEM:AddFrameSettings(bar, GetSettings())
    LEM:AddFrameSettingsButtons(bar, {
        {
            text = "Open Full Settings",
            click = function()
                if LibStub("AceConfigDialog-3.0") then
                    LibStub("AceConfigDialog-3.0"):SelectGroup("RoithiUI", "encounterbar")
                    LibStub("AceConfigDialog-3.0"):Open("RoithiUI")
                end
            end,
        }
    })
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Edit Mode enter/exit callbacks
-- ─────────────────────────────────────────────────────────────────────────────
LEM:RegisterCallback("enter", function()
    local bar = GetBar()
    local db = GetDB()
    if not bar or not db then return end

    bar.isInEditMode = true
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(75)
    bar:SetStatusBarColor(0.2, 0.8, 1.0)
    bar.Text:SetText("ENCOUNTER BAR")
    bar:Show()
    LEM:RefreshFrameSettings(bar)
end)

LEM:RegisterCallback("exit", function()
    local bar = GetBar()
    if not bar then return end
    bar.isInEditMode = false
    
    if bar.Update then
        bar:Update()
    else
        bar:Hide()
    end
end)
