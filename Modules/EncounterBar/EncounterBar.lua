local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local LibRoithi = LibStub("LibRoithi-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- Globals for luacheck
local IsEncounterInProgress = _G.IsEncounterInProgress
local issecretvalue = _G.issecretvalue

local EB = RoithiUI:NewModule("EncounterBar", "AceEvent-3.0", "AceConsole-3.0")

-- Blizzard source constant: ALTERNATE_POWER_INDEX = 10
-- Do NOT use Enum.PowerType.Alternate — it does not exist in 12.0.1.
local ALTERNATE_POWER_INDEX = 10

-- ─────────────────────────────────────────────────────────────────────────────
local WHITELISTED_TITLES = {
    ["Abyss Diver"] = true,
    ["Oxygen"] = true,
}

local WHITELISTED_IDS = {
    [4604] = true, -- Abyss Angling Oxygen Bar (Active)
}

local WIDGET_BLACKLIST = {
    [7372] = true, -- Hidden Encounter Timer / Abyss Background Widget
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Blizzard PlayerPowerBarAlt toggle helper
-- Suppresses the native bar while our custom one is active.
-- ─────────────────────────────────────────────────────────────────────────────
local function ToggleBlizzard(enableCustom)
    if not PlayerPowerBarAlt then return end

    if enableCustom then
        PlayerPowerBarAlt:UnregisterEvent("UNIT_POWER_BAR_SHOW")
        PlayerPowerBarAlt:Hide()

        -- Prevent OnUpdate crash by removing the script entirely
        if not PlayerPowerBarAlt.RoithiOriginalOnUpdate then
            PlayerPowerBarAlt.RoithiOriginalOnUpdate = PlayerPowerBarAlt:GetScript("OnUpdate")
        end
        PlayerPowerBarAlt:SetScript("OnUpdate", nil)

        -- Prevent re-showing via hook
        if not PlayerPowerBarAlt.RoithiHookedShow then
            hooksecurefunc(PlayerPowerBarAlt, "Show", function(self)
                if RoithiUI.db.profile.EncounterResource and RoithiUI.db.profile.EncounterResource.enabled then
                    self:Hide()
                end
            end)
            PlayerPowerBarAlt.RoithiHookedShow = true
        end

        -- Suppression removed to fix missing overlays in Hide and Seek mode
    else
        -- Restore Blizzard bar
        if PlayerPowerBarAlt.RoithiOriginalOnUpdate then
            PlayerPowerBarAlt:SetScript("OnUpdate", PlayerPowerBarAlt.RoithiOriginalOnUpdate)
            PlayerPowerBarAlt.RoithiOriginalOnUpdate = nil
        end

        PlayerPowerBarAlt:RegisterEvent("UNIT_POWER_BAR_SHOW")
        if UnitPowerBarID("player") then
            -- FIX: Force initialization so 'barInfo' exists before OnUpdate runs
            local onEvent = PlayerPowerBarAlt:GetScript("OnEvent")
            if onEvent then
                onEvent(PlayerPowerBarAlt, "UNIT_POWER_BAR_SHOW", "player")
            end
            if PlayerPowerBarAlt.barInfo then
                PlayerPowerBarAlt:Show()
            end
        end
        if UIWidgetPowerBarContainerFrame then
            UIWidgetPowerBarContainerFrame:Show()
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Toggle Function (External Access)
-- ─────────────────────────────────────────────────────────────────────────────
function EB:Toggle(enabled)
    if not RoithiUI.db.profile.EncounterResource then
        RoithiUI.db.profile.EncounterResource = {
            enabled  = true,
            width    = 250,
            height   = 20,
            fontSize = 12,
            texture  = "Solid",
            point    = "TOP",
            x        = 0,
            y        = -100,
        }
    end

    local db = RoithiUI.db.profile.EncounterResource
    db.enabled = enabled

    local encounterBar = _G.RoithiEncounterResource

    if enabled then
        ToggleBlizzard(true)
        if encounterBar then
            encounterBar:RegisterEvent("PLAYER_ENTERING_WORLD")
            encounterBar:RegisterEvent("ZONE_CHANGED_NEW_AREA")
            encounterBar:RegisterEvent("ZONE_CHANGED")
            encounterBar:RegisterEvent("PLAYER_DEAD")
            encounterBar:RegisterEvent("PLAYER_ALIVE")
            encounterBar:RegisterEvent("UPDATE_ALL_UI_WIDGETS")
            encounterBar:RegisterEvent("UPDATE_UI_WIDGET")
            encounterBar:RegisterUnitEvent("UNIT_POWER_BAR_SHOW", "player")
            encounterBar:RegisterUnitEvent("UNIT_POWER_BAR_HIDE", "player")
            encounterBar:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
            encounterBar:RegisterUnitEvent("UNIT_MAXPOWER", "player")
            if encounterBar.Update then encounterBar:Update() end
        end
    else
        ToggleBlizzard(false)
        if encounterBar then
            encounterBar:UnregisterAllEvents()
            encounterBar:Hide()
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- UIWidget power bar path
-- Handles 12.0.5+ world encounter bars (e.g. Oxygen for Abyss Angling).
-- These are NOT delivered via PlayerPowerBarAlt / UnitPowerBarID.
-- ─────────────────────────────────────────────────────────────────────────────

-- Drive widget scan when entering world or full refresh requested.
-- The UIWidget path will be re-driven when individual widgets update via UPDATE_UI_WIDGET.

local function UpdateFromWidget(s, widgetInfo)
    if not widgetInfo then return end

    -- Prevent blacklisted widgets from showing
    if WIDGET_BLACKLIST[widgetInfo.widgetID] then return end

    -- Prioritization: If we are already tracking the active Oxygen bar (4604),
    -- don't let static background widgets (like 7372) overwrite it.
    if s.hasWidgetID == 4604 and widgetInfo.widgetID ~= 4604 then
        return
    end

    local db = RoithiUI.db.profile.EncounterResource
    local widgetDebug = db and db.widgetDebug
    if widgetDebug then
        print("|cff00ccff[EB Debug]|r [UpdateFromWidget] ID: " ..
            tostring(widgetInfo.widgetID) .. " Type: " .. tostring(widgetInfo.widgetType))
    end

    local info
    if widgetInfo.widgetType == Enum.UIWidgetVisualizationType.UnitPowerBar or widgetInfo.widgetType == 23 then
        info = C_UIWidgetManager.GetUnitPowerBarWidgetVisualizationInfo(widgetInfo.widgetID)
    elseif widgetInfo.widgetType == Enum.UIWidgetVisualizationType.StatusBar or widgetInfo.widgetType == 2 then
        info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(widgetInfo.widgetID)
    elseif widgetInfo.widgetType == 24 then -- FillUpFrames (Oxygen/Vigor)
        info = C_UIWidgetManager.GetFillUpFramesWidgetVisualizationInfo(widgetInfo.widgetID)
    end

    -- Fallback for whitelisted IDs if type-specific call failed
    if not info and WHITELISTED_IDS[widgetInfo.widgetID] then
        info = C_UIWidgetManager.GetUnitPowerBarWidgetVisualizationInfo(widgetInfo.widgetID)
            or C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(widgetInfo.widgetID)
            or C_UIWidgetManager.GetFillUpFramesWidgetVisualizationInfo(widgetInfo.widgetID)
    end

    -- 1. Identify Whitelist Status
    local nameText = info and (info.barLabel or info.text) or ""
    local isWhitelisted = WHITELISTED_IDS[widgetInfo.widgetID] or
    (db and db.whitelist and db.whitelist[widgetInfo.widgetID])
    local isTitleWhitelisted = WHITELISTED_TITLES[nameText]

    if widgetDebug then
        if not info then
            print("|cff00ccff[EB Debug]|r [UpdateFromWidget] FAILED to get info for ID: " ..
            tostring(widgetInfo.widgetID))
        else
            print(string.format(
                "|cff00ccff[EB Debug]|r [UpdateFromWidget] ID: %d shownState: %d Title: '%s' Whitelisted: %s",
                widgetInfo.widgetID, info.shownState or -1, nameText, tostring(isWhitelisted or isTitleWhitelisted)))
        end
    end


    -- 2. Calculate values (min, max, val)
    local min, max, val = 0, 0, 0
    if info then
        if widgetInfo.widgetType == 24 and info.numTotalFrames then
            local unitMax = (info.fillMax and info.fillMax > 0) and info.fillMax or 1
            max = info.numTotalFrames or 1
            val = (info.numFullFrames or 0) + (info.fillValue or 0) / unitMax

            -- Raw value mode detection (e.g. Oxygen timer)
            if (info.numFullFrames or 0) > (info.numTotalFrames or 0) then
                max = (info.numTotalFrames or 1) * unitMax
            end
        else
            min = info.barMin or info.fillMin or 0
            max = info.barMax or info.fillMax or 0
            val = info.barValue or info.fillValue or 0
        end
    end

    -- Simplified Log Mode (only for bars)
    if db and db.widgetLogMode and not WIDGET_BLACKLIST[widgetInfo.widgetID] then
        if info and (widgetInfo.widgetType == 2 or widgetInfo.widgetType == 24 or widgetInfo.widgetType == 23) then
            print(string.format("|cff00ccff[EB Log]|r ID: %d | Set: %d | Title: '%s' | Val: %s / %s (Min: %s)",
                widgetInfo.widgetID, widgetInfo.widgetSetID or -1, nameText or "None", tostring(val), tostring(max),
                tostring(min)))
        end
    end

    -- 3. Handle Visibility
    local isHidden = not info or (info.shownState == Enum.WidgetShownState.Hidden)
    if isHidden then
        -- Whitelisted widgets (like Oxygen ID 4604) sometimes report Hidden (0) while active.
        -- However, Blizzard fires UNIT_POWER_BAR_HIDE when the event is truly over.
        -- We check if we recently got a hide signal to avoid re-showing a stale widget.
        local timeSinceHide = GetTime() - (s.lastHideTime or 0)
        local isRecentHide = timeSinceHide < 2.0 -- 2 second grace period for stale widget events

        local shouldBypassHide = (isWhitelisted or isTitleWhitelisted) and info and max > 0 and not isRecentHide
        if not shouldBypassHide then
            if not UnitPowerBarID("player") then
                s.hasWidgetID = nil
                s:Hide()
            end
            return
        end
    end

    -- 4. Opt-in logic for Widgets outside of Boss Encounters
    if not IsEncounterInProgress() and not s.isInEditMode then
        if not isWhitelisted and not isTitleWhitelisted then
            s.hasWidgetID = nil
            s:Hide()
            return
        end
    end

    if db and db.widgetDebug then
        print(string.format("|cff00ccff[EB Debug]|r [UpdateFromWidget] ID: %d Max: %s Val: %s",
            widgetInfo.widgetID, tostring(max), tostring(val)))
    end

    if widgetInfo.widgetID == 4604 then
        nameText = "Oxygen"
        -- Workaround: Capture the first seen value as the Max so it starts at 100%
        if not s.oxygenMax or s.oxygenMax == 0 then
            s.oxygenMax = val
        end
        if s.oxygenMax and s.oxygenMax > 0 then
            max = s.oxygenMax
        end
    end

    s:SetMinMaxValues(min or 0, max or 100)
    s:SetValue(val or 0)

    -- Set standard color (Light Blue) for all widgets to ensure readability
    s:SetStatusBarColor(0, 0.6, 1)
    s.hasWidgetColor = true

    local pct = (max and max > 0) and (val / max * 100) or 0
    s.Text:SetText(string.format("%s: %.0f%%", nameText, pct))

    s.hasWidgetID = widgetInfo.widgetID -- Track current source
    s.hasWidgetType = widgetInfo.widgetType
    s:Show()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Core Update — PlayerPowerBarAlt path
-- ─────────────────────────────────────────────────────────────────────────────
local function Update(s)
    local db = RoithiUI.db.profile.EncounterResource
    if not db or not db.enabled then
        s:Hide()
        return
    end

    -- 1. Check Widgets first (if we are tracking one)
    if s.hasWidgetID then
        local info
        if s.hasWidgetType == Enum.UIWidgetVisualizationType.UnitPowerBar then
            info = C_UIWidgetManager.GetUnitPowerBarWidgetVisualizationInfo(s.hasWidgetID)
        elseif s.hasWidgetType == Enum.UIWidgetVisualizationType.StatusBar then
            info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(s.hasWidgetID)
        elseif s.hasWidgetType == 24 then
            info = C_UIWidgetManager.GetFillUpFramesWidgetVisualizationInfo(s.hasWidgetID)
        end

        if not info or (info.shownState == Enum.WidgetShownState.Hidden) then
            s.hasWidgetID = nil
            s.hasWidgetType = nil
            -- Fall through to check PlayerPowerBarAlt
        else
            local min, max, val
            if s.hasWidgetType == 24 and info.numTotalFrames then
                local unitMax = (info.fillMax and info.fillMax > 0) and info.fillMax or 1
                if (info.numFullFrames or 0) > (info.numTotalFrames or 0) then
                    val = (info.numFullFrames or 0) + (info.fillValue or 0) / unitMax
                    max = (info.numTotalFrames or 1) * unitMax
                    min = 0

                    local aura = C_UnitAuras.GetPlayerAuraBySpellID(1225598)
                    if aura and aura.duration and aura.duration > 0 then
                        max = aura.duration
                    end
                else
                    min = 0
                    max = info.numTotalFrames or 1
                    val = (info.numFullFrames or 0) + (info.fillValue or 0) / unitMax
                end
            else
                min = info.barMin or info.fillMin or 0
                max = info.barMax or info.fillMax or 100
                val = info.barValue or info.fillValue or 0
            end
            local pct = (max > 0) and (val / max * 100) or 0
            s:SetMinMaxValues(min, max)
            s:SetValue(val)

            -- Keep the text updated with percentage if it was set by widget
            if s.Text:GetText() and s.Text:GetText():find(":") then
                local prefix = s.Text:GetText():match("^(.-):")
                s.Text:SetText(string.format("%s: %.0f%%", prefix, pct))
            end
            return
        end
    end

    -- 2. Check Alternate Power
    local barID = UnitPowerBarID("player")

    if not barID or barID == 0 then
        s:Hide()
        return
    end

    local info = GetUnitPowerBarInfo("player")
    local nameText = info and (info.name or info.barLabel) or ""

    -- Unified Blacklist Check Removed (Now using Opt-in/Boss bypass)

    -- STRICT REQUIREMENT: Hide if no name exists (background mechanics)
    if (not nameText or nameText == "") and not s.isInEditMode then
        s:Hide()
        return
    end

    if not info or (not info.showBar and not s.isInEditMode) then
        s:Hide()
        return
    end

    if not info and s.isInEditMode then
        s:SetMinMaxValues(0, 100)
        s:SetValue(75)
        s:Show()
        s.Text:SetText("Encounter Bar")
        s:SetStatusBarColor(1, 0, 1)
        return
    end

    local ok1, current = pcall(UnitPower, "player", ALTERNATE_POWER_INDEX)
    if not ok1 then current = 0 end
    local ok2, max = pcall(UnitPowerMax, "player", ALTERNATE_POWER_INDEX)
    if not ok2 then max = 0 end

    local currentIsSecret = issecretvalue and issecretvalue(current)
    local maxIsSecret = issecretvalue and issecretvalue(max)
    local isSecret = currentIsSecret or maxIsSecret

    local hasPower = false
    if maxIsSecret then
        hasPower = true
    elseif type(max) == "number" and max > 0 then
        hasPower = true
    end

    if hasPower then
        s:SetMinMaxValues(0, max)
        s:SetValue(current)
        s:Show()

        local barName = nil
        if _G.GetUnitPowerBarStrings then
            local n1 = _G.GetUnitPowerBarStrings("player")
            local n2 = _G.GetUnitPowerBarStrings(barID)
            barName = n1 or n2
        end

        isSecret = isSecret or (issecretvalue and issecretvalue(current))
        local currentStr

        if isSecret and _G.UnitPowerPercent then
            local curve = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or 0
            local success, pct = pcall(function()
                return _G.UnitPowerPercent("player", ALTERNATE_POWER_INDEX, false, curve)
            end)

            if success and pct then
                currentStr = string.format("%.0f%%", pct)
            else
                currentStr = "..."
            end
        else
            currentStr = LibRoithi.mixins:SafeFormat("%d / %d", current, max)
        end

        if barName and barName ~= "" then
            s.Text:SetText(barName .. ": " .. (currentStr or ""))
        else
            s.Text:SetText(currentStr or "")
        end
    else
        s:Hide()
    end

    -- Color: use bar-defined color, fall back to Deep Sky Blue
    -- Standard Color: Light Blue for all bars to ensure white text is readable
    s:SetStatusBarColor(0, 0.6, 1)

    -- Final Safety: If we have no data and no text, don't show an empty bar
    local currentText = s.Text:GetText()
    if (not currentText or currentText == "") then
        s:Hide()
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Smart OnEvent dispatcher
-- ─────────────────────────────────────────────────────────────────────────────
local function OnEvent(s, event, arg1, arg2)
    local db = RoithiUI.db.profile.EncounterResource
    local widgetDebug = db and db.widgetDebug
    if widgetDebug then
        print("|cff00ccff[EB Debug]|r [OnEvent] Fired: " .. tostring(event) .. " arg1: " .. tostring(arg1))
    end

    -- UNIT_POWER_BAR_HIDE → immediate hide
    if event == "UNIT_POWER_BAR_HIDE" then
        if arg1 == nil or arg1 == "player" then
            s.hasWidgetID = nil
            s.hasWidgetColor = false
            s.lastHideTime = GetTime()
            s.oxygenMax = nil
            s:Hide()
        end
        return
    end

    -- UNIT_POWER_UPDATE → only relevant for ALTERNATE power type
    if event == "UNIT_POWER_UPDATE" then
        if arg2 ~= "ALTERNATE" then return end
        Update(s)
        return
    end

    -- UNIT_MAXPOWER → only relevant for ALTERNATE power type
    if event == "UNIT_MAXPOWER" then
        if arg2 ~= "ALTERNATE" then return end
        Update(s)
        return
    end

    -- UPDATE_UI_WIDGET → UIWidget power bar path (oxygen bar, etc.)
    -- arg1 is the widgetInfo table: { widgetSetID, widgetID, widgetType, unit }
    if event == "UPDATE_UI_WIDGET" then
        if widgetDebug then
            print(string.format("|cff00ccff[EB Debug]|r [OnEvent] UPDATE_UI_WIDGET fired | ID: %s | SetID: %s",
                tostring(arg1 and arg1.widgetID), tostring(arg1 and arg1.widgetSetID)))
        end
        UpdateFromWidget(s, arg1)
        return
    end

    if event == "UPDATE_ALL_UI_WIDGETS" or event == "PLAYER_ENTERING_WORLD" or event:find("ZONE_CHANGED") or event:find("PLAYER_") then
        s.hasWidgetID = nil
        s.hasWidgetColor = false
        s.oxygenMax = nil
        Update(s)
        -- Individual widget updates will fire UPDATE_UI_WIDGET separately
        return
    end

    -- UNIT_POWER_BAR_SHOW, fallthrough → full update
    Update(s)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- CreateEncounterResource
-- ─────────────────────────────────────────────────────────────────────────────
function EB:OnInitialize()
    -- Check if module is disabled
    local profile = RoithiUI.db.profile
    if profile.EnabledModules and profile.EnabledModules.EncounterBar == false then
        self:Disable()
        return
    end

    -- Ensure DB has full defaults
    if not RoithiUI.db.profile.EncounterResource then
        RoithiUI.db.profile.EncounterResource = {
            enabled       = true,
            width         = 250,
            height        = 20,
            fontSize      = 12,
            texture       = "Solid",
            point         = "TOP",
            x             = 0,
            y             = -100,
            widgetDebug   = false,
            widgetLogMode = false,
            whitelist     = {},
        }
    end
    local db = RoithiUI.db.profile.EncounterResource

    -- Fill any missing keys (for older save data)
    if not db.point then db.point = "TOP" end
    if not db.x then db.x = 0 end
    if not db.y then db.y = -100 end
    if not db.width then db.width = 250 end
    if not db.height then db.height = 20 end
    if not db.fontSize then db.fontSize = 12 end
    if not db.texture then db.texture = "Solid" end
    if db.widgetDebug == nil then db.widgetDebug = false end
    if db.widgetLogMode == nil then db.widgetLogMode = false end
    if not db.whitelist then db.whitelist = {} end

    -- Slash Command
    self:RegisterChatCommand("reb", "ChatCommand")
    self:RegisterChatCommand("encounterbar", "ChatCommand")

    -- Guard against double-creation
    if _G.RoithiEncounterResource then return end

    -- Create the standalone bar (parented to UIParent)
    local encounterBar = CreateFrame("StatusBar", "RoithiEncounterResource", UIParent)
    encounterBar:SetSize(db.width, db.height)
    encounterBar:SetStatusBarTexture(
        LSM:Fetch("statusbar", db.texture) or "Interface\\TargetingFrame\\UI-StatusBar"
    )
    encounterBar:SetPoint(db.point, UIParent, db.point, db.x, db.y)

    LibRoithi.mixins:CreateBackdrop(encounterBar)

    local bg = encounterBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(LSM:Fetch("statusbar", "Solid") or "Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(0.1, 0.1, 0.1)
    encounterBar.bg = bg

    local text = encounterBar:CreateFontString(nil, "OVERLAY")
    LibRoithi.mixins:SetFont(text, "Friz Quadrata TT", db.fontSize, "OUTLINE")
    text:SetPoint("CENTER", encounterBar, "CENTER", 0, 0)
    encounterBar.Text = text

    encounterBar:Hide()

    -- Wire Update and OnEvent
    encounterBar.Update = function(barSelf) Update(barSelf) end
    encounterBar:SetScript("OnEvent", OnEvent)

    -- Register with LibEditMode
    self:InitLEM()
end

function EB:OnEnable()
    local db = RoithiUI.db.profile.EncounterResource
    self:Toggle(db.enabled)
end

function EB:OnDisable()
    self:Toggle(false)
end

function EB:ChatCommand(input)
    local db = RoithiUI.db.profile.EncounterResource
    if input == "debug" then
        db.widgetDebug = not db.widgetDebug
        RoithiUI:Print("EncounterBar Widget Debug: " ..
            (db.widgetDebug and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
    elseif input == "widgets" then
        db.widgetLogMode = not db.widgetLogMode
        RoithiUI:Print("EncounterBar Widget Log Mode: " ..
            (db.widgetLogMode and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
    else
        RoithiUI:Print("Usage: /reb [debug | widgets]")
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Module Metadata & Options Registry
-- ─────────────────────────────────────────────────────────────────────────────
local localeLib = LibStub("AceLocale-3.0", true)
local L = localeLib and localeLib:GetLocale("RoithiUI", true) or setmetatable({}, { __index = function(_, k) return k end })

EB.dbKey = "EncounterResource"
EB.displayName = L["Encounter Bar (Alt Power)"]
EB.description = L["Enables RoithiUI custom alternative power bar and encounter power widgets."]
EB.order = 30

EB.defaultSettings = {
    enabled  = true,
    width    = 250,
    height   = 20,
    fontSize = 12,
    texture  = "Solid",
    point    = "TOP",
    x        = 0,
    y        = -100,
}

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

local settingsSchema = {
    {
        key = "enabled",
        name = L["Enable"],
        type = "toggle",
        default = true,
        showIn = "options",
        set = function(_, v)
            local db = GetDB()
            if db then db.enabled = v end
            EB:Toggle(v)
        end,
    },
    {
        key = "width",
        name = L["Width"],
        type = "range",
        default = 250,
        min = 50,
        max = 700,
        step = 1,
        showIn = "both",
    },
    {
        key = "height",
        name = L["Height"],
        type = "range",
        default = 20,
        min = 4,
        max = 60,
        step = 1,
        showIn = "both",
    },
    {
        key = "fontSize",
        name = L["Font Size"],
        type = "range",
        default = 12,
        min = 6,
        max = 24,
        step = 1,
        showIn = "both",
    },
    {
        key = "texture",
        name = L["Bar Texture"],
        type = "select",
        default = "Solid",
        values = function()
            local list = LSM:List("statusbar")
            local out = {}
            for _, name in ipairs(list) do
                out[name] = name
            end
            return out
        end,
        showIn = "options",
    },
    {
        key = "x",
        name = L["X Position"],
        type = "range",
        default = 0,
        min = -2500,
        max = 2500,
        step = 1,
        showIn = "both",
    },
    {
        key = "y",
        name = L["Y Position"],
        type = "range",
        default = -100,
        min = -1500,
        max = 1500,
        step = 1,
        showIn = "both",
    },
}

local extraOptions = {
    intro = {
        type = "description",
        name = L["Configure the custom Encounter Resource Bar. Position it via LibEditMode (Edit Mode)."],
        order = 0,
    },
    whitelistGroup = {
        type = "group",
        name = L["Widget Whitelist"],
        order = 30,
        inline = true,
        args = {
            addID = {
                type  = "input",
                name  = L["Add Widget ID"],
                desc  = L["Enter a Widget ID to whitelist it."],
                order = 1,
                get   = function() return "" end,
                set   = function(_, v)
                    local id = tonumber(v)
                    if id then
                        local db = GetDB()
                        if not db.whitelist then db.whitelist = {} end
                        db.whitelist[id] = true
                    end
                end,
            },
            removeID = {
                type    = "multiselect",
                name    = L["Whitelisted IDs"],
                desc    = L["Uncheck an ID to remove it from the whitelist."],
                order   = 2,
                values  = function()
                    local db = GetDB()
                    local out = {}
                    if db and db.whitelist then
                        for id, _ in pairs(db.whitelist) do
                            out[id] = tostring(id)
                        end
                    end
                    return out
                end,
                get     = function(_, key) return true end,
                set     = function(_, key, value)
                    if not value then
                        local db = GetDB()
                        if db and db.whitelist then
                            db.whitelist[key] = nil
                        end
                    end
                end,
                confirm = true,
                hidden  = function()
                    local db = GetDB()
                    return not db or not db.whitelist or next(db.whitelist) == nil
                end,
            },
        },
    },
    posNote = {
        type = "description",
        name = L["\n|cffffd100Tip:|r Use Edit Mode (default key: Alt+C) to drag and reposition the bar on screen."],
        order = 40,
    },
}

function EB:GetOptions()
    return {
        type = "group",
        name = L["Encounter Resource Bar"],
        order = 5,
        hidden = function()
            local db = RoithiUI.db.profile
            return not db.EnabledModules or db.EnabledModules.EncounterBar == false
        end,
        args = RoithiUI.OptionGenerator:GenerateAceConfig(settingsSchema, GetDB, ApplyBarToDB, extraOptions)
    }
end

function EB:InitLEM()
    local bar = GetBar()
    if not bar then return end

    bar.editModeName = "Encounter Resource Bar"

    local db = GetDB()
    local defaults = { point = db.point or "TOP", x = db.x or 0, y = db.y or 0 }

    local LEM = LibStub("LibEditMode-Roithi", true)
    if not LEM then return end

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

    local settings = RoithiUI.OptionGenerator:GenerateLEMConfig(settingsSchema, GetDB, ApplyBarToDB, LEM)
    LEM:AddFrameSettings(bar, settings)

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

    -- Register callbacks
    LEM:RegisterCallback("enter", function()
        bar.isInEditMode = true
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(75)
        bar:SetStatusBarColor(0.2, 0.8, 1.0)
        bar.Text:SetText("ENCOUNTER BAR")
        bar:Show()
        LEM:RefreshFrameSettings(bar)
    end)

    LEM:RegisterCallback("exit", function()
        bar.isInEditMode = false
        if bar.Update then
            bar:Update()
        else
            bar:Hide()
        end
    end)
end
