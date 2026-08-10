--[[
===============================================================================
ROITHIUI OPTIONS & SETTINGS SPECIFICATION (SINGLE SOURCE OF TRUTH)
===============================================================================
All option tables in RoithiUI are defined once per module schema. The OptionsEngine
processes this schema and delivers options to AceConfig-3.0 (Options UI) and
LibEditMode-Roithi (Edit Mode Right-Click Popups).

Option Schema Fields:
-------------------------------------------------------------------------------
- type        : string  - AceConfig option type ("toggle", "range", "select", "group", "execute", "header", "description")
- name        : string  - Human-readable label displayed in settings UI
- desc        : string  - Tooltip/description text (optional)
- order       : number  - Sorting order index (optional)
- scope       : string  - Target delivery context: "ace" (AceConfig only), "lem" (Edit Mode only), or "both" (default)
- get         : function(info) -> val - Getter returning the current DB value
- set         : function(info, val)  - Setter updating DB and refreshing UI state
- min / max   : number  - Minimum/Maximum for "range" (Slider) options
- step        : number  - Step value for "range" (Slider) options
- values      : table|function - Key-value map or function returning key-value map for "select" (Dropdown) options
- hidden      : boolean|function - Visibility condition for AceConfig & LEM
- formatter   : function(val) -> str - Number formatter function for LEM sliders (e.g. string.format("%.1f", v))

LEM Structural Extensions (OptionsEngine):
-------------------------------------------------------------------------------
- lemKind     : string  - LEM widget type override:
                          - "expander" / "collapsible" : Section collapsible header in Edit Mode
                          - "divider"                : Horizontal separator bar in Edit Mode
                          - "checkbox" / "slider" / "dropdown" / "colorpicker" / "colorrow"
- lemName     : string  - Display name override for Edit Mode if different from AceConfig name
- lemGet      : function(unit) -> val - Getter override for LEM context
- lemSet      : function(unit, val)  - Setter override for LEM context
- lemSubFrame : string  - Target sub-frame key on the unit frame (e.g. "Power", "ClassPower", "AdditionalPower")

Example Single-Source Option Definition:
-------------------------------------------------------------------------------
local sampleOptionSchema = {
    type = "range",
    name = "Frame Width",
    desc = "Adjust the horizontal width of the frame",
    order = 10,
    scope = "both", -- Available in both AceConfig and Edit Mode
    min = 50,
    max = 400,
    step = 1,
    get = function() return RoithiUI.db.profile.UnitFrames["player"].width or 200 end,
    set = function(_, v)
        RoithiUI.db.profile.UnitFrames["player"].width = v
        ns.RefreshUnitFrame("player")
    end,
    formatter = function(v) return string.format("%.0f", v) end,
}
===============================================================================
--]]

local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local Config = RoithiUI.Config or {}
RoithiUI.Config = Config
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI", true)

--- Safe number parser for secret values
local SafeNum = function(val, default)
    if val == nil or (issecretvalue and issecretvalue(val)) then
        return default or 0
    end
    local num = tonumber(val)
    return num or default or 0
end
ns.SafeNum = SafeNum

--- Refresh Helpers
function ns.RefreshUnitFrame(unit)
    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
    if UF and UF.UpdateFrameFromSettings then
        UF:UpdateFrameFromSettings(unit)
    end
end

function ns.RefreshAllUnitFrames()
    local UF = RoithiUI:GetModule("UnitFrames") --[[@as UF]]
    if UF and UF.units then
        for unit in pairs(UF.units) do
            ns.RefreshUnitFrame(unit)
        end
    end
    if UF and UF.UpdateAllCustomAuras then
        UF:UpdateAllCustomAuras()
    end
end

local ACE_WHITELIST = {
    type = true, name = true, desc = true, order = true, width = true,
    hidden = true, disabled = true, get = true, set = true, icon = true,
    iconCoords = true, control = true, dialogControl = true, min = true,
    max = true, step = true, bigStep = true, isPercent = true, values = true,
    sorting = true, style = true, cmdHidden = true, guiHidden = true,
    dropdownHidden = true, cmdName = true, guiName = true, confirm = true,
    confirmText = true, func = true, args = true, pattern = true,
    multiline = true, tristate = true, image = true, imageWidth = true,
    imageHeight = true, imageCoords = true, inline = true, handler = true,
}

local function DeepCopyTable(tbl)
    if type(tbl) ~= "table" then return tbl end
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            copy[k] = DeepCopyTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function CleanOptionsTableForAceConfig(tbl)
    if type(tbl) ~= "table" then return end
    for _, item in pairs(tbl) do
        if type(item) == "table" then
            for prop in pairs(item) do
                if not ACE_WHITELIST[prop] then
                    item[prop] = nil
                end
            end
            if item.args and type(item.args) == "table" then
                CleanOptionsTableForAceConfig(item.args)
            end
        end
    end
end

local function GetOptions()
    local profileOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(RoithiUI.db)
    if profileOptions and profileOptions.args and ns.GetProfileSharingOptions then
        profileOptions.args.sharing = ns.GetProfileSharingOptions()
    end
    
    local rawOptions = {
        type = "group",
        name = L["RoithiUI Settings"],
        args = {
            general = ns.GetGeneralOptions and ns.GetGeneralOptions() or {
                type = "group",
                name = L["General"],
                order = 1,
                args = {},
            },
            unitframes = {
                type = "group",
                name = L["Unit Frames"],
                order = 2,
                args = {
                    intro = {
                        type = "description",
                        name = L["Configure text, auras, and indicators for Unit Frames."],
                        order = 1,
                    },
                },
            },
            customtags = RoithiUI.Config.GetCustomTagsOptions and RoithiUI.Config.GetCustomTagsOptions() or nil,
            castbars = {
                type = "group",
                name = L["Castbars"],
                order = 3,
                args = ns.GetCastbarOptions and ns.GetCastbarOptions() or {},
            },
            auras = ns.GetAurasOptions and ns.GetAurasOptions() or {
                type = "group",
                name = L["Auras"],
                order = 4,
                args = {},
            },
            encounterbar = ns.GetEncounterBarOptions and (ns.GetEncounterBarOptions().encounterbar or ns.GetEncounterBarOptions()) or nil,
        }
    }

    if ns.BuildUnitAndCastbarOptions then
        ns.BuildUnitAndCastbarOptions(rawOptions)
    end

    if ns.OptionsEngine and ns.OptionsEngine.CompileAceConfig then
        local compiled = ns.OptionsEngine:CompileAceConfig()
        for k, v in pairs(compiled) do
            if not rawOptions.args[k] then
                rawOptions.args[k] = v
            end
        end
    end

    local options = DeepCopyTable(rawOptions)
    CleanOptionsTableForAceConfig(options.args)
    options.args.profiles = profileOptions
    return options
end

function Config:RegisterOptions()
    -- Build options early to populate OptionsEngine schemas for Edit Mode
    pcall(GetOptions)

    local AC = LibStub("AceConfig-3.0", true)
    local ACD = LibStub("AceConfigDialog-3.0", true)

    if AC and ACD then
        AC:RegisterOptionsTable("RoithiUI", GetOptions)
        if not self.optionsFrame then
            local success, frame, categoryID = pcall(ACD.AddToBlizOptions, ACD, "RoithiUI", "RoithiUI")
            if success then
                self.optionsFrame = frame
                RoithiUI.SettingsCategoryID = categoryID
            end
        end
    else
        print("RoithiUI: AceConfig-3.0 not found. Detailed options disabled.")
    end
end
